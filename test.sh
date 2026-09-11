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

# the real systemd-inhibit would wrap every launch below; the one test that
# cares brings its own
# a PE header just complete enough for build.sh: machine at e_lfanew+4 tells
# 32 from 64 bits, subsystem at e_lfanew+0x5c tells console (3) from GUI (2)
fake_pe() {
  python3 -c "
import struct, sys
path, bits, sub = sys.argv[1], sys.argv[2], sys.argv[3]
d = bytearray(256)
d[0:2] = b'MZ'
d[0x3c:0x40] = struct.pack('<I', 0x80)
d[0x80:0x84] = b'PE\\0\\0'
d[0x84:0x86] = struct.pack('<H', 0x14c if bits == '32' else 0x8664)
d[0xdc:0xde] = struct.pack('<H', 3 if sub == 'console' else 2)
open(path, 'wb').write(bytes(d))
" "$1" "$2" "$3"
}

run() { WINE="$tmp/fakewine" WINE_GAMES="$tmp/cache" GOG2LINUX_INHIBIT=no "$@"; }
eq()  { [ "$2" = "$3" ] || { echo "FAILED $1:"; echo "  got:      $2"; echo "  expected: $3"; exit 1; }; }
has() { case "$2" in *"$3"*) ;; *) echo "FAILED $1:"; echo "  output:   $2"; echo "  should contain: $3"; exit 1 ;; esac; }

## build.sh

# destination omitted: the installer lands in $1 and mkdir would fail cryptically
touch "$tmp/setup.exe"
! "$here/build.sh" "$tmp/setup.exe" >/dev/null 2>&1 || { echo "FAILED: accepted a file as destination"; exit 1; }

# a folder stands in for the whole GOG download: base .exe at the root, DLCs in
# a subfolder, .bin parts ignored (innoextract picks them up on its own)
mkdir -p "$tmp/gog/DLC"
touch "$tmp/gog/base.exe" "$tmp/gog/base-1.bin" "$tmp/gog/DLC/d1.exe"
has folder "$("$here/build.sh" "$tmp/folder.pc" "$tmp/gog" 2>&1 || true)" "2 installers in"
mkdir -p "$tmp/none"
! "$here/build.sh" "$tmp/none.pc" "$tmp/none" >/dev/null 2>&1 || { echo "FAILED: accepted a folder with no installer"; exit 1; }

# the DLC subfolder's name is not part of the contract: GOG ships DLC/, the
# README writes dlc/, and any other subfolder works exactly the same
mkdir -p "$tmp/anycase/DLC"
touch "$tmp/anycase/setup_base.exe" "$tmp/anycase/DLC/setup_x.exe"
has dlc-case "$("$here/build.sh" "$tmp/anycase" 2>&1 || true)" "2 installers in"

# a folder really named "... [GOG]" is not someone copying the usage line: the
# brackets only get mentioned when nothing exists at that path
mkdir -p "$tmp/Game [GOG]"; touch "$tmp/Game [GOG]/setup_g.exe"
has real-brackets "$("$here/build.sh" "$tmp/br2.pc" "$tmp/Game [GOG]" 2>&1 || true)" \
                  "1 installers in"

# the usage line's brackets, pasted along with the path, are not a filename
! "$here/build.sh" "$tmp/br.pc" "[$tmp/gog/base.exe" >/dev/null 2>&1 || { echo "FAILED: accepted a bracketed path"; exit 1; }

# one folder per game: <name>/ holding setup_*.exe (and dlc/) becomes <name>.pc
mkdir -p "$tmp/grimdawn/dlc"; touch "$tmp/grimdawn/setup_g.exe" "$tmp/grimdawn/dlc/setup_d.exe"
has staging "$("$here/build.sh" "$tmp/grimdawn" 2>&1 || true)" "$tmp/grimdawn -> $tmp/grimdawn.pc"

# an extracted folder without the .pc suffix is still only reclassified: its own
# .exe files are the game, not installers waiting to be run
mkdir -p "$tmp/plain"; touch "$tmp/plain/game.exe"
has plain "$("$here/build.sh" "$tmp/plain")" "CMD=game.exe"
[ ! -d "$tmp/plain.pc" ] || { echo "FAILED: took an extracted folder for installers"; exit 1; }

# install/ is the inbox: every folder is a game, every loose file that carries an
# InnoSetup header is a game, and anything else is left alone
mkdir -p "$tmp/inbox/grimdawn/dlc"
touch "$tmp/inbox/grimdawn/setup_g.exe" "$tmp/inbox/grimdawn/dlc/setup_d.exe" "$tmp/inbox/junk.exe"
inbox=$(GOG2LINUX_INBOX="$tmp/inbox" GOG2LINUX_GAMES="$tmp/games" "$here/build.sh" 2>&1 || true)
has inbox "$inbox" "1 game(s) found"
has inbox-skip "$inbox" "not an InnoSetup installer: junk.exe"
has inbox-name "$inbox" "grimdawn -> grimdawn.pc"
# the game lands in the games folder, never inside the inbox -- that gets emptied
[ ! -e "$tmp/inbox/grimdawn.pc" ] || { echo "FAILED: built inside the inbox"; exit 1; }
[ -d "$tmp/games/grimdawn.pc" ] || { echo "FAILED: not built in the games folder"; exit 1; }

# and with nothing overriding it, the folder is named in the system's language
has games-pt "$(HOME="$tmp/home" GOG2LINUX_LANG=pt GOG2LINUX_INBOX="$tmp/inbox" \
                "$here/build.sh" 2>&1 || true)" "$tmp/home/Jogos"
