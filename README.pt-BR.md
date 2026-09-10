# Jogos GOG para Batocera e para qualquer distro Linux

*[English documentation](README.md)*

Um instalador GOG vira **uma pasta `.pc`** que roda nos dois lugares sem
modificação: o Batocera lê o `autorun.cmd`, as outras distros usam o `play.sh`.

O truque é não gerar prefixo wine na hora de empacotar. Cada sistema cria o
dele no primeiro boot, com o wine que tem. Prefixo empacotado = prefixo colado
na distro onde foi feito.

---

## Instalando numa distro nova

| Distro | Comando |
|---|---|
| Ubuntu / Mint / Debian | `sudo apt install innoextract wine` |
| Fedora | `sudo dnf install innoextract wine` |
| Arch / Manjaro | `sudo pacman -S innoextract wine` |
| openSUSE | `sudo zypper in innoextract wine` |
| **Batocera** | **nada** — o Wine-GE já vem embutido |

- `innoextract` e `python3` — só pra **empacotar** (desmontam o InnoSetup e leem os metadados da GOG; nada de Windows roda).
- `wine` — só pra **jogar**. Quem só copia a pasta pro Batocera não precisa dele.

Extras conforme o caso: `squashfs-tools` (abrir `.wsquashfs`), `winetricks`
(jogos que pedem DLL da Microsoft).

---

## Regra universal: qualquer jogo GOG em 3 passos

**Tudo que estiver em `install/` é um jogo.** Uma pasta por jogo, com as DLCs
numa `dlc/` dentro dela — ou o instalador solto, quando não há DLC:

```
install/
├── setup_stardew_valley_1.6.15_(70330).exe      <- solto: um jogo sem DLC
└── grimdawn/                                    <- pasta: o jogo e o que vem com ele
    ├── setup_grim_dawn_1.2.1.5_(51951).exe
    ├── setup_grim_dawn_1.2.1.5_(51951)-1.bin
    ├── setup_grim_dawn_1.2.1.5_(51951)-2.bin
    └── dlc/
        ├── setup_grim_dawn_ashes_of_malmouth_(51951).exe
        └── setup_grim_dawn_forgotten_gods_(51951).exe
```

Largue os `.bin` junto do `.exe` e esqueça deles: o innoextract junta as partes
sozinho. O nome da subpasta das DLCs não importa — `dlc/`, `DLC/` como a GOG
entrega, ou qualquer outro: o que estiver numa subpasta entra como DLC.

```bash
# 1. empacotar tudo que estiver em install/
./build.sh

# 2. testar na sua distro
~/Jogos/"Grim Dawn.pc"/play.sh

# 3. levar pro Batocera
cp -r ~/Jogos/"Grim Dawn.pc" /userdata/roms/windows/
```

Ele lista o que achou e deixa escolher:

```
install/: 3 jogo(s) encontrado(s)
instalando em: /home/voce/Jogos
   1) Grim Dawn                              grimdawn
   2) Stardew Valley                         setup_stardew_valley_1.6.15_(70330).exe
   3) jogo-antigo
Instalar quais? [Enter = todos; ex: 1 3, ou 1-2]:
```

Enter leva tudo, `1 3` escolhe avulsos, `1-2` é faixa. Sem terminal, empacota
tudo sem perguntar.

O nome do `.pc` sai do cabeçalho do instalador, o mesmo que a GOG usa — a coluna
da direita mostra de onde veio, e sem cabeçalho legível vale o nome da pasta
(item 3). Os jogos vão pra `~/Jogos`, ou `~/Games` num sistema em inglês.

Um jogo por processo: instalador ruim custa o próprio jogo, não a leva. No fim
ele pergunta se pode apagar os instaladores **dos jogos que empacotou** — padrão
**não**, diga sim quando eles abrirem. Se algum falhar, nada é apagado.

Sozinho ele ainda mescla as DLCs na mesma pasta, joga fora o andaime do
instalador (`tmp/`, `__redist/`), lê o `goggame-*.info` pra achar o executável e
escreve o `autorun.cmd`. Se for DOSBox ou ScummVM disfarçado, para antes e diz
qual sistema usar.

**Regras que valem sempre:**

