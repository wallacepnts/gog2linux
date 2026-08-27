#!/usr/bin/env bash
# Checks build.sh and play.sh. Runs in a temp folder, touches nothing else.
#   build.sh with no installer arguments only classifies the folder -- that is
#   how the detection gets tested without a real GOG installer.
#   play.sh gets a fake "wine" that prints cwd, prefix, env and arguments.
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
tmp=$(mktemp -d); tmp=$(cd "$tmp" && pwd -P); trap 'rm -rf "$tmp"' EXIT
printf '#!/bin/sh\necho "$PWD|$WINEPREFIX|$WINEDLLOVERRIDES|$*"\n' > "$tmp/fakewine"
chmod +x "$tmp/fakewine"

run() { WINE="$tmp/fakewine" WINE_GAMES="$tmp/cache" "$@"; }
eq()  { [ "$2" = "$3" ] || { echo "FAILED $1:"; echo "  got:      $2"; echo "  expected: $3"; exit 1; }; }
has() { case "$2" in *"$3"*) ;; *) echo "FAILED $1:"; echo "  output:   $2"; echo "  should contain: $3"; exit 1 ;; esac; }

## build.sh

# DOSBox game in disguise: warns and writes no autorun.cmd
mkdir -p "$tmp/dos.pc/DOSBOX"
has dos "$("$here/build.sh" "$tmp/dos.pc")" "dos game in disguise"
[ ! -e "$tmp/dos.pc/autorun.cmd" ] || { echo "FAILED: wrote autorun.cmd for a DOS game"; exit 1; }

# same for ScummVM
mkdir -p "$tmp/sv.pc"; touch "$tmp/sv.pc/scummvm.exe"
has scummvm "$("$here/build.sh" "$tmp/sv.pc")" "scummvm game in disguise"

# app/ holding a folder that already exists at the root: mv would fail, must merge
mkdir -p "$tmp/mix.pc/app/lib" "$tmp/mix.pc/lib"
touch "$tmp/mix.pc/app/lib/deApp" "$tmp/mix.pc/lib/daRaiz" "$tmp/mix.pc/game.exe"
has merge "$("$here/build.sh" "$tmp/mix.pc")" "CMD=game.exe"
[ ! -d "$tmp/mix.pc/app" ] || { echo "FAILED: app/ left behind"; exit 1; }
for f in lib/deApp lib/daRaiz; do
  [ -e "$tmp/mix.pc/$f" ] || { echo "FAILED merge: $f went missing"; exit 1; }
done

# with no goggame-*.info, grep must not fall through to the caller's stdin
# (it hangs, or -- as here -- eats the pipe and takes it for the exe name)
mkdir -p "$tmp/pipe.pc"; touch "$tmp/pipe.pc/game.exe"
has stdin "$(echo '"path": "deStdin.exe"' | "$here/build.sh" "$tmp/pipe.pc")" "CMD=game.exe"

# reclassifying must not delete a tmp/ that belongs to the game
mkdir -p "$tmp/t.pc/tmp"; touch "$tmp/t.pc/game.exe" "$tmp/t.pc/tmp/save.dat"
has tmp "$("$here/build.sh" "$tmp/t.pc")" "CMD=game.exe"
[ -e "$tmp/t.pc/tmp/save.dat" ] || { echo "FAILED: reclassify deleted the game's tmp/"; exit 1; }

# a .info listing launcher + game + tool: picks one, shows the rest
mkdir -p "$tmp/multi.pc"
touch "$tmp/multi.pc/Launcher.exe" "$tmp/multi.pc/Game_dx.exe" "$tmp/multi.pc/Editor.exe"
printf '{"playTasks":[{"category":"launcher","path":"Launcher.exe"},{"category":"game","path":"Game_dx.exe"},{"category":"tool","path":"Editor.exe"}]}' > "$tmp/multi.pc/goggame-1.info"
out=$("$here/build.sh" "$tmp/multi.pc")
has multi-cmd "$out" "CMD=Launcher.exe"
has multi-alt "$out" "Editor.exe, Game_dx.exe"

# plain Windows game: writes autorun.cmd
mkdir -p "$tmp/win.pc"; touch "$tmp/win.pc/game.exe"
has windows "$("$here/build.sh" "$tmp/win.pc")" "CMD=game.exe"
[ -e "$tmp/win.pc/autorun.cmd" ] || { echo "FAILED: no autorun.cmd written"; exit 1; }

## play.sh

# .pc folder: prefix beside it, DIR with a space, quoted CMD with an argument, CRLF
mkdir -p "$tmp/g.pc/64bit/bin dir"
cp "$here/play.sh" "$tmp/g.pc/"
printf 'ENV=WINEDLLOVERRIDES="d3d11=n"\r\nDIR=64bit/bin dir\r\nCMD="Meu Jogo.exe" --fullscreen\r\n' > "$tmp/g.pc/autorun.cmd"
eq .pc "$(run "$tmp/g.pc/play.sh")" \
      "$tmp/g.pc/64bit/bin dir|$tmp/g.pc/.prefix|d3d11=n|Meu Jogo.exe --fullscreen"

