#!/usr/bin/env bash
# GOG installer (InnoSetup) -> .pc folder that runs on Batocera and on any distro.
#
#   ./build.sh Game.pc setup.exe [dlc.exe ...]   package
#   ./build.sh Game.pc                           only reclassify an extracted folder
set -euo pipefail
shopt -s dotglob nullglob

die() { echo "$*" >&2; exit 1; }

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

# Messages in the two languages this is used in. Picked from $LANG; force with
# GOG2LINUX_LANG=pt or =en. No gettext, no .po files, no runtime dependency.
case "${GOG2LINUX_LANG:-${LC_ALL:-${LANG:-en}}}" in
  pt*)
    M_USAGE="uso: %s [--desktop|--no-desktop] [--lang CODIGO|all] Jogo.pc setup.exe [dlc.exe ...]\n"
    M_NO_INNO="falta o innoextract: instale o pacote innoextract (apt/dnf/pacman/zypper)"
    M_NO_PY="falta o python3: instale o pacote python3"
    M_NOT_DEST="o primeiro argumento e a pasta de destino, nao o instalador"
    M_NO_SETUP="instalador nao encontrado: %s\n"
    M_OFFERS="%s oferece %s idiomas:\n"
    M_ASK_LANG="Idioma [%s]: "
    M_LANG="idioma: %s (%s)\n"
    M_ONLY_LANG="idioma: %s (%s) - o unico que este instalador traz\n"
    M_META="nao consegui ler os metadados da GOG (veja o erro do python acima)"
    M_NO_EXE="nao achei o executavel do jogo em %s\n"
    M_EXTRACTED="extraido: %s\n"
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
    M_OTHERS="outras entradas no goggame-*.info: %s\n"
    M_OTHERS2="  se o jogo nao abrir, tente uma delas no autorun.cmd"
    M_NATIVE="obs: tem build Linux nativo aqui -> ./%s/%s (sem wine)\n"
    M_ASK_MENU='Adicionar "%s" ao menu de jogos? [s/N] '
    M_YES="sSyY"
    M_ENTRY="entrada de menu: %s\n"
    ;;
  *)
    M_USAGE="usage: %s [--desktop|--no-desktop] [--lang CODE|all] Game.pc setup.exe [dlc.exe ...]\n"
    M_NO_INNO="innoextract is missing: install the innoextract package (apt/dnf/pacman/zypper)"
    M_NO_PY="python3 is missing: install the python3 package"
    M_NOT_DEST="first argument is the destination folder, not the installer"
    M_NO_SETUP="installer not found: %s\n"
    M_OFFERS="%s offers %s languages:\n"
    M_ASK_LANG="Language [%s]: "
    M_LANG="language: %s (%s)\n"
    M_ONLY_LANG="language: %s (%s) - the only one this installer carries\n"
    M_META="could not read the GOG metadata (see the python error above)"
    M_NO_EXE="could not find the game executable in %s\n"
    M_EXTRACTED="extracted: %s\n"
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
    M_OTHERS="other entries in goggame-*.info: %s\n"
    M_OTHERS2="  if the game won't start, try one of those in autorun.cmd"
    M_NATIVE="note: native Linux build here -> ./%s/%s (no wine)\n"
    M_ASK_MENU='Add "%s" to the desktop games menu? [y/N] '
    M_YES="yY"
    M_ENTRY="menu entry: %s\n"
    ;;
esac


desktop=ask
lang=auto
while [ $# -gt 0 ]; do
  case "$1" in
    --desktop)    desktop=yes; shift ;;
    --no-desktop) desktop=no;  shift ;;
    --lang)       lang=${2:-}; shift 2 ;;
    --lang=*)     lang=${1#--lang=}; shift ;;
    *)            break ;;
  esac
done