has games-en "$(HOME="$tmp/home" GOG2LINUX_INBOX="$tmp/inbox" \
                "$here/build.sh" 2>&1 || true)" "$tmp/home/Games"
# a failed game keeps every installer: they are all that can rebuild it
has inbox-fail "$inbox" "1 game(s) failed"
[ -e "$tmp/inbox/grimdawn/setup_g.exe" ] || { echo "FAILED: deleted installers after a failure"; exit 1; }

# an empty inbox says what to put in it rather than exiting as if all was well
mkdir -p "$tmp/emptybox"
! GOG2LINUX_INBOX="$tmp/emptybox" "$here/build.sh" >/dev/null 2>&1 || { echo "FAILED: empty inbox exited 0"; exit 1; }

# DOSBox game in disguise: warns and writes no autorun.cmd
mkdir -p "$tmp/dos.pc/DOSBOX"
has dos "$("$here/build.sh" "$tmp/dos.pc")" "dos game in disguise"
[ ! -e "$tmp/dos.pc/autorun.cmd" ] || { echo "FAILED: wrote autorun.cmd for a DOS game"; exit 1; }

# same for ScummVM
mkdir -p "$tmp/sv.pc"; touch "$tmp/sv.pc/scummvm.exe"
has scummvm "$("$here/build.sh" "$tmp/sv.pc")" "scummvm game in disguise"

# a stale app/ from a run that died before the merge is hardlinked to the files
# at the root; extracting over it would write through to the game. It goes first.
mkdir -p "$tmp/stale.pc/app"
printf 'jogo\n' > "$tmp/stale.pc/game.dat"
ln "$tmp/stale.pc/game.dat" "$tmp/stale.pc/app/game.dat"
touch "$tmp/stale.pc/setup_x.exe"
"$here/build.sh" "$tmp/stale.pc" "$tmp/stale.pc/setup_x.exe" >/dev/null 2>&1 || true
[ ! -d "$tmp/stale.pc/app" ] || { echo "FAILED: kept a stale app/ before extracting"; exit 1; }
eq stale-intact "$(cat "$tmp/stale.pc/game.dat")" "jogo"

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

# the umu database turns a GOG id into the GAMEID protonfixes matches on, so a
# game with a fix of its own gets it. Cached copy, no network in a test: the
# lookup has to work offline once the file is there.
export XDG_CACHE_HOME="$tmp/cache"
mkdir -p "$tmp/cache/gog2linux"
{
  echo 'TITLE,STORE,CODENAME,UMU_ID,COMMON ACRONYM (Optional),NOTE (Optional),EXE_STRINGS (Optional)'
  echo 'Age of Wonders,gog,1207658883,umu-61500,aow,,'
  echo '"Blood, Sweat and Tears",zoomplatform,abc123,umu-999999,,,'
} > "$tmp/cache/gog2linux/umu-database.csv"
touch "$tmp/cache/gog2linux/umu-database.csv"   # fresh, so it is never re-fetched

mkdir -p "$tmp/umuid.pc"; touch "$tmp/umuid.pc/AoW.exe"
printf '{"gameId":"1207658883","rootGameId":"1207658883","name":"Age of Wonders","playTasks":[{"category":"game","path":"AoW.exe"}]}' \
  > "$tmp/umuid.pc/goggame-1.info"
has umu-id "$("$here/build.sh" "$tmp/umuid.pc")" "GAMEID=umu-61500"
has umu-id-env "$(cat "$tmp/umuid.pc/autorun.cmd")" "ENV=GAMEID=umu-61500"
has umu-id-store "$(cat "$tmp/umuid.pc/autorun.cmd")" "ENV=STORE=gog"

# a title the database has never heard of gets no GAMEID at all, rather than a
# wrong one: play.sh then falls back to umu-default and the global fixes
mkdir -p "$tmp/umunone.pc"; touch "$tmp/umunone.pc/Game.exe"
printf '{"gameId":"999","rootGameId":"999","name":"Not In The Database","playTasks":[{"category":"game","path":"Game.exe"}]}' \
  > "$tmp/umunone.pc/goggame-1.info"
"$here/build.sh" "$tmp/umunone.pc" >/dev/null
case "$(cat "$tmp/umunone.pc/autorun.cmd")" in
  *GAMEID*) echo "FAILED umu-id-absent: wrote a GAMEID for a game with no row"; exit 1 ;;
esac

# a comma inside a quoted title must not shift the columns -- csv, not cut -d,
mkdir -p "$tmp/umucomma.pc"; touch "$tmp/umucomma.pc/Game.exe"
printf '{"gameId":"nope","rootGameId":"nope","name":"Blood, Sweat and Tears","playTasks":[{"category":"game","path":"Game.exe"}]}' \
  > "$tmp/umucomma.pc/goggame-1.info"
"$here/build.sh" "$tmp/umucomma.pc" >/dev/null
has umu-id-comma "$(cat "$tmp/umucomma.pc/autorun.cmd")" "ENV=GAMEID=umu-999999"

# the .info names the exe with Windows casing; the file on disk differs
mkdir -p "$tmp/case.pc"; touch "$tmp/case.pc/Doom3.exe"
printf '{"playTasks":[{"category":"game","path":"DOOM3.exe"}]}' > "$tmp/case.pc/goggame-1.info"
has case "$("$here/build.sh" "$tmp/case.pc")" "CMD=Doom3.exe"

