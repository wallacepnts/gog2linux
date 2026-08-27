#!/usr/bin/env bash
# Removes a packaged game: its folder, its wine prefix and its menu entries.
# Copied into every .pc folder by build.sh, so it has to stand on its own.
#
#   ./uninstall.sh        ask first
#   ./uninstall.sh -y     do not ask
set -euo pipefail

target=$(dirname "$(readlink -f "$0")")
apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
slug=$(basename "$target"); slug=${slug%.pc}

echo "This removes:"
echo "  $target ($(du -sh "$target" 2>/dev/null | cut -f1))"
for entry in "$apps"/gog-"$slug".desktop "$apps"/gog-"$slug"-uninstall.desktop; do
  [ -f "$entry" ] && echo "  $entry"
done
echo "Saves kept elsewhere are not touched."

if [ "${1:-}" != -y ]; then
  printf 'Remove it? [y/N] '
  read -r answer
  case "$answer" in [yYsS]*) ;; *) echo "cancelled"; exit 0 ;; esac
fi

rm -f "$apps"/gog-"$slug".desktop "$apps"/gog-"$slug"-uninstall.desktop
command -v update-desktop-database >/dev/null && update-desktop-database "$apps" 2>/dev/null
cd /                      # never delete the directory we are standing in
rm -rf "$target"
echo "removed $target"