# .wtgz: the extracted folder is the prefix, packed with an extra root folder
mkdir -p "$tmp/x/g.wine/drive_c/game"
printf 'DIR=drive_c/game\nCMD=game.exe\n' > "$tmp/x/g.wine/autorun.cmd"
touch "$tmp/x/g.wine/sentinel"
tar czf "$tmp/g.wtgz" -C "$tmp/x" g.wine
eq .wtgz "$(run "$tmp/g.pc/play.sh" "$tmp/g.wtgz")" \
         "$tmp/cache/g/g.wine/drive_c/game|$tmp/cache/g/g.wine||game.exe"

# native Linux build alongside: run it, not wine (and FORCE_WINE goes back to wine)
mkdir -p "$tmp/n.pc/lib/py2-linux-x86_64"
cp "$here/play.sh" "$tmp/n.pc/"
printf 'CMD=game.exe\n' > "$tmp/n.pc/autorun.cmd"
printf '#!/bin/sh\necho native-ok\n' > "$tmp/n.pc/game.sh"; chmod +x "$tmp/n.pc/game.sh"
eq native "$(run "$tmp/n.pc/play.sh")" "native-ok"
eq force-wine "$(FORCE_WINE=1 run "$tmp/n.pc/play.sh")" "$tmp/n.pc|$tmp/n.pc/.prefix||game.exe"

# second run reuses the cache: the removed file must not come back
rm "$tmp/cache/g/g.wine/sentinel"
run "$tmp/g.pc/play.sh" "$tmp/g.wtgz" >/dev/null
[ ! -e "$tmp/cache/g/g.wine/sentinel" ] || { echo "FAILED cache: re-extracted"; exit 1; }

# an extraction that dies halfway must not become a valid cache forever
head -c 200 /dev/urandom > "$tmp/corrupt.wtgz"
! run "$tmp/g.pc/play.sh" "$tmp/corrupt.wtgz" >/dev/null 2>&1 || { echo "FAILED: exited 0 on a corrupt wtgz"; exit 1; }
[ ! -d "$tmp/cache/corrupt" ] || { echo "FAILED: aborted extraction became cache"; exit 1; }

# a second argument overrides CMD (launcher, editor) and skips the native build
eq override "$(run "$tmp/n.pc/play.sh" "$tmp/n.pc" "Other Game.exe" --windowed)" \
            "$tmp/n.pc|$tmp/n.pc/.prefix||Other Game.exe --windowed"

# native .sh without the execute bit: recover instead of dying with rc=126
mkdir -p "$tmp/nx.pc/lib/py2-linux-x86_64"; cp "$here/play.sh" "$tmp/nx.pc/"
printf 'CMD=game.exe\n' > "$tmp/nx.pc/autorun.cmd"
printf '#!/bin/sh\necho native-ok\n' > "$tmp/nx.pc/game.sh"
eq native-no-x "$(run "$tmp/nx.pc/play.sh")" "native-ok"

# last line without a trailing \n still counts
mkdir -p "$tmp/nl.pc"; cp "$here/play.sh" "$tmp/nl.pc/"
printf 'CMD=game.exe' > "$tmp/nl.pc/autorun.cmd"
eq no-newline "$(run "$tmp/nl.pc/play.sh")" "$tmp/nl.pc|$tmp/nl.pc/.prefix||game.exe"

# WINEARCH is only pinned for a fresh prefix (an existing 32-bit one won't boot)
printf '#!/bin/sh\necho "arch=${WINEARCH-unset}"\n' > "$tmp/archwine"
chmod +x "$tmp/archwine"
mkdir -p "$tmp/a.pc"; cp "$here/play.sh" "$tmp/a.pc/"
printf 'CMD=game.exe\n' > "$tmp/a.pc/autorun.cmd"
eq arch-fresh "$(WINE="$tmp/archwine" "$tmp/a.pc/play.sh")" "arch=win64"
mkdir -p "$tmp/a.pc/.prefix"
eq arch-existing "$(WINE="$tmp/archwine" "$tmp/a.pc/play.sh")" "arch=unset"

# missing autorun.cmd, or one with no CMD=: error, never a silent success
mkdir -p "$tmp/empty.pc"; cp "$here/play.sh" "$tmp/empty.pc/"
! run "$tmp/empty.pc/play.sh" >/dev/null 2>&1 || { echo "FAILED: exited 0 with no autorun.cmd"; exit 1; }
printf 'DIR=.\n' > "$tmp/empty.pc/autorun.cmd"
! run "$tmp/empty.pc/play.sh" >/dev/null 2>&1 || { echo "FAILED: exited 0 with no CMD="; exit 1; }

echo OK