# GOG's workingDir: play.sh cds there and CMD comes out relative to it, because
# a launcher that loads its DLLs by relative path exits the moment it is wrong
mkdir -p "$tmp/wd.pc/x64"; touch "$tmp/wd.pc/x64/Launcher64.exe"
printf '{"playTasks":[{"category":"game","isPrimary":true,"path":"x64/Launcher64.exe","workingDir":"x64/"}]}' \
  > "$tmp/wd.pc/goggame-1.info"
has workdir "$("$here/build.sh" "$tmp/wd.pc")" "runs from inside x64/"
has workdir-dir "$(cat "$tmp/wd.pc/autorun.cmd")" "DIR=x64"
has workdir-cmd "$(cat "$tmp/wd.pc/autorun.cmd")" "CMD=Launcher64.exe"

# a workingDir the executable does not live in buys nothing and is left alone
mkdir -p "$tmp/wd2.pc/bin" "$tmp/wd2.pc/data"; touch "$tmp/wd2.pc/bin/game.exe"
printf '{"playTasks":[{"category":"game","path":"bin/game.exe","workingDir":"data/"}]}' \
  > "$tmp/wd2.pc/goggame-1.info"
"$here/build.sh" "$tmp/wd2.pc" >/dev/null
has workdir-skip "$(cat "$tmp/wd2.pc/autorun.cmd")" "CMD=bin/game.exe"
grep -q '^DIR=' "$tmp/wd2.pc/autorun.cmd" && { echo "FAILED: cd'd away from the exe"; exit 1; }

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

# GOG writes some subkeys with forward slashes and shouts SOFTWARE; regedit
# would take "Software/Ubisoft/X" for a single key name and the game would never
# find its own setting -- which is how a game installed in Portuguese stays in
# English
mkdir -p "$tmp/slash.pc"; touch "$tmp/slash.pc/Game.exe"
printf '{"languages":["en-US"],"playTasks":[{"category":"game","path":"Game.exe"}]}' > "$tmp/slash.pc/goggame-1.info"
cat > "$tmp/slash.pc/goggame-1.script" <<'SCRIPT'
{"actions":[
 {"languages":["*"],"install":{"action":"setRegistry","arguments":{
   "root":"HKLM","subkey":"SOFTWARE/Ubisoft/Game/Settings","valueName":"Language","valueData":"0","valueType":"dword"}}}
]}
SCRIPT
"$here/build.sh" "$tmp/slash.pc" >/dev/null
sl=$(cat "$tmp/slash.pc/gog-registry.reg")
has slash-key "$sl" 'HKEY_LOCAL_MACHINE\SOFTWARE\Ubisoft\Game\Settings'
has slash-wow "$sl" 'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Ubisoft\Game\Settings'
case "$sl" in */Ubisoft*) echo "FAILED: left a forward slash in a registry key"; exit 1 ;; esac

# onlyOnce values are what the installer seeds, not what the game must always
# have: a language the player changed lives among them, so they go to a separate
# file that play.sh only applies to a prefix it just created
mkdir -p "$tmp/once.pc"; touch "$tmp/once.pc/Game.exe"
printf '{"languages":["en-US"],"playTasks":[{"category":"game","path":"Game.exe"}]}' > "$tmp/once.pc/goggame-1.info"
cat > "$tmp/once.pc/goggame-1.script" <<'SCRIPT'
{"actions":[
 {"languages":["*"],"install":{"action":"setRegistry","arguments":{
   "root":"HKLM","subkey":"Software/id","valueName":"InstallPath","valueData":"{app}","valueType":"string"}}},
 {"languages":["*"],"install":{"action":"setRegistry","arguments":{
   "conditions":["onlyOnce"],
   "root":"HKLM","subkey":"Software/id","valueName":"Language","valueData":"0","valueType":"dword"}}}
]}
SCRIPT
"$here/build.sh" "$tmp/once.pc" >/dev/null
has once-split "$(cat "$tmp/once.pc/gog-registry-once.reg")" '"Language"=dword:00000000'
case "$(cat "$tmp/once.pc/gog-registry.reg")" in
  *Language*) echo "FAILED: a onlyOnce value would be re-imposed on every move"; exit 1 ;;
esac

# a fresh prefix gets both files; one that already exists gets only the first
cp "$here/play.sh" "$tmp/once.pc/"
has once-fresh "$(run "$tmp/once.pc/play.sh")" "regedit /S"
printf '%s\n' "$tmp/once.pc" > "$tmp/once.pc/.prefix/.gog-registry-path"
printf 'elsewhere\n' > "$tmp/once.pc/.prefix/.gog-registry-path"
moved=$(run "$tmp/once.pc/play.sh")
eq once-moved "$(printf '%s\n' "$moved" | grep -c 'regedit /S')" "1"

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

# a console-subsystem game sets its console title on the first line of Main;
# launched from the menu without a terminal, .NET throws before the window opens
mkdir -p "$tmp/con.pc"; fake_pe "$tmp/con.pc/Game.exe" 64 console
XDG_DATA_HOME="$tmp/xdg" "$here/build.sh" --desktop "$tmp/con.pc" >/dev/null
has console-term "$(cat "$tmp/xdg/applications/gog-con.desktop")" "Terminal=true"

# a normal windowed game must not drag a terminal along with it
mkdir -p "$tmp/gui.pc"; fake_pe "$tmp/gui.pc/Game.exe" 64 gui
XDG_DATA_HOME="$tmp/xdg" "$here/build.sh" --desktop "$tmp/gui.pc" >/dev/null
has gui-term "$(cat "$tmp/xdg/applications/gog-gui.desktop")" "Terminal=false"

