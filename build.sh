#!/usr/bin/env bash
# GOG installer (InnoSetup) -> .pc folder that runs on Batocera and on any distro.
#
#   ./build.sh                                   packages everything in install/
#   ./build.sh Game                              Game/ holds the installers -> Game.pc
#   ./build.sh Game.pc gog-folder/               package (base + DLCs)
#   ./build.sh Game.pc setup.exe dlc.exe ...     same, one path at a time
#   ./build.sh Game.pc                           only reclassify an extracted folder
set -euo pipefail
shopt -s dotglob nullglob

# Everything below sits in one block on purpose. Bash reads a script as it goes,
# by byte offset, so editing this file while it runs -- a git pull during a seven-minute extraction
# -- makes it resume at whatever now sits at that offset, and it fails with
# nonsense: a command named "ich", a variable that is plainly set reported as
# unbound. A compound command is read whole before any of it runs, which closes
# that door. The closing brace is the last line of the file.
{

die() { echo "$*" >&2; exit 1; }

# GOG's own title, straight from the InnoSetup header. It names the .pc folder,
# so nothing in install/ has to be named by hand; empty means "not an installer"
gog_title() {
  innoextract -i "$1" 2>/dev/null |
    sed -n '1s|^Inspecting "\(.*\)" - setup data version.*|\1|p' |
    tr '/' '-'
}

# GOG labels languages by code; a list of codes is not a menu anyone can read.
lang_name() {
  case "$1" in
    en*) echo "English" ;;      de*) echo "Deutsch" ;;     fr*) echo "Francais" ;;
    es-MX) echo "Espanol (LA)" ;; es*) echo "Espanol" ;;   it*) echo "Italiano" ;;
    pt-BR) echo "Portugues (BR)" ;; pt*) echo "Portugues" ;; ru*) echo "Russkiy" ;;
    pl*) echo "Polski" ;;       cs*) echo "Cestina" ;;     hu*) echo "Magyar" ;;
    nl*) echo "Nederlands" ;;   sv*) echo "Svenska" ;;     da*) echo "Dansk" ;;
    fi*) echo "Suomi" ;;        no*) echo "Norsk" ;;       tr*) echo "Turkce" ;;
    ja*) echo "Nihongo" ;;      ko*) echo "Hangugeo" ;;    th*) echo "Thai" ;;
    zh-Hans) echo "Zhongwen (jianti)" ;; zh-Hant) echo "Zhongwen (fanti)" ;;
    zh*) echo "Zhongwen" ;;     ar*) echo "Arabiy" ;;      *) echo "$1" ;;
  esac
}

# innoextract hands over the installer's own label when the installer carries one
# ("brazilian: Portugues (Brasil)"); the table above is for the newer ones, which
# only give a code. $offered is set right before this is ever called.
lang_show() {
  local label
  label=$(printf '%s\n' "${offered:-}" | awk -F'\t' -v c="$1" '$1 == c {print $2; exit}')
  printf '%s' "${label:-$(lang_name "$1")}"
}

