#!/usr/bin/env bash
# GOG installer (InnoSetup) -> .pc folder that runs on Batocera and on any distro.
#
#   ./build.sh Game.pc setup.exe [dlc.exe ...]   package
#   ./build.sh Game.pc                           only reclassify an extracted folder
set -euo pipefail
shopt -s dotglob nullglob

die() { echo "$*" >&2; exit 1; }

[ $# -ge 1 ] || die "usage: $0 Game.pc setup.exe [dlc.exe ...]"
command -v innoextract >/dev/null ||
  die "innoextract is missing: install the innoextract package (apt/dnf/pacman/zypper)"

target=$(readlink -f "$1"); shift

# check everything before extracting: failing halfway leaves a half-built folder
for setup in "$@"; do
  [ -f "$setup" ] || die "installer not found: $setup"
done

mkdir -p "$target"
if [ $# -gt 0 ]; then
  for setup in "$@"; do
    innoextract --gog --silent --collisions=overwrite -d "$target" "$(readlink -f "$setup")"
  done
  # installer scaffolding. Only after extracting: in reclassify mode that tmp/
  # may well be a folder belonging to the game itself.
  rm -rf "$target/tmp" "$target/__redist"
fi

# innoextract drops the contents of {app} at the root
if [ -d "$target/app" ]; then
  # mv won't merge an existing directory; hardlinks are instant and cost no disk
  cp -alf "$target/app/." "$target/" 2>/dev/null || cp -af "$target/app/." "$target/"
  rm -rf "$target/app"
fi

# goggame-*.info names the exe to launch
# the /dev/null guarantees an operand: without it grep would read stdin and hang
exe=$(grep -oh '"path": *"[^"]*\.exe"' "$target"/goggame-*.info /dev/null 2>/dev/null |
      head -1 | sed 's/.*"\(.*\)"/\1/' | tr '\\' '/') || true

# no .info: first .exe at the root that isn't an accessory
if [ -z "$exe" ]; then
  for candidate in "$target"/*.exe; do
    case "${candidate##*/}" in
      unins*|UnityCrashHandler*|*etup.exe) continue ;;
      *) exe=${candidate##*/}; break ;;
    esac
  done
fi

# GOG wraps old games in a DOSBox/ScummVM. Pushing that through wine means
# running an emulator inside an API translator: send it to the native system.
kind=
if [ -d "$target/DOSBOX" ] || [ -d "$target/dosbox" ]; then
  kind=dos
elif [ -e "$target/scummvm.exe" ] || compgen -G "$target/*.scummvm" >/dev/null; then
  kind=scummvm
else
  case "${exe,,}" in
    *dosbox*)  kind=dos ;;
    *scummvm*) kind=scummvm ;;
  esac
fi

if [ -n "$kind" ]; then
  echo "extracted: $target"
  echo
  echo "WARNING: this is a $kind game in disguise. Do NOT run it through wine."
  if [ "$kind" = dos ]; then
    echo "  here:     install the dosbox package, then:"
    echo "            cd $(basename "$target") && dosbox -conf dosbox_*.conf -conf dosbox_*_single.conf"
    echo "  Batocera: /userdata/roms/dos/  (name <=8 chars, with dosbox.bat; don't copy GOG's .conf)"
  else
    echo "  here:     install the scummvm package"
    echo "  Batocera: /userdata/roms/scummvm/"
  fi
  echo
  echo "No autorun.cmd written - it would be useless. See the README."
  exit 0
fi

if [ -z "$exe" ] || [ ! -e "$target/$exe" ]; then
  die "could not find the game executable in $target"
fi
# the .info often lists a launcher, the game and tools. build.sh cannot know
# which one actually survives wine, so it shows what else is on offer.
others=$(grep -oh '"path": *"[^"]*\.exe"' "$target"/goggame-*.info /dev/null 2>/dev/null |
         sed 's/.*"\(.*\)"/\1/' | tr '\\' '/' | grep -Fxv "$exe" | sort -u | paste -sd';') || true

case "$exe" in *\ *) exe="\"$exe\"" ;; esac

printf 'CMD=%s\n' "$exe" > "$target/autorun.cmd"
cp "$(dirname "$(readlink -f "$0")")/play.sh" "$target/"
echo "done: $target (CMD=$exe)"
if [ -n "$others" ]; then
  echo "other entries in goggame-*.info: ${others//;/, }"
  echo "  if the game won't start, try one of those in autorun.cmd"
fi

# Ren'Py and friends: the Windows installer usually carries the Linux build too.
# Same rule as play.sh (the two copies are deliberate, see the note there).
if compgen -G "$target/lib/*linux*" >/dev/null; then
  for candidate in "$target"/*.sh; do
    native=${candidate##*/}
    [ "$native" = play.sh ] && continue
    # a Windows installer does not carry the execute bit
    chmod +x "$candidate" "$target"/lib/*linux*/* 2>/dev/null || true
    echo "note: native Linux build here -> ./$(basename "$target")/$native (no wine)"
    break
  done
fi
