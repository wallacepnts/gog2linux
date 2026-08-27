#!/usr/bin/env bash
# Checks build.sh and play.sh. Runs in a temp folder, touches nothing else.
#   build.sh with no installer arguments only classifies the folder -- that is
#   how the detection gets tested without a real GOG installer.
#   play.sh gets a fake "wine" that prints cwd, prefix, env and arguments.
set -euo pipefail
exec </dev/null          # build.sh only offers the menu entry on a tty
export GOG2LINUX_LANG=en # assertions below are in English
here=$(dirname "$(readlink -f "$0")")
tmp=$(mktemp -d); tmp=$(cd "$tmp" && pwd -P); trap 'rm -rf "$tmp"' EXIT
printf '#!/bin/sh\necho "$PWD|$WINEPREFIX|$WINEDLLOVERRIDES|$*"\n' > "$tmp/fakewine"
chmod +x "$tmp/fakewine"

run() { WINE="$tmp/fakewine" WINE_GAMES="$tmp/cache" "$@"; }
eq()  { [ "$2" = "$3" ] || { echo "FAILED $1:"; echo "  got:      $2"; echo "  expected: $3"; exit 1; }; }
has() { case "$2" in *"$3"*) ;; *) echo "FAILED $1:"; echo "  output:   $2"; echo "  should contain: $3"; exit 1 ;; esac; }

## build.sh

# destination omitted: the installer lands in $1 and mkdir would fail cryptically
touch "$tmp/setup.exe"
! "$here/build.sh" "$tmp/setup.exe" >/dev/null 2>&1 || { echo "FAILED: accepted a file as destination"; exit 1; }

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

# the .info names the exe with Windows casing; the file on disk differs
mkdir -p "$tmp/case.pc"; touch "$tmp/case.pc/Doom3.exe"
printf '{"playTasks":[{"category":"game","path":"DOOM3.exe"}]}' > "$tmp/case.pc/goggame-1.info"
has case "$("$here/build.sh" "$tmp/case.pc")" "CMD=Doom3.exe"

# launcher + game + tool: the game wins even when GOG marks the launcher primary
mkdir -p "$tmp/multi.pc"
touch "$tmp/multi.pc/Launcher.exe" "$tmp/multi.pc/Game_dx.exe" "$tmp/multi.pc/Editor.exe"
printf '{"playTasks":[{"category":"launcher","isPrimary":true,"path":"Launcher.exe"},{"category":"game","path":"Game_dx.exe"},{"category":"tool","path":"Editor.exe"}]}' > "$tmp/multi.pc/goggame-1.info"
out=$("$here/build.sh" "$tmp/multi.pc")
has multi-cmd "$out" "CMD=Game_dx.exe"
has multi-alt "$out" "Editor.exe, Launcher.exe"

# the .script becomes a .reg, minus the actions meant for other languages
mkdir -p "$tmp/reg.pc"; touch "$tmp/reg.pc/Game.exe"
printf '{"languages":["en-US"],"playTasks":[{"category":"game","path":"Game.exe"}]}' > "$tmp/reg.pc/goggame-1.info"
cat > "$tmp/reg.pc/goggame-1.script" <<'SCRIPT'
{"actions":[
 {"languages":["*"],"install":{"action":"setRegistry","arguments":{
   "root":"HKLM","subkey":"Software\\id","valueName":"InstallPath","valueData":"{app}","valueType":"string"}}},
 {"languages":["it-IT"],"install":{"action":"setRegistry","arguments":{
   "root":"HKLM","subkey":"Software\\id","valueName":"Language","valueData":"ita","valueType":"string"}}}
]}
SCRIPT
"$here/build.sh" "$tmp/reg.pc" >/dev/null
reg=$(cat "$tmp/reg.pc/gog-registry.reg")
has reg-path "$reg" '"InstallPath"="%APP%"'
has reg-wow "$reg" 'HKEY_LOCAL_MACHINE\Software\WOW6432Node\id'
case "$reg" in *ita*) echo "FAILED reg-lang: kept an it-IT action in an en-US copy"; exit 1 ;; esac

