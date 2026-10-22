#!/usr/bin/env bash
# Installation d'OpenSimulator 0.9.3.0 (monde Cyberpunk) sur Linux.
# Voir README_install.md pour le détail des étapes et des options.
set -euo pipefail

OPENSIM_VERSION="0.9.3.0"
INSTALL_ROOT="${INSTALL_ROOT:-$HOME/JEUX/SECONDLIFE}"
DIST_URL="http://opensimulator.org/dist/opensim-${OPENSIM_VERSION}.tar.gz"
SOURCE_URL="http://opensimulator.org/dist/opensim-${OPENSIM_VERSION}-source.tar.gz"
DOTNET_DIR="${DOTNET_DIR:-$HOME/.dotnet}"
DOTNET_CHANNEL="8.0"

REGION_NAME="Cyberpunk"
REGION_PORT="9000"
REGION_LOCATION="1000,1000"
SKIP_DEPS=0
SKIP_BUILD=0
SETUP_PROFILE=0

usage() {
    cat <<EOF
Usage : $0 [options]

  --skip-deps          Ne pas installer libgdiplus (apt)
  --dir REPERTOIRE     Répertoire d'installation (défaut : ~/JEUX/SECONDLIFE)
  --skip-build         Ne pas compiler : utiliser les DLL de la distribution binaire
  --region NOM         Nom de la région à créer si bin/Regions/ est vide (défaut : $REGION_NAME)
  --port PORT          Port UDP de la région (défaut : $REGION_PORT)
  --location X,Y       Coordonnées de la région sur la grille (défaut : $REGION_LOCATION)
  --setup-profile      Ajouter DOTNET_ROOT et PATH à ~/.bashrc et ~/.zshrc
  -h, --help           Afficher cette aide

OpenSim est installé dans <REPERTOIRE>/opensim-$OPENSIM_VERSION.
Variables d'environnement : INSTALL_ROOT (comme --dir), DOTNET_DIR (défaut : ~/.dotnet)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-deps)     SKIP_DEPS=1 ;;
        --dir)           INSTALL_ROOT="${2:?--dir attend un répertoire}"; shift ;;
        --skip-build)    SKIP_BUILD=1 ;;
        --region)        REGION_NAME="${2:?--region attend un nom}"; shift ;;
        --port)          REGION_PORT="${2:?--port attend un numéro}"; shift ;;
        --location)      REGION_LOCATION="${2:?--location attend X,Y}"; shift ;;
        --setup-profile) SETUP_PROFILE=1 ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "Option inconnue : $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

info() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }
trap 'die "Échec de la commande à la ligne $LINENO : $BASH_COMMAND"' ERR

[[ "$(uname -s)" == "Linux" ]] || die "Ce script ne gère que Linux."
command -v curl >/dev/null || die "curl est requis."
command -v tar >/dev/null || die "tar est requis."

OPENSIM_DIR="$INSTALL_ROOT/opensim-$OPENSIM_VERSION"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Télécharge une archive OpenSim et l'extrait dans INSTALL_ROOT sans écraser les fichiers existants
fetch_and_extract() {
    local url="$1" archive="$tmp/${1##*/}"
    info "Téléchargement de $url…"
    curl -fL --retry 3 --retry-delay 2 --progress-bar "$url" -o "$archive" \
        || die "Échec du téléchargement de $url"
    info "Extraction dans $INSTALL_ROOT…"
    # L'archive des sources s'appelle opensim-X-source/ : on la ramène dans opensim-X/
    tar -xzf "$archive" -C "$INSTALL_ROOT" --skip-old-files \
        --transform "s|^opensim-${OPENSIM_VERSION}-source|opensim-${OPENSIM_VERSION}|"
}

# --- 0. Répertoire d'installation et code d'OpenSim ------------------------
info "Répertoire d'installation : $INSTALL_ROOT"
mkdir -p "$INSTALL_ROOT"

if [[ -f "$OPENSIM_DIR/bin/OpenSim.dll" ]]; then
    info "Distribution OpenSim déjà présente dans $OPENSIM_DIR."
else
    fetch_and_extract "$DIST_URL"
fi

# La distribution binaire ne contient pas le code C# : il faut l'archive des sources pour compiler
if [[ $SKIP_BUILD -eq 0 && ! -f "$OPENSIM_DIR/prebuild.xml" ]]; then
    fetch_and_extract "$SOURCE_URL"
fi

# --- 1. Dépendances système ------------------------------------------------
if [[ $SKIP_DEPS -eq 0 ]]; then
    if dpkg -s libgdiplus >/dev/null 2>&1; then
        info "libgdiplus déjà installé."
    elif command -v apt-get >/dev/null; then
        info "Installation de libgdiplus et libc6-dev (sudo requis)…"
        sudo apt-get update
        sudo apt-get install -y libgdiplus libc6-dev
    else
        warn "apt-get introuvable : installe libgdiplus avec le gestionnaire de paquets de ta distribution."
    fi
