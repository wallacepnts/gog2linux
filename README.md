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

**Whatever sits in `install/` is a game.** One folder per game, with its DLCs in
a `dlc/` inside it — or a loose installer, when the game has no DLC:

```
install/
├── setup_stardew_valley_1.6.15_(70330).exe      <- loose: a game with no DLC
└── grimdawn/                                    <- a folder: the game and what comes with it
    ├── setup_grim_dawn_1.2.1.5_(51951).exe
    ├── setup_grim_dawn_1.2.1.5_(51951)-1.bin
    ├── setup_grim_dawn_1.2.1.5_(51951)-2.bin
    └── dlc/
        ├── setup_grim_dawn_ashes_of_malmouth_(51951).exe
        └── setup_grim_dawn_forgotten_gods_(51951).exe
```

```bash
# 1. package everything sitting in install/
./build.sh

# 2. test it on your distro
~/Games/"Grim Dawn.pc"/play.sh

# 3. take it to Batocera
cp -r ~/Games/"Grim Dawn.pc" /userdata/roms/windows/
```

It lists what it found and lets you choose:

```
install/: 3 game(s) found
installing into: /home/you/Games
   1) Grim Dawn                              grimdawn
   2) Stardew Valley                         setup_stardew_valley_1.6.15_(70330).exe
   3) my-old-game
Install which? [Enter = all; e.g. 1 3, or 1-2]:
```

Enter takes everything; `1 3` picks individually, `1-2` is a range, and commas
work too. In a script, with no terminal, there is no question: the whole inbox
gets packaged.

**The name comes out of the installer header** — the same one GOG uses, and you
type none of it. When the name came from there, the right-hand column shows what
it came from, as in items 1 and 2 above; when the header says nothing, the
folder's own name stands, as in item 3. The games are installed into `~/Games`,
or `~/Jogos` on a Portuguese system — the same `$LANG` that picks the language of
these messages picks the folder. Not beside `install/`: that one is an inbox and
gets emptied, and on a fresh checkout it sits in the repo, which is no place for
twenty gigabytes of game. Anything
in there that is not an InnoSetup installer is skipped with a note; `.bin` files
are the parts and stay quiet.

One game per run, each in its own process: a bad installer costs its own game,
not the whole batch. At the end, if every game made it, you are asked whether
the installers **of the games it packaged** may go — whatever you left for later
stays put. The default is **no**, say yes once the games start. If any game
failed, nothing is deleted: the installers are the only thing that can rebuild
the folder.

`build.sh` extracts the base installer and the DLCs into the same folder (DLCs
overwrite and merge), throws away the installer scaffolding (`tmp/`,
`__redist/`), reads `goggame-*.info` to find the right executable and writes
`autorun.cmd`. If it spots a DOSBox or ScummVM game in disguise, it stops before
writing `autorun.cmd` and tells you which system to use instead.

**Rules that always apply:**

1. **Pass the `.exe`, never the `.bin` files.** Large GOG installers ship as
   `setup_game.exe` + `setup_game-1.bin` + `setup_game-2.bin`. innoextract's
   `--gog` pulls them together on its own — the `.bin` files only need to sit in
   the same folder.
2. **DLCs come along when you pass the folder**, from `dlc/` (or any
   subfolder). Passing files one by one, the order matters: base first, DLCs
   after. And **no brackets** — in the `usage:` line they only mark what is
   optional; copied along, they become part of the path and `build.sh` stops
   with `installer not found: [/...`.
3. **Multi-language installers ask, and default to English.** GOG ships one
   installer with every language inside; extracting all of them lets the last
   one win the metadata, which is how an English game comes out Italian. When
   the installer offers more than one language, `build.sh` lists them and waits:

   ```
   setup_final_fantasy_iii.exe offers 10 languages:
      1) de-DE    Deutsch
      2) en-US    English
      3) es-ES    Espanol
      ...
     10) zh-Hant  Zhongwen (fanti)
   Language [en-US]:
   ```

   Answer with the number or the code. Enter takes English, and the choice
   carries over to the DLCs in the same run. When the installer carries a single
   language it says so instead of asking:

   ```
   language: en-US (English) - the only one this installer carries
   ```

   That line matters: a GOG store page may advertise four localizations while
   the installer you downloaded holds one. The others are separate downloads;
   drop them all in the same folder, or pass them all on the same command line,
   like DLCs.

   In a script there is no question: `--lang it-IT` picks one, `--lang all`
   keeps every language, and with neither it takes `en-*` silently.
