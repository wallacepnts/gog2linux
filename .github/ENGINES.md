# Native engines for GOG classics

*As tabelas são neutras de idioma; a introdução está em inglês, como o resto do
repositório. Veja o [README em português](README.pt-BR.md).*

Many classics have had their engine rewritten or their source released. Where
that happened, the result beats wine on every count: native binary, real
fullscreen at any resolution, modern controllers, savegames that survive, and
no 400 MB prefix.

The rule this project follows: **native engine > DOSBox or ScummVM > wine**.

You still need to own the game — none of these ship assets. Package the GOG
installer with `build.sh` as usual, then point the engine at the `.pc` folder
instead of running `play.sh`. Drop a `launch.sh` in that folder and the desktop
entry follows it automatically; see the README.

`build.sh` recognises a subset of this list and prints a note when it does. The
tables below are the fuller reference. A far larger catalogue, covering consoles
too, lives at the [Emulation General Wiki][egw] — worth checking for anything
missing here.

[egw]: https://emulation.gametechwiki.com/index.php/Game_engine_recreations_and_source_ports

---

## Shooters

| Game | Engine | Project |
|---|---|---|
| Blood | NBlood | <https://github.com/nukeykt/NBlood> |
| Descent 1 and 2 | DXX-Rebirth | <https://dxx-rebirth.com> |
| DOOM 3 | dhewm3 | <https://dhewm3.org> |
| Doom, Doom II, Final Doom, Heretic, Hexen, Strife | GZDoom | <https://zdoom.org> |
| Doom (vanilla-accurate) | Chocolate Doom | <https://www.chocolate-doom.org> |
| Duke Nukem 3D | EDuke32 | <https://eduke32.com> |
| Half-Life | Xash3D FWGS | <https://github.com/FWGS/xash3d-fwgs> |
| Hexen II | Hammer of Thyrion | <https://sourceforge.net/projects/uhexen2> |
| Jedi Knight: Dark Forces II | OpenJKDF2 | <https://github.com/shinyquagsire23/OpenJKDF2> |
| Jedi Outcast, Jedi Academy | OpenJK | <https://github.com/JACoders/OpenJK> |
| Marathon | Aleph One | <https://alephone.lhowon.org> |
| Quake | vkQuake | <https://github.com/Novum/vkQuake> |
| Quake II | Yamagi Quake II | <https://www.yamagi.org/quake2> |
| Quake III Arena | ioquake3 | <https://ioquake3.org> |
| Return to Castle Wolfenstein | iortcw | <https://github.com/iortcw/iortcw> |
| Shadow Warrior, Redneck Rampage | Raze | <https://raze.zdoom.org> |
| Star Wars: Dark Forces | The Force Engine | <https://theforceengine.github.io> |
| System Shock | Shockolate | <https://github.com/Interrupt/systemshock> |
| Wolfenstein 3D, Spear of Destiny | ECWolf | <https://maniacsvault.net/ecwolf> |
| Wolfenstein: Enemy Territory | ET: Legacy | <https://www.etlegacy.com> |

## Role-playing

| Game | Engine | Project |
|---|---|---|
| Arx Fatalis | Arx Libertatis | <https://arx-libertatis.org> |
| Baldur's Gate, Planescape: Torment, Icewind Dale | GemRB | <https://gemrb.org> |
| Diablo | DevilutionX | <https://github.com/diasurgical/devilutionX> |
| Fallout 1 and 2 | Fallout Community Edition | <https://github.com/alexbatalov/fallout2-ce> |
| Might and Magic VI, VII, VIII | OpenEnroth | <https://github.com/OpenEnroth/OpenEnroth> |
| Morrowind | OpenMW | <https://openmw.org> |
| The Elder Scrolls II: Daggerfall | Daggerfall Unity | <https://www.dfworkshop.net> |
| Ultima VII | Exult | <https://exult.info> |
| Ultima VIII | Pentagram | <https://pentagram.sourceforge.net> |

## Strategy and simulation

| Game | Engine | Project |
|---|---|---|
| Caesar III | Augustus | <https://github.com/Keriew/augustus> |
| Colonization | FreeCol | <https://www.freecol.org> |
| Command & Conquer, Red Alert, Dune 2000, Tiberian Sun | OpenRA | <https://www.openra.net> |
| Dune II | Dune Legacy | <https://dunelegacy.sourceforge.net> |
| Dungeon Keeper | KeeperFX | <https://keeperfx.net> |
| Heroes of Might and Magic II | fheroes2 | <https://github.com/ihhub/fheroes2> |
| Heroes of Might and Magic III | VCMI | <https://vcmi.eu> |
| Jagged Alliance 2 | ja2-stracciatella | <https://github.com/ja2-stracciatella/ja2-stracciatella> |
| Master of Orion 2 | 1oom | <https://gitlab.com/KilgoreTroutMaskReplicant/1oom> |
| Pharaoh | Ozymandias | <https://github.com/Keriew/ozymandias> |
| Syndicate | FreeSynd | <https://freesynd.sourceforge.io> |
| The Settlers II | Return to the Roots | <https://www.siedler25.org> |
| Theme Hospital | CorsixTH | <https://corsixth.com> |
| Transport Tycoon Deluxe | OpenTTD | <https://www.openttd.org> |
| Warcraft II | Wargus | <https://wargus.github.io> |
| StarCraft | Stargus | <https://github.com/Wargus/stargus> |
| X-COM: UFO Defense, Terror from the Deep | OpenXcom | <https://openxcom.org> |

## Adventure and action

| Game | Engine | Project |
|---|---|---|
| Another World | rawgl | <https://github.com/cyxx/rawgl> |
| Commander Keen | Commander Genius | <https://github.com/gerstrong/Commander-Genius> |
| Flashback | REminiscence | <https://github.com/cyxx/reminiscence> |
| Freespace 2 | FreeSpace Open | <https://fsnebula.org> |
| Little Big Adventure | TwinE | <https://github.com/mgerhardy/vengi-twinengine> |
| Nox | OpenNox | <https://flathub.org/apps/io.github.noxworld_dev.OpenNox> |
| Prince of Persia | SDLPoP | <https://github.com/NagyD/SDLPoP> |
| Star Control 2 | The Ur-Quan Masters | <https://sc2.sourceforge.net> |
| Tomb Raider | TR1X | <https://github.com/LostArtefacts/TRX> |
| Tomb Raider (alternative) | OpenLara | <https://github.com/XProger/OpenLara> |

## Whole catalogues, not single games

| Games | Engine | Project |
|---|---|---|
| LucasArts, Sierra, Revolution and ~300 more adventures | ScummVM | <https://www.scummvm.org> |
| Grim Fandango, Myst III, The Longest Journey | ScummVM | <https://www.scummvm.org> |
| Infocom text adventures | Frotz, Gargoyle | <https://ccxvii.net/gargoyle> |

`build.sh` already detects ScummVM games from the installer and tells you to use
the `scummvm` system rather than wine — the same holds on the desktop.

---

## Caveats

**The engine is not the game.** Every project here needs the original data
files, which is exactly what the `.pc` folder holds. Nothing is pirated by
installing them.

**Recreations drift from the original.** OpenMW and VCMI change balance and fix
bugs the original had; purists sometimes prefer the wine route. Source ports
built from released code — dhewm3, ioquake3, ECWolf — stay far closer.

**Not everything on this list is finished.** OpenEnroth and Stargus are works in
progress. Check the project's own status before deleting the wine copy.

**Names are not reliable keys.** GOG bundles and re-releases carry titles that
do not match, so `build.sh` will miss some. This page is the manual check.