# Inno writes hex the Pascal way; an unreadable value is skipped, not fatal
mkdir -p "$tmp/dw.pc"; touch "$tmp/dw.pc/Game.exe"
printf '{"languages":["en-US"],"playTasks":[{"category":"game","path":"Game.exe"}]}' > "$tmp/dw.pc/goggame-1.info"
cat > "$tmp/dw.pc/goggame-1.script" <<'SCRIPT'
{"actions":[
 {"languages":["*"],"install":{"action":"setRegistry","arguments":{
   "root":"HKCU","subkey":"Software\\x","valueName":"Pascal","valueData":"$0000002a","valueType":"dword"}}},
 {"languages":["*"],"install":{"action":"setRegistry","arguments":{
   "root":"HKCU","subkey":"Software\\x","valueName":"Junk","valueData":"not a number","valueType":"dword"}}},
 {"languages":["*"],"install":{"action":"setRegistry","arguments":{
   "root":"HKCU","subkey":"Software\\x","valueName":"Bin","valueData":"QUJD","valueType":"binary"}}}
]}
SCRIPT
"$here/build.sh" "$tmp/dw.pc" >/dev/null
dw=$(cat "$tmp/dw.pc/gog-registry.reg")
has dword-pascal "$dw" '"Pascal"=dword:0000002a'
has binary-hex   "$dw" '"Bin"=hex:41,42,43'
case "$dw" in *Junk*) echo "FAILED: kept a value it cannot parse"; exit 1 ;; esac

# play.sh applies that .reg when it creates the prefix, with %APP% resolved
cp "$here/play.sh" "$tmp/reg.pc/"
out=$(run "$tmp/reg.pc/play.sh")
has reg-import "$out" "regedit /S"
has reg-run "$out" "Game.exe"

# renaming the folder makes the recorded paths stale, so it re-applies
mv "$tmp/reg.pc" "$tmp/moved.pc"
has reg-removed "$(run "$tmp/moved.pc/play.sh")" "regedit /S"
mv "$tmp/moved.pc" "$tmp/reg.pc"

# and the path it splices in keeps its backslashes doubled, the way .reg wants
printf '#!/bin/sh\ncat "$3"\n' > "$tmp/dumpwine"; chmod +x "$tmp/dumpwine"
rm -rf "$tmp/reg.pc/.prefix"
esc=$(printf '%s' "$tmp/reg.pc" | sed 's|/|\\\\|g')
has reg-path "$(WINE="$tmp/dumpwine" "$tmp/reg.pc/play.sh" 2>/dev/null)" "\"InstallPath\"=\"Z:$esc\""

# --desktop writes a freedesktop entry, with the GOG icon when there is one
# the wrapper scan must not clobber the game name used by the menu entry
mkdir -p "$tmp/menu.pc"; touch "$tmp/menu.pc/Game.exe" "$tmp/menu.pc/ddraw.dll"
python3 - "$tmp/menu.pc/goggame-9.ico" <<'ICO'
import struct, sys
# two entries, 16x16 and 256x256, both PNG-compressed like GOG ships them
small, big = b'\x89PNG' + b'small', b'\x89PNG' + b'big'
head = struct.pack('<HHH', 0, 1, 2)
off = 6 + 32
d1 = struct.pack('<BBBBHHII', 16, 16, 0, 0, 1, 32, len(small), off)
d2 = struct.pack('<BBBBHHII', 0, 0, 0, 0, 1, 32, len(big), off + len(small))
open(sys.argv[1], 'wb').write(head + d1 + d2 + small + big)
ICO
printf '{"name":"My Game","playTasks":[{"category":"game","path":"Game.exe"}]}' > "$tmp/menu.pc/goggame-9.info"
XDG_DATA_HOME="$tmp/xdg" "$here/build.sh" --desktop "$tmp/menu.pc" >/dev/null
entry="$tmp/xdg/applications/gog-menu.desktop"
[ -f "$entry" ] || { echo "FAILED: no .desktop written"; exit 1; }
has desktop-name "$(cat "$entry")" "Name=My Game"
has desktop-exec "$(cat "$entry")" "Exec=$tmp/menu.pc/play.sh"
has desktop-icon "$(cat "$entry")" "Icon=$tmp/menu.pc/icon.png"
[ "$(cat "$tmp/menu.pc/icon.png")" = "$(printf '\x89PNGbig')" ] || { echo "FAILED: took the small icon"; exit 1; }
has desktop-cat  "$(cat "$entry")" "Categories=Game;"

# the flags parse in any order and none of them swallow the destination
has flags "$("$here/build.sh" --lang en-US --no-desktop "$tmp/multi.pc")" "CMD=Game_dx.exe"

