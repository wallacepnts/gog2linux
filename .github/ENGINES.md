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

`build.sh` recognises every game named below and prints a note when it packages
one — a test keeps the script and this page from drifting apart. Both were
generated from the same list, so the tables are the script's own knowledge
written out.

The source is the [Emulation General Wiki][egw], which covers consoles and
handhelds too; this page keeps the PC entries a GOG library can actually use.
Two flags carry over from there: *work in progress* means playable but rough or
incomplete, and *dormant* means it works yet nobody maintains it.

[egw]: https://emulation.gametechwiki.com/index.php/Game_engine_recreations_and_source_ports

---

## Shooters

| Game | Engine | Project |
|---|---|---|
| Aliens Versus Predator Gold | NakedAVP | <https://github.com/nitramtaz/NakedAVP> |
| Blake Stone | BStone | <https://github.com/bibendovsky/bstone> |
| Blood | NBlood | <https://github.com/nukeykt/NBlood> |
| DOOM 3 | dhewm3 | <https://dhewm3.org> |
| Descent 1 and 2 | DXX-Rebirth | <https://dxx-rebirth.com> |
| Deus Ex | Surreal 98 *(work in progress)* | <https://github.com/HKRepublic/Deus-Ex-Surreal-98> |
| Doom 64 | Doom64 EX Plus | <https://github.com/atsb/Doom64EX-Plus> |
| Doom, Doom II, Final Doom, Heretic, Strife | GZDoom | <https://zdoom.org> |
| Duke Nukem 3D | EDuke32 | <https://eduke32.com> |
| Half-Life and GoldSrc games | Xash3D FWGS | <https://github.com/FWGS/xash3d-fwgs> |
| Hexen | GZDoom | <https://zdoom.org> |
| Hexen II | Hammer of Thyrion | <https://sourceforge.net/projects/uhexen2> |
| Jedi Knight: Dark Forces II | OpenJKDF2 | <https://github.com/shinyquagsire23/OpenJKDF2> |
| Jedi Outcast, Jedi Academy | OpenJK | <https://github.com/JACoders/OpenJK> |
| Marathon trilogy | Aleph One | <https://alephone.lhowon.org> |
| Medal of Honor: Allied Assault | OpenMoHAA | <https://github.com/openmoh/openmohaa> |
| Quake | vkQuake | <https://github.com/Novum/vkQuake> |
| Quake II | Yamagi Quake II | <https://www.yamagi.org/quake2> |
| Quake III Arena | ioquake3 | <https://ioquake3.org> |
| Redneck Rampage, Powerslave, TekWar, Witchaven, NAM | Raze | <https://raze.zdoom.org> |
| Return to Castle Wolfenstein | iortcw | <https://github.com/iortcw/iortcw> |
| Rise of the Triad: Dark War | rottexpr | <https://github.com/fabiangreffrath/rottexpr> |
| S.T.A.L.K.E.R. series | OpenXRay | <https://github.com/OpenXRay/xray-16> |
| Serious Sam: The First and Second Encounter | Serious Sam Classic VK | <https://github.com/tx00100xt/SeriousSamClassic-VK> |
| Shadow Warrior | VoidSW | <https://voidsw.com> |
| Star Wars: Dark Forces | The Force Engine | <https://theforceengine.github.io> |
| System Shock | Shockolate | <https://github.com/Interrupt/systemshock> |
| System Shock 2 | openDarkEngine *(work in progress)* | <https://github.com/volca02/openDarkEngine> |
| Unreal Gold, Unreal Tournament 99 | Surreal Engine *(work in progress)* | <https://github.com/dpjudas/SurrealEngine> |
| Wolfenstein 3D, Spear of Destiny | ECWolf | <https://maniacsvault.net/ecwolf> |
| Wolfenstein: Enemy Territory | ET: Legacy | <https://www.etlegacy.com> |

## Role-playing

| Game | Engine | Project |
|---|---|---|
| Albion | M-HT SR | <https://github.com/M-HT/SR> |
| Ambermoon | Ambermoon.net | <https://github.com/Pyrdacor/Ambermoon.net> |
| Arcanum | Arcanum CE *(work in progress)* | <https://github.com/alexbatalov/arcanum-ce> |
| Arx Fatalis | Arx Libertatis | <https://arx-libertatis.org> |
| Baldur's Gate, Planescape: Torment, Icewind Dale | GemRB | <https://gemrb.org> |
| Betrayal at Krondor | BaKGL *(dormant, but usable)* | <https://github.com/xavierpuigf/BaKGL> |
| Daggerfall | Daggerfall Unity | <https://www.dfworkshop.net> |
| Diablo | DevilutionX | <https://github.com/diasurgical/devilutionX> |
| Fallout | Fallout CE | <https://github.com/alexbatalov/fallout1-ce> |
| Fallout 2 | Fallout 2 CE | <https://github.com/alexbatalov/fallout2-ce> |
| Gothic II | OpenGothic | <https://github.com/Try/OpenGothic> |
| Knights of the Old Republic 1 and 2 | reone *(work in progress)* | <https://github.com/seedhartha/reone> |
| Might and Magic VII | OpenEnroth *(work in progress)* | <https://github.com/OpenEnroth/OpenEnroth> |
| Morrowind | OpenMW | <https://openmw.org> |
| Neverwinter Nights, The Witcher | xoreos *(work in progress)* | <https://xoreos.org> |
| The Elder Scrolls: Arena | OpenTESArena *(work in progress)* | <https://github.com/afritz1/OpenTESArena> |
| Ultima Underworld 1 and 2 | UnderworldGodot *(work in progress)* | <https://github.com/hankmorgan/UnderworldGodot> |
| Ultima VII | Exult | <https://exult.info> |
| Ultima VIII | Pentagram *(work in progress)* | <https://pentagram.sourceforge.net> |

