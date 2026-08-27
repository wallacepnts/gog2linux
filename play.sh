#!/usr/bin/env bash
# Runs a Batocera-format game on any distro.
#
#   ./play.sh                        the folder this script sits in (.pc or .wine)
#   ./play.sh Game.wtgz              extract and run
#   ./play.sh Game.wsquashfs         same (needs unsquashfs)
#   ./play.sh . "Launcher.exe"       run another executable in the same prefix
#
# Batocera ignores this script and reads autorun.cmd directly. This file gets
# copied into every game folder, so it has to stand on its own: no sourcing,
# no assuming build.sh is anywhere nearby.
set -euo pipefail
shopt -s nullglob

die() { echo "$*" >&2; exit 1; }

target=$(readlink -f "${1:-$(dirname "$(readlink -f "$0")")}")

# extra arguments override CMD: handy for the launcher, map editor, config tools
# that GOG ships alongside the game. printf %q keeps it safe for the eval below.
override=
if [ $# -gt 1 ]; then
  shift
  override=$(printf '%q ' "$@")
fi

cache="${WINE_GAMES:-$HOME/.local/share/wine-games}"

# ponytail: extracts instead of mounting (doubles the disk). Swap for squashfuse
# + fuse-overlayfs if space matters more than having no dependencies.
if [ -f "$target" ]; then
  unpacked="$cache/$(basename "${target%.*}")"
  if [ ! -d "$unpacked" ]; then
    # extract into a temporary name and only then rename: an extraction killed
    # halfway must not become a valid cache forever
    rm -rf "$unpacked.tmp"
    mkdir -p "$unpacked.tmp"
    case "$target" in
      *squashfs) unsquashfs -d "$unpacked.tmp" -f "$target" ;;
      *)         tar xzf "$target" -C "$unpacked.tmp" ;;
    esac
    mv "$unpacked.tmp" "$unpacked"
  fi
  target=$unpacked
fi

# tolerate an archive packed with one extra folder at the root
if [ ! -e "$target/autorun.cmd" ]; then
  for folder in "$target"/*/; do
    if [ -e "$folder/autorun.cmd" ]; then
      target=${folder%/}
      break
    fi
  done
fi

# Native Linux build shipped alongside (Ren'Py and friends): better than wine.
# FORCE_WINE=1 skips this. Both clues are required so an install script doesn't
# get mistaken for a launcher.
if [ -z "${FORCE_WINE:-}" ] && [ -z "$override" ] && compgen -G "$target/lib/*linux*" >/dev/null; then
  for candidate in "$target"/*.sh; do
    [ "${candidate##*/}" = play.sh ] && continue
    # copying through NTFS/exFAT, or unzipping, loses the execute bit
    [ -x "$candidate" ] || chmod +x "$candidate" 2>/dev/null || true
    if [ -x "$candidate" ]; then
      cd "$target"
      exec "$candidate"
    fi
    echo "warning: $candidate is not executable, falling back to wine" >&2
    break
  done
fi

[ -e "$target/autorun.cmd" ] || die "autorun.cmd not found in $target"

DIR=. CMD= GAMELANG=
# `|| [ -n "$line" ]` rescues the last line when the trailing \n is missing
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    DIR=*)  DIR=${line#DIR=} ;;
    CMD=*)  CMD=${line#CMD=} ;;
    ENV=*)  eval "export ${line#ENV=}" ;;
    LANG=*) GAMELANG=${line#LANG=} ;;
  esac
done < <(tr -d '\r' < "$target/autorun.cmd")   # autorun.cmd often comes with CRLF

if [ -n "$override" ]; then
  CMD=$override
fi
[ -n "$CMD" ] || die "autorun.cmd has no CMD= line in $target"

# a .wine/.wtgz folder already IS the prefix; a .pc folder keeps its own beside it
if [ -d "$target/drive_c" ]; then
  prefix=$target
else
  prefix=$target/.prefix
fi
export WINEPREFIX="${WINEPREFIX:-$prefix}"

# only pin the architecture when creating a fresh prefix: forcing win64 onto an
# existing 32-bit prefix (what wine2winetgz yields for old games) blocks the boot
if [ -n "${WINEARCH:-}" ]; then
  export WINEARCH
elif [ ! -d "$WINEPREFIX" ]; then
  export WINEARCH=win64
fi

[ -n "$GAMELANG" ] && export LC_ALL="$GAMELANG"

cd "$target/$DIR"
eval exec "${WINE:-wine}" "$CMD"   # eval because CMD carries quotes and arguments