# a bundled ddraw is a wrapper wine would otherwise ignore; UnityPlayer is not
mkdir -p "$tmp/wrap.pc"; touch "$tmp/wrap.pc/Game.exe" "$tmp/wrap.pc/ddraw.dll" "$tmp/wrap.pc/dinput.dll" "$tmp/wrap.pc/UnityPlayer.dll"
"$here/build.sh" "$tmp/wrap.pc" >/dev/null
has wrappers "$(cat "$tmp/wrap.pc/autorun.cmd")" 'ENV=WINEDLLOVERRIDES="ddraw,dinput=n,b"'
case "$(cat "$tmp/wrap.pc/autorun.cmd")" in *UnityPlayer*) echo "FAILED: overrode a DLL wine does not provide"; exit 1 ;; esac

# saves.sh finds both places a game keeps saves, and puts them back
mkdir -p "$tmp/sv2.pc/SAVE" "$tmp/sv2.pc/.prefix/drive_c/users/w/Documents"
touch "$tmp/sv2.pc/Game.exe"
printf '{"name":"Sv","playTasks":[{"category":"game","path":"Game.exe"}]}' > "$tmp/sv2.pc/goggame-9.info"
"$here/build.sh" --no-desktop "$tmp/sv2.pc" >/dev/null
echo old > "$tmp/sv2.pc/SAVE/slot1.dat"
echo doc > "$tmp/sv2.pc/.prefix/drive_c/users/w/Documents/save.txt"
"$tmp/sv2.pc/saves.sh" backup "$tmp/bk.tar.gz" >/dev/null
rm -rf "$tmp/sv2.pc/SAVE" "$tmp/sv2.pc/.prefix/drive_c/users"
"$tmp/sv2.pc/saves.sh" restore "$tmp/bk.tar.gz" >/dev/null
eq save-game "$(cat "$tmp/sv2.pc/SAVE/slot1.dat")" "old"
eq save-prefix "$(cat "$tmp/sv2.pc/.prefix/drive_c/users/w/Documents/save.txt")" "doc"

has saves-ptbr "$(GOG2LINUX_LANG=pt "$tmp/sv2.pc/saves.sh" backup "$tmp/bk2.tar.gz")" "backup feito:"

# uninstalling backs the saves up before it deletes anything
mkdir -p "$tmp/bye.pc/SAVE"; touch "$tmp/bye.pc/Game.exe"
printf '{"name":"Bye","playTasks":[{"category":"game","path":"Game.exe"}]}' > "$tmp/bye.pc/goggame-9.info"
"$here/build.sh" --no-desktop "$tmp/bye.pc" >/dev/null
echo keep > "$tmp/bye.pc/SAVE/slot1.dat"
( cd "$tmp" && XDG_DATA_HOME="$tmp/xdg" "$tmp/bye.pc/uninstall.sh" -y >/dev/null )
[ ! -d "$tmp/bye.pc" ] || { echo "FAILED: folder survived"; exit 1; }
bk=("$tmp"/bye-saves-*.tar.gz)
[ ${#bk[@]} -eq 1 ] || { echo "FAILED: no save backup left behind"; exit 1; }
eq save-rescued "$(tar xzf "${bk[0]}" -O SAVE/slot1.dat)" "keep"

# the uninstaller lands in the folder and takes the game and both entries away
mkdir -p "$tmp/gone.pc"; touch "$tmp/gone.pc/Game.exe"
printf '{"name":"Gone","playTasks":[{"category":"game","path":"Game.exe"}]}' > "$tmp/gone.pc/goggame-9.info"
XDG_DATA_HOME="$tmp/xdg" "$here/build.sh" --desktop "$tmp/gone.pc" >/dev/null
[ -x "$tmp/gone.pc/uninstall.sh" ] || { echo "FAILED: no uninstall.sh copied"; exit 1; }
[ ! -e "$tmp/xdg/applications/gog-gone-uninstall.desktop" ] || { echo "FAILED: uninstaller does not belong in the menu"; exit 1; }
XDG_DATA_HOME="$tmp/xdg" "$tmp/gone.pc/uninstall.sh" -y >/dev/null
[ ! -d "$tmp/gone.pc" ] || { echo "FAILED: folder survived"; exit 1; }
[ ! -e "$tmp/xdg/applications/gog-gone.desktop" ] || { echo "FAILED: menu entry survived"; exit 1; }

# the same run speaks Portuguese when asked to
has ptbr "$(GOG2LINUX_LANG=pt "$here/build.sh" "$tmp/multi.pc")" "pronto:"
has ptbr-others "$(GOG2LINUX_LANG=pt "$here/build.sh" "$tmp/multi.pc")" "outras entradas"

# an icon that is not called goggame-*.ico still counts
mkdir -p "$tmp/ico.pc"; touch "$tmp/ico.pc/Game.exe"
for f in gog.ico Support.ico NOTES.ICO; do
python3 - "$tmp/ico.pc/$f" <<'ICO'
import struct, sys
small = b'\x89PNG' + b'generic'
open(sys.argv[1], 'wb').write(
    struct.pack('<HHH', 0, 1, 1) + struct.pack('<BBBBHHII', 16, 16, 0, 0, 1, 32, len(small), 22) + small)
ICO
done
python3 - "$tmp/ico.pc/ICO.ICO" <<'ICO'
import struct, sys
big = b'\x89PNG' + b'nox'
open(sys.argv[1], 'wb').write(
    struct.pack('<HHH', 0, 1, 1) + struct.pack('<BBBBHHII', 0, 0, 0, 0, 1, 32, len(big), 22) + big)
ICO
XDG_DATA_HOME="$tmp/xdg" "$here/build.sh" --desktop "$tmp/ico.pc" >/dev/null
has icon-alt "$(cat "$tmp/xdg/applications/gog-ico.desktop")" "Icon=$tmp/ico.pc/icon.png"
eq icon-named "$(cat "$tmp/ico.pc/icon.png")" "$(printf '\x89PNGnox')"

# every game listed in ENGINES.md must be recognised by build.sh, or the doc and
# the script have drifted apart
missing=""
while IFS='|' read -r _ games engine _; do
  game=$(printf '%s' "$games" | cut -d, -f1 | sed 's/^ *//; s/ *$//')
  [ -n "$game" ] || continue
  case "$game" in Game|Games|---*|"") continue ;; esac
  rm -rf "$tmp/eng.pc"; mkdir -p "$tmp/eng.pc"; touch "$tmp/eng.pc/Game.exe"
  printf '{"name":"%s","playTasks":[{"category":"game","path":"Game.exe"}]}' "$game" > "$tmp/eng.pc/goggame-1.info"
  case "$("$here/build.sh" "$tmp/eng.pc")" in
    *"reimplemented engine"*) ;;
    *) missing="$missing$game; " ;;
  esac