4. **Copy the whole folder** to Batocera, minus `.prefix/` (that's the local
   prefix, ~400 MB, and Batocera doesn't use it).
5. **Keep `/userdata/` on btrfs or ext4.** NTFS breaks wine, Steam/Galaxy games
   especially.
6. **The folder name is the name shown** in EmulationStation.

---

## Other ways to package

`install/` is the short path, not the only one. A target and installers still
work on the command line — that is what to use to package without touching the
inbox, or to pick the `.pc` name, which inside `install/` comes from the
installer:

```bash
# a folder holding the installers becomes the .pc of the same name
./build.sh grimdawn                                 # grimdawn/ -> grimdawn.pc

# the folder GOG handed you, with whatever destination you pick
./build.sh Game.pc "/path/Game_1.2.3_(58051)_win_gog"

# or loose paths, in order base -> DLCs
./build.sh Game.pc "/path/setup_game.exe" "/path/DLC/setup_dlc.exe"

# and with no installer at all, a re-read of an already extracted folder
./build.sh Game.pc
```

That last one is the repair mode: it re-reads `goggame-*.info`, runs the
detection again and rewrites `autorun.cmd` without extracting anything. Run it
after editing the folder by hand, or to add a menu entry to a game that is
already packaged (`./build.sh --desktop Game.pc`).

**Quote the path.** GOG-Games filenames almost always carry parentheses or
spaces, and unquoted, bash complains with `syntax error near unexpected token
'('`:

```bash
./build.sh Game.pc "/path/game (45311)/setup_game_(arbys)_(45311).exe"
./build.sh Game.pc ~/"Downloads/game (45311)/setup.exe"   # tilde outside the quotes
```

`~` does not expand inside quotes — use `$HOME` or leave the tilde out. When in
doubt, type the beginning and hit **Tab**; bash escapes it for you. None of this
comes up in `install/`, where you type no paths at all.

Neither end has to stay where it is:

```bash
GOG2LINUX_INBOX=/mnt/hd/downloads ./build.sh    # where to read from
GOG2LINUX_GAMES=/mnt/hd/games ./build.sh        # where to install
```

Worth knowing when home is a small partition: one GOG game passes 20 GB easily.

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
| cutscene plays black, sound and timing fine | Unity hands the decoded frame over through `dxgi`, which wine leaves stubbed | DXVK in the prefix (just below) |
| the game demands a real install (registry, DirectX) | it isn't portable | install it into a prefix with wine and package that as `.wtgz` (see below) |

The black cutscene is one `build.sh` spots on its own: a Unity game
(`UnityPlayer.dll`) with an `.mp4` cutscene gets
`ENV=WINEDLLOVERRIDES="d3d11,dxgi=n,b"` in its `autorun.cmd`, which is what makes
wine reach for DXVK. Putting DXVK in the prefix is still yours to do:

```bash
sudo zypper in dxvk          # or your distro's package
cd ~/Games/"My Game.pc"
WINEPREFIX=$PWD/.prefix /usr/libexec/dxvk/bin/setup_dxvk.sh install --symlink
```

Check what the script did. Here it put the **32-bit** DLLs into the `system32` of
a 64-bit prefix, and when that happens wine falls back to its own without a word
— the cutscene stays black and nothing in the log admits it:

```bash
file -L .prefix/drive_c/windows/system32/d3d11.dll   # has to say x86-64
```

If it says `i386`, redo the links against `lib64`. A `.webm` cutscene is VP8,
which Unity decodes by itself: none of this applies.

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

## When a native engine exists

Some classics have had their engine reimplemented — open source, native, real
fullscreen, modern controllers. That beats wine every time, so `build.sh` says
so at the end of packaging:

```
note: Nox has a reimplemented engine (OpenNox) - native, better than wine: flathub io.github.noxworld_dev.OpenNox
```

It only tells you. Installing the port, and keeping the wine copy or not, stays
your call. The full list, sorted by genre and with a link to every project,
lives in **[ENGINES.md](ENGINES.md)** — around sixty games.

Order matters when matching: DOOM 3 gets dhewm3, not the GZDoom that serves
the rest of the family. Matching is on the game name, so a GOG bundle or a
differently titled edition may slip past. The list is worth a look before
packaging anything from the nineties.

If you do install one, drop a `launch.sh` in the `.pc` folder and the menu entry
points at it instead of `play.sh`:

```bash
#!/usr/bin/env bash
exec flatpak run io.github.noxworld_dev.OpenNox "-data=$(dirname "$(readlink -f "$0")")" -fullscreen "$@"
```

Delete the file and the wine path comes back.

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
| `install/` | the inbox: whatever sits here is what `build.sh` packages |
| `play.sh` | runs `.pc`, `.wine`, `.wtgz` or `.wsquashfs` outside Batocera |
| `uninstall.sh` | removes a packaged game, its prefix and its menu entries |
| `saves.sh` | backs up and restores a game's saves, from both places they live |
| `test.sh` | checks both (detection, parser, CRLF, native build, cache) |

`play.sh` takes an optional second argument that overrides `CMD`.

Variables it honours: `WINE` (binary), `WINEPREFIX`, `WINEARCH`,
`FORCE_WINE=1` (ignore the native build),
`WINE_GAMES` (where single-file games get extracted).
