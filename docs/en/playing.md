# Playing

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

A native game tends to write **outside** its own folder, and that travels in the
backup too, going back where it belongs on `restore`:

- **Steam rip on Goldberg** — a `local_save.txt`, if present, names a folder
  inside the game (rarely called "save", so only that file finds it). Without
  it the saves go to `~/.local/share/Goldberg SteamEmu Saves/<AppID>/`, and the
  App ID comes from the `steam_appid.txt` shipped alongside.
- **Ren'Py** — `~/.renpy/<Name>/`, under the name the game uses rather than
  ours. `saves.sh` works out which folder is its own from the launcher it ships.

While you are in there: Goldberg's `settings/language.txt` sets the game
language and `settings/account_name.txt` the player name. A Steam rip carrying
`activated.ini` uses `Language` and `UserName` for the same thing.

`uninstall.sh` runs a backup before deleting anything, and with `-y` it does so
without asking. The game comes back from the installer; the saves do not.

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

## The machine stays awake while you play

By default `play.sh` runs wine inside `systemd-inhibit --what=idle`. A wine game
touches neither the screensaver nor the idle-inhibit protocol, so without this
the desktop keeps counting down and suspends in the middle of a level. The hold
lasts exactly as long as the game. Native games go through SDL, which already
does it; with no systemd, there is nothing to hold.