# the name comes from the base game, not from a DLC whose .info sorts first
mkdir -p "$tmp/dlc.pc"; touch "$tmp/dlc.pc/Game.exe"
printf '{"name":"Extra Pack","gameId":"111","rootGameId":"999"}' > "$tmp/dlc.pc/goggame-111.info"
printf '{"name":"Real Game","gameId":"999","rootGameId":"999","playTasks":[{"category":"game","path":"Game.exe"}]}' \
  > "$tmp/dlc.pc/goggame-999.info"
XDG_DATA_HOME="$tmp/xdg" "$here/build.sh" --desktop "$tmp/dlc.pc" >/dev/null
has dlc-name "$(cat "$tmp/xdg/applications/gog-dlc.desktop")" "Name=Real Game"

# GOG puts its wrappers next to the executable, and with a workingDir that is
# not the root of the .pc: the override has to name them anyway, once each
mkdir -p "$tmp/wrapdir.pc/bin"
touch "$tmp/wrapdir.pc/bin/game.exe" "$tmp/wrapdir.pc/bin/xinput1_3.dll" "$tmp/wrapdir.pc/dsound.dll"
touch "$tmp/wrapdir.pc/bin/dsound.dll"          # o mesmo nos dois lugares
printf '{"playTasks":[{"category":"game","path":"bin/game.exe","workingDir":"bin/"}]}' \
  > "$tmp/wrapdir.pc/goggame-1.info"
"$here/build.sh" "$tmp/wrapdir.pc" >/dev/null
env_line=$(grep '^ENV=' "$tmp/wrapdir.pc/autorun.cmd")
has wrap-deep "$env_line" "xinput1_3"
has wrap-root "$env_line" "dsound"
eq wrap-once "$(printf '%s' "$env_line" | grep -o dsound | wc -l)" "1"

# --prefix adopts a prefix made elsewhere -- Lutris, Bottles, Faugus, a plain
# wine session -- so the .pc ends up self-contained
mkdir -p "$tmp/foreign/drive_c/windows" "$tmp/adopt.pc"
touch "$tmp/adopt.pc/game.exe" "$tmp/foreign/drive_c/marker"
has adopt "$("$here/build.sh" --prefix "$tmp/foreign" "$tmp/adopt.pc")" "prefix adopted"
[ -f "$tmp/adopt.pc/.prefix/drive_c/marker" ] || { echo "FAILED: prefix did not move in"; exit 1; }
[ ! -d "$tmp/foreign" ] || { echo "FAILED: left the prefix behind as well"; exit 1; }

# and a folder that is not a prefix is refused instead of moved
mkdir -p "$tmp/notpfx" "$tmp/adopt2.pc"; touch "$tmp/adopt2.pc/game.exe"
! "$here/build.sh" --prefix "$tmp/notpfx" "$tmp/adopt2.pc" >/dev/null 2>&1 ||
  { echo "FAILED: adopted something with no drive_c"; exit 1; }

# GOG ships Linux builds as a shell script with a zip appended: the game lives
# under data/noarch/ and comes out native, with no wine anywhere
mkdir -p "$tmp/gl.pc"
python3 -c "
import zipfile
open('$tmp/gogsetup.sh', 'wb').write(b'#!/bin/sh\n# MojoSetup\n' + b'x' * 4000)
z = zipfile.ZipFile('$tmp/gogsetup.sh', 'a')
z.writestr('data/noarch/gameinfo', 'Some/Game\n1.0\n123\n')
z.writestr('data/noarch/start.sh', '#!/bin/sh\ncd game && ./Binary\n')
z.writestr('data/noarch/game/Binary', '#!/bin/sh\necho ran\n')
z.close()"
out=$("$here/build.sh" "$tmp/gl.pc" "$tmp/gogsetup.sh" 2>&1)
has goglinux "$out" "GOG Linux installer"
has goglinux-done "$out" "native, through launch.sh"
[ -x "$tmp/gl.pc/launch.sh" ] || { echo "FAILED: no launch.sh written"; exit 1; }
[ -x "$tmp/gl.pc/game/Binary" ] || { echo "FAILED: game binary is not executable"; exit 1; }
[ ! -d "$tmp/gl.pc/data" ] || { echo "FAILED: left data/noarch nesting behind"; exit 1; }
# the slash in the name would make a second directory level
eq goglinux-name "$(cat "$tmp/gl.pc/gameinfo" | head -1)" "Some/Game"

# a folder with its own launch.sh is a finished native package, not a failure:
# there is no Windows executable to find and none is needed
mkdir -p "$tmp/nat.pc"; printf '#!/bin/sh\necho hi\n' > "$tmp/nat.pc/launch.sh"
chmod +x "$tmp/nat.pc/launch.sh"
has native-pkg "$("$here/build.sh" "$tmp/nat.pc")" "native, through launch.sh"
[ -f "$tmp/nat.pc/play.sh" ] || { echo "FAILED: native package got no play.sh"; exit 1; }

# the launcher at the root is the convention; its name is the packager's taste.
# GOG writes start.sh, a YAD installer writes plain start -- both are finished
# packages, and both need the launch.sh play.sh looks for.
for launcher in start.sh start; do
  d="$tmp/ns-$launcher.pc"
  mkdir -p "$d/game"
  printf '#!/bin/sh\ncd game && ./Binary\n' > "$d/$launcher"
  printf '#!/bin/sh\necho ran\n' > "$d/game/Binary"
  chmod +x "$d/$launcher" "$d/game/Binary"
  has "native-$launcher" "$("$here/build.sh" "$d")" "native, through launch.sh"
  has "native-$launcher-cmd" "$(cat "$d/launch.sh")" "exec ./$launcher"
  [ -f "$d/play.sh" ] || { echo "FAILED native-$launcher: got no play.sh"; exit 1; }
