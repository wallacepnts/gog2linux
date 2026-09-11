# Jogos GOG em qualquer distro Linux

*[English documentation](README.md)*

Um instalador GOG vira **uma pasta `.pc`** que roda em qualquer distro pelo
`play.sh`. Nada de prefixo wine empacotado: cada máquina cria o dela no primeiro
boot, com o runtime que tem.

## Instale o umu primeiro

Os jogos rodam pelo **umu-launcher**, que os executa com Proton dentro do
*pressure-vessel*, o contêiner da Valve — DXVK, VKD3D e FAudio com FFmpeg já
montados. O Steam não precisa estar instalado: o umu baixa o contêiner e o
Proton sozinho. Sem root:

```bash
curl -sSL -o /tmp/umu.tar \
  https://github.com/Open-Wine-Components/umu-launcher/releases/latest/download/umu-launcher-1.4.4-zipapp.tar
mkdir -p ~/.local/share/umu ~/.local/bin
tar xf /tmp/umu.tar -C ~/.local/share/umu --strip-components=1
ln -sfn ~/.local/share/umu/umu-run ~/.local/bin/umu-run
```

Mais o `innoextract` e o `python3` para empacotar. Detalhes em
**[Instalação](docs/pt-BR/setup.md)**.

## Dois passos

```bash
# 1. jogue os instaladores da GOG em install/ e rode
./build.sh

# 2. jogue
~/Jogos/"Nome do Jogo.pc"/play.sh
```

## Documentação

| | |
|---|---|
| **[Instalação](docs/pt-BR/setup.md)** | umu, pacotes da distro, escolha do runner |
| **[Empacotando](docs/pt-BR/packaging.md)** | a pasta `install/`, outros modos, o `autorun.cmd` |
| **[Jogando](docs/pt-BR/playing.md)** | menu do desktop, saves, launcher e ferramentas |
| **[Motor nativo](docs/pt-BR/native.md)** | DOSBox, ScummVM, builds Linux e source ports |
| **[Problemas](docs/pt-BR/troubleshooting.md)** | quando o jogo não abre, e o registro da GOG |
| **[ENGINES.md](docs/ENGINES.md)** | jogos com motor reimplementado |

## Arquivos deste projeto

| | |
|---|---|
| `build.sh` | instalador GOG → pasta `.pc` |
| `install/` | caixa de entrada: o que estiver aqui é o que o `build.sh` empacota |
| `play.sh` | roda uma pasta `.pc` ou `.wine`, ou um `.wtgz`/`.wsquashfs` |
| `uninstall.sh` | remove um jogo empacotado, seu prefixo e as entradas de menu |
| `saves.sh` | faz backup e restaura os saves, dos dois lugares onde eles ficam |
| `test.sh` | checagem dos dois (detecção, parser, CRLF, nativo, cache) |

O `play.sh` aceita um segundo argumento opcional que sobrescreve o `CMD`.

Variáveis que ele respeita: `WINE` (binário), `WINEPREFIX`, `WINEARCH`,
`FORCE_WINE=1` (ignora build nativo),
`WINE_GAMES` (onde extrair arquivo único),
`GOG2LINUX_INHIBIT=no` (deixa a máquina dormir durante o jogo),
`GOG2LINUX_UMU=no` (usa o wine da distro em vez do umu).
