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
    [ ${#paths[@]} -gt 0 ] || { echo "no saves found in $target" >&2; exit 1; }
    file=${2:-$PWD/$name-saves-$(date +%Y%m%d-%H%M).tar.gz}
    tar czf "$file" -C "$target" "${paths[@]}"
    echo "backed up: $file ($(du -h "$file" | cut -f1))"
    printf '  from: %s\n' "${paths[@]}"
    ;;
  restore)
    file=${2:-}
    [ -f "$file" ] || { echo "usage: $0 restore FILE.tar.gz" >&2; exit 1; }
    tar xzf "$file" -C "$target"
    echo "restored $file into $target"
    ;;
  *)
    echo "usage: $0 [backup|restore] [FILE.tar.gz]" >&2; exit 1 ;;
esac