[ $# -ge 1 ] || die "$(printf "$M_USAGE" "$0")"
command -v innoextract >/dev/null ||
  die "$M_NO_INNO"
command -v python3 >/dev/null || die "$M_NO_PY"

target=$(readlink -f "$1"); shift

# a forgotten destination turns the installer into $1 and mkdir fails cryptically
[ -f "$target" ] && die "$M_NOT_DEST
$(printf "$M_USAGE" "$0")"

# check everything before extracting: failing halfway leaves a half-built folder
for setup in "$@"; do
  [ -f "$setup" ] || die "$(printf "$M_NO_SETUP" "$setup")"
done

mkdir -p "$target"
if [ $# -gt 0 ]; then
  for setup in "$@"; do
    setup=$(readlink -f "$setup")
    # a multi-language installer extracts every language at once, and the last
    # one wins the metadata -- which is how an English game ends up Italian.
    pick=$lang
    if [ "$lang" = auto ]; then
      offered=$(innoextract --list-languages "$setup" 2>/dev/null | awk '/^ - /{print $2}') || true
      pick=$(printf '%s\n' "$offered" | awk '/^en/{print; exit}')
      count=$(printf '%s\n' "$offered" | grep -c .) || true

      # more than one language and someone watching: let them pick
      if [ "$count" -gt 1 ] && [ -t 0 ]; then
        printf "$M_OFFERS" "$(basename "$setup")" "$count"
        i=0
        while IFS= read -r code; do
          [ -n "$code" ] || continue
          i=$((i + 1))
          printf '  %2d) %-8s %s\n' "$i" "$code" "$(lang_name "$code")"
        done <<< "$offered"
        printf "$M_ASK_LANG" "${pick:-1}"
        read -r answer
        case "$answer" in
          '') ;;
          *[!0-9]*) pick=$answer ;;
          *) pick=$(printf '%s\n' "$offered" | sed -n "${answer}p") ;;
        esac
      fi
      # chosen once, reused for the DLCs that follow
      [ -n "$pick" ] && lang=$pick
    fi
    opts=()
    if [ -n "$pick" ] && [ "$pick" != all ]; then
      opts+=(--language "$pick")
      if [ "${count:-1}" -le 1 ]; then
        printf "$M_ONLY_LANG" "$pick" "$(lang_name "$pick")"
      else
        printf "$M_LANG" "$pick" "$(lang_name "$pick")"
      fi
    fi
    innoextract --gog --silent --collisions=overwrite "${opts[@]}" -d "$target" "$setup"
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


tasks, langs, name = [], {'*'}, ''
for d in load('goggame-*.info'):
    name = name or (d.get('name') or '')
    langs |= {str(x).lower() for x in (d.get('languages') or [])}
    for t in d.get('playTasks') or []:
        path = (t.get('path') or '').replace('\\', '/')
        if path.lower().endswith('.exe'):
            tasks.append((t.get('category'), t.get('isPrimary'), path))

# a launcher wants a mouse and often starts a build wine cannot run; the entry
# GOG tags as the game itself is the better default.
chosen = ''
for wanted in (lambda c, p: c == 'game', lambda c, p: p, lambda c, p: True):
    for cat, primary, path in tasks:
        if wanted(cat, primary):
            chosen = path
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


keys = {}
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
        entries = keys.setdefault(root + '\\' + args.get('subkey', ''), [])
        if args.get('valueName'):
            kind = args.get('valueType') or 'string'
            try:                  # a value we cannot read is worth skipping, not crashing over
                value(kind, args.get('valueData'))
            except (TypeError, ValueError):
                continue
            entries.append((args['valueName'], kind, args.get('valueData')))


if keys:
    out = ['Windows Registry Editor Version 5.00', '']
    for key, entries in keys.items():
        # a 32-bit game in a win64 prefix reads HKLM\Software through WOW6432Node
        variants = [key]
        if key.startswith('HKEY_LOCAL_MACHINE\\Software\\'):
            variants.append(key.replace('HKEY_LOCAL_MACHINE\\Software\\',
                                        'HKEY_LOCAL_MACHINE\\Software\\WOW6432Node\\', 1))
        for k in variants:
            out.append('[%s]' % k)
            out += ['"%s"=%s' % (n, value(t, d)) for n, t, d in entries]
            out.append('')
    with open(os.path.join(target, 'gog-registry.reg'), 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(out))