## Strategy and simulation

| Game | Engine | Project |
|---|---|---|
| Age of Empires I and II | openage *(work in progress)* | <https://openage.dev> |
| Black & White | Openblack *(work in progress)* | <https://github.com/openblack/openblack> |
| C&C: Tiberian Sun, Generals | OpenSAGE *(work in progress)* | <https://opensage.github.io> |
| Caesar III | Augustus | <https://github.com/Keriew/augustus> |
| Chris Sawyer's Locomotion | OpenLoco | <https://github.com/OpenLoco/OpenLoco> |
| Civilization: Call to Power II | civctp2 | <https://github.com/civctp2/civctp2> |
| Colonization | FreeCol | <https://www.freecol.org> |
| Command & Conquer, Red Alert, Dune 2000 | OpenRA | <https://www.openra.net> |
| Dune II | Dune Legacy | <https://dunelegacy.sourceforge.net> |
| Dungeon Keeper | KeeperFX | <https://keeperfx.net> |
| Dungeon Keeper 2 | OpenKeeper *(work in progress)* | <https://github.com/tonihele/OpenKeeper> |
| Heroes of Might and Magic II | fheroes2 | <https://github.com/ihhub/fheroes2> |
| Heroes of Might and Magic III | VCMI | <https://vcmi.eu> |
| Homeworld | Homeworld SDL *(dormant, but usable)* | <https://github.com/HomeworldSDL/HomeworldSDL> |
| Jagged Alliance 2 | JA2-Stracciatella | <https://ja2-stracciatella.github.io> |
| Knights and Merchants | KaM Remake | <https://www.kamremake.com> |
| Master of Orion | 1oom | <https://gitlab.com/KilgoreTroutMaskReplicant/1oom> |
| Pharaoh | Akhenaten | <https://github.com/dalerank/Akhenaten> |
| RollerCoaster Tycoon 2 | OpenRCT2 | <https://openrct2.io> |
| Sid Meier's Alpha Centauri | GLSMAC *(work in progress)* | <https://github.com/afwbkbc/glsmac> |
| SimCity (1989) | Micropolis | <https://github.com/SimHacker/micropolis> |
| StarCraft | Stargus *(work in progress)* | <https://github.com/Wargus/stargus> |
| Syndicate | FreeSynd *(dormant, but usable)* | <https://freesynd.sourceforge.io> |
| Syndicate Wars | Syndicate Wars Port | <https://github.com/swaledge/swars> |
| Terminal Velocity, Fury3 | terminal-recall | <https://github.com/jtrfp/terminal-recall> |
| The Settlers | Freeserf.net *(work in progress)* | <https://github.com/Pyrdacor/freeserf.net> |
| The Settlers II | Return to the Roots | <https://www.siedler25.org> |
| Theme Hospital | CorsixTH | <https://corsixth.com> |
| Total Annihilation | TA3D *(work in progress)* | <https://github.com/TA3D/TA3D> |
| Transport Tycoon Deluxe | OpenTTD | <https://www.openttd.org> |
| Warcraft II | Wargus | <https://wargus.github.io> |
| Warcraft III | WarsmashModEngine *(work in progress)* | <https://github.com/Retera/WarsmashModEngine> |
| Warcraft: Orcs & Humans | War1gus | <https://github.com/Wargus/war1gus> |
| X-COM: Apocalypse | OpenApoc *(work in progress)* | <https://github.com/OpenApoc/OpenApoc> |
| X-COM: UFO Defense, Terror from the Deep | OpenXcom | <https://openxcom.org> |
| Zeus: Master of Olympus | eZeus *(work in progress)* | <https://github.com/mortylab/ezeus> |

## Action and adventure