# Messages in the two languages this is used in. Picked from $LANG; force with
# GOG2LINUX_LANG=pt or =en. No gettext, no .po files, no runtime dependency.
case "${GOG2LINUX_LANG:-${LC_ALL:-${LANG:-en}}}" in
  pt*)
    M_USAGE="uso: %s [--desktop|--no-desktop] [--lang CODIGO|all] [ALVO [instaladores ...]]\n\
  (sem nada)  empacota tudo que estiver em install/\n\
  Jogo        pasta com os instaladores (DLCs numa subpasta) -> vira Jogo.pc\n\
  Jogo.pc     pasta-da-gog (ou setup.exe dlc.exe ...)\n\
  Jogo.pc     sozinho, so reclassifica uma pasta ja extraida\n"
    M_NO_INNO="falta o innoextract: instale o pacote innoextract (apt/dnf/pacman/zypper)"
    M_NO_PY="falta o python3: instale o pacote python3"
    M_NOT_DEST="o primeiro argumento e a pasta de destino, nao o instalador"
    M_NO_SETUP="instalador nao encontrado: %s\n"
    M_NO_PARTS="nenhum %s-*.bin ao lado do instalador\n  instalador GOG grande vem em partes: leve os .bin junto com o .exe\n"
    M_EMPTY_DIR="nenhum instalador .exe nesta pasta: %s\n"
    M_BRACKETS="tire os colchetes do caminho: %s\n  no uso acima eles so marcam o que e opcional\n"
    M_FROM_DIR="pasta: %s instaladores em %s\n"
    M_OFFERS="%s oferece %s idiomas:\n"
    M_ASK_LANG="Idioma [%s]: "
    M_LANG="idioma: %s (%s)\n"
    M_ONLY_LANG="idioma: %s (%s) - o unico que este instalador traz\n"
    M_META="nao consegui ler os metadados da GOG (veja o erro do python acima)"
    M_NO_EXE="nao achei o executavel do jogo em %s\n"
    M_WORKDIR="obs: o jogo roda de dentro de %s/ - e o que a GOG pede\n"
    M_EXTRACTED="extraido: %s\n"
    M_EXTRACTING="extraindo: %s\n"
    M_WARN_KIND="ATENCAO: este e um jogo %s disfarcado. NAO passe pelo wine.\n"
    M_HERE="  aqui:"
    M_BATOCERA="  Batocera:"
    M_DOS_PKG="instale o pacote dosbox, depois:"
    M_DOS_BATO="/userdata/roms/dos/  (nome <=8 caracteres, com dosbox.bat; nao copie o .conf da GOG)"
    M_SCUMM_PKG="instale o pacote scummvm"
    M_SCUMM_BATO="/userdata/roms/scummvm/"
    M_NO_AUTORUN="Nenhum autorun.cmd gerado - seria inutil. Veja o README."
    M_DONE="pronto: %s (CMD=%s)\n"
    M_PORT="obs: %s tem motor reimplementado (%s) - nativo, melhor que wine: %s\n"
    M_DXCFG="obs: dxcfg.ini estava em janela; mudei para tela cheia (edite o arquivo para voltar)"
    M_REG="obs: gog-registry.reg gerado; o play.sh aplica ao criar o prefixo"
    M_WRAPPERS="obs: wrappers do jogo tem prioridade sobre os do wine: %s\n"
    M_SCREEN="obs: jogo Unity - o play.sh vai pedir a resolucao nativa da tela\n"
    M_UNITY_MF="obs: jogo Unity com animacao em .mp4 - DXVK pedido no autorun.cmd\n"
    M_UNITY_MF2="  sem ele a animacao fica preta: o dxgi do wine nao entrega o quadro decodificado"
    M_OTHERS="outras entradas no goggame-*.info: %s\n"
    M_OTHERS2="  se o jogo nao abrir, tente uma delas no autorun.cmd"
    M_NATIVE="obs: tem build Linux nativo aqui -> ./%s/%s (sem wine)\n"
    M_LOVE="obs: jogo LOVE (%s) - launch.sh escrito, o play.sh roda pelo motor nativo\n"
    M_PENDING="\nfalta no sistema, pra este jogo rodar:\n"
    M_NEED_LOVE="  o motor LOVE: pacote love, ou flatpak install flathub org.love2d.love2d\n"
    M_NEED_DXVK="  DXVK: pacote dxvk - sem ele a animacao fica preta\n"
    M_NEED_GST32="  plugins gstreamer de 32 bits: gstreamer-plugins-libav-32bit,\n    -good-32bit, -ugly-32bit - sem eles o audio comprimido derruba o jogo\n"
    M_NEED_WINE="  wine: so pra jogar, empacotar nao precisa\n"
    M_ASK_MENU='Adicionar "%s" ao menu de jogos? [s/N] '
    M_YES="sSyY"
    M_ENTRY="entrada de menu: %s\n"
    M_STAGING="pasta de instaladores: %s -> %s\n"
    M_ASK_STAGE='Apagar os instaladores em "%s"? [s/N] '
    M_STAGE_GONE="instaladores apagados: %s\n"
    M_STAGE_KEPT="instaladores mantidos em: %s (apague quando o jogo abrir)\n"
    M_GAMES="Jogos"
    M_GAMES_DIR="instalando em: %s\n"
    M_INBOX="install/: %s jogo(s) encontrado(s)\n"
    M_ASK_PICK="Instalar quais? [Enter = todos; ex: 1 3, ou 1-2]: "
    M_ALL="todos"
    M_BAD_PICK="escolha invalida: %s\n"
    M_ASK_DONE='Apagar os instaladores dos %s jogo(s) empacotados? [s/N] '
    M_INBOX_GAME="\n== %s -> %s ==\n"
    M_INBOX_SKIP="ignorado, nao e instalador InnoSetup: %s\n"
    M_INBOX_EMPTY="nada em %s\n  ponha um setup_*.exe solto, ou uma pasta por jogo com as DLCs numa subpasta\n"
    M_INBOX_FAIL="%s jogo(s) falharam - nada foi apagado\n"
    ;;
  *)
    M_USAGE="usage: %s [--desktop|--no-desktop] [--lang CODE|all] [TARGET [installers ...]]\n\
  (nothing)   packages everything sitting in install/\n\
  Game        folder holding the installers (DLCs in a subfolder) -> becomes Game.pc\n\
  Game.pc     gog-folder (or setup.exe dlc.exe ...)\n\
  Game.pc     on its own, only reclassifies an already extracted folder\n"
    M_NO_INNO="innoextract is missing: install the innoextract package (apt/dnf/pacman/zypper)"
    M_NO_PY="python3 is missing: install the python3 package"
    M_NOT_DEST="first argument is the destination folder, not the installer"
    M_NO_SETUP="installer not found: %s\n"
    M_NO_PARTS="no %s-*.bin next to the installer\n  large GOG installers ship in parts: keep the .bin files with the .exe\n"
    M_EMPTY_DIR="no .exe installer in this folder: %s\n"
    M_BRACKETS="drop the brackets from the path: %s\n  in the usage above they only mark what is optional\n"
    M_FROM_DIR="folder: %s installers in %s\n"
    M_OFFERS="%s offers %s languages:\n"
    M_ASK_LANG="Language [%s]: "
    M_LANG="language: %s (%s)\n"
    M_ONLY_LANG="language: %s (%s) - the only one this installer carries\n"
    M_META="could not read the GOG metadata (see the python error above)"
    M_NO_EXE="could not find the game executable in %s\n"
    M_WORKDIR="note: the game runs from inside %s/ - which is what GOG asks for\n"
    M_EXTRACTED="extracted: %s\n"
    M_EXTRACTING="extracting: %s\n"
    M_WARN_KIND="WARNING: this is a %s game in disguise. Do NOT run it through wine.\n"
    M_HERE="  here:"
    M_BATOCERA="  Batocera:"
    M_DOS_PKG="install the dosbox package, then:"
    M_DOS_BATO="/userdata/roms/dos/  (name <=8 chars, with dosbox.bat; don't copy GOG's .conf)"
    M_SCUMM_PKG="install the scummvm package"
    M_SCUMM_BATO="/userdata/roms/scummvm/"
    M_NO_AUTORUN="No autorun.cmd written - it would be useless. See the README."
    M_DONE="done: %s (CMD=%s)\n"
    M_PORT="note: %s has a reimplemented engine (%s) - native, better than wine: %s\n"
    M_DXCFG="note: dxcfg.ini was set to windowed; switched to fullscreen (edit the file to revert)"
    M_REG="note: gog-registry.reg written; play.sh applies it when it creates the prefix"
    M_WRAPPERS="note: bundled wrappers given priority over wine's own: %s\n"
    M_SCREEN="note: Unity game - play.sh will ask for the screen's native resolution\n"
    M_UNITY_MF="note: Unity game with .mp4 cutscenes - asking for DXVK in autorun.cmd\n"
    M_UNITY_MF2="  without it the cutscenes are black: wine's dxgi never hands the frame over"
    M_OTHERS="other entries in goggame-*.info: %s\n"
    M_OTHERS2="  if the game won't start, try one of those in autorun.cmd"
    M_NATIVE="note: native Linux build here -> ./%s/%s (no wine)\n"
    M_LOVE="note: LOVE game (%s) - launch.sh written, play.sh runs the native engine\n"
    M_PENDING="\nmissing on this system, for this game to run:\n"
    M_NEED_LOVE="  the LOVE engine: the love package, or flatpak install flathub org.love2d.love2d\n"
    M_NEED_DXVK="  DXVK: the dxvk package - without it the cutscenes play black\n"
    M_NEED_GST32="  32-bit gstreamer plugins: gstreamer-plugins-libav-32bit,\n    -good-32bit, -ugly-32bit - without them compressed audio takes the game down\n"
    M_NEED_WINE="  wine: only needed to play, not to package\n"
    M_ASK_MENU='Add "%s" to the desktop games menu? [y/N] '
    M_YES="yY"
    M_ENTRY="menu entry: %s\n"
    M_STAGING="installer folder: %s -> %s\n"
    M_ASK_STAGE='Delete the installers in "%s"? [y/N] '
    M_STAGE_GONE="installers deleted: %s\n"
    M_STAGE_KEPT="installers kept in: %s (delete them once the game runs)\n"
    M_GAMES="Games"
    M_GAMES_DIR="installing into: %s\n"
    M_INBOX="install/: %s game(s) found\n"
    M_ASK_PICK="Install which? [Enter = all; e.g. 1 3, or 1-2]: "
    M_ALL="all"
    M_BAD_PICK="not a valid choice: %s\n"
    M_ASK_DONE='Delete the installers of the %s game(s) packaged? [y/N] '
    M_INBOX_GAME="\n== %s -> %s ==\n"
    M_INBOX_SKIP="skipped, not an InnoSetup installer: %s\n"
    M_INBOX_EMPTY="nothing in %s\n  drop a loose setup_*.exe in, or one folder per game with its DLCs in a subfolder\n"
    M_INBOX_FAIL="%s game(s) failed - nothing was deleted\n"
    ;;
esac


desktop=ask
lang=auto
missing=      # what the host still needs for this game; reported at the end
flags=()   # kept verbatim: the install/ pass below re-runs this script per game
while [ $# -gt 0 ]; do
  case "$1" in
    --desktop)    desktop=yes; flags+=("$1"); shift ;;
    --no-desktop) desktop=no;  flags+=("$1"); shift ;;
    --lang)       lang=${2:-}; flags+=("$1" "${2:-}"); shift 2 ;;
    --lang=*)     lang=${1#--lang=}; flags+=("$1"); shift ;;
    # without this, --help lands in readlink -f and comes back as its own usage
    -h|--help)    printf "$M_USAGE" "$0"; exit 0 ;;
    *)            break ;;
  esac
done
here=$(dirname "$(readlink -f "$0")")

