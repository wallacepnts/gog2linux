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
a `dlc/` inside it — or a loose installer, when there is no DLC:

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

Drop the `.bin` files next to the `.exe` and forget them: innoextract pulls the
parts together on its own. The DLC subfolder's name does not matter — `dlc/`,
`DLC/` as GOG ships it, or anything else: whatever sits in a subfolder is a DLC.

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

Enter takes everything, `1 3` picks individually, `1-2` is a range. With no
terminal it packages the lot without asking.

The `.pc` name comes out of the installer header, the same one GOG uses — the
right-hand column shows where it came from, and with no readable header the
folder's own name stands (item 3). The games go to `~/Games`, or `~/Jogos` on a
Portuguese system.

One game per process: a bad installer costs its own game, not the batch. At the
end it asks whether the installers **of the games it packaged** may go — the
default is **no**, say yes once they start. If any game failed, nothing is
deleted.

On its own it also merges the DLCs into the same folder, throws away the
installer scaffolding (`tmp/`, `__redist/`), reads `goggame-*.info` to find the
executable and writes `autorun.cmd`. If it is a DOSBox or ScummVM game in
disguise, it stops before that and says which system to use.

**Rules that always apply:**

1. **The language question only comes up when it decides something.** Nearly
   every GOG installer offers a list, but that list is usually its *own*
   interface — the game carries every language inside and picks at run time.
   `build.sh` compares what comes out with and without a language filter (a
   header read, milliseconds) and, when it is the same, extracts the lot without
   asking. Where the files really do differ it lists them and waits; Enter takes
   English, and the choice carries to the DLCs in the same run. In a script,
   `--lang it-IT` or `--lang all`.

   GOG's page may advertise four localisations while the installer carries one:
   the others are separate downloads, and go in the same folder as the game.
2. **Copy the whole folder** to Batocera, minus `.prefix/` (that's the local
   prefix, some 400 MB, and Batocera doesn't use it).
3. **Keep `/userdata/` on btrfs or ext4.** NTFS breaks wine, Steam/Galaxy games
   worst of all.
4. **The folder name is the name shown** in EmulationStation.

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
| a 32-bit game dies the moment it plays a sound | the 32-bit gstreamer plugins are missing | `gstreamer-plugins-{libav,good,ugly}-32bit` — the 32-bit core loads happily and decodes nothing |

At the end of every packaging run `build.sh` says what **this system** still
lacks for **that game** — DXVK, the LÖVE engine, the 32-bit plugins, wine itself
— by package name. Finding that out from a crash dump costs an evening.

This one is automatic. `build.sh` spots a Unity game (`UnityPlayer.dll`) with an
`.mp4` cutscene and writes `ENV=WINEDLLOVERRIDES="d3d11,dxgi=n,b"` into its
`autorun.cmd`; `play.sh`, on the first run, wires DXVK into the prefix if it
finds it installed — it looks in `/usr/libexec/dxvk/lib64`, `/usr/share/dxvk/x64`,
`/usr/lib/dxvk/x64` and `/opt/dxvk/x64`. All you need is the package:

```bash
sudo zypper in dxvk          # or whatever your distro calls it
```

It picks the 64-bit directory by name on purpose: the `setup_dxvk.sh` that ships
with the package hands the **32-bit** DLLs to a 64-bit prefix, and wine then
falls back to its own without a word — the cutscene stays black and nothing in
the log admits it. If in doubt, check:

```bash
file -L .prefix/drive_c/windows/system32/d3d11.dll   # has to say x86-64
```

A `.webm` cutscene is VP8, which Unity decodes by itself: none of this applies.

---

## `autorun.cmd`

Read by Batocera **and** by `play.sh`. It needs **LF** (Unix) line endings, not
CRLF — CRLF is the number one cause of "it doesn't start".

```
CMD=game.exe                      # required; quote it if it has spaces
DIR=64bit/bin                     # optional; CMD is relative to it
ENV=WINEDLLOVERRIDES="d3d11=n"    # optional, repeatable
SCREEN=native                     # optional, only play.sh reads it
LANG=pt_BR.UTF-8                  # optional
SAVEDIR=drive_c/users/...         # optional, Batocera v42+
```

Arguments ride along with `CMD`: `CMD="My Game.exe" --fullscreen`

`DIR=` comes from `workingDir` in `goggame-*.info`, when GOG gives one and the
executable lives inside it. A game that loads its DLLs by relative path — a
`Launcher64.exe` inside `x64/`, say — exits without a word if run from the root.

`SCREEN=native` is written by `build.sh` for a Unity game. At launch `play.sh`
reads the screen's preferred mode from `/sys/class/drm/*/modes` — no `xrandr`, so
Batocera has it too — and appends `-screen-width`, `-screen-height` and
`-screen-fullscreen 1`. The numbers belong to the machine that plays, not the one
that packaged. `GOG2LINUX_SCREEN=1280x720` pins a size, `=no` turns it off.

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

## Other ways to package

`install/` is the standard path. When you want to pick the `.pc` name, or
package something that lives outside the inbox, the target goes on the command
line:

```bash
./build.sh grimdawn                              # grimdawn/ -> grimdawn.pc
./build.sh Game.pc "/path/Game_(58051)_win_gog"  # GOG's folder as it came
./build.sh Game.pc "/path/setup.exe" "/path/DLC/dlc.exe"
./build.sh Game.pc                               # no installer: just a re-read
```

That last one is the repair mode: it runs the detection again and rewrites
`autorun.cmd` without extracting anything. Use it after editing the folder by
hand, or to add a menu entry to a finished game (`./build.sh --desktop Game.pc`).

Here you type the paths, so **quote them** — GOG-Games filenames almost always
carry parentheses, and unquoted, bash complains with `syntax error`. `~` does not
expand inside quotes: leave the tilde out, or hit **Tab** and let bash escape it.
And no brackets; in the `usage:` line they only mark what is optional, and copied
along they become part of the path.

Both ends of `install/` move too:

```bash
GOG2LINUX_INBOX=/mnt/hd/downloads ./build.sh    # where to read from
GOG2LINUX_GAMES=/mnt/hd/games ./build.sh        # where to install
```

Worth it when home is a small partition: one GOG game passes 20 GB easily.

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
`WINE_GAMES` (where single-file games get extracted),
`GOG2LINUX_INHIBIT=no` (let the machine sleep while playing).

By default `play.sh` runs wine inside `systemd-inhibit --what=idle`. A wine game
touches neither the screensaver nor the idle-inhibit protocol, so without this
the desktop keeps counting down and suspends in the middle of a level. The hold
lasts exactly as long as the game. Native games go through SDL, which already
does it; with no systemd, as on Batocera, there is nothing to hold.