| Game | Engine | Project |
|---|---|---|
| Abuse | Abuse 2025 | <https://github.com/Xenoveritas/abuse> |
| Alone in the Dark 1-3 | Free In The Dark *(work in progress)* | <https://github.com/OpenFITD/freeInTheDark> |
| Another World | rawgl | <https://github.com/cyxx/rawgl> |
| Cave Story | NXEngine-evo | <https://github.com/nxengine/nxengine-evo> |
| Commander Keen, Cosmo's Cosmic Adventure | Commander Genius | <https://github.com/gerstrong/Commander-Genius> |
| Drakan: Order of the Flame | OpenDrakan *(work in progress)* | <https://github.com/Zenol/OpenDrakan> |
| Flashback | REminiscence | <https://github.com/cyxx/reminiscence> |
| Future Cop: LAPD | Future Cop: MIT *(work in progress)* | <https://github.com/BastianInsideYou/FutureCopMIT> |
| Jazz Jackrabbit | OpenJazz | <https://github.com/AlisterT/openjazz> |
| Jazz Jackrabbit 2 | Jazz2 Resurrection | <https://github.com/deathkiller/jazz2-native> |
| Lemmings | Lemmini *(dormant, but usable)* | <https://github.com/Java-Lemmini/lemmini> |
| Little Big Adventure | TwinE | <https://github.com/mgerhardy/vengi-twinengine> |
| Magic Carpet 2 | remc2 *(work in progress)* | <https://github.com/AlexRiedel/remc2> |
| Nox | OpenNox | <https://flathub.org/apps/io.github.noxworld_dev.OpenNox> |
| Oddworld: Abe's Oddysee and Exoddus | R.E.L.I.V.E. | <https://github.com/AliveTeam/alive_reversing> |
| Prince of Persia | SDLPoP | <https://github.com/NagyD/SDLPoP> |
| Rick Dangerous | xrick | <https://github.com/oco2000/xrick> |
| The Elder Scrolls Adventures: Redguard | Redguard Unity *(work in progress)* | <https://github.com/hazelnutcloud/redguard-unity> |
| Tomb Raider 1 and 2 | TRX | <https://github.com/LostArtefacts/TRX> |
| Tyrian | OpenTyrian | <https://github.com/opentyrian/opentyrian> |

## Racing

| Game | Engine | Project |
|---|---|---|
| Carmageddon | Dethrace | <https://github.com/dethrace-labs/dethrace> |
| Death Rally | DRally *(work in progress)* | <https://github.com/tapio/drally> |
| Driver 2 | REDriver2 | <https://github.com/OpenDriver2/REDRIVER2> |
| Midtown Madness | Open1560 | <https://github.com/0x1F9F1/Open1560> |
| Need for Speed I-III, High Stakes, Porsche | OpenNFS *(work in progress)* | <https://github.com/OpenNFS/OpenNFS> |
| Re-Volt | RVGL | <https://rvgl.re-volt.io> |
| Star Wars Episode I Racer | OpenSWE1R *(work in progress)* | <https://github.com/OpenSWE1R/openswe1r> |
| Stunt Car Racer | stuntcarremake | <https://github.com/ptitSeb/stuntcarremake> |
| Wipeout | Wipeout Rewrite | <https://github.com/phoboslab/wipeout-rewrite> |
## Whole catalogues, not single games

| Games | Engine | Project |
|---|---|---|
| LucasArts, Sierra, Revolution and ~300 more adventures | ScummVM | <https://www.scummvm.org> |
| Grim Fandango, Myst III, The Longest Journey | ScummVM | <https://www.scummvm.org> |
| Infocom text adventures | Frotz, Gargoyle | <https://ccxvii.net/gargoyle> |

`build.sh` already detects ScummVM games from the installer and tells you to use
the `scummvm` system rather than wine — the same holds on the desktop. That
detection reads the files, not the title, which is why this last section is the
only one `build.sh` does not match by name.

---

## Where the answer is a remaster, not a port

For a few classics the practical route is buying the official re-release rather
than running an engine over your GOG copy. They are listed here so the absence
from the tables above is not read as an oversight — none of them uses your
original files.

| Classic | Official re-release | Open alternative |
|---|---|---|
| Diablo II | Diablo II: Resurrected | OpenDiablo2, Riiablo — both unfinished |
| Warcraft III | Warcraft III: Reforged | WarsmashModEngine, work in progress |
| StarCraft | StarCraft: Remastered | Stargus, partially playable |
| Age of Empires I and II | Definitive Editions | openage, work in progress |
| Baldur's Gate, Planescape, Icewind Dale | Enhanced Editions | GemRB, which also runs the originals |
| System Shock | System Shock (2023 remake) | Shockolate, which runs the original |
| Homeworld | Homeworld Remastered | Homeworld SDL, from the released source |
| Carmageddon | Carmageddon: Max Damage | Dethrace, which runs the original |
| Quake, Doom | Remastered editions on modern stores | GZDoom, vkQuake — usually better |

The last row is the pattern worth noticing: for id Software games the community
engines beat the official re-releases, because the source has been open for
decades. For Blizzard and Relic titles the opposite holds, since no source was
ever released and the recreations are still years from complete.

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