done

# a YAD Simple Installer carries its own -e flag: it asks for a destination on
# stdin and unpacks to <destination>/<app>. build.sh has only to ask, and to
# move what comes out into the .pc.
cat > "$tmp/yadsetup.sh" <<'YADSTUB'
#!/bin/sh
# YAD Simple Installer script version 12.01.2021
app="Stub Game"
case $1 in
  -e) read -r p
      mkdir -p "$p/$app/game"
      printf '#!/bin/sh\ncd game && ./Binary\n' > "$p/$app/start"
      printf '#!/bin/sh\necho ran\n' > "$p/$app/game/Binary"
      chmod +x "$p/$app/start" "$p/$app/game/Binary" ;;
esac
YADSTUB
chmod +x "$tmp/yadsetup.sh"
out=$("$here/build.sh" "$tmp/yad.pc" "$tmp/yadsetup.sh" 2>&1)
has yad "$out" "YAD installer (Stub Game)"
has yad-done "$out" "native, through launch.sh"
has yad-launch "$(cat "$tmp/yad.pc/launch.sh")" "exec ./start"
[ -x "$tmp/yad.pc/game/Binary" ] || { echo "FAILED yad: game binary missing"; exit 1; }
[ -d "$tmp/yad.pc/Stub Game" ] && { echo "FAILED yad: left the app folder nested"; exit 1; }
# nothing of the staging area may survive, beside the game or anywhere else
case "$(ls -A "$(dirname "$tmp/yad.pc")")" in
  *.gog2linux-yad*) echo "FAILED yad: left a staging folder behind"; exit 1 ;;
esac

# the inbox names a YAD installer by the app it declares, not by its filename
mkdir -p "$tmp/yadbox"
cp "$tmp/yadsetup.sh" "$tmp/yadbox/MARVEL_Something_[Linux,_LinuxRuleZ!].sh"
has yad-inbox "$(GOG2LINUX_INBOX="$tmp/yadbox" GOG2LINUX_GAMES="$tmp/yadgames" \
  "$here/build.sh" </dev/null 2>&1)" "Stub Game"

# a native package is a game like any other and belongs in the menu too -- it
# used to walk out before ever being asked. Its icon is a PNG the packager
# shipped, since a Linux build carries no .ico for the reader to cut up.
mkdir -p "$tmp/nd.pc/support" "$tmp/nd.pc/game"
printf '#!/bin/sh\ncd game && ./Binary\n' > "$tmp/nd.pc/start.sh"
printf '#!/bin/sh\necho ran\n' > "$tmp/nd.pc/game/Binary"
printf 'png' > "$tmp/nd.pc/support/icon.png"
chmod +x "$tmp/nd.pc/start.sh" "$tmp/nd.pc/game/Binary"
XDG_DATA_HOME="$tmp/xdg" "$here/build.sh" --desktop "$tmp/nd.pc" >/dev/null
[ -f "$tmp/xdg/applications/gog-nd.desktop" ] ||
  { echo "FAILED native-desktop: no menu entry for a native package"; exit 1; }
has native-desktop-icon "$(cat "$tmp/xdg/applications/gog-nd.desktop")" "support/icon.png"
has native-desktop-term "$(cat "$tmp/xdg/applications/gog-nd.desktop")" "Terminal=false"

# a repack ships the decompressors and keeps the game in its own archives:
# extracting reaches the scaffolding, so say that instead of "no executable"
mkdir -p "$tmp/fg"; touch "$tmp/fg/setup.exe" "$tmp/fg/fg-01.bin" "$tmp/fg/fg-02.bin"
has repack "$("$here/build.sh" "$tmp/repack.pc" "$tmp/fg/setup.exe" 2>&1 || true)" "is a repack"
# and it says so before spending five gigabytes of extraction on scaffolding
[ ! -d "$tmp/repack.pc/_Redist" ] || { echo "FAILED: extracted before checking"; exit 1; }

# a Unity game with .mp4 cutscenes asks for DXVK: wine's own dxgi stubs the call
# that hands the decoded frame over, and the video plays black
mkdir -p "$tmp/unity.pc/Game_Data/StreamingAssets"
touch "$tmp/unity.pc/Game.exe" "$tmp/unity.pc/UnityPlayer.dll"
touch "$tmp/unity.pc/Game_Data/StreamingAssets/intro.mp4"
has unity "$("$here/build.sh" "$tmp/unity.pc")" "asking for DXVK"
has unity-env "$(cat "$tmp/unity.pc/autorun.cmd")" 'ENV=WINEDLLOVERRIDES="d3d11,dxgi=n,b"'
has unity-screen "$(cat "$tmp/unity.pc/autorun.cmd")" 'SCREEN=unity'

# a .webm cutscene is VP8, which Unity decodes on its own: nothing to override
mkdir -p "$tmp/webm.pc/Game_Data/StreamingAssets"
touch "$tmp/webm.pc/Game.exe" "$tmp/webm.pc/UnityPlayer.dll"
touch "$tmp/webm.pc/Game_Data/StreamingAssets/intro.webm"
"$here/build.sh" "$tmp/webm.pc" >/dev/null
[ -z "$(grep -c 'dxgi' "$tmp/webm.pc/autorun.cmd" | grep -v '^0$')" ] ||
  { echo "FAILED: asked for DXVK with no .mp4 in sight"; exit 1; }

