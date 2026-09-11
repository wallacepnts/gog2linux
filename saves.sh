#!/usr/bin/env bash
# Backs up or restores a packaged game's saves. Old games keep them next to
# themselves, modern ones write into the wine profile; this covers both.
# Copied into every .pc folder by build.sh, so it has to stand on its own.
#
#   ./saves.sh                       write Game-saves-<date>.tar.gz here
#   ./saves.sh backup /path/file.tar.gz
#   ./saves.sh restore /path/file.tar.gz
set -euo pipefail
shopt -s nullglob

case "${GOG2LINUX_LANG:-${LC_ALL:-${LANG:-en}}}" in
  pt*) M_NONE="nenhum save encontrado em %s\n"
       M_DONE="backup feito: %s (%s)\n"
       M_FROM="  de: %s\n"
       M_RESTORED="restaurado %s em %s\n"
       M_USE_RESTORE="uso: %s restore ARQUIVO.tar.gz\n"
       M_USAGE="uso: %s [backup|restore] [ARQUIVO.tar.gz]\n" ;;
  *)   M_NONE="no saves found in %s\n"
       M_DONE="backed up: %s (%s)\n"
       M_FROM="  from: %s\n"
       M_RESTORED="restored %s into %s\n"
       M_USE_RESTORE="usage: %s restore FILE.tar.gz\n"
       M_USAGE="usage: %s [backup|restore] [FILE.tar.gz]\n" ;;
esac

target=$(dirname "$(readlink -f "$0")")
name=$(basename "$target"); name=${name%.pc}

# Inside the .pc, kept as paths relative to it. Outside it -- a native game that
# writes into the home directory -- kept as "label|absolute path", copied into
# the archive under .external/ so restore knows where each one goes back to.
paths=() external=()

# Documents, Saved Games, AppData - all of them live under users/
[ -d "$target/.prefix/drive_c/users" ] && paths+=(".prefix/drive_c/users")

# Not just at the root: a Ren'Py game buries its saves in game/game/saves, and
# the prefix is already covered whole, so nothing under it is worth a second
# look. Depth 3 reaches the buried ones without walking a five-gigabyte game.
while IFS= read -r dir; do
  [ -n "$dir" ] && paths+=("${dir#"$target"/}")
done < <(find "$target" -mindepth 1 -maxdepth 3 -type d \
              \( -iname 'save' -o -iname 'saves' -o -iname 'savegame*' \
                 -o -iname 'saved games' -o -iname 'profiles' \) \
              -not -path "$target/.prefix/*" 2>/dev/null)

# A Steam rip runs on the Goldberg emulator, which stores saves in one of two
# places. local_save.txt names a folder inside the game; without that file the
# saves go to a shared folder in the home directory, one per Steam App ID.
if [ -f "$target/local_save.txt" ]; then
  goldberg=$(tr -d '\r\n' < "$target/local_save.txt")
  [ -n "$goldberg" ] && [ -d "$target/$goldberg" ] && paths+=("$goldberg")
else
  appid=$(find "$target" -maxdepth 3 -name steam_appid.txt \
               -not -path "$target/.prefix/*" -print -quit 2>/dev/null)
  if [ -n "$appid" ]; then
    appid=$(tr -d '\r\n' < "$appid")
    shared="${XDG_DATA_HOME:-$HOME/.local/share}/Goldberg SteamEmu Saves/$appid"
    [ -n "$appid" ] && [ -d "$shared" ] && external+=("goldberg/$appid|$shared")
  fi
fi

# Ren'Py keeps saves and the persistent file under ~/.renpy, in a folder named
# after the game rather than after ours. Match by the launcher the game ships:
# ~/.renpy/JASON belongs to the package that carries JASON.py, and to no other.
# The launcher sits at the top -- game/JASON.py. Look no deeper, and never into
# renpy/: that is the engine's own source, and it carries a persistent.py that
# would claim ~/.renpy/persistent, a folder shared by every Ren'Py game here.
for dir in "${RENPY_BASE:-$HOME/.renpy}"/*/; do
  [ -d "$dir" ] || continue
  base=$(basename "$dir")
  [ -n "$(find "$target" -maxdepth 2 -name "$base.py" -not -path '*/renpy/*' \
               -print -quit 2>/dev/null)" ] &&
    external+=("renpy/$base|${dir%/}")
done

case "${1:-backup}" in
  backup)
    [ $((${#paths[@]} + ${#external[@]})) -gt 0 ] ||
      { printf "$M_NONE" "$target" >&2; exit 1; }
    file=${2:-$PWD/$name-saves-$(date +%Y%m%d-%H%M).tar.gz}
    # tar can start from several directories, but everything it stores has to
    # come out under one. Stage the outside saves under .external/ first, so the
    # archive carries where they belong along with what they hold.
    stage= args=()
    if [ ${#external[@]} -gt 0 ]; then
      stage=$(mktemp -d)
      trap 'rm -rf "$stage"' EXIT
      for entry in "${external[@]}"; do
        mkdir -p "$stage/.external/$(dirname "${entry%%|*}")"
        cp -a "${entry#*|}" "$stage/.external/${entry%%|*}"
      done
    fi
    [ ${#paths[@]} -gt 0 ] && args+=(-C "$target" "${paths[@]}")
    [ -n "$stage" ] && args+=(-C "$stage" .external)
    tar czf "$file" "${args[@]}"
    printf "$M_DONE" "$file" "$(du -h "$file" | cut -f1)"
    [ ${#paths[@]} -gt 0 ] && printf "$M_FROM" "${paths[@]}"
    for entry in "${external[@]}"; do printf "$M_FROM" "${entry#*|}"; done
    ;;
  restore)
    file=${2:-}
    [ -f "$file" ] || { printf "$M_USE_RESTORE" "$0" >&2; exit 1; }
    tar xzf "$file" -C "$target" --exclude='.external' --exclude='.external/*'
    # The outside saves go back where they came from, not into the .pc. Asked
    # for by pattern, and an archive without them simply fails to match: no
    # listing first. "tar tzf | grep -q" would look tidier and be a race --
    # grep leaves on the first hit, tar takes SIGPIPE, and pipefail then reports
    # the whole pipeline as failed, so the restore silently skips them.
    stage=$(mktemp -d)
    trap 'rm -rf "$stage"' EXIT
    if tar xzf "$file" -C "$stage" --wildcards '*.external/*' 2>/dev/null; then
      for dir in "$stage"/.external/goldberg/*/; do
        [ -d "$dir" ] || continue
        dest="${XDG_DATA_HOME:-$HOME/.local/share}/Goldberg SteamEmu Saves"
        mkdir -p "$dest"; cp -a "${dir%/}" "$dest/"
        printf "$M_RESTORED" "$(basename "${dir%/}")" "$dest"
      done
      for dir in "$stage"/.external/renpy/*/; do
        [ -d "$dir" ] || continue
        dest="${RENPY_BASE:-$HOME/.renpy}"
        mkdir -p "$dest"; cp -a "${dir%/}" "$dest/"
        printf "$M_RESTORED" "$(basename "${dir%/}")" "$dest"
      done
    fi
    printf "$M_RESTORED" "$file" "$target"
    ;;
  *)
    printf "$M_USAGE" "$0" >&2; exit 1 ;;
esac
