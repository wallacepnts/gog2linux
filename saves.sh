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

paths=()
# Documents, Saved Games, AppData - all of them live under users/
[ -d "$target/.prefix/drive_c/users" ] && paths+=(".prefix/drive_c/users")
for dir in "$target"/[Ss][Aa][Vv][Ee]* "$target"/[Pp]rofile[Ss] "$target"/[Ss]ave[Gg]ames; do
  [ -d "$dir" ] && paths+=("${dir#"$target"/}")
done

case "${1:-backup}" in
  backup)
    [ ${#paths[@]} -gt 0 ] || { printf "$M_NONE" "$target" >&2; exit 1; }
    file=${2:-$PWD/$name-saves-$(date +%Y%m%d-%H%M).tar.gz}
    tar czf "$file" -C "$target" "${paths[@]}"
    printf "$M_DONE" "$file" "$(du -h "$file" | cut -f1)"
    printf "$M_FROM" "${paths[@]}"
    ;;
  restore)
    file=${2:-}
    [ -f "$file" ] || { printf "$M_USE_RESTORE" "$0" >&2; exit 1; }
    tar xzf "$file" -C "$target"
    printf "$M_RESTORED" "$file" "$target"
    ;;
  *)
    printf "$M_USAGE" "$0" >&2; exit 1 ;;
esac