# what the host still lacks is said at the end, with package names: a 32-bit
# game with compressed audio decodes it through a 32-bit GStreamer, which is a
# separate install and whose absence only shows up as a crash dump
mkdir -p "$tmp/gst.pc/Content"
fake_pe "$tmp/gst.pc/Game.exe" 32 gui
touch "$tmp/gst.pc/Content/sound.xwb"
out=$(GOG2LINUX_GST32=none "$here/build.sh" "$tmp/gst.pc" 2>&1)
case "$out" in
  *"32-bit gstreamer"*) ;;
  *) echo "FAILED: said nothing about the missing 32-bit plugins"; echo "$out"; exit 1 ;;
esac

# a 64-bit game has nothing to do with them, and is not told to install anything
mkdir -p "$tmp/gst64.pc/Content"
fake_pe "$tmp/gst64.pc/Game.exe" 64 gui
touch "$tmp/gst64.pc/Content/sound.xwb"
case "$(GOG2LINUX_GST32=none "$here/build.sh" "$tmp/gst64.pc" 2>&1)" in
  *"32-bit gstreamer"*) echo "FAILED: asked a 64-bit game for 32-bit plugins"; exit 1 ;;
esac

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
has desktop-exec "$(cat "$entry")" "Exec=\"$tmp/menu.pc/play.sh\""
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

# a Steam rip saves through Goldberg. local_save.txt names a folder inside the
# game -- and it is not called "save", so only that file can find it.
mkdir -p "$tmp/gb.pc/MyGame Goldberg/settings"; touch "$tmp/gb.pc/Game.exe"
printf 'MyGame Goldberg' > "$tmp/gb.pc/local_save.txt"
printf 'slot' > "$tmp/gb.pc/MyGame Goldberg/settings/account_name.txt"
printf '{"name":"Gb","playTasks":[{"category":"game","path":"Game.exe"}]}' > "$tmp/gb.pc/goggame-9.info"
"$here/build.sh" --no-desktop "$tmp/gb.pc" >/dev/null
has saves-goldberg-local "$("$tmp/gb.pc/saves.sh" backup "$tmp/gb.tar.gz")" "MyGame Goldberg"

# without local_save.txt the emulator writes outside the game, one folder per
# Steam App ID. Those have to travel too, and go back where they came from.
mkdir -p "$tmp/gs.pc/game/steam_settings" "$tmp/xdgsave/Goldberg SteamEmu Saves/12345"
touch "$tmp/gs.pc/Game.exe"
printf '12345' > "$tmp/gs.pc/game/steam_settings/steam_appid.txt"
printf 'progress' > "$tmp/xdgsave/Goldberg SteamEmu Saves/12345/remote.dat"
printf '{"name":"Gs","playTasks":[{"category":"game","path":"Game.exe"}]}' > "$tmp/gs.pc/goggame-9.info"
"$here/build.sh" --no-desktop "$tmp/gs.pc" >/dev/null
XDG_DATA_HOME="$tmp/xdgsave" "$tmp/gs.pc/saves.sh" backup "$tmp/gs.tar.gz" >/dev/null
rm -rf "$tmp/xdgsave/Goldberg SteamEmu Saves/12345"
XDG_DATA_HOME="$tmp/xdgsave" "$tmp/gs.pc/saves.sh" restore "$tmp/gs.tar.gz" >/dev/null
eq saves-goldberg-shared "$(cat "$tmp/xdgsave/Goldberg SteamEmu Saves/12345/remote.dat")" "progress"

# Ren'Py saves live in ~/.renpy under the game's own name. The launcher it ships
# says which folder is its own -- and renpy/ is the engine's source, not a clue:
# its persistent.py would otherwise claim ~/.renpy/persistent, shared by all.
mkdir -p "$tmp/rp.pc/game/renpy" "$tmp/renpybase/Mine" "$tmp/renpybase/persistent"
touch "$tmp/rp.pc/Game.exe" "$tmp/rp.pc/game/Mine.py" "$tmp/rp.pc/game/renpy/persistent.py"
printf 'slot1' > "$tmp/renpybase/Mine/save.dat"
printf 'shared' > "$tmp/renpybase/persistent/other.dat"
printf '{"name":"Rp","playTasks":[{"category":"game","path":"Game.exe"}]}' > "$tmp/rp.pc/goggame-9.info"
"$here/build.sh" --no-desktop "$tmp/rp.pc" >/dev/null
out=$(RENPY_BASE="$tmp/renpybase" "$tmp/rp.pc/saves.sh" backup "$tmp/rp.tar.gz")
has saves-renpy "$out" "renpybase/Mine"
case "$out" in *persistent*) echo "FAILED saves-renpy-shared: took a folder shared by every game"; exit 1 ;; esac
rm -rf "$tmp/renpybase/Mine"
RENPY_BASE="$tmp/renpybase" "$tmp/rp.pc/saves.sh" restore "$tmp/rp.tar.gz" >/dev/null
eq saves-renpy-back "$(cat "$tmp/renpybase/Mine/save.dat")" "slot1"

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
done < <(sed '/^## Whole catalogues/,$d' "$here/docs/ENGINES.md" | grep '^| ')
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
has port-exec "$(cat "$tmp/xdg/applications/gog-port.desktop")" "Exec=\"$tmp/port.pc/launch.sh\""

# a game whose name carries a space: Exec is split on whitespace, so without the
# quotes the menu entry starts nothing at all
mkdir -p "$tmp/Two Words.pc"; touch "$tmp/Two Words.pc/game.exe"
XDG_DATA_HOME="$tmp/xdg" "$here/build.sh" --desktop "$tmp/Two Words.pc" >/dev/null
has space-exec "$(cat "$tmp/xdg/applications/gog-Two Words.desktop")" \
               "Exec=\"$tmp/Two Words.pc/play.sh\""
