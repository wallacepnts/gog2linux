#!/usr/bin/env bash
# Runs a packaged .pc game on any Linux distro.
#
#   ./play.sh                        the folder this script sits in (.pc or .wine)
#   ./play.sh Game.wtgz              extract and run
#   ./play.sh Game.wsquashfs         same (needs unsquashfs)
#   ./play.sh . "Launcher.exe"       run another executable in the same prefix
#
# This file gets copied into every game folder, so it has to stand on its own:
# no sourcing, no assuming build.sh is anywhere nearby.
set -euo pipefail
shopt -s nullglob

# Everything below sits in one block on purpose. Bash reads a script as it goes,
# by byte offset, so editing this file while it runs -- a git pull during a game already running
# -- makes it resume at whatever now sits at that offset, and it fails with
# nonsense: a command named "ich", a variable that is plainly set reported as
# unbound. A compound command is read whole before any of it runs, which closes
# that door. The closing brace is the last line of the file.
{

die() { echo "$*" >&2; exit 1; }

case "${GOG2LINUX_LANG:-${LC_ALL:-${LANG:-en}}}" in
  pt*) M_NO_AUTORUN="autorun.cmd nao encontrado em %s\n"
       M_NO_CMD="autorun.cmd sem linha CMD= em %s\n"
       M_NO_EXEC="aviso: %s sem permissao de execucao, seguindo pelo wine\n"
       M_DXVK="dxvk ligado no prefixo, de %s\n"
       M_UMU="rodando pelo umu (%s)\n" ;;
  *)   M_NO_AUTORUN="autorun.cmd not found in %s\n"
       M_NO_CMD="autorun.cmd has no CMD= line in %s\n"
       M_NO_EXEC="warning: %s is not executable, falling back to wine\n"
       M_DXVK="dxvk wired into the prefix, from %s\n"
       M_UMU="running through umu (%s)\n" ;;
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

# A game never tells the desktop it is busy on its own -- wine touches neither
# the X screensaver nor the idle-inhibit protocol, and a native engine only
# sometimes does: SDL registers "Playing a game" the moment it opens a window,
# Ren'Py registers nothing at all. Holding idle off here covers both, costs a
# duplicate inhibitor where SDL already has one, and lets go when the game ends.
# Worked out before anything is executed, because the native paths exec straight
# out of this script and would otherwise never reach it.
inhibit_cmd=()
if [ "${GOG2LINUX_INHIBIT:-}" != no ] && command -v systemd-inhibit >/dev/null 2>&1; then
  inhibit_cmd=(systemd-inhibit --what=idle --who=gog2linux --why="${target##*/}")
fi

# A native engine beats wine, and there are two ways to find one. FORCE_WINE=1
# skips both, and so does asking for a specific executable.
#
# The explicit one: launch.sh. This project writes it, for a game whose engine
# is native but ships no Linux build of its own -- LOVE, DOSBox, a source port.
# Nothing else is named that, so the name is the whole clue.
if [ -z "${FORCE_WINE:-}" ] && [ -z "$override" ] && [ -f "$target/launch.sh" ]; then
  # copying through NTFS/exFAT, or unzipping, loses the execute bit
  [ -x "$target/launch.sh" ] || chmod +x "$target/launch.sh" 2>/dev/null || true
  if [ -x "$target/launch.sh" ]; then
    cd "$target"
    exec "${inhibit_cmd[@]}" "$target/launch.sh" "$@"
  fi
  printf "$M_NO_EXEC" "$target/launch.sh" >&2
fi

# The implicit one: a Linux build shipped alongside (Ren'Py and friends). Both
# clues are required here so an install script doesn't get mistaken for a
# launcher.
native_lib=("$target"/lib/*linux*)
if [ -z "${FORCE_WINE:-}" ] && [ -z "$override" ] && [ ${#native_lib[@]} -gt 0 ]; then
  for candidate in "$target"/*.sh; do
    # launch.sh was already tried above; warning about it twice helps no one
    case "${candidate##*/}" in play.sh|launch.sh) continue ;; esac
    [ -x "$candidate" ] || chmod +x "$candidate" 2>/dev/null || true
    if [ -x "$candidate" ]; then
      cd "$target"
      exec "${inhibit_cmd[@]}" "$candidate"
    fi
    printf "$M_NO_EXEC" "$candidate" >&2
    break
  done
fi

[ -e "$target/autorun.cmd" ] || die "$(printf "$M_NO_AUTORUN" "$target")"