# install/ is the inbox: one folder per game (with its dlc/), or a loose
# installer that names itself. Drop the downloads in, run ./build.sh, walk away.
inbox=${GOG2LINUX_INBOX:-$here/install}
if [ $# -eq 0 ] && [ -d "$inbox" ]; then
  command -v innoextract >/dev/null || die "$M_NO_INNO"
  games=() names=()
  for item in "$inbox"/*; do
    if [ -d "$item" ]; then
      # the base installer sits at the root; the dlc/ ones do not name the game
      title=
      for probe in "$item"/*.exe; do
        title=$(gog_title "$probe") || title=
        [ -n "$title" ] && break
      done
      # a folder the header cannot name still packages, under its own name
      games+=("$item"); names+=("${title:-$(basename "$item")}")
    else
      title=$(gog_title "$item") || title=
      if [ -n "$title" ]; then
        games+=("$item"); names+=("$title")
      else
        # .bin slices belong to an installer and are not games of their own
        case "$item" in *.exe) printf "$M_INBOX_SKIP" "$(basename "$item")" ;; esac
      fi
    fi
  done
  [ ${#games[@]} -gt 0 ] || die "$(printf "$M_INBOX_EMPTY" "$inbox")"
  # the games go to the home games folder, named in the language of the system.
  # Not beside the inbox: that one gets emptied, and on a fresh checkout it sits
  # in the repo, which is no place for twenty gigabytes of game.
  root=${GOG2LINUX_GAMES:-$HOME/$M_GAMES}
  mkdir -p "$root"

  printf "$M_INBOX" "${#games[@]}"
  printf "$M_GAMES_DIR" "$root"
  for i in "${!games[@]}"; do
    item=$(basename "${games[$i]}")
    # the source is worth showing only when the header renamed the game
    if [ "$item" = "${names[$i]}" ]; then
      printf '  %2d) %s\n' "$((i + 1))" "${names[$i]}"
    else
      printf '  %2d) %-38s %s\n' "$((i + 1))" "${names[$i]}" "$item"
    fi
  done

  # only ask when someone is watching; a script gets the whole inbox
  if [ -t 0 ]; then
    printf "$M_ASK_PICK"
    read -r answer
    case "$answer" in
      ''|all|"$M_ALL") ;;
      *) chosen=() chosen_names=()
         for token in ${answer//,/ }; do
           case "$token" in
             *-*) first=${token%%-*}; last=${token##*-} ;;
             *)   first=$token; last=$token ;;
           esac
           case "$first$last" in ''|*[!0-9]*) die "$(printf "$M_BAD_PICK" "$token")" ;; esac
           for n in $(seq "$first" "$last"); do
             [ "$n" -ge 1 ] && [ "$n" -le ${#games[@]} ] ||
               die "$(printf "$M_BAD_PICK" "$n")"
             chosen+=("${games[$((n - 1))]}"); chosen_names+=("${names[$((n - 1))]}")
           done
         done
         games=("${chosen[@]}"); names=("${chosen_names[@]}") ;;
    esac
  fi

  failed=0
  for i in "${!games[@]}"; do
    printf "$M_INBOX_GAME" "$(basename "${games[$i]}")" "${names[$i]}.pc"
    # one game per run: a bad installer costs its own game, not the whole batch
    "$here/$(basename "$0")" ${flags[@]+"${flags[@]}"} \
      "$root/${names[$i]}.pc" "${games[$i]}" || failed=$((failed + 1))
  done

  if [ "$failed" -gt 0 ]; then
    printf "$M_INBOX_FAIL" "$failed"
    printf "$M_STAGE_KEPT" "$inbox"
    exit 1
  fi
  answer=n
  if [ -t 0 ]; then
    printf "$M_ASK_DONE" "${#games[@]}"
    read -r answer
  fi
  case "$answer" in
    # only what was packaged: the inbox may still hold games left for later,
    # and a loose installer takes its .bin slices with it
    ["$M_YES"]*) for i in "${!games[@]}"; do
                   rm -rf "${games[$i]}" "${games[$i]%.exe}"-*.bin
                 done
                 printf "$M_STAGE_GONE" "$inbox" ;;
    *)           printf "$M_STAGE_KEPT" "$inbox" ;;
  esac
  exit 0
fi

[ $# -ge 1 ] || die "$(printf "$M_USAGE" "$0")"
command -v innoextract >/dev/null ||
  die "$M_NO_INNO"
command -v python3 >/dev/null || die "$M_NO_PY"

target=$(readlink -f -- "$1"); shift

# a forgotten destination turns the installer into $1 and mkdir fails cryptically
[ -f "$target" ] && die "$M_NOT_DEST
$(printf "$M_USAGE" "$0")"

# One folder per game: <name>/ holds the installers, with the DLCs in a dlc/
# subfolder, and becomes <name>.pc. GOG names every installer setup_*, which is
# what tells such a folder apart from an extracted game handed over to be
# reclassified -- that one is full of .exe files too, none of them installers.
staging=
if [ $# -eq 0 ] && [ -d "$target" ]; then
  case "$target" in
    *.pc) ;;
    *) installers=("$target"/setup_*.exe "$target"/*/setup_*.exe)
       if [ ${#installers[@]} -gt 0 ]; then
         staging=$target
         target=$target.pc
         printf "$M_STAGING" "$staging" "$target"
         set -- "$staging"
       fi ;;
  esac
fi

# check everything before extracting: failing halfway leaves a half-built folder
if [ $# -gt 0 ]; then
  setups=()
  for arg in "$@"; do
    # copying the usage line verbatim leaves its brackets glued to the path
    case "$arg" in \[*|*\]) die "$(printf "$M_BRACKETS" "$arg")
$(printf "$M_USAGE" "$0")" ;; esac
    # a GOG download is one folder: base .exe at the root, DLCs in a subfolder,
    # and the .bin parts tag along on their own. Pass the folder, not the list.
    if [ -d "$arg" ]; then
      found=("$arg"/*.exe "$arg"/*/*.exe)
      [ ${#found[@]} -gt 0 ] || die "$(printf "$M_EMPTY_DIR" "$arg")"
      printf "$M_FROM_DIR" "${#found[@]}" "$arg"
      setups+=("${found[@]}")
    else
      [ -f "$arg" ] || die "$(printf "$M_NO_SETUP" "$arg")"
      setups+=("$arg")
    fi
  done
  set -- "${setups[@]}"
fi

mkdir -p "$target"
if [ $# -gt 0 ]; then
  # The merge below hardlinks app/ onto the root, so a run that died between
  # extracting and merging leaves app/ pointing at the very files the game now
  # uses. Extracting over those links writes straight through to the game --
  # which is how a second run turns "could not open output file" into a folder
  # that is quietly wrong. app/ is installer scaffolding either way; start clean.
  rm -rf "$target/app"
  for setup in "$@"; do
    setup=$(readlink -f "$setup")
    # a multi-language installer extracts every language at once, and the last
    # one wins the metadata -- which is how an English game ends up Italian.
    pick=$lang
    if [ "$lang" = auto ]; then
      # two shapes in the wild: " - en-US" from a recent installer, and
      # " - brazilian: Portugues (Brasil)" from an old one. Splitting on the
      # colon keeps the code clean -- passing "brazilian:" to --language, and
      # printing it as the language name, is what happens without this.
      offered=$(innoextract --list-languages "$setup" 2>/dev/null |
                sed -n 's/^ - \([^ :]*\):\{0,1\} *\(.*\)$/\1\t\2/p') || true
      pick=$(printf '%s\n' "$offered" | awk -F'\t' '/^en/{print $1; exit}')
      count=$(printf '%s\n' "$offered" | grep -c .) || true

      # The languages an installer offers are usually its own interface, not the
      # game's: GOG ships every language and the game picks at run time, from a
      # registry value or the system locale. Listing is a header read, so asking
      # innoextract twice costs nothing -- and it turns a menu that decides
      # nothing into one line saying so. Where the files really do differ (the
      # goggame-*.info is per-language in some releases) the menu still comes.
      varies=
      if [ "$count" -gt 1 ]; then
        every=$(innoextract --gog --silent --list "$setup" 2>/dev/null | sort | md5sum)
        just=$(innoextract --gog --silent --language "${pick:-en}" --list "$setup" \
               2>/dev/null | sort | md5sum)
        [ "$every" = "$just" ] || varies=yes
      fi

      # more than one language that matters, and someone watching: let them pick
      if [ -n "$varies" ] && [ -t 0 ]; then
        printf "$M_OFFERS" "$(basename "$setup")" "$count"
        i=0
        while IFS=$'\t' read -r code label; do
          [ -n "$code" ] || continue
          i=$((i + 1))
          printf '  %2d) %-10s %s\n' "$i" "$code" "${label:-$(lang_name "$code")}"
        done <<< "$offered"
        printf "$M_ASK_LANG" "${pick:-1}"
        read -r answer
        case "$answer" in
          '') ;;
          *[!0-9]*) pick=$answer ;;
          *) pick=$(printf '%s\n' "$offered" | sed -n "${answer}p" | cut -f1) ;;
        esac
      elif [ "$count" -gt 1 ]; then
        # the languages are the installer's own interface: nothing to choose,
        # nothing worth saying. Extract the lot.
        pick=
      fi
      # chosen once, reused for the DLCs that follow
      [ -n "$pick" ] && lang=$pick
    fi
    opts=()
    if [ -n "$pick" ] && [ "$pick" != all ]; then
      opts+=(--language "$pick")
      if [ "${count:-1}" -le 1 ]; then
        printf "$M_ONLY_LANG" "$pick" "$(lang_show "$pick")"
      else
        printf "$M_LANG" "$pick" "$(lang_show "$pick")"
      fi
    fi
    # --silent eats the progress bar, and a 1.6 GB installer is minutes of
    # silence without it. Put it back -- but only on a terminal: innoextract
    # draws it wherever output goes, and a log of escape codes helps no one.
    [ -t 1 ] && progress=1 || progress=0
    printf "$M_EXTRACTING" "$(basename "$setup")"
    if ! innoextract --gog --silent --progress=$progress --collisions=overwrite \
                     "${opts[@]}" -d "$target" "$setup"; then
      # an installer past 4 GB ships as setup.exe + setup-1.bin + setup-2.bin,
      # and moving only the .exe is the usual way to end up here. Only worth
      # saying once innoextract has already failed: plenty of installers are a
      # single file, and a missing slice is not something its header knows.
      parts=("${setup%.exe}"-*.bin)
      [ ${#parts[@]} -gt 0 ] || die "$(printf "$M_NO_PARTS" "$(basename "${setup%.exe}")")"
      exit 1
    fi
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

# GOG metadata: which exe to launch, what else it offers, and the registry the
# installer would have written. Needs real JSON, hence python3.
meta=$(python3 - "$target" <<'PYMETA'
import base64, glob, json, os, sys

target = sys.argv[1]
ROOTS = {'HKLM': 'HKEY_LOCAL_MACHINE', 'HKCU': 'HKEY_CURRENT_USER',
         'HKEY_LOCAL_MACHINE': 'HKEY_LOCAL_MACHINE', 'HKEY_CURRENT_USER': 'HKEY_CURRENT_USER'}


def load(pattern):
    for f in sorted(glob.glob(os.path.join(target, pattern))):
        try:
            yield json.load(open(f, encoding='utf-8-sig'))
        except (ValueError, OSError):
            pass


tasks, langs, name, base = [], {'*'}, '', ''
for d in load('goggame-*.info'):
    title = d.get('name') or ''
    # a DLC ships its own .info, and sorting by filename can put it first --
    # only the base game has gameId == rootGameId
    if title and d.get('gameId') and d.get('gameId') == d.get('rootGameId'):
        base = base or title
    name = name or title
    langs |= {str(x).lower() for x in (d.get('languages') or [])}
    for t in d.get('playTasks') or []:
        path = (t.get('path') or '').replace('\\', '/')
        # GOG records the directory the game has to run from; a launcher that
        # loads its DLLs by relative path just exits when it is wrong
        wd = (t.get('workingDir') or '').replace('\\', '/').strip('/')
        if path.lower().endswith('.exe'):
            tasks.append((t.get('category'), t.get('isPrimary'), path, '' if wd == '.' else wd))

# a launcher wants a mouse and often starts a build wine cannot run; the entry
# GOG tags as the game itself is the better default.
chosen, chosen_dir = '', ''
for wanted in (lambda c, p: c == 'game', lambda c, p: p, lambda c, p: True):
    for cat, primary, path, wd in tasks:
        if wanted(cat, primary):
            chosen, chosen_dir = path, wd
            break
    if chosen:
        break

def dword(data):
    text = str(data).strip()
    if text.startswith('$'):      # Inno writes hex the Pascal way
        return int(text[1:], 16)
    return int(text, 0)


def value(kind, data):
    if kind == 'dword':
        return 'dword:%08x' % dword(data)
    if kind == 'binary':
        # GOG stores REG_BINARY base64-encoded; writing it as text is what makes
        # a game read its own settings as garbage and call them damaged
        raw = base64.b64decode(str(data), validate=True)
        return 'hex:' + ','.join('%02x' % b for b in raw)
    text = str(data).replace('{app}', '%APP%').replace('\\', '\\\\').replace('"', '\\"')
    return '"%s"' % text


# GOG marks some values onlyOnce: they are what the installer seeds, not what
# the game must always have. A language picked by the player lives among them,
# and re-imposing the seed on every move would quietly undo the choice.
keys, once = {}, {}
for d in load('goggame-*.script'):
    for action in d.get('actions') or []:
        install = action.get('install') or {}
        if install.get('action') != 'setRegistry':
            continue
        if not ({str(x).lower() for x in (action.get('languages') or ['*'])} & langs):
            continue          # action meant for a language this copy does not use
        args = install.get('arguments') or {}
        root = ROOTS.get(args.get('root') or '')
        if not root:
            continue
        # GOG writes the subkey with forward slashes; the registry wants
        # backslashes, and regedit takes "Software/Ubisoft/X" for one key name
        subkey = (args.get('subkey') or '').replace('/', '\\').strip('\\')
        where = once if 'onlyOnce' in (args.get('conditions') or []) else keys
        entries = where.setdefault(root + '\\' + subkey, [])
        if args.get('valueName'):
            kind = args.get('valueType') or 'string'
            try:                  # a value we cannot read is worth skipping, not crashing over
                value(kind, args.get('valueData'))
            except (TypeError, ValueError):
                continue
            entries.append((args['valueName'], kind, args.get('valueData')))


def write_reg(table, path):
    if not table:
        return
    out = ['Windows Registry Editor Version 5.00', '']
    for key, entries in table.items():
        # a 32-bit game in a win64 prefix reads HKLM\Software through WOW6432Node
        variants = [key]
        head = 'HKEY_LOCAL_MACHINE\\Software\\'
        if key.upper().startswith(head.upper()):   # GOG shouts SOFTWARE sometimes
            variants.append(key[:len(head)] + 'WOW6432Node\\' + key[len(head):])
        for k in variants:
            out.append('[%s]' % k)
            out += ['"%s"=%s' % (n, value(t, d)) for n, t, d in entries]
            out.append('')
    with open(os.path.join(target, path), 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(out))


for stale in ('gog-registry.reg', 'gog-registry-once.reg'):
    if os.path.exists(os.path.join(target, stale)):
        os.remove(os.path.join(target, stale))
write_reg(keys, 'gog-registry.reg')
write_reg(once, 'gog-registry-once.reg')

print(chosen)
print(';'.join(sorted({p for _, _, p, _ in tasks if p != chosen})))
print(base or name)
print(chosen_dir)
PYMETA
) || die "$M_META"

exe=$(printf '%s\n' "$meta" | sed -n 1p)
others=$(printf '%s\n' "$meta" | sed -n 2p)
name=$(printf '%s\n' "$meta" | sed -n 3p)
workdir=$(printf '%s\n' "$meta" | sed -n 4p)
# no metadata: the folder name, with the first letter raised
if [ -z "$name" ]; then
  name=$(basename "${target%.pc}")
  name="$(printf '%s' "${name:0:1}" | tr '[:lower:]' '[:upper:]')${name:1}"
fi

# no .info: first .exe at the root that isn't an accessory
if [ -z "$exe" ]; then
  for candidate in "$target"/*.exe; do
    case "${candidate##*/}" in
      unins*|UnityCrashHandler*|*etup.exe) continue ;;
      *) exe=${candidate##*/}; break ;;
    esac
  done
fi

# the .info is written on Windows, where filename case does not matter
if [ -n "$exe" ] && [ ! -e "$target/$exe" ]; then
  found=$(find "$target" -ipath "$target/$exe" -print -quit 2>/dev/null) || true
  if [ -n "$found" ]; then
    exe=${found#"$target/"}
  fi
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
  printf "$M_EXTRACTED" "$target"
  echo
  printf "$M_WARN_KIND" "$kind"
  if [ "$kind" = dos ]; then
    echo "$M_HERE     $M_DOS_PKG"
    echo "            cd $(basename "$target") && dosbox -conf dosbox_*.conf -conf dosbox_*_single.conf"
    echo "$M_BATOCERA $M_DOS_BATO"
  else
    echo "$M_HERE     $M_SCUMM_PKG"
    echo "$M_BATOCERA $M_SCUMM_BATO"
  fi
  echo
  echo "$M_NO_AUTORUN"
  exit 0
fi

if [ -z "$exe" ] || [ ! -e "$target/$exe" ]; then
  die "$(printf "$M_NO_EXE" "$target")"
fi
# A console-subsystem game asks the console for things -- Streets of Rage 4
# sets its title on the first line of Main -- and without one .NET throws
# IOException before the window ever opens. The menu entry has to say so.
read -r exe_bits exe_console <<< "$(python3 - "$target/$exe" <<'PYPE'
import struct, sys
try:
    with open(sys.argv[1], 'rb') as fh:
        fh.seek(0x3c)
        head = struct.unpack('<I', fh.read(4))[0]
        fh.seek(head + 4)
        machine = struct.unpack('<H', fh.read(2))[0]
        fh.seek(head + 0x5c)
        subsystem = struct.unpack('<H', fh.read(2))[0]
    print(32 if machine == 0x14c else 64, 'true' if subsystem == 3 else 'false')
except Exception:
    print('? false')
PYPE
)"

# play.sh cds into DIR and runs CMD from there, so the two have to agree. Only
# worth it when the executable lives inside the working directory -- anywhere
# else and the relative path back out costs more than it buys.
if [ -n "$workdir" ] && [ -d "$target/$workdir" ]; then
  case "$exe" in
    "$workdir"/*) exe=${exe#"$workdir"/}; printf "$M_WORKDIR" "$workdir" ;;
    *) workdir= ;;
  esac
else
  workdir=
fi

case "$exe" in *\ *) exe="\"$exe\"" ;; esac

# GOG ships graphics/input wrappers named after wine builtins - a scaling ddraw,
# a gamepad dinput. Wine has a hardcoded load order and uses its own, so the
# wrapper sits there unused and the game renders in a corner. ENV= fixes it on
# Batocera too, which is why it goes in autorun.cmd rather than play.sh.
wrappers=
for candidate in "$target"/*.dll; do
  case "${candidate##*/}" in
    ddraw.dll|d3d8.dll|d3d9.dll|dinput.dll|dinput8.dll|dsound.dll|xinput1_[1-4].dll)
      dll=${candidate##*/}
      wrappers="${wrappers:+$wrappers,}${dll%.dll}" ;;
  esac
done

# Unity decodes an .mp4 cutscene through Media Foundation and hands the frame
# to the game as a shared D3D11 texture. wined3d stubs GetSharedHandle, so the
# frame never arrives and the video plays black with the sound and the timing
# perfectly right. DXVK implements it. A .webm cutscene is VP8, which Unity
# decodes by itself, and needs none of this.
# kept apart from $wrappers: those are the game's own DLLs, this is a request
# for one wine does not ship, and saying so in the same breath would be a lie
unity=
[ -f "$target/UnityPlayer.dll" ] && unity=yes
unity_mf=
if [ -n "$unity" ] &&
   [ -n "$(find "$target" -iname '*.mp4' -print -quit 2>/dev/null)" ]; then
  unity_mf="d3d11,dxgi"
fi
overrides="$wrappers${wrappers:+${unity_mf:+,}}$unity_mf"

{
  [ -n "$overrides" ] && printf 'ENV=WINEDLLOVERRIDES="%s=n,b"\n' "$overrides"
  # a Unity player left to itself picks a 16:9 mode and lets the compositor
  # stretch it. The numbers belong to the machine that plays, so play.sh fills
  # them in; here we only say that this game wants them.
  [ -n "$workdir" ] && printf 'DIR=%s\n' "$workdir"
  [ -n "$unity" ] && printf 'SCREEN=native\n' 
  printf 'CMD=%s\n' "$exe"
} > "$target/autorun.cmd"
cp "$here/play.sh" "$here/uninstall.sh" "$here/saves.sh" "$target/"
# GOG's DirectDraw wrapper ships set to windowed. On a desktop that is a small
# box in the corner; on Batocera it is worse. Flip it, and say so.
if [ -f "$target/dxcfg.ini" ] && grep -q '^presentation=windowed' "$target/dxcfg.ini"; then
  sed -i 's/^presentation=windowed/presentation=fullscreen/' "$target/dxcfg.ini"
  echo "$M_DXCFG"
fi

# Some of these classics have an open reimplementation of their engine, which
# beats wine every time: native, real fullscreen, modern controllers. Say so;
# installing it is the user's call.
port= ; port_url=
case " $(printf '%s %s' "$name" "$(basename "${target%.pc}")" | tr '[:upper:]' '[:lower:]') " in
  *"doom 3"*|*doom3*)
    port="dhewm3"; port_url="dhewm3.org" ;;
  *"doom 64"*)
    port="Doom64 EX Plus"; port_url="github.com/atsb/Doom64EX-Plus" ;;
  *doom*|*heretic*|*strife*|*"chex quest"*)
    port="GZDoom"; port_url="zdoom.org" ;;
  *"hexen ii"*|*"hexen 2"*)
    port="Hammer of Thyrion"; port_url="sourceforge.net/projects/uhexen2" ;;
  *hexen*)
    port="GZDoom"; port_url="zdoom.org" ;;
  *"quake ii"*|*"quake 2"*)
    port="Yamagi Quake II"; port_url="www.yamagi.org/quake2" ;;
  *"quake iii"*|*"quake 3"*)
    port="ioquake3"; port_url="ioquake3.org" ;;
  *quake*)
    port="vkQuake"; port_url="github.com/Novum/vkQuake" ;;
  *"duke nukem 3d"*|*"duke nukem ii"*)
    port="EDuke32"; port_url="eduke32.com" ;;
  *blood*)
    port="NBlood"; port_url="github.com/nukeykt/NBlood" ;;
  *"shadow warrior"*)
    port="VoidSW"; port_url="voidsw.com" ;;
  *"redneck rampage"*|*powerslave*|*exhumed*|*tekwar*|*witchaven*|*nam*|*"world war ii gi"*)
    port="Raze"; port_url="raze.zdoom.org" ;;
  *"rise of the triad"*)
    port="rottexpr"; port_url="github.com/fabiangreffrath/rottexpr" ;;
  *"wolfenstein 3d"*|*"spear of destiny"*|*"noah's ark"*)
    port="ECWolf"; port_url="maniacsvault.net/ecwolf" ;;
  *"return to castle wolfenstein"*)
    port="iortcw"; port_url="github.com/iortcw/iortcw" ;;
  *"enemy territory"*)
    port="ET: Legacy"; port_url="www.etlegacy.com" ;;
  *"blake stone"*)
    port="BStone"; port_url="github.com/bibendovsky/bstone" ;;
  *"serious sam"*)
    port="Serious Sam Classic VK"; port_url="github.com/tx00100xt/SeriousSamClassic-VK" ;;
  *"medal of honor"*|*"medal of honour"*)
    port="OpenMoHAA"; port_url="github.com/openmoh/openmohaa" ;;
  *stalker*|*"s.t.a.l.k.e.r"*)
    port="OpenXRay"; port_url="github.com/OpenXRay/xray-16" ;;
  *"aliens versus predator"*|*"aliens vs predator"*)
    port="NakedAVP"; port_url="github.com/nitramtaz/NakedAVP" ;;
  *"jedi knight"*|*"dark forces ii"*|*"mysteries of the sith"*)
    port="OpenJKDF2"; port_url="github.com/shinyquagsire23/OpenJKDF2" ;;
  *"jedi outcast"*|*"jedi academy"*)
    port="OpenJK"; port_url="github.com/JACoders/OpenJK" ;;
  *"dark forces"*)
    port="The Force Engine"; port_url="theforceengine.github.io" ;;
  *"half-life"*|*"half life"*|*"counter-strike"*)
    port="Xash3D FWGS"; port_url="github.com/FWGS/xash3d-fwgs" ;;
  *"system shock 2"*)
    port="openDarkEngine"; port_url="github.com/volca02/openDarkEngine" ;;
  *"system shock"*)
    port="Shockolate"; port_url="github.com/Interrupt/systemshock" ;;
  *descent*)
    port="DXX-Rebirth"; port_url="dxx-rebirth.com" ;;
  *marathon*|*"pathways into darkness"*)
    port="Aleph One"; port_url="alephone.lhowon.org" ;;
  *unreal*)
    port="Surreal Engine"; port_url="github.com/dpjudas/SurrealEngine" ;;
  *"deus ex"*)
    port="Surreal 98"; port_url="github.com/HKRepublic/Deus-Ex-Surreal-98" ;;
  *"tomb raider"*)
    port="TRX"; port_url="github.com/LostArtefacts/TRX" ;;
  *drakan*)
    port="OpenDrakan"; port_url="github.com/Zenol/OpenDrakan" ;;
  *redguard*)
    port="Redguard Unity"; port_url="github.com/hazelnutcloud/redguard-unity" ;;
  *"alone in the dark"*)
    port="Free In The Dark"; port_url="github.com/OpenFITD/freeInTheDark" ;;
  *"prince of persia"*)
    port="SDLPoP"; port_url="github.com/NagyD/SDLPoP" ;;
  *"another world"*|*"out of this world"*)
    port="rawgl"; port_url="github.com/cyxx/rawgl" ;;
  *flashback*)
    port="REminiscence"; port_url="github.com/cyxx/reminiscence" ;;
  *"commander keen"*|*"cosmo's cosmic"*|*"keen dreams"*)
    port="Commander Genius"; port_url="github.com/gerstrong/Commander-Genius" ;;
  *"jazz jackrabbit 2"*)
    port="Jazz2 Resurrection"; port_url="github.com/deathkiller/jazz2-native" ;;
  *"jazz jackrabbit"*)
    port="OpenJazz"; port_url="github.com/AlisterT/openjazz" ;;
  *"abe's oddysee"*|*"abe's exoddus"*|*oddworld*)
    port="R.E.L.I.V.E."; port_url="github.com/AliveTeam/alive_reversing" ;;
  *"cave story"*)
    port="NXEngine-evo"; port_url="github.com/nxengine/nxengine-evo" ;;
  *abuse*)
    port="Abuse 2025"; port_url="github.com/Xenoveritas/abuse" ;;
  *tyrian*)
    port="OpenTyrian"; port_url="github.com/opentyrian/opentyrian" ;;
  *lemmings*)
    port="Lemmini"; port_url="github.com/Java-Lemmini/lemmini" ;;
  *"rick dangerous"*)
    port="xrick"; port_url="github.com/oco2000/xrick" ;;
  *nox*)
    port="OpenNox"; port_url="flathub.org/apps/io.github.noxworld_dev.OpenNox" ;;
  *"little big adventure"*|*"relentless twinsen"*)
    port="TwinE"; port_url="github.com/mgerhardy/vengi-twinengine" ;;
  *"magic carpet"*)
    port="remc2"; port_url="github.com/AlexRiedel/remc2" ;;
  *"future cop"*)
    port="Future Cop: MIT"; port_url="github.com/BastianInsideYou/FutureCopMIT" ;;
  *morrowind*)
    port="OpenMW"; port_url="openmw.org" ;;
  *daggerfall*)
    port="Daggerfall Unity"; port_url="www.dfworkshop.net" ;;
  *arena*)
    port="OpenTESArena"; port_url="github.com/afritz1/OpenTESArena" ;;
  *diablo*)
    port="DevilutionX"; port_url="github.com/diasurgical/devilutionX" ;;
  *"fallout 2"*)
    port="Fallout 2 CE"; port_url="github.com/alexbatalov/fallout2-ce" ;;
  *fallout*)
    port="Fallout CE"; port_url="github.com/alexbatalov/fallout1-ce" ;;
  *"baldur's gate"*|*planescape*|*"icewind dale"*)
    port="GemRB"; port_url="gemrb.org" ;;
  *"ultima underworld"*)
    port="UnderworldGodot"; port_url="github.com/hankmorgan/UnderworldGodot" ;;
  *"ultima viii"*|*"ultima 8"*)
    port="Pentagram"; port_url="pentagram.sourceforge.net" ;;
  *"ultima vii"*|*"ultima 7"*)
    port="Exult"; port_url="exult.info" ;;
  *"might and magic"*)
    port="OpenEnroth"; port_url="github.com/OpenEnroth/OpenEnroth" ;;
  *"arx fatalis"*)
    port="Arx Libertatis"; port_url="arx-libertatis.org" ;;
  *arcanum*)
    port="Arcanum CE"; port_url="github.com/alexbatalov/arcanum-ce" ;;
  *gothic*)
    port="OpenGothic"; port_url="github.com/Try/OpenGothic" ;;
  *"betrayal at krondor"*)
    port="BaKGL"; port_url="github.com/xavierpuigf/BaKGL" ;;
  *ambermoon*)
    port="Ambermoon.net"; port_url="github.com/Pyrdacor/Ambermoon.net" ;;
  *albion*)
    port="M-HT SR"; port_url="github.com/M-HT/SR" ;;
  *"knights of the old republic"*|*kotor*)
    port="reone"; port_url="github.com/seedhartha/reone" ;;
  *"neverwinter nights"*|*witcher*)
    port="xoreos"; port_url="xoreos.org" ;;
  *"heroes of might and magic ii"*|*"heroes of might and magic 2"*)
    port="fheroes2"; port_url="github.com/ihhub/fheroes2" ;;
  *"heroes of might"*|*homm*)
    port="VCMI"; port_url="vcmi.eu" ;;
  *"warcraft ii"*|*"warcraft 2"*|*"tides of darkness"*)
    port="Wargus"; port_url="wargus.github.io" ;;
  *"warcraft: orcs"*|*"orcs & humans"*|*"orcs and humans"*)
    port="War1gus"; port_url="github.com/Wargus/war1gus" ;;
  *starcraft*)
    port="Stargus"; port_url="github.com/Wargus/stargus" ;;
  *"age of empires"*|*"galactic battlegrounds"*)
    port="openage"; port_url="openage.dev" ;;
  *"command & conquer"*|*"command and conquer"*|*"red alert"*|*"tiberian dawn"*)
    port="OpenRA"; port_url="www.openra.net" ;;
  *"tiberian sun"*|*generals*)
    port="OpenSAGE"; port_url="opensage.github.io" ;;
  *"dune ii"*|*"dune 2"*|*"battle for dune"*)
    port="Dune Legacy"; port_url="dunelegacy.sourceforge.net" ;;
  *"knights and merchants"*)
    port="KaM Remake"; port_url="www.kamremake.com" ;;
  *"dungeon keeper 2"*)
    port="OpenKeeper"; port_url="github.com/tonihele/OpenKeeper" ;;
  *"dungeon keeper"*)
    port="KeeperFX"; port_url="keeperfx.net" ;;
  *"total annihilation"*)
    port="TA3D"; port_url="github.com/TA3D/TA3D" ;;
  *"warcraft iii"*|*"warcraft 3"*)
    port="WarsmashModEngine"; port_url="github.com/Retera/WarsmashModEngine" ;;
  *"syndicate wars"*)
    port="Syndicate Wars Port"; port_url="github.com/swaledge/swars" ;;
  *syndicate*)
    port="FreeSynd"; port_url="freesynd.sourceforge.io" ;;
  *apocalypse*)
    port="OpenApoc"; port_url="github.com/OpenApoc/OpenApoc" ;;
  *"x-com"*|*xcom*|*"ufo defense"*|*"enemy unknown"*|*"terror from the deep"*)
    port="OpenXcom"; port_url="openxcom.org" ;;
  *"jagged alliance 2"*)
    port="JA2-Stracciatella"; port_url="ja2-stracciatella.github.io" ;;
  *"master of orion"*)
    port="1oom"; port_url="gitlab.com/KilgoreTroutMaskReplicant/1oom" ;;
  *"alpha centauri"*)
    port="GLSMAC"; port_url="github.com/afwbkbc/glsmac" ;;
  *"call to power"*)
    port="civctp2"; port_url="github.com/civctp2/civctp2" ;;
  *colonization*)
    port="FreeCol"; port_url="www.freecol.org" ;;
  *"caesar iii"*|*"caesar 3"*)
    port="Augustus"; port_url="github.com/Keriew/augustus" ;;
  *pharaoh*|*cleopatra*)
    port="Akhenaten"; port_url="github.com/dalerank/Akhenaten" ;;
  *zeus*|*poseidon*)
    port="eZeus"; port_url="github.com/mortylab/ezeus" ;;
  *"settlers ii"*|*"settlers 2"*)
    port="Return to the Roots"; port_url="www.siedler25.org" ;;
  *"settlers"*)
    port="Freeserf.net"; port_url="github.com/Pyrdacor/freeserf.net" ;;
  *"theme hospital"*)
    port="CorsixTH"; port_url="corsixth.com" ;;
  *simcity*|*micropolis*)
    port="Micropolis"; port_url="github.com/SimHacker/micropolis" ;;
  *homeworld*)
    port="Homeworld SDL"; port_url="github.com/HomeworldSDL/HomeworldSDL" ;;
  *"transport tycoon"*)
    port="OpenTTD"; port_url="www.openttd.org" ;;
  *locomotion*)
    port="OpenLoco"; port_url="github.com/OpenLoco/OpenLoco" ;;
  *"rollercoaster tycoon 2"*|*"rollercoaster tycoon"*)
    port="OpenRCT2"; port_url="openrct2.io" ;;
  *"black & white"*|*"black and white"*)
    port="Openblack"; port_url="github.com/openblack/openblack" ;;
  *"terminal velocity"*|*fury3*)
    port="terminal-recall"; port_url="github.com/jtrfp/terminal-recall" ;;
  *carmageddon*)
    port="Dethrace"; port_url="github.com/dethrace-labs/dethrace" ;;
  *"death rally"*)
    port="DRally"; port_url="github.com/tapio/drally" ;;
  *"need for speed"*)
    port="OpenNFS"; port_url="github.com/OpenNFS/OpenNFS" ;;
  *"episode i"*|*"episode 1 racer"*|*swe1r*)
    port="OpenSWE1R"; port_url="github.com/OpenSWE1R/openswe1r" ;;
  *"midtown madness"*)
    port="Open1560"; port_url="github.com/0x1F9F1/Open1560" ;;
  *wipeout*)
    port="Wipeout Rewrite"; port_url="github.com/phoboslab/wipeout-rewrite" ;;
  *re-volt*|*revolt*)
    port="RVGL"; port_url="rvgl.re-volt.io" ;;
  *"stunt car racer"*)
    port="stuntcarremake"; port_url="github.com/ptitSeb/stuntcarremake" ;;
  *driver*)
    port="REDriver2"; port_url="github.com/OpenDriver2/REDRIVER2" ;;
