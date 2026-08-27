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

case "${GOG2LINUX_LANG:-${LC_ALL:-${LANG:-en}}}" in
  pt*) M_NO_AUTORUN="autorun.cmd nao encontrado em %s\n"
       M_NO_CMD="autorun.cmd sem linha CMD= em %s\n"
       M_NO_EXEC="aviso: %s sem permissao de execucao, seguindo pelo wine\n" ;;
  *)   M_NO_AUTORUN="autorun.cmd not found in %s\n"
       M_NO_CMD="autorun.cmd has no CMD= line in %s\n"
       M_NO_EXEC="warning: %s is not executable, falling back to wine\n" ;;
esac

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
    printf "$M_NO_EXEC" "$candidate" >&2
    break
  done
fi

[ -e "$target/autorun.cmd" ] || die "$(printf "$M_NO_AUTORUN" "$target")"

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
[ -n "$CMD" ] || die "$(printf "$M_NO_CMD" "$target")"

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

# First run in a fresh prefix: apply the registry the GOG installer would have
# written - install paths, CD-key locations, DirectPlay. Without it, games ask
# for a key they already ship, or claim they are not installed.
# The paths inside it are absolute, so renaming or moving the .pc folder makes
# them stale and the game acts as if it was never installed. The stamp records
# what was applied, so a move re-applies instead of failing quietly.
stamp="$WINEPREFIX/.gog-registry-path"
if [ -f "$target/gog-registry.reg" ] && [ "$(cat "$stamp" 2>/dev/null)" != "$target" ]; then
  app="Z:${target//\//\\}"
  app=${app//\\/\\\\}          # a .reg file wants its backslashes doubled
  reg=$(mktemp)
  # ${var//x/y} eats backslashes in the replacement, which mangles the path into
  # something regedit reads as escapes. Splicing with printf keeps it literal.
  while IFS= read -r line || [ -n "$line" ]; do
    while :; do
      case "$line" in
        *%APP%*) line="${line%%%APP%*}$app${line#*%APP%}" ;;
        *) break ;;
      esac
    done
    printf '%s\n' "$line"
  done < "$target/gog-registry.reg" > "$reg"
  "${WINE:-wine}" regedit /S "$reg" 2>/dev/null || true
  rm -f "$reg"
  mkdir -p "$WINEPREFIX" && printf '%s\n' "$target" > "$stamp"
fi

[ -n "$GAMELANG" ] && export LC_ALL="$GAMELANG"

cd "$target/$DIR"
eval exec "${WINE:-wine}" "$CMD"   # eval because CMD carries quotes and arguments
