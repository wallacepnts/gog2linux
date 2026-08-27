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

- `innoextract` — for **packaging** only (unpacks GOG's InnoSetup without running anything).
- `wine` — for **playing** only. If you just copy the folder to Batocera, you don't need it.

Case by case: `squashfs-tools` (to open `.wsquashfs`), `winetricks` (games that
want a Microsoft DLL).

---

## The universal rule: any GOG game in 3 steps

```bash
# 1. package (once, on any Linux PC)
./build.sh GameName.pc "/path/setup_game_1.2.3.exe" ["dlc1.exe" "dlc2.exe" ...]

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
4. **Copy the whole folder** to Batocera, minus `.prefix/` (that's the local
   prefix, ~400 MB, and Batocera doesn't use it).
5. **Keep `/userdata/` on btrfs or ext4.** NTFS breaks wine, Steam/Galaxy games
   especially.
6. **The folder name is the name shown** in EmulationStation.

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

## Running the launcher or the bundled tools

GOG games often ship more than the game: a launcher, a map editor, a key
changer, a DirectPlay setup. Pass the executable as a second argument and it
runs in the same prefix, with `autorun.cmd` untouched:

```bash
./Game.pc/play.sh . "Launcher.exe"
./Game.pc/play.sh . "Map Editor.exe"
```

`build.sh` lists what else the `goggame-*.info` offers, right after packaging:

```
done: /path/Game.pc (CMD=Launcher.exe)
other entries in goggame-*.info: Game_dx.exe, Map Editor.exe
  if the game won't start, try one of those in autorun.cmd
```

Worth knowing: GOG usually marks the **launcher** as the primary task, so that
is what lands in `autorun.cmd`. If the game won't start from it, one of the
listed alternatives usually does — old titles often ship both a classic and a
DirectX build, and only the latter survives wine.

---

## Files in this project

| | |
|---|---|
| `build.sh` | GOG installer → `.pc` folder |
| `play.sh` | runs `.pc`, `.wine`, `.wtgz` or `.wsquashfs` outside Batocera |
| `test.sh` | checks both (detection, parser, CRLF, native build, cache) |

`play.sh` takes an optional second argument that overrides `CMD`.

Variables it honours: `WINE` (binary), `WINEPREFIX`, `WINEARCH`,
`FORCE_WINE=1` (ignore the native build),
`WINE_GAMES` (where single-file games get extracted).