esac
[ -n "$port" ] && printf "$M_PORT" "$name" "$port" "$port_url"

printf "$M_DONE" "$target" "$exe"
[ -n "$wrappers" ] && printf "$M_WRAPPERS" "$wrappers"
[ -n "$unity" ] && printf "$M_SCREEN"
if [ -n "$unity_mf" ]; then
  printf "$M_UNITY_MF"
  echo "$M_UNITY_MF2"
fi
if [ -f "$target/gog-registry.reg" ]; then
  echo "$M_REG"
fi
if [ -n "$others" ]; then
  printf "$M_OTHERS" "${others//;/, }"
  echo "$M_OTHERS2"
fi

# Ren'Py and friends: the Windows installer usually carries the Linux build too.
# Same rule as play.sh (the two copies are deliberate, see the note there).
if compgen -G "$target/lib/*linux*" >/dev/null; then
  for candidate in "$target"/*.sh; do
    native=${candidate##*/}
    [ "$native" = play.sh ] && continue
    # a Windows installer does not carry the execute bit
    chmod +x "$candidate" "$target"/lib/*linux*/* 2>/dev/null || true
    printf "$M_NATIVE" "$(basename "$target")" "$native"
    break
  done
fi

# LOVE keeps its runtime in love.dll beside the game, and the .exe is that
# runtime with the game appended as a zip -- which a native LOVE opens as it is,
# no renaming and no unpacking. Worth the detour: a LOVE game that brings its
# own window up (t.window = false in conf.lua) jumps to a null pointer under
# wine, right where it creates the GL context.
if [ -f "$target/love.dll" ] && [ ! -e "$target/launch.sh" ]; then
  # shipped beside the runtime as a .love, or fused into the .exe
  lovegame=${exe//\"/}
  for archive in "$target"/*.love; do lovegame=${archive##*/}; break; done
  # only write a launcher for something that really is a LOVE archive; zipfile
  # reads past the .exe in front of it, the same way LOVE itself does
  if python3 - "$target/$lovegame" <<'PYLOVE'
