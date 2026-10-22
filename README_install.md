# Installation d'OpenSimulator 0.9.3.0 — monde Cyberpunk

Ce dépôt contient le code source d'OpenSimulator 0.9.3.0 (.NET 8), configuré en mode **Standalone** : tous les services tournent dans un seul processus, avec des bases SQLite. Aucun serveur de base de données n'est nécessaire.

Tout est installé dans **`~/JEUX/SECONDLIFE/opensim-0.9.3.0`**.

> Cette installation a été réalisée et testée sur **Lubuntu 26.04 LTS** (x86_64).

## Installation rapide (avec le script)

```sh
./install.sh --setup-profile
```

Le script peut être lancé depuis n'importe quel dossier. Il crée `~/JEUX/SECONDLIFE/`, y télécharge et y décompresse OpenSim, installe les dépendances, compile et configure. Ensuite :

```sh
cd ~/JEUX/SECONDLIFE/opensim-0.9.3.0/bin && ./opensim.sh
```

## Installation manuelle

1. Créer le répertoire d'installation :

   ```sh
   mkdir -p ~/JEUX/SECONDLIFE
   cd ~/JEUX/SECONDLIFE
   ```

2. Télécharger et décompresser la distribution d'OpenSim. Elle crée le dossier `opensim-0.9.3.0/` :

   ```sh
   curl -fLO http://opensimulator.org/dist/opensim-0.9.3.0.tar.gz
   tar -xzf opensim-0.9.3.0.tar.gz
   ```

3. Cette archive contient le serveur déjà compilé, mais pas le code C#. Pour compiler, ajouter le code source dans le même dossier, sans écraser les fichiers existants :

   ```sh
   curl -fLO http://opensimulator.org/dist/opensim-0.9.3.0-source.tar.gz
   tar -xzf opensim-0.9.3.0-source.tar.gz --skip-old-files \
       --transform 's|^opensim-0.9.3.0-source|opensim-0.9.3.0|'
   ```

4. Installer les prérequis, puis compiler et configurer comme indiqué dans les sections suivantes (ou lancer `./install.sh`, qui ne retélécharge rien si les fichiers sont déjà là).

## Prérequis

| Élément | Rôle | Installé par `install.sh` |
|---|---|---|
| Linux x86_64 ou arm64 | testé sur Lubuntu 26.04 LTS | — |
| `curl` | téléchargement du SDK .NET | non |
| `libgdiplus`, `libc6-dev` | rendu d'images (cartes, textures) ; sans eux le serveur plante au démarrage (`DllNotFoundException: libgdiplus`) | oui, via `apt` (demande `sudo`) |
| SDK .NET **8.0** | compilation et exécution | oui, dans `~/.dotnet` (sans `sudo`) |

> Lubuntu 26.04, comme Ubuntu 26.04, ne fournit que .NET 10 dans ses dépôts. Le SDK 8 est donc installé avec le script officiel de Microsoft (`dotnet-install.sh`) dans le dossier personnel, sans toucher au système.

## Ce que fait `install.sh`

0. **Téléchargement** : crée `~/JEUX/SECONDLIFE/`, puis télécharge et décompresse `opensim-0.9.3.0.tar.gz` s'il n'est pas déjà là. Si la compilation est demandée, ajoute aussi `opensim-0.9.3.0-source.tar.gz` sans écraser les fichiers existants.
1. **Dépendances** : installe `libgdiplus` et `libc6-dev` avec `apt-get` s'ils sont absents.
2. **.NET 8** : installe le SDK dans `~/.dotnet` s'il n'y est pas déjà. Avec `--setup-profile`, ajoute `DOTNET_ROOT` et `PATH` à `~/.bashrc` et `~/.zshrc`.
3. **Compilation** : génère `OpenSim.sln` avec Prebuild à partir de `prebuild.xml`, puis lance `dotnet build -c Release`. Les DLL sont écrites directement dans `bin/` (environ 1 à 2 minutes).
4. **Configuration** :
   - crée `OpenSim.ini`, `StandaloneCommon.ini` et `FlotsamCache.ini` à partir des fichiers `.example` s'ils manquent ;
   - crée `bin/Regions/Regions.ini` si aucune région n'existe.

Le script peut être relancé sans risque : il n'écrase ni la configuration ni les régions existantes.

### Options

| Option | Effet |
|---|---|
| `--dir REPERTOIRE` | répertoire d'installation (défaut : `~/JEUX/SECONDLIFE`) |
| `--skip-deps` | ne pas installer les paquets système (aucun appel à `sudo`) |
| `--skip-build` | ne pas compiler et utiliser les DLL de la distribution binaire (l'archive des sources n'est pas téléchargée) |
| `--region NOM` | nom de la région créée (défaut : `Cyberpunk`) |
| `--port PORT` | port UDP de la région (défaut : `9000`) |
| `--location X,Y` | position sur la carte de la grille (défaut : `1000,1000`) |
| `--setup-profile` | rendre `dotnet` disponible dans les nouveaux terminaux |

