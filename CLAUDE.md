# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is **OpenSimulator 0.9.3.0**: the official source tarball merged over the binary distribution, targeting .NET 8. The `opensim_cyberpunk` branch holds the customizations for this particular world. `main` is the base distribution. Upstream build and configuration notes are in `BUILDING.md`, and test notes are in `TESTING.txt`.

## Toolchain

`./install.sh` (documented in `README_install.md`, in French) installs libgdiplus and the .NET 8 SDK, builds the server, and creates any missing config and region files. It is idempotent. `./install.sh --skip-deps` is the quickest full rebuild.

The .NET 8 SDK is installed per-user in `~/.dotnet`. Ubuntu 26.04 only ships .NET 10, so it does not come from apt. Every shell that builds or runs the server needs:

```sh
export DOTNET_ROOT=$HOME/.dotnet PATH=$HOME/.dotnet:$PATH
```

The runtime also needs the `libgdiplus` system package. Without it, startup dies with `DllNotFoundException: libgdiplus`.

## Build

The `.csproj` files and `OpenSim.sln` are **generated** from `prebuild.xml` by Prebuild, and they are gitignored. Add projects and references in `prebuild.xml`, never in a `.csproj`. Then regenerate:

```sh
# from the repo root. runprebuild.sh has CRLF line endings and fails under sh, so run its steps directly:
cp bin/System.Drawing.Common.dll.linux bin/System.Drawing.Common.dll
dotnet bin/prebuild.dll /target vs2022 /targetframework net8_0 /excludedir = "obj | bin" /file prebuild.xml
dotnet build -c Release OpenSim.sln        # ~1.5 min. Outputs straight into bin/
dotnet build -c Release OpenSim/Region/CoreModules/OpenSim.Region.CoreModules.csproj   # rebuild a single project
```

Build output overwrites the tracked `bin/OpenSim*.dll` and `bin/Robust.dll`. Committing a rebuild therefore shows up as modified DLLs.

## Running

```sh
cd bin && ./opensim.sh    # ulimit -s 1048576 && dotnet OpenSim.dll
```

Always run from inside `bin/`. Config paths and the SQLite files (`OpenSim.db`, `Asset.db`, `inventory.db`, …) are relative to the working directory. The region is defined in `bin/Regions/Regions.ini`: region `Cyberpunk`, port 9000. The first start asks interactively for the estate name and the estate owner's name and password. Viewers log in with `-loginuri http://127.0.0.1:9000`. More users are created with `create user` in the console.

## Configuration architecture

OpenSim's config is a layered Nini INI system. Settings resolve in this order, with later layers overriding earlier ones:

1. `bin/OpenSimDefaults.ini`: shipped defaults. **Do not edit.** Override values in `OpenSim.ini` instead.
2. `bin/OpenSim.ini`: the main local config. Its `[Architecture]` section chooses the topology through `Include-Architecture`. It is currently set to **`config-include/Standalone.ini`**, meaning every service runs in-process with no Robust server.
3. The architecture file pulls in `config-include/StandaloneCommon.ini`, which in turn includes:
   - `storage/SQLiteStandalone.ini`: the database backend.
   - `FlotsamCache.ini`: the asset cache.
4. `config-include/osslDefaultEnable.ini` sets OSSL script-function permissions.
5. `bin/addon-modules/*/config/*.ini` and `bin/Regions/*.ini` are picked up automatically.

Each `*.ini.example` sits next to its live `*.ini`. Start new local configs from the example file.

## Code architecture (`OpenSim/`)

- `Region/Application`: the `OpenSim.dll` entry point. `OpenSimBase` loads application plugins, such as LoadRegions and RegionModulesController, through Mono.Addins.
- `Region/Framework`: the `Scene` / `SceneObjectGroup` / `ScenePresence` model, plus the `INonSharedRegionModule` / `ISharedRegionModule` interfaces. Most features are **region modules**, discovered through `[Extension(Path = "/OpenSim/RegionModules")]` attributes and enabled or disabled by `[Modules]` keys in the ini files.
- `Region/CoreModules`, `Region/OptionalModules`: the built-in region modules. New gameplay features normally go here, or in `addon-modules/<Name>/` with their own `prebuild.xml` fragment.
- `Region/ClientStack/Linden`: the viewer protocol, with UDP in `LindenUDP` and HTTP capabilities in `Caps`.
- `Region/ScriptEngine`: LSL/OSSL runtime and the YEngine. The script API lives in `Shared/Api/Implementation`.
- `Region/PhysicsModules`: BulletS (the default, `physics = BulletSim`) and ubODE. The native libraries are in `bin/lib64/`.
- `Services/*` + `Services/Interfaces`: the backend services (assets, inventory, users, grid…). In Standalone mode they run in-process through the `Services/Connectors` local connectors. In Grid mode `Server/` (Robust) hosts them over HTTP.
- `Data/*`: storage backends (SQLite, MySQL, PGSQL, Null). Schema migrations live as `Resources/*.migrations` files.

## Repo hygiene

`.gitignore` excludes generated build files (`*.csproj` under `OpenSim/`, `OpenSim.sln`, `obj/`, `bin/*.pdb`, apphosts). It also excludes runtime state: `*.db`, logs, caches and `addin-db-*`. World data lives in the `.db` files, so back them up separately, for example with `save oar` in the console.