import sys, zipfile
try:
    names = zipfile.ZipFile(sys.argv[1]).namelist()
except Exception:
    sys.exit(1)
sys.exit(0 if {'conf.lua', 'main.lua'} & set(names) else 1)
PYLOVE
  then
    {
      echo '#!/bin/sh'
      printf '# %s, through the LOVE engine instead of wine. Written by build.sh:\n' "$name"
      echo '# play.sh prefers this file over wine. Delete it to go back to wine, or'
      echo '# set FORCE_WINE=1 for a single run.'
      echo 'set -eu'
      echo 'here=$(dirname "$(readlink -f "$0")")'
      printf 'game="$here/%s"\n' "$lovegame"
      echo ''
      echo '# a distro package if there is one, the flatpak otherwise'
      echo 'if command -v love >/dev/null 2>&1; then'
      echo '  exec love "$game" "$@"'
      echo 'fi'
      echo 'command -v flatpak >/dev/null 2>&1 || {'
      echo '  echo "install love, or: flatpak install flathub org.love2d.love2d" >&2'
      echo '  exit 1'
      echo '}'
      echo '# the sandbox cannot see the game folder unless it is handed over'
      echo 'exec flatpak run --filesystem="$here" org.love2d.love2d "$game" "$@"'
    } > "$target/launch.sh"
    chmod +x "$target/launch.sh"
    printf "$M_LOVE" "$lovegame"
    command -v love >/dev/null || command -v flatpak >/dev/null ||
      missing="$missing$M_NEED_LOVE"
  fi