print(chosen)
print(';'.join(sorted({p for _, _, p in tasks if p != chosen})))
print(name)
PYMETA
) || die "$M_META"

exe=$(printf '%s\n' "$meta" | sed -n 1p)
others=$(printf '%s\n' "$meta" | sed -n 2p)
name=$(printf '%s\n' "$meta" | sed -n 3p)
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

{
  [ -n "$wrappers" ] && printf 'ENV=WINEDLLOVERRIDES="%s=n,b"\n' "$wrappers"
  printf 'CMD=%s\n' "$exe"
} > "$target/autorun.cmd"
here=$(dirname "$(readlink -f "$0")")
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
  *"doom 3"*|*doom3*)         port="dhewm3";           port_url="dhewm3.org" ;;
  *"hexen ii"*)               port="Hammer of Thyrion"; port_url="sourceforge.net/projects/uhexen2" ;;
  *doom*|*heretic*|*hexen*|*strife*) port="GZDoom";    port_url="zdoom.org" ;;
  *"duke nukem 3d"*)          port="EDuke32";          port_url="eduke32.com" ;;
  *blood*)                    port="NBlood";           port_url="github.com/nukeykt/NBlood" ;;
  *"shadow warrior"*|*"redneck rampage"*) port="Raze"; port_url="raze.zdoom.org" ;;
  *"quake ii"*|*"quake 2"*)   port="Yamagi Quake II";  port_url="yamagi.org/quake2" ;;
  *"quake iii"*|*"quake 3"*)  port="ioquake3";         port_url="ioquake3.org" ;;
  *quake*)                    port="vkQuake";          port_url="github.com/Novum/vkQuake" ;;
  *"wolfenstein 3d"*|*"spear of destiny"*) port="ECWolf"; port_url="maniacsvault.net/ecwolf" ;;
  *"return to castle wolfenstein"*) port="iortcw";     port_url="github.com/iortcw/iortcw" ;;
  *"jedi knight"*|*"dark forces ii"*) port="OpenJKDF2"; port_url="github.com/shinyquagsire23/OpenJKDF2" ;;
  *"jedi outcast"*|*"jedi academy"*) port="OpenJK";     port_url="github.com/JACoders/OpenJK" ;;
  *"dark forces"*)            port="The Force Engine"; port_url="theforceengine.github.io" ;;
  *"enemy territory"*)        port="ET: Legacy";       port_url="etlegacy.com" ;;
  *"might and magic vi"*|*"might and magic vii"*|*"might and magic viii"*) port="OpenEnroth"; port_url="github.com/OpenEnroth/OpenEnroth" ;;
  *"ultima viii"*|*"ultima 8"*) port="Pentagram";      port_url="pentagram.sourceforge.net" ;;
  *colonization*)             port="FreeCol";          port_url="freecol.org" ;;
  *"dune ii"*|*"dune 2"*)     port="Dune Legacy";      port_url="dunelegacy.sourceforge.net" ;;
  *"heroes of might and magic ii"*|*"heroes of might and magic 2"*) port="fheroes2"; port_url="github.com/ihhub/fheroes2" ;;
  *"jagged alliance 2"*)      port="ja2-stracciatella"; port_url="github.com/ja2-stracciatella/ja2-stracciatella" ;;
  *"settlers ii"*|*"settlers 2"*) port="Return to the Roots"; port_url="siedler25.org" ;;
  *starcraft*)                port="Stargus";          port_url="github.com/Wargus/stargus" ;;
  *"x-com"*|*"xcom"*|*"ufo defense"*|*"terror from the deep"*) port="OpenXcom"; port_url="openxcom.org" ;;
  *"another world"*|*"out of this world"*) port="rawgl"; port_url="github.com/cyxx/rawgl" ;;
  *"commander keen"*)         port="Commander Genius"; port_url="github.com/gerstrong/Commander-Genius" ;;
  *flashback*)                port="REminiscence";     port_url="github.com/cyxx/reminiscence" ;;
  *"prince of persia"*)       port="SDLPoP";           port_url="github.com/NagyD/SDLPoP" ;;
  *"star control"*)           port="The Ur-Quan Masters"; port_url="sc2.sourceforge.net" ;;
  *"half-life"*|*"half life"*) port="Xash3D FWGS";     port_url="github.com/FWGS/xash3d-fwgs" ;;
  *marathon*)                 port="Aleph One";        port_url="alephone.lhowon.org" ;;
  *"little big adventure"*)   port="TwinE";            port_url="github.com/mgerhardy/vengi-twinengine" ;;
  *nox*)                      port="OpenNox";          port_url="flathub io.github.noxworld_dev.OpenNox" ;;
  *morrowind*|*elder\ scrolls\ iii*) port="OpenMW";  port_url="openmw.org" ;;
  *diablo*)                   port="DevilutionX";      port_url="github.com/diasurgical/devilutionX" ;;
  *"heroes of might"*|*homm*) port="VCMI";             port_url="vcmi.eu" ;;   # III; II acima
  *"command & conquer"*|*"red alert"*|*"dune 2000"*|*"tiberian sun"*) port="OpenRA"; port_url="openra.net" ;;
  *"transport tycoon"*)       port="OpenTTD";          port_url="openttd.org" ;;
  *"theme hospital"*)         port="CorsixTH";         port_url="corsixth.com" ;;
  *"arx fatalis"*)            port="Arx Libertatis";   port_url="arx-libertatis.org" ;;
  *"dungeon keeper"*)         port="KeeperFX";         port_url="keeperfx.net" ;;
  *"caesar 3"*|*"caesar iii"*) port="Augustus";        port_url="github.com/Keriew/augustus" ;;
  *pharaoh*)                  port="Ozymandias";       port_url="github.com/Keriew/ozymandias" ;;
  *"ultima vii"*|*"ultima 7"*) port="Exult";           port_url="exult.info" ;;
  *daggerfall*)               port="Daggerfall Unity"; port_url="dfworkshop.net" ;;
  *"fallout 2"*|*"fallout 1"*) port="Fallout Community Edition"; port_url="github.com/alexbatalov/fallout2-ce" ;;
  *"baldur's gate"*|*"planescape"*|*"icewind dale"*) port="GemRB"; port_url="gemrb.org" ;;
  *"system shock"*)           port="Shockolate";       port_url="github.com/Interrupt/systemshock" ;;
  *descent*)                  port="DXX-Rebirth";      port_url="dxx-rebirth.com" ;;
  *"master of orion 2"*)      port="1oom";             port_url="gitlab.com/KilgoreTroutMaskReplicant/1oom" ;;
  *syndicate*)                port="FreeSynd";         port_url="freesynd.sourceforge.io" ;;
  *"tomb raider"*)            port="TR1X";             port_url="github.com/LostArtefacts/TR1X" ;;
  *"freespace 2"*)            port="Freespace Open";   port_url="fsnebula.org" ;;
  *"warcraft ii"*|*"warcraft 2"*) port="Wargus";       port_url="wargus.github.io" ;;
esac
[ -n "$port" ] && printf "$M_PORT" "$name" "$port" "$port_url"

printf "$M_DONE" "$target" "$exe"
[ -n "$wrappers" ] && printf "$M_WRAPPERS" "$wrappers"
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
    if [ -x "$target/launch.sh" ]; then
      echo "Exec=$target/launch.sh"
    else
      echo "Exec=$target/play.sh"
    fi
    echo "Path=$target"
    [ -n "$icon" ] && echo "Icon=$icon"
    echo "Categories=Game;"
    echo "Terminal=false"
  } > "$entry"
  chmod +x "$entry"


  command -v update-desktop-database >/dev/null && update-desktop-database "$apps" 2>/dev/null
  printf "$M_ENTRY" "$entry"
fi