La variable `INSTALL_ROOT` a le même effet que `--dir`. La variable `DOTNET_DIR` permet d'installer .NET ailleurs que dans `~/.dotnet`.

## Premier démarrage

```sh
export DOTNET_ROOT=$HOME/.dotnet PATH=$HOME/.dotnet:$PATH   # inutile après --setup-profile
cd ~/JEUX/SECONDLIFE/opensim-0.9.3.0/bin
sed -i 's/\r$//' opensim.sh   # fins de ligne Windows -> Unix (déjà fait par install.sh)
chmod +x opensim.sh           # rendre le script exécutable (déjà fait par install.sh)
./opensim.sh
```

`opensim.sh` est livré sans droit d'exécution et avec des fins de ligne Windows (CRLF). Sans ces deux commandes, `./opensim.sh` échoue avec `Permission non accordée` ou `No such file or directory`.

Lancez toujours le serveur depuis `bin/` : les chemins de configuration et les bases SQLite sont relatifs à ce dossier.

Au premier lancement, la console pose quelques questions :

1. **Rejoindre un estate existant ?** Répondez `no`, puis donnez un nom à l'estate.
2. **Propriétaire de l'estate** : prénom, nom, mot de passe et e-mail (facultatif). Ce compte est le seul à pouvoir administrer la région au départ, et il sert aussi pour la première connexion. Notez ces informations.

Le serveur est prêt quand l'invite `Region (Cyberpunk) #` apparaît. Pour créer d'autres comptes, tapez `create user` dans cette console. Pour arrêter proprement le serveur, tapez `quit`.

## Se connecter

Dans un viewer compatible OpenSim (Firestorm, Singularity…), ajoutez une grille avec l'URI de connexion :

```
http://127.0.0.1:9000
```

Depuis une autre machine du réseau local, utilisez l'adresse IP du serveur (par exemple `http://192.168.1.10:9000`). Pour un accès depuis Internet, réglez `BaseHostname` dans la section `[Const]` de `bin/OpenSim.ini` et ouvrez dans le pare-feu le port **9000 en TCP** (HTTP) et le port **9000 en UDP** (région).

## Configuration

Les fichiers sont lus dans cet ordre ; chacun remplace les valeurs du précédent :

1. `bin/OpenSimDefaults.ini` — valeurs par défaut, **ne pas modifier** ;
2. `bin/OpenSim.ini` — configuration principale. La section `[Architecture]` choisit le mode (`Standalone.ini` actuellement) ;
3. `bin/config-include/StandaloneCommon.ini` — services et stockage (`storage/SQLiteStandalone.ini`) ;
4. `bin/Regions/*.ini` — définition des régions.

Documentation officielle : <http://opensimulator.org/wiki/Configuration>.

## Recompiler après une modification du code

```sh
./install.sh --skip-deps
```

Ou à la main, depuis la racine du dépôt :

```sh
dotnet bin/prebuild.dll /target vs2022 /targetframework net8_0 /excludedir = "obj | bin" /file prebuild.xml   # seulement si prebuild.xml a changé
dotnet build -c Release OpenSim.sln
```

Les `.csproj` et `OpenSim.sln` sont générés à partir de `prebuild.xml` : modifiez `prebuild.xml`, jamais les `.csproj`.

## Sauvegardes

Les données du monde (comptes, inventaires, objets, terrain) sont stockées dans les fichiers `bin/*.db`, qui ne sont **pas** versionnés par git. Pour les sauvegarder :

- arrêtez le serveur, puis copiez les fichiers `bin/*.db` ;
- ou, dans la console du serveur, exportez la région avec `save oar cyberpunk.oar` (et rechargez-la avec `load oar`).

## Dépannage

| Symptôme | Solution |
|---|---|
| `DllNotFoundException: libgdiplus` | `sudo apt-get install -y libgdiplus libc6-dev` |
| `dotnet: command not found` | `export DOTNET_ROOT=$HOME/.dotnet PATH=$HOME/.dotnet:$PATH`, ou relancez `./install.sh --setup-profile` |
| `Échec du téléchargement` | vérifiez la connexion, puis relancez `./install.sh` : il reprend là où il s'est arrêté |
| `./opensim.sh` : `Permission non accordée` ou `No such file or directory` | `sed -i 's/\r$//' opensim.sh && chmod +x opensim.sh` dans `bin/` |
| `./runprebuild.sh` : `Syntax error` | le script a des fins de ligne Windows ; utilisez `install.sh` ou la commande `prebuild` ci-dessus |
| `MSB1009: Le fichier projet n'existe pas` | `OpenSim.sln` n'a pas été généré : lancez l'étape Prebuild |
| Le viewer ne se connecte pas depuis une autre machine | vérifiez `BaseHostname` dans `[Const]` et le pare-feu (port 9000 en TCP et en UDP) |
