# Setup

## umu-launcher

`play.sh` looks for umu and prefers it. It runs the game with Proton inside
*pressure-vessel*, the container Valve built to run games — DXVK, VKD3D and a
FAudio built with ffmpeg already assembled. It is the difference between a game
that opens and one that shows a black screen.

**Steam does not have to be installed.** The container is a piece of its own,
and umu downloads it (some 660 MB into `~/.local/share/umu/steamrt4`) along
with Proton. Nothing here opens Steam or asks for an account.

umu keeps Proton in `~/.local/share/Steam/compatibilitytools.d/`. The folder has
"Steam" in its name by convention -- umu creates it itself if it is missing.

No root, and distro-independent:

```bash
curl -sSL -o /tmp/umu.tar \
  https://github.com/Open-Wine-Components/umu-launcher/releases/latest/download/umu-launcher-1.4.4-zipapp.tar
mkdir -p ~/.local/share/umu ~/.local/bin
tar xf /tmp/umu.tar -C ~/.local/share/umu --strip-components=1
ln -sfn ~/.local/share/umu/umu-run ~/.local/bin/umu-run
```

Check the number on the [releases page](https://github.com/Open-Wine-Components/umu-launcher/releases);
Fedora and Debian have a package, other distros do not.

On the first run it downloads GE-Proton and the runtime: a few minutes and a few
GB, once.

### Choosing the Proton

**`PROTONPATH=GE-Proton` is a name, not a path.** umu fetches the latest itself,
and the same `.pc` folder works on a machine that never had Proton.

To use another, the name of any folder in
`~/.local/share/Steam/compatibilitytools.d/` will do, or a full path:

```bash
ls ~/.local/share/Steam/compatibilitytools.d/   # what this machine has
PROTONPATH="Proton-CachyOS Latest" ./play.sh    # just this once
```

To pin the choice to one game, put it in that game's `autorun.cmd`:

```
CMD=game.exe
ENV=PROTONPATH="Proton-CachyOS Latest"
```

**Quote it if the name has a space.** Without the quotes the line becomes
`PROTONPATH=Proton-CachyOS`, and umu goes looking for a Proton that is not there.

Switching Proton reuses the same `.prefix`. Moving up a version usually passes
quietly; going back to an older one is what sometimes leaves the prefix
inconsistent -- if a game stops opening after the switch, delete `.prefix` and
let it be rebuilt.

### Per-game fixes

protonfixes, which ships inside Proton-GE, keeps one workaround per game --
installing `xact` for a game whose audio needs it, forcing a DLL, passing a
flag. It picks which one to apply by `GAMEID`.

umu does not work that id out on its own: *"GAMEID is strictly required and the
client is responsible for setting this"*. The client here is `build.sh`, which
takes the GOG id out of `goggame-*.info`, looks it up in the [umu
database](https://github.com/Open-Wine-Components/umu-database) and writes the
answer into the game's `autorun.cmd`:

```
ENV=GAMEID=umu-61500
ENV=STORE=gog
```

`GAMEID` is what protonfixes matches on; `STORE` says which of its tables to
look in (`gamefixes-gog/`, `gamefixes-steam/`). Both come from the row that
matched.

The database is fetched once a week into `~/.cache/gog2linux/` -- 90 KB -- and
the lookup works offline after that. With no network and no cache the game is
packaged just the same; it simply goes without the fix.

Two matches, both exact: the GOG id first, then the title. Nothing fuzzier -- a
fix aimed at the wrong game is worse than no fix. The database holds around 200
GOG games, so **most will not match, and that is expected**: with no id, umu
uses `umu-default` and applies only the global fixes.

With no umu installed, `play.sh` falls back to the distro's wine. That works for
most games, with less guarantee — and `GOG2LINUX_UMU=no` forces it on purpose.

**Do not mix the two in one prefix.** Pointing the distro's wine at a
Proton-made prefix triggers a slow rebuild that swaps files out. To compare
them, use separate prefixes.

## What else you need

| Distro | Command |
|---|---|
| Ubuntu / Mint / Debian | `sudo apt install innoextract wine` |
| Fedora | `sudo dnf install innoextract wine` |
| Arch / Manjaro | `sudo pacman -S innoextract wine` |
| openSUSE | `sudo zypper in innoextract wine` |

- `innoextract` and `python3` — only to **package** (they take the InnoSetup
  apart and read GOG's metadata; nothing Windows runs).
- `wine` — the fallback when umu is missing, and still used by some games.

Extras as needed: `winetricks` (games that want a Microsoft DLL),
`squashfs-tools` (to open a `.wsquashfs`).

## Language of the tool itself

The scripts speak English or Portuguese, picked from `$LANG`:

```bash
GOG2LINUX_LANG=pt ./build.sh Game.pc "/path/setup.exe"   # force Portuguese
GOG2LINUX_LANG=en ./build.sh Game.pc "/path/setup.exe"   # force English
```

All four scripts follow it: `build.sh`, `play.sh`, `saves.sh` and
`uninstall.sh`. Anything not matching `pt*` gets English. There is no gettext
and no `.po` file — a block of shell variables per script, chosen once at
startup, so the copies that live inside each game folder stay self-contained.

Note this is the language of the **messages**, not of the game: that one is
`--lang`, and the two are independent.
