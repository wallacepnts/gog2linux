#!/usr/bin/env bash
# Removes a packaged game: its folder, its wine prefix and its menu entries.
# Copied into every .pc folder by build.sh, so it has to stand on its own.
#
#   ./uninstall.sh        ask first
#   ./uninstall.sh -y     do not ask
set -euo pipefail

case "${GOG2LINUX_LANG:-${LC_ALL:-${LANG:-en}}}" in
  pt*) M_LIST="Isto remove:"
       M_SAVES="Saves guardados em outro lugar nao sao tocados."
       M_ASK_BK="Fazer backup dos saves antes? [S/n] "
       M_NO="nN"
       M_ASK_RM="Remover? [s/N] "
       M_YES="sSyY"
       M_CANCEL="cancelado"
       M_REMOVED="removido %s\n" ;;
  *)   M_LIST="This removes:"
       M_SAVES="Saves kept elsewhere are not touched."
       M_ASK_BK="Back up the saves first? [Y/n] "
       M_NO="nN"
       M_ASK_RM="Remove it? [y/N] "
       M_YES="yY"
       M_CANCEL="cancelled"
       M_REMOVED="removed %s\n" ;;
esac

target=$(dirname "$(readlink -f "$0")")
apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
slug=$(basename "$target"); slug=${slug%.pc}

echo "$M_LIST"
echo "  $target ($(du -sh "$target" 2>/dev/null | cut -f1))"
for entry in "$apps"/gog-"$slug".desktop "$apps"/gog-"$slug"-uninstall.desktop; do
  [ -f "$entry" ] && echo "  $entry"
done
echo "$M_SAVES"

# saves are the one thing here that cannot be rebuilt from the installer
if [ -x "$target/saves.sh" ]; then
  if [ "${1:-}" = -y ]; then
    "$target/saves.sh" backup 2>/dev/null || true
  else
    printf "$M_ASK_BK"
    read -r answer
    case "$answer" in ["$M_NO"]*) ;; *) "$target/saves.sh" backup || true ;; esac
  fi
fi

if [ "${1:-}" != -y ]; then
  printf "$M_ASK_RM"
  read -r answer
  case "$answer" in ["$M_YES"]*) ;; *) echo "$M_CANCEL"; exit 0 ;; esac
fi

rm -f "$apps"/gog-"$slug".desktop "$apps"/gog-"$slug"-uninstall.desktop
command -v update-desktop-database >/dev/null && update-desktop-database "$apps" 2>/dev/null
cd /                      # never delete the directory we are standing in
rm -rf "$target"
printf "$M_REMOVED" "$target"
