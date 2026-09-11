# GOG games on any Linux distro

*[Documentação em português](README.pt-BR.md)*

A GOG installer becomes **one `.pc` folder** that runs on any distro through
`play.sh`. No wine prefix is ever packaged: each machine builds its own on first
boot, with the runtime it has.

## Install umu first

The games run through **umu-launcher**, which runs them with Proton inside
*pressure-vessel*, Valve's container — DXVK, VKD3D and a FAudio built with
ffmpeg already assembled. Steam does not have to be installed: umu downloads
the container and Proton by itself. No root needed:

```bash
curl -sSL -o /tmp/umu.tar \
  https://github.com/Open-Wine-Components/umu-launcher/releases/latest/download/umu-launcher-1.4.4-zipapp.tar
mkdir -p ~/.local/share/umu ~/.local/bin
tar xf /tmp/umu.tar -C ~/.local/share/umu --strip-components=1
ln -sfn ~/.local/share/umu/umu-run ~/.local/bin/umu-run
```

Plus `innoextract` and `python3` to package. Details in
**[Setup](docs/en/setup.md)**.

## Two steps

```bash
# 1. drop GOG installers into install/ and run
./build.sh

# 2. play
~/Games/"Game Name.pc"/play.sh
```

## Documentation

| | |
|---|---|
| **[Setup](docs/en/setup.md)** | umu, distro packages, choosing the runner |
| **[Packaging](docs/en/packaging.md)** | the `install/` inbox, other modes, `autorun.cmd` |
| **[Playing](docs/en/playing.md)** | desktop menu, saves, launcher and bundled tools |
| **[Native engines](docs/en/native.md)** | DOSBox, ScummVM, Linux builds and source ports |
| **[Troubleshooting](docs/en/troubleshooting.md)** | when a game won't start, and GOG's registry |
| **[ENGINES.md](docs/ENGINES.md)** | games with a reimplemented engine |

## Files in this project

| | |
|---|---|
| `build.sh` | GOG installer → `.pc` folder |
| `install/` | the inbox: whatever sits here is what `build.sh` packages |
| `play.sh` | runs a `.pc` or `.wine` folder, or a `.wtgz`/`.wsquashfs` |
| `uninstall.sh` | removes a packaged game, its prefix and its menu entries |
| `saves.sh` | backs up and restores a game's saves, from both places they live |
| `test.sh` | checks both (detection, parser, CRLF, native build, cache) |

`play.sh` takes an optional second argument that overrides `CMD`.

Variables it honours: `WINE` (binary), `WINEPREFIX`, `WINEARCH`,
`FORCE_WINE=1` (ignore the native build),
`WINE_GAMES` (where single-file games get extracted),
`GOG2LINUX_INHIBIT=no` (let the machine sleep while playing),
`GOG2LINUX_UMU=no` (use the distro's wine instead of umu).
