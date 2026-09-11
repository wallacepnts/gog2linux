# Troubleshooting

## When the game won't start

| Symptom | Likely cause | Way out |
|---|---|---|
| `innoextract` complains about the Inno version | installer too new | update innoextract, or install with `wine setup.exe /VERYSILENT /DIR=$PWD/Game.pc` and delete the `unins*` files |
| opens and closes immediately | 32-bit running as 64 | `WINEARCH=win32 ./Game.pc/play.sh` (delete `.prefix` first) |
| a Microsoft `.dll` is missing | game expects an installed runtime | `WINEPREFIX=$PWD/Game.pc/.prefix winetricks vcrun2019` (or whatever it wants) |
| cutscene plays black, sound and timing fine | Unity hands the decoded frame over through `dxgi`, which wine leaves stubbed | DXVK in the prefix (just below) |
| the game demands a real install (registry, DirectX) | it isn't portable | install it under wine and package the folder afterwards |
| a 32-bit game dies the moment it plays a sound | the 32-bit gstreamer plugins are missing | `gstreamer-plugins-{libav,good,ugly}-32bit` — the 32-bit core loads happily and decodes nothing |

At the end of every packaging run `build.sh` says what **this system** still
lacks for **that game** — DXVK, the LÖVE engine, the 32-bit plugins, wine itself
— by package name. Finding that out from a crash dump costs an evening.

### If you are on wine, without umu

Almost everything above only happens on the fallback to the distro's wine:
Proton brings DXVK, VKD3D and the codecs already assembled, and `play.sh` leaves
the prefix alone.

Without umu, for the black cutscene `build.sh` writes
`ENV=WINEDLLOVERRIDES="d3d11,dxgi=n,b"` into `autorun.cmd` and `play.sh` wires
the system DXVK into the prefix. That needs the distro package (`dxvk`), and it
is worth checking what its `setup_dxvk.sh` did — openSUSE's hands **32-bit**
DLLs to a 64-bit prefix, and wine falls back to its own without a word:

```bash
file -L .prefix/drive_c/windows/system32/d3d11.dll   # has to say x86-64
```

A `.webm` cutscene is VP8, which Unity decodes by itself: none of this applies.

## What the GOG installer would have done

Packaging skips the installer, so everything it would have written is missing:
install paths in the registry, CD-key locations, DirectPlay entries. Games
notice. Doom 3 asks for a key it already ships; Warcraft II says the game is
not installed.

`build.sh` reads `goggame-*.script` — GOG's own install recipe — and turns its
registry actions into `gog-registry.reg` inside the `.pc` folder. `play.sh`
applies that the first time it creates a prefix, resolving the install path to
wherever the folder happens to sit.

Two details it gets right that a hand-written `.reg` usually doesn't: actions
tagged for a language this copy doesn't ship are skipped (otherwise Doom 3
turns Italian), and `HKLM\Software` keys are written to `WOW6432Node` as well,
because a 32-bit game in a 64-bit prefix reads them from there.
