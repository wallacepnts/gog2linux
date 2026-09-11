# Native engines

## Old games: DOSBox and ScummVM

A GOG classic is usually a DOSBox 0.74 (from 2010) in a wrapper. Running that
through wine means running an emulator inside an API translator — `build.sh`
detects it and refuses. To find out before you even extract:

```bash
innoextract -l "setup_game.exe" | grep -iE 'dosbox|scummvm'
```

GOG's own `.conf` files are good and save you the work:

```bash
sudo apt install dosbox-staging   # openSUSE ships it as `dosbox` 0.82, already staging
cd Game.pc && dosbox -conf dosbox_game.conf -conf dosbox_game_single.conf
```

Before any of that, though: check whether a **source port** exists (OpenMW,
DevilutionX, VCMI, OpenRA, GZDoom, OpenTTD, Arx Libertatis, CorsixTH...).
PCGamingWiki lists them per game. Native port > DOSBox > wine.

### Ren'Py: the Linux build is already in there

Ren'Py visual novels (and some Java/Löve games) pack every platform into the
same installer. After `build.sh`, if you see

```
note: native Linux build here -> ./Game.pc/Game.sh (no wine)
```

use that `.sh` on the desktop — it's the game running natively, no API
translation. `build.sh` already fixes the execute bit, which a Windows installer
does not carry.

`autorun.cmd` is still written either way: it is the record of what the game
needs, and the fallback if the native build does not serve.

## When a native engine exists

Some classics have had their engine reimplemented — open source, native, real
fullscreen, modern controllers. That beats wine every time, so `build.sh` says
so at the end of packaging:

```
note: Nox has a reimplemented engine (OpenNox) - native, better than wine: flathub io.github.noxworld_dev.OpenNox
```

It only tells you. Installing the port, and keeping the wine copy or not, stays
your call. The full list, sorted by genre and with a link to every project,
lives in **[ENGINES.md](../ENGINES.md)** — around sixty games.

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