has space-path "$(cat "$tmp/xdg/applications/gog-Two Words.desktop")" \
               "Path=$tmp/Two Words.pc"

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

# a LOVE game: love.dll beside an .exe that is really a zip carrying conf.lua.
# build.sh writes the launcher, so play.sh runs the engine instead of wine.
# Never run it here: that would want a real LOVE, and a window with it.
mkdir -p "$tmp/love.pc"; touch "$tmp/love.pc/love.dll"
printf 'MZ fake PE header' > "$tmp/love.pc/Game.exe"
python3 -c "import zipfile
z = zipfile.ZipFile('$tmp/love.pc/Game.exe', 'a')
z.writestr('conf.lua', 'function love.conf(t) t.window = false end')
z.close()"
has love "$("$here/build.sh" "$tmp/love.pc")" "LOVE game (Game.exe)"
[ -x "$tmp/love.pc/launch.sh" ] || { echo "FAILED: no launch.sh for a LOVE game"; exit 1; }
has love-target "$(cat "$tmp/love.pc/launch.sh")" 'game="$here/Game.exe"'

# a hand-written launcher is the user's, not ours to overwrite
printf '#!/bin/sh\necho mine\n' > "$tmp/love.pc/launch.sh"; chmod +x "$tmp/love.pc/launch.sh"
"$here/build.sh" "$tmp/love.pc" >/dev/null
eq love-keep "$("$tmp/love.pc/launch.sh")" "mine"

# an .exe that is not a LOVE archive gets no launcher that would only fail later
mkdir -p "$tmp/notlove.pc"; touch "$tmp/notlove.pc/love.dll" "$tmp/notlove.pc/Game.exe"
"$here/build.sh" "$tmp/notlove.pc" >/dev/null
[ ! -e "$tmp/notlove.pc/launch.sh" ] || { echo "FAILED: launcher for a non-LOVE exe"; exit 1; }

# and nothing without love.dll gets a launcher it never asked for
[ ! -e "$tmp/mix.pc/launch.sh" ] || { echo "FAILED: wrote launch.sh with no love.dll"; exit 1; }

# launch.sh is this project's own marker for a native engine, so it needs no
# lib/*linux* beside it -- and it gets the execute bit fixed like the rest
mkdir -p "$tmp/lp.pc"; cp "$here/play.sh" "$tmp/lp.pc/"
printf 'CMD=game.exe\n' > "$tmp/lp.pc/autorun.cmd"
printf '#!/bin/sh\necho launch-ok\n' > "$tmp/lp.pc/launch.sh"
eq launch "$(run "$tmp/lp.pc/play.sh")" "launch-ok"

# FORCE_WINE=1 and an explicit executable must both still reach wine
eq launch-forced "$(FORCE_WINE=1 run "$tmp/lp.pc/play.sh")" \
                 "$tmp/lp.pc|$tmp/lp.pc/.prefix||game.exe"
eq launch-override "$(run "$tmp/lp.pc/play.sh" "$tmp/lp.pc" "Editor.exe")" \
                   "$tmp/lp.pc|$tmp/lp.pc/.prefix||Editor.exe"

# an Unreal game lives under <Name>/Binaries/Win64 and spells the resolution
# its own way; left alone it picks 16:9 and lets the compositor stretch it
mkdir -p "$tmp/ue.pc/Game/Binaries/Win64"
touch "$tmp/ue.pc/Game/Binaries/Win64/Game-Win64-Shipping.exe"
printf '{"playTasks":[{"category":"game","path":"Game/Binaries/Win64/Game-Win64-Shipping.exe"}]}' \
  > "$tmp/ue.pc/goggame-1.info"
"$here/build.sh" "$tmp/ue.pc" >/dev/null
has unreal-screen "$(cat "$tmp/ue.pc/autorun.cmd")" 'SCREEN=unreal'
mkdir -p "$tmp/ue2.pc"; cp "$here/play.sh" "$tmp/ue2.pc/"
printf 'SCREEN=unreal\nCMD=game.exe\n' > "$tmp/ue2.pc/autorun.cmd"
eq unreal-args "$(GOG2LINUX_SCREEN=1280x720 run "$tmp/ue2.pc/play.sh")" \
               "$tmp/ue2.pc|$tmp/ue2.pc/.prefix||game.exe -ResX=1280 -ResY=720 -fullscreen"

# SCREEN=native is what build.sh wrote before it named the engine: still Unity
mkdir -p "$tmp/old.pc"; cp "$here/play.sh" "$tmp/old.pc/"
printf 'SCREEN=native\nCMD=game.exe\n' > "$tmp/old.pc/autorun.cmd"
eq screen-legacy "$(GOG2LINUX_SCREEN=1280x720 run "$tmp/old.pc/play.sh")" \
                 "$tmp/old.pc|$tmp/old.pc/.prefix||game.exe -screen-width 1280 -screen-height 720 -screen-fullscreen 1"

# SCREEN=native: play.sh asks Unity for the screen's own mode, so nothing has to
# stretch a 16:9 picture onto a 16:10 panel
mkdir -p "$tmp/sc.pc"; cp "$here/play.sh" "$tmp/sc.pc/"
printf 'SCREEN=native\nCMD=game.exe\n' > "$tmp/sc.pc/autorun.cmd"
eq screen "$(GOG2LINUX_SCREEN=1280x720 run "$tmp/sc.pc/play.sh")" \
          "$tmp/sc.pc|$tmp/sc.pc/.prefix||game.exe -screen-width 1280 -screen-height 720 -screen-fullscreen 1"
