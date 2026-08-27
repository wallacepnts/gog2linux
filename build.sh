#!/usr/bin/env bash
# GOG installer (InnoSetup) -> .pc folder that runs on Batocera and on any distro.
#
#   ./build.sh Game.pc setup.exe [dlc.exe ...]   package
#   ./build.sh Game.pc                           only reclassify an extracted folder
set -euo pipefail
shopt -s dotglob nullglob

die() { echo "$*" >&2; exit 1; }

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

[ $# -ge 1 ] || die "usage: $0 [--desktop|--no-desktop] [--lang CODE|all] Game.pc setup.exe [dlc.exe ...]"
command -v innoextract >/dev/null ||
  die "innoextract is missing: install the innoextract package (apt/dnf/pacman/zypper)"
command -v python3 >/dev/null || die "python3 is missing: install the python3 package"

target=$(readlink -f "$1"); shift

# a forgotten destination turns the installer into $1 and mkdir fails cryptically
[ -f "$target" ] && die "first argument is the destination folder, not the installer
usage: $0 Game.pc setup.exe [dlc.exe ...]"

# check everything before extracting: failing halfway leaves a half-built folder
for setup in "$@"; do
  [ -f "$setup" ] || die "installer not found: $setup"
done

mkdir -p "$target"
if [ $# -gt 0 ]; then
  for setup in "$@"; do
    setup=$(readlink -f "$setup")
    # a multi-language installer extracts every language at once, and the last
    # one wins the metadata -- which is how an English game ends up Italian.
    pick=$lang
    if [ "$lang" = auto ]; then
      pick=$(innoextract --list-languages "$setup" 2>/dev/null | awk '/^ - en/{print $2; exit}') || true
    fi
    opts=()
    [ -n "$pick" ] && [ "$pick" != all ] && opts+=(--language "$pick") && echo "language: $pick"
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
) || die "python3 is required to read the GOG metadata"

exe=$(printf '%s\n' "$meta" | sed -n 1p)
others=$(printf '%s\n' "$meta" | sed -n 2p)
name=$(printf '%s\n' "$meta" | sed -n 3p)
[ -n "$name" ] || name=$(basename "${target%.pc}")

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
  echo "extracted: $target"
  echo
  echo "WARNING: this is a $kind game in disguise. Do NOT run it through wine."
  if [ "$kind" = dos ]; then
    echo "  here:     install the dosbox package, then:"
    echo "            cd $(basename "$target") && dosbox -conf dosbox_*.conf -conf dosbox_*_single.conf"
    echo "  Batocera: /userdata/roms/dos/  (name <=8 chars, with dosbox.bat; don't copy GOG's .conf)"
  else
    echo "  here:     install the scummvm package"
    echo "  Batocera: /userdata/roms/scummvm/"
  fi
  echo
  echo "No autorun.cmd written - it would be useless. See the README."
  exit 0
fi

if [ -z "$exe" ] || [ ! -e "$target/$exe" ]; then
  die "could not find the game executable in $target"
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
      name=${candidate##*/}
      wrappers="${wrappers:+$wrappers,}${name%.dll}" ;;
  esac
done

{
  [ -n "$wrappers" ] && printf 'ENV=WINEDLLOVERRIDES="%s=n,b"\n' "$wrappers"
  printf 'CMD=%s\n' "$exe"
} > "$target/autorun.cmd"
cp "$(dirname "$(readlink -f "$0")")/play.sh" "$target/"
echo "done: $target (CMD=$exe)"
[ -n "$wrappers" ] && echo "note: bundled wrappers given priority over wine's own: $wrappers"
if [ -f "$target/gog-registry.reg" ]; then
  echo "note: gog-registry.reg written; play.sh applies it when it creates the prefix"
fi
if [ -n "$others" ]; then
  echo "other entries in goggame-*.info: ${others//;/, }"
  echo "  if the game won't start, try one of those in autorun.cmd"
fi

# Ren'Py and friends: the Windows installer usually carries the Linux build too.
# Same rule as play.sh (the two copies are deliberate, see the note there).
if compgen -G "$target/lib/*linux*" >/dev/null; then
  for candidate in "$target"/*.sh; do
    native=${candidate##*/}
    [ "$native" = play.sh ] && continue
    # a Windows installer does not carry the execute bit
    chmod +x "$candidate" "$target"/lib/*linux*/* 2>/dev/null || true
    echo "note: native Linux build here -> ./$(basename "$target")/$native (no wine)"
    break
  done
fi

# A .desktop entry is all KDE, GNOME and XFCE need; no per-desktop code.
if [ "$desktop" = ask ] && [ -t 0 ]; then
  printf 'Add "%s" to the desktop games menu? [y/N] ' "$name"
  read -r answer
  case "$answer" in [yYsS]*) desktop=yes ;; *) desktop=no ;; esac
fi

if [ "$desktop" = yes ]; then
  apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  mkdir -p "$apps"
  entry="$apps/gog-$(basename "${target%.pc}").desktop"
  # a .ico holds every size; desktops tend to grab the first (16x16), so pull
  # out the biggest one. GOG stores them PNG-compressed, so it is a plain cut.
  icon=$(python3 - "$target" <<'PYICON'
import glob, os, struct, sys

target = sys.argv[1]
found = glob.glob(os.path.join(target, 'goggame-*.ico'))
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
    echo "Exec=$target/play.sh"
    echo "Path=$target"
    [ -n "$icon" ] && echo "Icon=$icon"
    echo "Categories=Game;"
    echo "Terminal=false"
  } > "$entry"
  chmod +x "$entry"
  command -v update-desktop-database >/dev/null && update-desktop-database "$apps" 2>/dev/null
  echo "menu entry: $entry"
fi
