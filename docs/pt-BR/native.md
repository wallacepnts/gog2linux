# Motor nativo

## Jogo antigo: DOSBox e ScummVM

Clássico da GOG quase sempre é um DOSBox 0.74 (de 2010) embrulhado. Passar isso
por wine é rodar um emulador dentro de um tradutor de API — o `build.sh` detecta
e recusa. Pra saber antes mesmo de extrair:

```bash
innoextract -l "setup_jogo.exe" | grep -iE 'dosbox|scummvm'
```

Os `.conf` que a GOG já traz são bons e poupam trabalho:

```bash
sudo apt install dosbox-staging   # no openSUSE o pacote `dosbox` já é 0.82 (staging)
cd Jogo.pc && dosbox -conf dosbox_jogo.conf -conf dosbox_jogo_single.conf
```

Antes de tudo isso, porém: veja se existe **source port** (OpenMW, DevilutionX,
VCMI, OpenRA, GZDoom, OpenTTD, Arx Libertatis, CorsixTH...). O PCGamingWiki lista
por jogo. Port nativo > DOSBox > wine.

### Ren'Py: o build Linux vem junto

Visual novel Ren'Py (e alguns jogos com Java/Löve) empacota todas as plataformas
no mesmo instalador. Depois do `build.sh`, se aparecer

```
note: native Linux build here -> ./Jogo.pc/Jogo.sh (no wine)
```

use esse `.sh` no desktop — é o jogo rodando nativo, sem tradução de API. O
`build.sh` já acerta o bit de execução, que o instalador Windows não carrega.

O `autorun.cmd` continua sendo gerado do mesmo jeito: ele é o registro do que o
jogo precisa, e serve de recuo se o build nativo não servir.

## Quando existe motor nativo

Alguns clássicos tiveram o motor reimplementado — código aberto, nativo, tela
cheia de verdade, controles modernos. Isso ganha do wine sempre, então o
`build.sh` avisa ao terminar de empacotar:

```
obs: Nox tem motor reimplementado (OpenNox) - nativo, melhor que wine: flathub io.github.noxworld_dev.OpenNox
```

Ele só avisa. Instalar o port, e manter ou não a cópia para wine, é decisão sua.
A lista completa, separada por gênero e com o link de cada projeto, está em
**[ENGINES.md](../ENGINES.md)** — cerca de sessenta jogos.

A ordem importa no casamento: DOOM 3 recebe o dhewm3, não o GZDoom que atende o
resto da família. O casamento é pelo nome do jogo, então uma coletânea da GOG ou
uma edição com título diferente pode escapar. Vale olhar a lista antes de
empacotar qualquer coisa dos anos noventa.

Se instalar, ponha um `launch.sh` na pasta `.pc` e a entrada de menu passa a
apontar pra ele em vez do `play.sh`:

```bash
#!/usr/bin/env bash
exec flatpak run io.github.noxworld_dev.OpenNox "-data=$(dirname "$(readlink -f "$0")")" -fullscreen "$@"
```

Apagando o arquivo, o caminho do wine volta.