eq screen-off "$(GOG2LINUX_SCREEN=no run "$tmp/sc.pc/play.sh")" \
              "$tmp/sc.pc|$tmp/sc.pc/.prefix||game.exe"
# asking for a specific executable is asking for that and nothing else
eq screen-override "$(GOG2LINUX_SCREEN=1280x720 run "$tmp/sc.pc/play.sh" "$tmp/sc.pc" "Editor.exe")" \
                   "$tmp/sc.pc|$tmp/sc.pc/.prefix||Editor.exe"

# umu is the default runner where it exists: it brings Proton inside Steam's
# container, with DXVK and the rest already assembled
mkdir -p "$tmp/home/.local/share/umu" "$tmp/umu.pc"
printf '#!/bin/sh\necho "umu|$PROTONPATH|$GAMEID|$*"\n' > "$tmp/home/.local/share/umu/umu-run"
chmod +x "$tmp/home/.local/share/umu/umu-run"
cp "$here/play.sh" "$tmp/umu.pc/"; printf 'CMD=game.exe\n' > "$tmp/umu.pc/autorun.cmd"
eq umu-default "$(HOME="$tmp/home" GOG2LINUX_INHIBIT=no "$tmp/umu.pc/play.sh" 2>/dev/null)" \
                "umu|GE-Proton|umu-default|game.exe"

# and it steps aside for a runner named on purpose, or when told to
eq umu-off "$(HOME="$tmp/home" GOG2LINUX_UMU=no run "$tmp/umu.pc/play.sh")" \
           "$tmp/umu.pc|$tmp/umu.pc/.prefix||game.exe"
eq umu-explicit "$(HOME="$tmp/home" run "$tmp/umu.pc/play.sh")" \
                "$tmp/umu.pc|$tmp/umu.pc/.prefix||game.exe"

# a wine game keeps the machine awake: it speaks no idle-inhibit protocol of its
# own, so the desktop would suspend mid-level
mkdir -p "$tmp/bin" "$tmp/aw.pc"; cp "$here/play.sh" "$tmp/aw.pc/"
printf 'CMD=game.exe\n' > "$tmp/aw.pc/autorun.cmd"
printf '#!/bin/sh\necho "held: $1 $2"\nshift 3\nexec "$@"\n' > "$tmp/bin/systemd-inhibit"
chmod +x "$tmp/bin/systemd-inhibit"
awake=$(PATH="$tmp/bin:$PATH" WINE="$tmp/fakewine" "$tmp/aw.pc/play.sh")
has inhibit "$awake" "held: --what=idle --who=gog2linux"
has inhibit-cmd "$awake" "$tmp/aw.pc|$tmp/aw.pc/.prefix||game.exe"

# a native game gets the same treatment. SDL registers "Playing a game" on its
# own, but Ren'Py registers nothing, and from outside there is no telling which
# engine is in the folder -- so hold idle off for both. The native paths exec
# straight out of play.sh, and used to leave without ever holding anything.
mkdir -p "$tmp/awn.pc"; cp "$here/play.sh" "$tmp/awn.pc/"
printf '#!/bin/sh\necho "native ran"\n' > "$tmp/awn.pc/launch.sh"
chmod +x "$tmp/awn.pc/launch.sh"
awoke=$(PATH="$tmp/bin:$PATH" WINE="$tmp/fakewine" "$tmp/awn.pc/play.sh")
has inhibit-native "$awoke" "held: --what=idle --who=gog2linux"
has inhibit-native-ran "$awoke" "native ran"
eq inhibit-native-off "$(PATH="$tmp/bin:$PATH" WINE="$tmp/fakewine" \
                         GOG2LINUX_INHIBIT=no "$tmp/awn.pc/play.sh")" "native ran"

# and it can be turned off, for a machine that would rather sleep
eq inhibit-off "$(PATH="$tmp/bin:$PATH" WINE="$tmp/fakewine" GOG2LINUX_INHIBIT=no \
                  "$tmp/aw.pc/play.sh")" "$tmp/aw.pc|$tmp/aw.pc/.prefix||game.exe"

# a wine binary whose path has a space: it goes through eval, and a Proton build
# lives in "Proton - Experimental"
mkdir -p "$tmp/two words"; cp "$tmp/fakewine" "$tmp/two words/wine"
mkdir -p "$tmp/sp.pc"; cp "$here/play.sh" "$tmp/sp.pc/"
printf 'CMD=game.exe\n' > "$tmp/sp.pc/autorun.cmd"
eq wine-space "$(WINE="$tmp/two words/wine" WINE_GAMES="$tmp/cache" GOG2LINUX_INHIBIT=no \
                 "$tmp/sp.pc/play.sh")" "$tmp/sp.pc|$tmp/sp.pc/.prefix||game.exe"

# WINE_DESKTOP names the virtual desktop after the folder, which can carry
# spaces -- and that line goes through eval, so it has to arrive as one argument
mkdir -p "$tmp/Two Words.pc"; cp "$here/play.sh" "$tmp/Two Words.pc/"
printf 'CMD=game.exe\n' > "$tmp/Two Words.pc/autorun.cmd"
eq desktop-space "$(WINE_DESKTOP=800x600 run "$tmp/Two Words.pc/play.sh")" \
   "$tmp/Two Words.pc|$tmp/Two Words.pc/.prefix||explorer /desktop=Two Words.pc,800x600 game.exe"

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