fi

# --- 2. SDK .NET 8 (installation utilisateur, sans sudo) -------------------
if [[ -x "$DOTNET_DIR/dotnet" ]] && "$DOTNET_DIR/dotnet" --list-sdks 2>/dev/null | grep -q "^${DOTNET_CHANNEL}\."; then
    info "SDK .NET $DOTNET_CHANNEL déjà présent dans $DOTNET_DIR."
else
    info "Installation du SDK .NET $DOTNET_CHANNEL dans $DOTNET_DIR…"
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$tmp/dotnet-install.sh"
    bash "$tmp/dotnet-install.sh" --channel "$DOTNET_CHANNEL" --install-dir "$DOTNET_DIR"
fi

export DOTNET_ROOT="$DOTNET_DIR"
export PATH="$DOTNET_DIR:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1

if [[ $SETUP_PROFILE -eq 1 ]]; then
    line='export DOTNET_ROOT=$HOME/.dotnet PATH=$HOME/.dotnet:$PATH'
    [[ "$DOTNET_DIR" == "$HOME/.dotnet" ]] || line="export DOTNET_ROOT=$DOTNET_DIR PATH=$DOTNET_DIR:\$PATH"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [[ -f "$rc" ]] || continue
        if grep -qF "$line" "$rc"; then
            info "$rc contient déjà la configuration .NET."
        else
            printf '\n# .NET 8 pour OpenSimulator\n%s\n' "$line" >> "$rc"
            info "Configuration .NET ajoutée à $rc."
        fi
    done
fi

# --- 3. Génération des projets et compilation ------------------------------
cd "$OPENSIM_DIR"
if [[ $SKIP_BUILD -eq 0 ]]; then
    [[ -f prebuild.xml ]] || die "prebuild.xml introuvable : les sources ne sont pas présentes dans $OPENSIM_DIR."
    info "Génération de OpenSim.sln avec Prebuild…"
    # Équivalent de runprebuild.sh (ce dernier a des fins de ligne CRLF et échoue sous sh)
    cp bin/System.Drawing.Common.dll.linux bin/System.Drawing.Common.dll
    dotnet bin/prebuild.dll /target vs2022 /targetframework net8_0 /excludedir = "obj | bin" /file prebuild.xml
    info "Compilation (Release)…"
    dotnet build -c Release OpenSim.sln
else
    info "Compilation ignorée (--skip-build)."
fi

# --- 4. Configuration -------------------------------------------------------
cd "$OPENSIM_DIR/bin"
# opensim.sh est livré avec des fins de ligne Windows (CRLF) et sans droit d'exécution
sed -i 's/\r$//' opensim.sh
chmod +x opensim.sh
info "opensim.sh converti au format Unix et rendu exécutable."

for f in OpenSim.ini config-include/StandaloneCommon.ini config-include/FlotsamCache.ini; do
    if [[ ! -f "$f" ]]; then
        cp "$f.example" "$f"
        info "Créé $f à partir de $f.example."
    fi
done

shopt -s nullglob
regions=(Regions/*.ini Regions/*.xml)
shopt -u nullglob
if [[ ${#regions[@]} -eq 0 ]]; then
    cat > Regions/Regions.ini <<EOF
; Région générée par install.sh (voir Regions.ini.example pour toutes les options)
[$REGION_NAME]
RegionUUID = $(cat /proc/sys/kernel/random/uuid)
Location = $REGION_LOCATION
InternalAddress = 0.0.0.0
InternalPort = $REGION_PORT
AllowAlternatePorts = False
ExternalHostName = SYSTEMIP
EOF
    info "Région « $REGION_NAME » créée dans bin/Regions/Regions.ini (port $REGION_PORT)."
else
    info "Région(s) déjà configurée(s) : ${regions[*]}"
fi

# --- Fin ---------------------------------------------------------------------
cat <<EOF

Installation terminée.

Pour lancer le serveur :
  export DOTNET_ROOT=$DOTNET_DIR PATH=$DOTNET_DIR:\$PATH   # inutile si --setup-profile a été utilisé
  cd "$OPENSIM_DIR/bin" && ./opensim.sh

Au premier démarrage, la console demande le nom de l'estate et le compte
du propriétaire (prénom, nom, mot de passe). Connexion du viewer
(port HTTP http_listener_port de OpenSim.ini, 9000 par défaut) :
  -loginuri http://127.0.0.1:9000
EOF
