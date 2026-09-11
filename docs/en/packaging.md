# Packaging

## The universal rule: any GOG game in 2 steps

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

# 2. play
~/Games/"Grim Dawn.pc"/play.sh
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
2. **The folder travels, the `.prefix/` does not.** Copying a game to another
   machine, leave `.prefix/` behind: it is some 400 MB and is rebuilt on the
   first boot there, with that machine's runtime.
3. **Do not keep games on NTFS.** It breaks wine, Steam/Galaxy games worst of
   all.

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

## `autorun.cmd`

Read by `play.sh`. It needs **LF** (Unix) line endings, not
CRLF — CRLF is the number one cause of "it doesn't start".

```
CMD=game.exe                      # required; quote it if it has spaces
DIR=64bit/bin                     # optional; CMD is relative to it
ENV=WINEDLLOVERRIDES="d3d11=n"    # optional, repeatable
SCREEN=native                     # optional, only play.sh reads it
LANG=pt_BR.UTF-8                  # optional
```

Arguments ride along with `CMD`: `CMD="My Game.exe" --fullscreen`

`DIR=` comes from `workingDir` in `goggame-*.info`, when GOG gives one and the
executable lives inside it. A game that loads its DLLs by relative path — a
`Launcher64.exe` inside `x64/`, say — exits without a word if run from the root.

`SCREEN=native` is written by `build.sh` for a Unity game. At launch `play.sh`
reads the screen's preferred mode from `/sys/class/drm/*/modes` — no `xrandr`, so
no `xrandr` needed — and appends `-screen-width`, `-screen-height` and
`-screen-fullscreen 1`. The numbers belong to the machine that plays, not the one
that packaged. `GOG2LINUX_SCREEN=1280x720` pins a size, `=no` turns it off.

## GOG's Linux builds

Many GOG games have a Linux version, downloaded separately from the Windows
installer — one large `.sh`. Drop it in `install/` like anything else:

```bash
./build.sh
```

`build.sh` recognises the format (a MojoSetup shell script with a zip glued to
the end), extracts the game from `data/noarch/`, fixes the execute bit on the
binary and writes a `launch.sh`. What comes out is a **native** package: no
wine, no Proton, no prefix.

The name comes from the `gameinfo` inside, which is the one GOG uses.

It is always worth checking whether a game has a Linux build before packaging
the Windows one — it tends to settle in one step what costs hours under wine.
That was Owlboy here: the Windows version played no music because of a defect in
wine's audio reimplementation, and the Linux build simply works.

## Bringing in a game installed by another app

A game installed elsewhere — by Lutris, Bottles, Faugus, or a plain wine session
— leaves its prefix in one place and its files in another. `--prefix` puts them
together:

```bash
./build.sh --prefix ~/path/to/prefix ~/path/to/game
```

It moves the prefix into the folder as `.prefix`, then does the usual re-read:
finds the executable, detects the engine, looks for wrappers and writes
`autorun.cmd`. After that the game runs like any other:

```bash
~/path/to/game/play.sh
```

No runner to pin: `play.sh` finds umu on its own.

With the prefix inside the folder the `.pc` is self-contained — `saves.sh` and
`uninstall.sh` can see it, and the folder travels whole. In exchange, **the
other app's entry points at the old path and stops working**; copy the prefix
first if you want to keep both.

`--prefix` refuses a folder with no `drive_c`, so you cannot move the wrong
thing by accident.

## Repacks (FitGirl and the like)

A repack cannot be extracted: the game lives in FreeArc archives beside the
installer (`fg-*.bin`, `*.arc`), and only it knows how to open them. What is
inside the `.exe` is just the decompressors. `build.sh` spots this before
extracting and stops.

Install it with whatever tool you like and bring the folder over with `--prefix`
above. Two choices while installing, each of which has cost hours here:

- **Use the installer's own interface.** `/VERYSILENT` does not work: the
  unpacking is driven by the repack's own form, and in silent mode it exits with
  code 0 without writing a byte.
- **Tick the memory limit** if there is one. FitGirl repacks have a *"Limit
  installer to 2 GB of RAM usage"* box on the first screen. It installs more
  slowly and does not blow the address space of the installer, which is 32-bit.

Calling `umu-run` straight on `setup.exe` tends to fail at mapping the game
drive (`unable to use parent for game drive`), and the error you see is Unarc's
generic *"Unable to write data to disk"*, which sends you looking in the wrong
place. Front-ends that wrap umu set that variable and do not suffer from it.

One caveat: a repack has no `goggame-*.info`, so there is no GOG metadata to go
on — the name, `workingDir` and tasks come from whatever is in the folder.
