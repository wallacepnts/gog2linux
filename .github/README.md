# GOG games on Batocera and on any Linux distro

*[Documentação em português](README.pt-BR.md)*

A GOG installer becomes **one `.pc` folder** that runs in both places unchanged:
Batocera reads `autorun.cmd`, every other distro uses `play.sh`.

The trick is not building a wine prefix at packaging time. Each system creates
its own on first boot, with the wine it has. A packaged prefix is a prefix
welded to the distro that made it.

---

## Setting up a fresh distro

| Distro | Command |
|---|---|
| Ubuntu / Mint / Debian | `sudo apt install innoextract wine` |
| Fedora | `sudo dnf install innoextract wine` |
| Arch / Manjaro | `sudo pacman -S innoextract wine` |
| openSUSE | `sudo zypper in innoextract wine` |
| **Batocera** | **nothing** — Wine-GE ships with it |

- `innoextract` and `python3` — for **packaging** only (unpack the InnoSetup and read GOG's metadata; nothing Windows runs).
- `wine` — for **playing** only. If you just copy the folder to Batocera, you don't need it.

Case by case: `squashfs-tools` (to open `.wsquashfs`), `winetricks` (games that
want a Microsoft DLL).

---

## The universal rule: any GOG game in 3 steps

```bash
# 1. package (once, on any Linux PC)
./build.sh [--desktop] GameName.pc "/path/setup_game_1.2.3.exe" ["dlc1.exe" "dlc2.exe" ...]

# 2. test it on your distro
./GameName.pc/play.sh

# 3. take it to Batocera
cp -r GameName.pc /userdata/roms/windows/
```

`build.sh` extracts the base installer and the DLCs into the same folder (DLCs
overwrite and merge), throws away the installer scaffolding (`tmp/`,
`__redist/`), reads `goggame-*.info` to find the right executable and writes
`autorun.cmd`. If it spots a DOSBox or ScummVM game in disguise, it stops before
writing `autorun.cmd` and tells you which system to use instead.

**Rules that always apply:**

1. **Quote the installer path.** GOG-Games filenames almost always carry
   parentheses or spaces, and unquoted, bash complains with
   `syntax error near unexpected token '('`:

   ```bash
   ./build.sh Game.pc "/path/game (45311)/setup_game_(arbys)_(45311).exe"
   ./build.sh Game.pc ~/"Downloads/game (45311)/setup.exe"   # tilde outside the quotes
   ```

   `~` does not expand inside quotes — use `$HOME` or leave the tilde out. When
   in doubt, type the beginning and hit **Tab**; bash escapes it for you.
2. **Pass the `.exe`, never the `.bin` files.** Large GOG installers ship as
   `setup_game.exe` + `setup_game-1.bin` + `setup_game-2.bin`. innoextract's
   `--gog` pulls them together on its own — the `.bin` files only need to sit in
   the same folder.
3. **A DLC is just one more argument**, in order: base first, DLCs after.
4. **Multi-language installers ask, and default to English.** GOG ships one
   installer with every language inside; extracting all of them lets the last
   one win the metadata, which is how an English game comes out Italian. When
   the installer offers more than one language, `build.sh` lists them and waits:

   ```
   setup_final_fantasy_iii.exe offers 10 languages:
      1) de-DE
      2) en-US
      ...
   Language [en-US]:
   ```

   Enter takes English. The choice carries over to the DLCs in the same run. In
   a script there is no question: pass `--lang it-IT`, or `--lang all` to keep
   every language, and with neither it picks `en-*` silently.
5. **Copy the whole folder** to Batocera, minus `.prefix/` (that's the local
   prefix, ~400 MB, and Batocera doesn't use it).
6. **Keep `/userdata/` on btrfs or ext4.** NTFS breaks wine, Steam/Galaxy games
   especially.
7. **The folder name is the name shown** in EmulationStation.

---

## Old games: DOSBox and ScummVM

A GOG classic is usually a DOSBox 0.74 (from 2010) in a wrapper. Running that
through wine means running an emulator inside an API translator — `build.sh`
detects it and refuses. To find out before you even extract:

```bash
innoextract -l "setup_game.exe" | grep -iE 'dosbox|scummvm'
```

Mind the name collision: **Batocera's `dos` system also uses `.pc` folders**.
What changes is the contents.

| | `roms/windows/Game.pc` | `roms/dos/GAME.pc` |
|---|---|---|
| control file | `autorun.cmd` | `dosbox.bat` |
| runs with | Wine-GE | DOSBox |

Two rules for the `dos` system: folder name of **8 characters or fewer**, no
accents, and **don't copy GOG's `.conf`** to Batocera (the wiki warns it
crashes) — take only the `[autoexec]` block and make it your `dosbox.bat`:

```
c:
cd GAME
GAME.EXE
```

On the desktop it's the opposite: GOG's `.conf` files are good and save you work.

```bash
sudo apt install dosbox-staging   # openSUSE ships it as `dosbox` 0.82, already staging
cd Game.pc && dosbox -conf dosbox_game.conf -conf dosbox_game_single.conf
```

Before any of that, though: check whether a **source port** exists (OpenMW,
DevilutionX, VCMI, OpenRA, GZDoom, OpenTTD, Arx Libertatis, CorsixTH...).
PCGamingWiki lists them per game, and Batocera ships several ready to go.
Native port > DOSBox > wine.

### Ren'Py: the Linux build is already in there

Ren'Py visual novels (and some Java/Löve games) pack every platform into the
same installer. After `build.sh`, if you see

```
note: native Linux build here -> ./Game.pc/Game.sh (no wine)
```

use that `.sh` on the desktop — it's the game running natively, no API
translation. `build.sh` already fixes the execute bit, which a Windows installer
does not carry.

`autorun.cmd` is still written, because on Batocera wine is the way (the
`windows` system does not run Linux binaries).

---

## When the game won't start

| Symptom | Likely cause | Way out |
|---|---|---|
| `innoextract` complains about the Inno version | installer too new | update innoextract, or install with `wine setup.exe /VERYSILENT /DIR=$PWD/Game.pc` and delete the `unins*` files |
| opens and closes immediately | 32-bit running as 64 | `WINEARCH=win32 ./Game.pc/play.sh` (delete `.prefix` first) |
| a Microsoft `.dll` is missing | game expects an installed runtime | `WINEPREFIX=$PWD/Game.pc/.prefix winetricks vcrun2019` (or whatever it wants) |
| black screen / freezing on Batocera | no DXVK | turn on `windows.dxvk` in the game's advanced options — **only applies before the first boot**, otherwise delete the prefix in `/userdata/saves/windows/` |
| the game demands a real install (registry, DirectX) | it isn't portable | install it into a prefix with wine and package that as `.wtgz` (see below) |

---

## `autorun.cmd`

Read by Batocera **and** by `play.sh`. It needs **LF** (Unix) line endings, not
CRLF — CRLF is the number one cause of "it doesn't start".

```
CMD=game.exe                      # required; quote it if it has spaces
DIR=64bit/bin                     # optional, relative to the .pc folder
ENV=WINEDLLOVERRIDES="d3d11=n"    # optional, repeatable
LANG=pt_BR.UTF-8                  # optional
SAVEDIR=drive_c/users/...         # optional, Batocera v42+
```

Arguments ride along with `CMD`: `CMD="My Game.exe" --fullscreen`

---

## Single-file format (optional)

Only worth it for a game that **had to** be installed with wine for real. What
gets packaged then is the whole prefix:

```bash
tar czf Game.wtgz -C /path/to/prefix .        # on any distro
batocera-wine windows wine2winetgz Game.wine  # or, over SSH on Batocera
```

`./play.sh Game.wtgz` extracts to `~/.local/share/wine-games/` and runs it.
`.wsquashfs` works too (needs `unsquashfs`).

Prefer **`.wtgz`**: it's just a tar.gz, it opens anywhere. But remember the
prefix inside carries the wine that made it — for distribution, `.pc` is still
better.

---

## What the GOG installer would have done

Packaging skips the installer, so everything it would have written is missing:
install paths in the registry, CD-key locations, DirectPlay entries. Games
notice. Doom 3 asks for a key it already ships; Warcraft II says the game is
not installed.

`build.sh` reads `goggame-*.script` — GOG's own install recipe — and turns its
registry actions into `gog-registry.reg` inside the `.pc` folder. `play.sh`
applies that the first time it creates a prefix, resolving the install path to
wherever the folder happens to sit.

Two details it gets right that a hand-written `.reg` usually doesn't: actions
tagged for a language this copy doesn't ship are skipped (otherwise Doom 3
turns Italian), and `HKLM\Software` keys are written to `WOW6432Node` as well,
because a 32-bit game in a 64-bit prefix reads them from there.

On Batocera `play.sh` never runs, so apply it once over SSH:

```bash
WINEPREFIX=/userdata/saves/windows/Game wine regedit /S /userdata/roms/windows/Game.pc/gog-registry.reg
```

Replace `%APP%` in the file with the Windows-side path first — `Z:\userdata\roms\windows\Game.pc`.

---

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

---

## Adding the game to the desktop menu

At the end of packaging, `build.sh` offers to create a menu entry:

```
Add "DOOM 3" to the desktop games menu? [y/N]
```

Answering no — which is the default, so Enter is enough — changes nothing.
Answering yes writes a freedesktop `.desktop` file to
`~/.local/share/applications/`, using the game name from the GOG metadata. That
is all KDE, GNOME and XFCE need; there is no per-desktop code.

The icon comes out of `goggame-*.ico`, which packs every size from 16×16 to
256×256. Desktops tend to grab the first entry and show a blurry 16×16, so
`build.sh` cuts the largest one out into `icon.png` and points the entry there.

The question only appears on a terminal. For scripts, decide up front:

```bash
./build.sh --desktop    Game.pc "/path/setup.exe"    # always create it
./build.sh --no-desktop Game.pc "/path/setup.exe"    # never ask
```

Only the game gets an entry. Removing it is `uninstall.sh`, which sits in the
folder rather than cluttering the games menu:

```bash
./Game.pc/uninstall.sh        # lists what goes, then asks
./Game.pc/uninstall.sh -y     # no question
```

It takes the folder, the wine prefix inside it and the menu entry. Saves the
game wrote elsewhere are left alone.

The entry points at the `.pc` folder by absolute path, so move the folder and it
breaks — rerun `./build.sh --desktop Game.pc` from the new place to fix it, or
delete `~/.local/share/applications/gog-<name>.desktop`.

---

## Backing up saves

Old games keep saves next to themselves, modern ones write into the wine
profile. `saves.sh` covers both:

```bash
./Game.pc/saves.sh                             # Game-saves-<date>.tar.gz, here
./Game.pc/saves.sh backup /backup/game.tar.gz
./Game.pc/saves.sh restore /backup/game.tar.gz
```

It packs `.prefix/drive_c/users` — Documents, Saved Games, AppData — plus any
`SAVE`, `Saves`, `savegames` or `Profiles` folder in the game directory, and
prints which ones it found.

`uninstall.sh` runs a backup before deleting anything, and with `-y` it does so
without asking. The game comes back from the installer; the saves do not.

---

## Running the launcher or the bundled tools

GOG games often ship more than the game: a launcher, a map editor, a key
changer, a DirectPlay setup. Pass the executable as a second argument and it
runs in the same prefix, with `autorun.cmd` untouched:

```bash
./Game.pc/play.sh . "Launcher.exe"
./Game.pc/play.sh . "Map Editor.exe"
```

`build.sh` picks the entry GOG tags as the game — not the launcher it marks as
primary — and lists what else is on offer:

```
done: /path/Game.pc (CMD=Launcher.exe)
other entries in goggame-*.info: Game_dx.exe, Map Editor.exe
  if the game won't start, try one of those in autorun.cmd
```

Worth knowing: GOG usually marks the **launcher** as primary, which is why the
game entry is preferred instead — a launcher needs a mouse and often starts a
build wine cannot run. Old titles ship both a classic and a DirectX build, and
frequently only the latter survives wine.

---

## Files in this project

| | |
|---|---|
| `build.sh` | GOG installer → `.pc` folder |
| `play.sh` | runs `.pc`, `.wine`, `.wtgz` or `.wsquashfs` outside Batocera |
| `uninstall.sh` | removes a packaged game, its prefix and its menu entries |
| `saves.sh` | backs up and restores a game's saves, from both places they live |
| `test.sh` | checks both (detection, parser, CRLF, native build, cache) |

`play.sh` takes an optional second argument that overrides `CMD`.

Variables it honours: `WINE` (binary), `WINEPREFIX`, `WINEARCH`,
`FORCE_WINE=1` (ignore the native build),
`WINE_GAMES` (where single-file games get extracted).