1. **Instalador multi-idioma pergunta, e assume inglês.** A GOG entrega um
   instalador só com todos os idiomas dentro, e extrair tudo faz o último vencer
   os metadados — é assim que um jogo em inglês termina em italiano. O
   `build.sh` lista e espera; Enter aceita inglês, e a escolha vale pras DLCs da
   mesma execução. Em script, `--lang it-IT` ou `--lang all`.

   A página da GOG pode anunciar quatro localizações e o instalador trazer uma:
   as outras são downloads separados, e vão na mesma pasta do jogo.
2. **Copie a pasta inteira** pro Batocera, sem o `.prefix/` (é o prefixo local,
   pesa uns 400 MB e o Batocera não usa).
3. **`/userdata/` em btrfs ou ext4.** NTFS quebra wine, principalmente jogos
   Steam/Galaxy.
4. **Nome da pasta = nome que aparece na lista** do EmulationStation.

---

## Jogo antigo: DOSBox e ScummVM

Clássico da GOG quase sempre é um DOSBox 0.74 (de 2010) embrulhado. Passar isso
por wine é rodar um emulador dentro de um tradutor de API — o `build.sh` detecta
e recusa. Pra saber antes mesmo de extrair:

```bash
innoextract -l "setup_jogo.exe" | grep -iE 'dosbox|scummvm'
```

Cuidado com a coincidência de nomes: **o sistema `dos` do Batocera também usa
pasta `.pc`**. O que muda é o conteúdo.

| | `roms/windows/Jogo.pc` | `roms/dos/JOGO.pc` |
|---|---|---|
| arquivo de controle | `autorun.cmd` | `dosbox.bat` |
| roda com | Wine-GE | DOSBox |

Duas regras do sistema `dos`: nome da pasta com **até 8 caracteres** sem acento,
e **não copie o `.conf` da GOG** pro Batocera (a wiki avisa que trava) — use só o
conteúdo do bloco `[autoexec]` como `dosbox.bat`:

```
c:
cd JOGO
JOGO.EXE
```

No desktop é o contrário: os `.conf` da GOG são bons e poupam trabalho.

```bash
sudo apt install dosbox-staging   # no openSUSE o pacote `dosbox` já é 0.82 (staging)
cd Jogo.pc && dosbox -conf dosbox_jogo.conf -conf dosbox_jogo_single.conf
```

Antes de tudo isso, porém: veja se existe **source port** (OpenMW, DevilutionX,
VCMI, OpenRA, GZDoom, OpenTTD, Arx Libertatis, CorsixTH...). O PCGamingWiki lista
por jogo, e o Batocera já traz vários prontos. Port nativo > DOSBox > wine.

### Ren'Py: o build Linux vem junto

Visual novel Ren'Py (e alguns jogos com Java/Löve) empacota todas as plataformas
no mesmo instalador. Depois do `build.sh`, se aparecer

```
note: native Linux build here -> ./Jogo.pc/Jogo.sh (no wine)
```

use esse `.sh` no desktop — é o jogo rodando nativo, sem tradução de API. O
`build.sh` já acerta o bit de execução, que o instalador Windows não carrega.

O `autorun.cmd` continua sendo gerado, porque no Batocera o caminho é o wine
mesmo (o sistema `windows` não roda binário Linux).

---

## Quando o jogo não abre

| Sintoma | Causa provável | Saída |
|---|---|---|
| `innoextract` reclama da versão do Inno | instalador novo demais | atualize o innoextract, ou instale com `wine setup.exe /VERYSILENT /DIR=$PWD/Jogo.pc` e apague os `unins*` |
| abre e fecha na hora | 32-bit rodando como 64 | `WINEARCH=win32 ./Jogo.pc/play.sh` (apague o `.prefix` antes) |
| falta `.dll` da Microsoft | jogo espera runtime instalado | `WINEPREFIX=$PWD/Jogo.pc/.prefix winetricks vcrun2019` (ou o que faltar) |
| tela preta / travando no Batocera | falta DXVK | ligue `windows.dxvk` nas opções avançadas do jogo — **só vale antes do 1º boot**, senão apague o prefixo em `/userdata/saves/windows/` |
| animação em tela preta, som e tempo certos | Unity entrega o quadro decodificado pelo `dxgi`, que o wine deixa como stub | DXVK no prefixo (logo abaixo) |
| jogo pede instalação de verdade (registro, DirectX) | não é portátil | instale num prefixo com wine e empacote como `.wtgz` (veja abaixo) |