fi

# What this machine still lacks for this particular game. Said once, at the end,
# with the package names -- finding out from a crash dump costs an evening.
if [ -n "$unity_mf" ]; then
  have=
  for dxvk in /usr/libexec/dxvk/lib64 /usr/share/dxvk/x64 /usr/lib/dxvk/x64 /opt/dxvk/x64; do
    [ -f "$dxvk/d3d11.dll" ] && have=yes && break
  done
  [ -n "$have" ] || missing="$missing$M_NEED_DXVK"
fi

# A 32-bit game decodes its compressed audio and video through the 32-bit
# GStreamer, which is a separate install from the 64-bit one and easy to miss:
# the core alone loads happily and then decodes nothing.
# the parentheses matter: -o binds looser than the implied -a, so without them
# -print would only ever apply to the last name in the list
if [ -n "$(find "$target" \( -iname '*.xwb' -o -iname '*.wma' -o -iname '*.wmv' \
                -o -iname '*.asf' \) -print -quit 2>/dev/null)" ] &&
   [ "$exe_bits" = 32 ]; then
  have=
  for gst in ${GOG2LINUX_GST32:-/usr/lib/gstreamer-1.0 /usr/lib32/gstreamer-1.0 \
             /usr/lib/i386-linux-gnu/gstreamer-1.0}; do
    [ -f "$gst/libgstlibav.so" ] && have=yes && break
  done
  [ -n "$have" ] || missing="$missing$M_NEED_GST32"
