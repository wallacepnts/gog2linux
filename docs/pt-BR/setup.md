# Instalação

## umu-launcher

O `play.sh` procura o umu e o usa por padrão. Ele executa o jogo com Proton
dentro do *pressure-vessel*, o contêiner que a Valve criou para rodar jogos —
DXVK, VKD3D e um FAudio compilado com FFmpeg já montados. É a diferença entre
um jogo que abre e um que mostra tela preta.

**O Steam não precisa estar instalado.** O contêiner é uma peça solta, e o
próprio umu o baixa (uns 660 MB em `~/.local/share/umu/steamrt4`), junto com o
Proton. Nada aqui abre o Steam nem pede conta.

O umu guarda o Proton em `~/.local/share/Steam/compatibilitytools.d/`. A pasta
tem "Steam" no nome por convenção — o umu a cria sozinho se não existir.

Sem root, e independente de distro:

```bash
curl -sSL -o /tmp/umu.tar \
  https://github.com/Open-Wine-Components/umu-launcher/releases/latest/download/umu-launcher-1.4.4-zipapp.tar
mkdir -p ~/.local/share/umu ~/.local/bin
tar xf /tmp/umu.tar -C ~/.local/share/umu --strip-components=1
ln -sfn ~/.local/share/umu/umu-run ~/.local/bin/umu-run
```

Confira o número na [página de releases](https://github.com/Open-Wine-Components/umu-launcher/releases);
Fedora e Debian têm pacote pronto, outras distros não.

Na primeira execução ele baixa o GE-Proton e o runtime: alguns minutos e alguns
GB, uma vez só.

### Escolher o Proton

**`PROTONPATH=GE-Proton` é nome, não caminho.** O umu baixa a versão mais recente
sozinho, e a mesma pasta `.pc` funciona numa máquina que nunca teve Proton.

Para usar outro, serve o nome de qualquer pasta em
`~/.local/share/Steam/compatibilitytools.d/`, ou um caminho completo:

```bash
ls ~/.local/share/Steam/compatibilitytools.d/   # o que existe nesta máquina
PROTONPATH="Proton-CachyOS Latest" ./play.sh    # só desta vez
```

Para fixar num jogo, ponha a escolha no `autorun.cmd` dele:

```
CMD=jogo.exe
ENV=PROTONPATH="Proton-CachyOS Latest"
```

**Aspas, se o nome tiver espaço.** Sem elas a linha vira `PROTONPATH=Proton-CachyOS`
e o umu vai procurar um Proton que não existe.

Trocar de Proton reaproveita o mesmo `.prefix`. Subir de versão costuma passar
liso; voltar para uma mais antiga é que às vezes deixa o prefixo inconsistente —
se o jogo parar de abrir depois da troca, apague o `.prefix` e deixe recriar.

### Correções por jogo

O protonfixes, que vem dentro do Proton-GE, guarda um ajuste por jogo — instalar
o `xact` para um cujo áudio precisa dele, forçar uma DLL, passar uma flag. Ele
escolhe qual aplicar pelo `GAMEID`.

O umu não descobre esse id sozinho: *"GAMEID is strictly required and the client
is responsible for setting this"*. O cliente aqui é o `build.sh`, que pega o id
GOG do `goggame-*.info`, procura na [base do
umu](https://github.com/Open-Wine-Components/umu-database) e grava a resposta no
`autorun.cmd` do jogo:

```
ENV=GAMEID=umu-61500
ENV=STORE=gog
```

`GAMEID` é o que o protonfixes casa; `STORE` diz em qual tabela dele procurar
(`gamefixes-gog/`, `gamefixes-steam/`). Os dois vêm da linha que casou.

A base é baixada uma vez por semana para `~/.cache/gog2linux/` — 90 KB — e a
busca funciona offline depois disso. Sem rede e sem cache o jogo é empacotado
do mesmo jeito; só fica sem o ajuste.

São dois casamentos, ambos exatos: primeiro o id GOG, depois o título. Nada de
aproximação — um ajuste mirado no jogo errado é pior que ajuste nenhum. A base
tem cerca de 200 jogos GOG, então **a maioria não vai casar, e isso é esperado**:
sem id, o umu usa `umu-default` e aplica só os ajustes globais.

Sem umu instalado, o `play.sh` cai no wine da distro. Funciona para a maioria dos
jogos, com menos garantia — e `GOG2LINUX_UMU=no` força isso de propósito.

**Não misture os dois no mesmo prefixo.** Apontar o wine da distro para um
prefixo criado pelo Proton dispara uma reconstrução demorada que troca arquivos.
Para comparar, use prefixos separados.

## O que mais precisa

| Distro | Comando |
|---|---|
| Ubuntu / Mint / Debian | `sudo apt install innoextract wine` |
| Fedora | `sudo dnf install innoextract wine` |
| Arch / Manjaro | `sudo pacman -S innoextract wine` |
| openSUSE | `sudo zypper in innoextract wine` |

- `innoextract` e `python3` — só pra **empacotar** (desmontam o InnoSetup e leem
  os metadados da GOG; nada de Windows roda).
- `wine` — o recuo quando não há umu, e ainda usado por alguns jogos.

Extras conforme o caso: `winetricks` (jogos que pedem DLL da Microsoft),
`squashfs-tools` (abrir `.wsquashfs`).

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