Esse caso é automático. O `build.sh` reconhece jogo Unity (`UnityPlayer.dll`)
com animação em `.mp4` e escreve `ENV=WINEDLLOVERRIDES="d3d11,dxgi=n,b"` no
`autorun.cmd`; o `play.sh`, na primeira execução, liga o DXVK no prefixo se
achar ele instalado — procura em `/usr/libexec/dxvk/lib64`, `/usr/share/dxvk/x64`,
`/usr/lib/dxvk/x64` e `/opt/dxvk/x64`. Você só precisa do pacote:

```bash
sudo zypper in dxvk          # ou o equivalente na sua distro
```

Ele escolhe o diretório de 64 bits pelo nome de propósito: o `setup_dxvk.sh` que
vem no pacote entrega as DLLs de **32 bits** para um prefixo de 64, e o wine
então volta para o builtin sem dizer nada — a animação continua preta e nada no
log acusa. Se desconfiar, confira:

```bash
file -L .prefix/drive_c/windows/system32/d3d11.dll   # tem que dizer x86-64
```

Animação em `.webm` é VP8, que o Unity decodifica sozinho: nada disso se aplica.

---

## O `autorun.cmd`

Lido pelo Batocera **e** pelo `play.sh`. Precisa de quebra de linha **LF**
(Unix), não CRLF — CRLF é a causa nº 1 de "não abre".

```
CMD=jogo.exe                      # obrigatório; entre aspas se tiver espaço
DIR=64bit/bin                     # opcional; o CMD é relativo a ele
ENV=WINEDLLOVERRIDES="d3d11=n"    # opcional, repetível
SCREEN=native                     # opcional, só o play.sh lê
LANG=pt_BR.UTF-8                  # opcional
SAVEDIR=drive_c/users/...         # opcional, Batocera v42+
```

Argumentos vão junto do `CMD`: `CMD="Meu Jogo.exe" --fullscreen`

O `DIR=` sai do `workingDir` do `goggame-*.info`, quando a GOG informa um e o
executável mora lá dentro. Jogo que carrega as DLLs por caminho relativo — um
`Launcher64.exe` dentro de `x64/`, por exemplo — sai calado se rodar da raiz.

O `SCREEN=native` o `build.sh` escreve sozinho em jogo Unity. Na hora de rodar,
o `play.sh` lê o modo preferido da tela em `/sys/class/drm/*/modes` — sem
`xrandr`, então o Batocera também tem — e acrescenta `-screen-width`,
`-screen-height` e `-screen-fullscreen 1`. Os números são da máquina que joga,
não da que empacotou. `GOG2LINUX_SCREEN=1280x720` fixa um tamanho, `=no` desliga.

---

## Formato de arquivo único (opcional)

Só faz sentido pra jogo que **precisou** ser instalado com wine de verdade. Aí
o que se empacota é o prefixo inteiro:

```bash
tar czf Jogo.wtgz -C /caminho/do/prefixo .   # em qualquer distro
batocera-wine windows wine2winetgz Jogo.wine # ou, via SSH no Batocera
```

`./play.sh Jogo.wtgz` extrai pra `~/.local/share/wine-games/` e roda.
Também aceita `.wsquashfs` (precisa de `unsquashfs`).

Prefira **`.wtgz`**: é só um tar.gz, abre em qualquer lugar. Mas lembre que o
prefixo lá dentro carrega o wine de origem — pra distribuir, `.pc` continua
sendo melhor.

---

## O que o instalador da GOG faria

Empacotar pula o instalador, então tudo que ele escreveria fica faltando:
caminhos no registro, localização das chaves de CD, entradas de DirectPlay. Os
jogos percebem. O Doom 3 pede uma chave que já vem junto; o Warcraft II diz que
não está instalado.

O `build.sh` lê o `goggame-*.script` — a receita de instalação da própria GOG —
e converte as ações de registro num `gog-registry.reg` dentro da pasta `.pc`. O
`play.sh` aplica esse arquivo na primeira vez que cria um prefixo, resolvendo o
caminho de instalação pra onde quer que a pasta esteja.

Dois detalhes que um `.reg` escrito à mão costuma errar: ações marcadas para um
idioma que esta cópia não usa são descartadas (senão o Doom 3 vira italiano), e
chaves de `HKLM\Software` também vão para `WOW6432Node`, porque é de lá que um
jogo 32-bit num prefixo 64-bit lê.

