# Empacotando

## Regra universal: qualquer jogo GOG em 2 passos

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

# 2. jogar
~/Jogos/"Grim Dawn.pc"/play.sh
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

1. **A pergunta de idioma só aparece quando ela decide algo.** Quase todo
   instalador GOG oferece uma lista, mas ela costuma ser a interface *dele* — o
   jogo traz todos os idiomas dentro e escolhe na hora de rodar. O `build.sh`
   compara o que sai com e sem filtro de idioma (é leitura de cabeçalho, custa
   milissegundos) e, se der no mesmo, extrai tudo sem perguntar. Quando os arquivos
   realmente mudam, aí ele lista e espera; Enter aceita inglês, e a escolha vale
   pras DLCs da mesma execução. Em script, `--lang it-IT` ou `--lang all`.

   A página da GOG pode anunciar quatro localizações e o instalador trazer uma:
   as outras são downloads separados, e vão na mesma pasta do jogo.
2. **A pasta é portátil, o `.prefix/` não.** Copiando o jogo para outra máquina,
   deixe o `.prefix/` para trás: ele pesa uns 400 MB e nasce de novo no primeiro
   boot, com o runtime de lá.
3. **Não guarde o jogo em NTFS.** Quebra o wine, principalmente jogos que
   passam por Steam ou Galaxy.

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

## O `autorun.cmd`

Lido pelo `play.sh`. Precisa de quebra de linha **LF**
(Unix), não CRLF — CRLF é a causa nº 1 de "não abre".

```
CMD=jogo.exe                      # obrigatório; entre aspas se tiver espaço
DIR=64bit/bin                     # opcional; o CMD é relativo a ele
ENV=WINEDLLOVERRIDES="d3d11=n"    # opcional, repetível
SCREEN=native                     # opcional, só o play.sh lê
LANG=pt_BR.UTF-8                  # opcional
```

Argumentos vão junto do `CMD`: `CMD="Meu Jogo.exe" --fullscreen`

O `DIR=` sai do `workingDir` do `goggame-*.info`, quando a GOG informa um e o
executável mora lá dentro. Jogo que carrega as DLLs por caminho relativo — um
`Launcher64.exe` dentro de `x64/`, por exemplo — sai calado se rodar da raiz.

O `SCREEN=native` o `build.sh` escreve sozinho em jogo Unity. Na hora de rodar,
o `play.sh` lê o modo preferido da tela em `/sys/class/drm/*/modes` — sem
`xrandr` — e acrescenta `-screen-width`,
`-screen-height` e `-screen-fullscreen 1`. Os números são da máquina que joga,
não da que empacotou. `GOG2LINUX_SCREEN=1280x720` fixa um tamanho, `=no` desliga.

## Build Linux da GOG

Muitos jogos da GOG têm versão Linux, baixada à parte do instalador Windows — um
`.sh` grande. Largue no `install/` como qualquer outro:

```bash
./build.sh
```

O `build.sh` reconhece o formato (um script MojoSetup com um zip colado no fim),
extrai o jogo de `data/noarch/`, acerta o bit de execução do binário e escreve um
`launch.sh`. O resultado é um pacote **nativo**: sem wine, sem Proton, sem
prefixo.

O nome sai do `gameinfo` que vem dentro, que é o mesmo que a GOG usa.

Vale sempre conferir se o jogo tem build Linux antes de empacotar a versão
Windows — ela costuma resolver de uma vez problemas que no wine custam horas.
Foi o caso do Owlboy aqui: a versão Windows não tocava a trilha sonora por um
defeito na reimplementação de áudio do wine, e a build Linux simplesmente
funciona.

## Trazendo um jogo instalado por outro app

Jogo instalado fora — por Lutris, Bottles, Faugus, ou uma sessão de wine na mão
— deixa o prefixo num lugar e os arquivos noutro. O `--prefix` junta os dois:

```bash
./build.sh --prefix ~/caminho/do/prefixo ~/caminho/do/jogo
```

Ele move o prefixo para dentro da pasta como `.prefix`, e daí faz a releitura de
sempre: acha o executável, detecta o motor, procura wrappers e escreve o
`autorun.cmd`. Depois disso o jogo roda como qualquer outro:

```bash
~/caminho/do/jogo/play.sh
```

Não precisa fixar runner: o `play.sh` procura o umu sozinho.

Com o prefixo dentro da pasta, o `.pc` fica autossuficiente — o `saves.sh` e o
`uninstall.sh` o enxergam, e a pasta viaja inteira. Em troca, **a entrada do
outro app aponta para o caminho antigo e para de funcionar**; copie o prefixo
antes se quiser manter as duas.

O `--prefix` recusa pasta que não tenha `drive_c`, para você não mover a coisa
errada por engano.

## Repack (FitGirl e semelhantes)

Um repack não se extrai: o jogo mora em arquivos FreeArc ao lado do instalador
(`fg-*.bin`, `*.arc`), e só ele sabe abri-los. Dentro do `.exe` estão apenas os
descompressores. O `build.sh` reconhece isso antes de extrair e para.

Instale-o com a ferramenta que preferir e traga a pasta com o `--prefix` acima.
Duas escolhas na hora de instalar, cada uma já custou horas aqui:

- **Use a interface do instalador.** `/VERYSILENT` não serve: a descompressão é
  disparada por um formulário próprio do repack, e em modo silencioso ele
  termina com código 0 sem gravar um byte.
- **Marque o limite de memória**, se houver. Os repacks da FitGirl têm uma caixa
  *"Limit installer to 2 GB of RAM usage"* na primeira tela. Instala mais devagar
  e não estoura o espaço de endereçamento do instalador, que é de 32 bits.

Chamar o `umu-run` direto no `setup.exe` costuma falhar em mapear a unidade do
jogo (`unable to use parent for game drive`), e o erro que aparece é o genérico
do Unarc — *"Unable to write data to disk"* —, que manda procurar no lugar
errado. As interfaces que empacotam o umu definem essa variável e não sofrem
disso.

Um aviso: repack não tem `goggame-*.info`, então não há metadados da GOG para
guiar — nome, `workingDir` e tarefas saem do que houver na pasta.