# the "Whole catalogues" section is out of scope: ScummVM games are recognised
# by the files in the installer, never by their name
done < <(sed '/^## Whole catalogues/,$d' "$here/.github/ENGINES.md" | grep '^| ')
[ -z "$missing" ] || { echo "FAILED: ENGINES.md lists games build.sh ignores: $missing"; exit 1; }

# a classic with an open engine gets a heads-up, not a decision
mkdir -p "$tmp/morrowind.pc"; touch "$tmp/morrowind.pc/Game.exe"
has port-note "$("$here/build.sh" "$tmp/morrowind.pc")" "OpenMW"
mkdir -p "$tmp/plain.pc"; touch "$tmp/plain.pc/Game.exe"
case "$("$here/build.sh" "$tmp/plain.pc")" in *"reimplemented engine"*) echo "FAILED: invented a port"; exit 1 ;; esac

# a launch.sh in the folder takes over the menu entry, for source ports
mkdir -p "$tmp/port.pc"; touch "$tmp/port.pc/Game.exe"
printf '#!/bin/sh\necho port\n' > "$tmp/port.pc/launch.sh"; chmod +x "$tmp/port.pc/launch.sh"
XDG_DATA_HOME="$tmp/xdg" "$here/build.sh" --desktop "$tmp/port.pc" >/dev/null
has port-exec "$(cat "$tmp/xdg/applications/gog-port.desktop")" "Exec=$tmp/port.pc/launch.sh"

# GOG's ddraw wrapper ships windowed; packaging flips it to fullscreen
mkdir -p "$tmp/dx.pc"; touch "$tmp/dx.pc/Game.exe"
printf '[dxcfg]\ndisplay=desktop\npresentation=windowed\nscaling=fit\n' > "$tmp/dx.pc/dxcfg.ini"
has dxcfg "$("$here/build.sh" "$tmp/dx.pc")" "switched to fullscreen"
has dxcfg-file "$(cat "$tmp/dx.pc/dxcfg.ini")" "presentation=fullscreen"
has dxcfg-keep "$(cat "$tmp/dx.pc/dxcfg.ini")" "scaling=fit"

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

# WINE_DESKTOP wraps the game in a virtual desktop of that size
has desktop-wrap "$(WINE_DESKTOP=1024x768 run "$tmp/n.pc/play.sh" "$tmp/n.pc" "game.exe")" \
                 "explorer /desktop=n.pc,1024x768 game.exe"

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