fi

command -v wine >/dev/null 2>&1 || missing="$missing$M_NEED_WINE"

if [ -n "$missing" ]; then
  printf "$M_PENDING"
  printf '%b' "$missing"   # the messages carry their own newlines
fi

# A .desktop entry is all KDE, GNOME and XFCE need; no per-desktop code.
if [ "$desktop" = ask ] && [ -t 0 ]; then
  printf "$M_ASK_MENU" "$name"
  read -r answer
  case "$answer" in ["$M_YES"]*) desktop=yes ;; *) desktop=no ;; esac
fi

if [ "$desktop" = yes ]; then
  apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  mkdir -p "$apps"
  entry="$apps/gog-$(basename "${target%.pc}").desktop"
  # a .ico holds every size; desktops tend to grab the first (16x16), so pull
  # out the biggest one. GOG stores them PNG-compressed, so it is a plain cut.
  icon=$(python3 - "$target" "$(basename "${target%.pc}")" "${exe//\"/}" <<'PYICON'
import glob, os, struct, sys

target = sys.argv[1]
# A release can carry five .ico files: the game, the GOG logo, a Games for
# Windows badge, the support page, a readme. Prefer the one named after the
# game, then GOG's per-game icon; the generic logo is a last resort.
slug = (sys.argv[2] if len(sys.argv) > 2 else '').lower()
stem = os.path.splitext(os.path.basename(sys.argv[3] if len(sys.argv) > 3 else ''))[0].lower()
# NOX.ICO exists next to gog.ico: globbing '*.ico' on Linux would miss it
every = sorted(f for f in glob.glob(os.path.join(target, '*')) if f.lower().endswith('.ico'))


def named(*wanted):
    return [f for f in every if os.path.splitext(os.path.basename(f))[0].lower() in wanted]


found = (named(slug, stem)
         or [f for f in every if os.path.basename(f).lower().startswith('goggame-')]
         or [f for f in every if os.path.basename(f).lower().startswith('gog')]
         or every)
if found:
    blob = open(found[0], 'rb').read()
    best = (0, None)
    for i in range(struct.unpack('<H', blob[4:6])[0]):
        w, h, _, _, _, _, size, off = struct.unpack('<BBBBHHII', blob[6 + i * 16:22 + i * 16])
        if (w or 256) * (h or 256) > best[0] and blob[off:off + 4] == b'\x89PNG':
            best = ((w or 256) * (h or 256), blob[off:off + size])
    if best[1]:
        png = os.path.join(target, 'icon.png')
        open(png, 'wb').write(best[1])
        print(png)
    else:
        print(found[0])
PYICON
) || icon=
  {
    echo "[Desktop Entry]"
    echo "Type=Application"
    echo "Name=$name"
    # a source port beats wine; drop a launch.sh in the folder and it wins
    launcher=$target/play.sh
    [ -x "$target/launch.sh" ] && launcher=$target/launch.sh
    # Exec is split on whitespace, so "Gravity Circuit.pc" would arrive as two
    # arguments and start nothing. Quoting is the fix, and inside the quotes the
    # spec wants a backslash before \ " ` and $. Path and Icon are plain
    # strings, taken literally, and must NOT be quoted the same way.
    echo "Exec=\"$(printf '%s' "$launcher" | sed 's/[\\"`$]/\\&/g')\""
    echo "Path=$target"
    [ -n "$icon" ] && echo "Icon=$icon"
    echo "Categories=Game;"
    echo "Terminal=$exe_console"
  } > "$entry"
  chmod +x "$entry"


  command -v update-desktop-database >/dev/null && update-desktop-database "$apps" 2>/dev/null
  printf "$M_ENTRY" "$entry"
fi

# the installers did their job and weigh several GB; offer to reclaim the space,
# but only after everything above went through -- a half-built folder is worth
# rebuilding, and it cannot be rebuilt from installers that are gone
if [ -n "$staging" ]; then
  answer=n
  if [ -t 0 ]; then
    printf "$M_ASK_STAGE" "$staging"
    read -r answer
  fi
  case "$answer" in
    ["$M_YES"]*) rm -rf "$staging"; printf "$M_STAGE_GONE" "$staging" ;;
    *)           printf "$M_STAGE_KEPT" "$staging" ;;
  esac
fi

}