DIR=. CMD= GAMELANG= SCREEN=
# `|| [ -n "$line" ]` rescues the last line when the trailing \n is missing
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    DIR=*)  DIR=${line#DIR=} ;;
    CMD=*)  CMD=${line#CMD=} ;;
    ENV=*)  eval "export ${line#ENV=}" ;;
    LANG=*) GAMELANG=${line#LANG=} ;;
    SCREEN=*) SCREEN=${line#SCREEN=} ;;
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
if [ "$(cat "$stamp" 2>/dev/null)" != "$target" ]; then
  # gog-registry-once.reg holds what the installer only seeds -- a language the
  # player later changed lives in there, so it goes in on a fresh prefix and
  # never again. The other file is install paths, which a move makes stale.
  [ -e "$stamp" ] && sources="gog-registry.reg" || sources="gog-registry.reg gog-registry-once.reg"
  app="Z:${target//\//\\}"
  app=${app//\\/\\\\}          # a .reg file wants its backslashes doubled
  for source in $sources; do
    [ -f "$target/$source" ] || continue
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
    done < "$target/$source" > "$reg"
    "${WINE:-wine}" regedit /S "$reg" 2>/dev/null || true
    rm -f "$reg"
  done
  mkdir -p "$WINEPREFIX" && printf '%s\n' "$target" > "$stamp"
fi

[ -n "$GAMELANG" ] && export LC_ALL="$GAMELANG"

# A Unity player left to itself picks a 16:9 mode, and a 16:10 screen then gets
# it stretched by whoever composites -- which is not antialiasing wearing off,
# it is resampling. Asking for the screen's own mode removes the step entirely.
# GOG2LINUX_SCREEN=1280x720 pins a size, GOG2LINUX_SCREEN=no leaves it alone.
if [ -n "$SCREEN" ] && [ -z "$override" ] && [ "${GOG2LINUX_SCREEN:-}" != no ]; then
  mode=${GOG2LINUX_SCREEN:-}
  if [ -z "$mode" ]; then
    # first line of a connected output's mode list is the one it prefers; a
    # disconnected output has an empty file. No xrandr needed.
    for modes in /sys/class/drm/*/modes; do
      read -r mode < "$modes" 2>/dev/null || continue
      case "$mode" in [0-9]*x[0-9]*) break ;; *) mode= ;; esac
    done
  fi
  # each engine spells it its own way; "native" is what build.sh wrote before
  # it started naming the engine, and meant Unity
  case "$mode:$SCREEN" in
    [0-9]*x[0-9]*:unity|[0-9]*x[0-9]*:native)
      CMD="$CMD -screen-width ${mode%%x*} -screen-height ${mode#*x} -screen-fullscreen 1" ;;
    [0-9]*x[0-9]*:unreal)
      CMD="$CMD -ResX=${mode%%x*} -ResY=${mode#*x} -fullscreen" ;;
  esac
fi

# umu runs the game through Proton inside Steam's own container, which is where
# DXVK, VKD3D and a FAudio built with ffmpeg come from already assembled. It is
# the better runner wherever it exists; where it is missing, the distro's wine
# is still the answer, so this falls back rather than insisting.
# WINE set by hand, or by an ENV= line, always wins. GOG2LINUX_UMU=no opts out.
umu=
if [ -z "${WINE:-}" ] && [ "${GOG2LINUX_UMU:-}" != no ]; then
  for candidate in "$HOME/.local/share/umu/umu-run" "$HOME/.local/bin/umu-run" \
                   "$(command -v umu-run 2>/dev/null)"; do
    [ -n "$candidate" ] && [ -x "$candidate" ] || continue
    umu=$candidate
    WINE=$candidate
    # GE-Proton by name, not by path: umu fetches it, and the same autorun.cmd
    # then works on a machine that never had it
    export PROTONPATH="${PROTONPATH:-GE-Proton}"
    export GAMEID="${GAMEID:-umu-default}"
    export STORE="${STORE:-none}"
    printf "$M_UMU" "$PROTONPATH" >&2
    break
  done
fi

# The ENV= line can ask for DXVK, but asking is not having: the DLLs have to be
# in the prefix, and only this machine knows where its distro keeps them.
case "${umu:+skip}${WINEDLLOVERRIDES:-}" in
  skip*) ;;                       # Proton brings its own; leave the prefix alone
  *dxgi*)
    sys="$WINEPREFIX/drive_c/windows/system32"
    if [ ! -L "$sys/d3d11.dll" ]; then
      for dxvk in /usr/libexec/dxvk/lib64 /usr/share/dxvk/x64 /usr/lib/dxvk/x64 /opt/dxvk/x64; do
        [ -f "$dxvk/d3d11.dll" ] || continue
        # the prefix has to exist before anything can be put in it
        [ -d "$sys" ] || "${WINE:-wine}" wineboot -u >/dev/null 2>&1
        [ -d "$sys" ] || break
        # the 64-bit directory by name: openSUSE's own setup script hands the
        # 32-bit build to a 64-bit prefix, and wine then falls back in silence
        for dll in d3d11 dxgi d3d10core d3d9 d3d8; do
          [ -f "$dxvk/$dll.dll" ] || continue
          [ -e "$sys/$dll.dll" ] && [ ! -L "$sys/$dll.dll" ] &&
            mv "$sys/$dll.dll" "$sys/$dll.dll.old"
          ln -sfn "$dxvk/$dll.dll" "$sys/$dll.dll"
        done
        printf "$M_DXVK" "$dxvk" >&2
        break
      done
    fi ;;
esac

cd "$target/$DIR"

# the line below runs through eval, so anything with a space in it has to reach
# eval already quoted -- a Proton build lives in "Proton - Experimental", and
# the inhibitor's --why carries the game's folder name, spaces and all
winecmd=$(printf '%q' "${WINE:-wine}")
inhibit=
[ ${#inhibit_cmd[@]} -gt 0 ] && inhibit=$(printf '%q ' "${inhibit_cmd[@]}")

# Old games ask for a 640x480 fullscreen mode wine cannot really set, so they
# paint a small picture in the corner of a big black window. Wrapping them in a
# virtual desktop of that exact size gives an honest window instead.
if [ -n "${WINE_DESKTOP:-}" ]; then
  # the folder name goes into the desktop's name and can carry spaces, and this
  # line goes through eval: without %q the argument arrives in pieces
  eval exec $inhibit $winecmd explorer \
       "$(printf '%q' "/desktop=${target##*/},$WINE_DESKTOP")" "$CMD"
fi

eval exec $inhibit $winecmd "$CMD"   # eval because CMD carries quotes and arguments

}