No Batocera o `play.sh` não roda, então aplique uma vez por SSH:

```bash
WINEPREFIX=/userdata/saves/windows/Jogo wine regedit /S /userdata/roms/windows/Jogo.pc/gog-registry.reg
```

Troque o `%APP%` do arquivo pelo caminho do lado Windows antes — `Z:\userdata\roms\windows\Jogo.pc`.

---

## Idioma da própria ferramenta

Os scripts falam inglês ou português, conforme o `$LANG`:

```bash
GOG2LINUX_LANG=pt ./build.sh Jogo.pc "/caminho/setup.exe"   # força português
GOG2LINUX_LANG=en ./build.sh Jogo.pc "/caminho/setup.exe"   # força inglês
```

Os quatro scripts seguem: `build.sh`, `play.sh`, `saves.sh` e `uninstall.sh`. O
que não casar com `pt*` recebe inglês. Não há gettext nem arquivo `.po` — é um
bloco de variáveis de shell por script, escolhido uma vez na partida, para que
as cópias dentro de cada pasta de jogo continuem autossuficientes.

Repare que isto é o idioma das **mensagens**, não do jogo: aquele é o `--lang`,
e os dois são independentes.

---

## Colocando o jogo no menu do desktop

Ao terminar de empacotar, o `build.sh` oferece criar a entrada de menu:

```
Add "DOOM 3" to the desktop games menu? [y/N]
```

Responder não — que é o padrão, então Enter basta — não muda nada. Aceitando,
ele grava um `.desktop` padrão freedesktop em `~/.local/share/applications/`,
com o nome tirado dos metadados da GOG. É tudo que KDE, GNOME e XFCE precisam;
não há código específico por ambiente.

O ícone sai do `goggame-*.ico`, que embute todos os tamanhos, de 16×16 a
256×256. Os ambientes costumam pegar a primeira entrada e exibir um 16×16
borrado, então o `build.sh` recorta o maior pra `icon.png` e aponta a entrada
pra lá.

A pergunta só aparece em terminal. Em script, decida de antemão:

```bash
./build.sh --desktop    Jogo.pc "/caminho/setup.exe"    # cria sempre
./build.sh --no-desktop Jogo.pc "/caminho/setup.exe"    # nunca pergunta
```

Só o jogo ganha entrada. Pra remover existe o `uninstall.sh`, que fica na pasta
em vez de poluir o menu de jogos:

```bash
./Jogo.pc/uninstall.sh        # lista o que vai sair, depois pergunta
./Jogo.pc/uninstall.sh -y     # sem pergunta
```

Ele leva a pasta, o prefixo wine dentro dela e a entrada de menu. Saves que o
jogo gravou em outro lugar não são tocados.

A entrada aponta pra pasta `.pc` por caminho absoluto, então mover a pasta
quebra o atalho — rode `./build.sh --desktop Jogo.pc` do novo lugar pra
corrigir, ou apague `~/.local/share/applications/gog-<nome>.desktop`.

---

## Quando existe motor nativo

Alguns clássicos tiveram o motor reimplementado — código aberto, nativo, tela
cheia de verdade, controles modernos. Isso ganha do wine sempre, então o
`build.sh` avisa ao terminar de empacotar:

```
obs: Nox tem motor reimplementado (OpenNox) - nativo, melhor que wine: flathub io.github.noxworld_dev.OpenNox
```

Ele só avisa. Instalar o port, e manter ou não a cópia para wine, é decisão sua.
A lista completa, separada por gênero e com o link de cada projeto, está em
**[ENGINES.md](ENGINES.md)** — cerca de sessenta jogos.

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

---

## Backup dos jogos salvos

Jogo antigo guarda save ao lado de si; jogo moderno grava no perfil do wine. O
`saves.sh` cobre os dois:

```bash
./Jogo.pc/saves.sh                             # Jogo-saves-<data>.tar.gz, aqui
./Jogo.pc/saves.sh backup /backup/jogo.tar.gz
./Jogo.pc/saves.sh restore /backup/jogo.tar.gz
```

Ele empacota `.prefix/drive_c/users` — Documentos, Saved Games, AppData — mais
qualquer pasta `SAVE`, `Saves`, `savegames` ou `Profiles` dentro do jogo, e
mostra quais encontrou.

O `uninstall.sh` faz o backup antes de apagar qualquer coisa, e com `-y` faz sem
perguntar. O jogo você recupera do instalador; o save, não.

---

## Rodando o launcher ou as ferramentas que vêm junto

Jogo da GOG costuma trazer mais que o jogo: launcher, editor de mapas,
trocador de chave, configuração de DirectPlay. Passe o executável como segundo
argumento e ele roda no mesmo prefixo, sem tocar no `autorun.cmd`:

```bash
./Jogo.pc/play.sh . "Launcher.exe"
./Jogo.pc/play.sh . "Map Editor.exe"
```

O `build.sh` escolhe a entrada que a GOG marca como jogo — não o launcher que
ela marca como primário — e lista o que mais existe:

```
done: /caminho/Jogo.pc (CMD=Launcher.exe)
other entries in goggame-*.info: Jogo_dx.exe, Map Editor.exe
  if the game won't start, try one of those in autorun.cmd
```

Vale saber: a GOG normalmente marca o **launcher** como primário, e é por isso
que a entrada do jogo tem preferência — launcher precisa de mouse e muitas
vezes dispara uma build que o wine não roda. Títulos antigos trazem uma versão
clássica e uma DirectX, e com frequência só a segunda sobrevive ao wine.

---

## Outros jeitos de empacotar

O `install/` é o caminho padrão. Quando quiser escolher o nome do `.pc`, ou
empacotar algo que está fora da caixa, o alvo vai na linha de comando:

```bash
./build.sh grimdawn                                  # grimdawn/ -> grimdawn.pc
./build.sh Jogo.pc "/caminho/Jogo_(58051)_win_gog"   # pasta da GOG como veio
./build.sh Jogo.pc "/caminho/setup.exe" "/caminho/DLC/dlc.exe"
./build.sh Jogo.pc                                   # sem instalador: só relê
```

O último é o modo de conserto: refaz a detecção e o `autorun.cmd` sem extrair
nada. É o que usar depois de mexer na pasta na mão, ou pra criar a entrada de
menu de um jogo já pronto (`./build.sh --desktop Jogo.pc`).

Aqui os caminhos são digitados, então **ponha entre aspas** — nome da GOG-Games
quase sempre tem parêntese, e sem aspas o bash reclama de `erro de sintaxe`. O
`~` não expande dentro delas: deixe o til de fora, ou complete com **Tab**, que
o bash escapa sozinho. E nada de colchetes; na linha `uso:` eles só marcam o que
é opcional, e copiados junto viram parte do caminho.

As duas pontas do `install/` também se movem:

```bash
GOG2LINUX_INBOX=/mnt/hd/downloads ./build.sh    # de onde ler
GOG2LINUX_GAMES=/mnt/hd/jogos ./build.sh        # onde instalar
```

Vale quando a home é uma partição pequena: jogo GOG passa dos 20 GB fácil.

---

## Arquivos deste projeto

| | |
|---|---|
| `build.sh` | instalador GOG → pasta `.pc` |
| `install/` | caixa de entrada: o que estiver aqui é o que o `build.sh` empacota |
| `play.sh` | roda `.pc`, `.wine`, `.wtgz` ou `.wsquashfs` fora do Batocera |
| `uninstall.sh` | remove um jogo empacotado, seu prefixo e as entradas de menu |
| `saves.sh` | faz backup e restaura os saves, dos dois lugares onde eles ficam |
| `test.sh` | checagem dos dois (detecção, parser, CRLF, nativo, cache) |

O `play.sh` aceita um segundo argumento opcional que sobrescreve o `CMD`.

Variáveis que ele respeita: `WINE` (binário), `WINEPREFIX`, `WINEARCH`,
`FORCE_WINE=1` (ignora build nativo),
`WINE_GAMES` (onde extrair arquivo único),
`GOG2LINUX_INHIBIT=no` (deixa a máquina dormir durante o jogo).

Por padrão o `play.sh` roda o wine dentro de um `systemd-inhibit --what=idle`.
Jogo no wine não mexe no protetor de tela nem fala o protocolo de ociosidade,
então sem isso o contador do desktop continua correndo e a máquina entra em
espera no meio da partida. A trava dura só enquanto o jogo roda. Jogo nativo
passa pelo SDL, que já faz isso sozinho; sem systemd, como no Batocera, não há o
que travar.
