# Problemas

## Quando o jogo não abre

| Sintoma | Causa provável | Saída |
|---|---|---|
| `innoextract` reclama da versão do Inno | instalador novo demais | atualize o innoextract, ou instale com `wine setup.exe /VERYSILENT /DIR=$PWD/Jogo.pc` e apague os `unins*` |
| abre e fecha na hora | 32-bit rodando como 64 | `WINEARCH=win32 ./Jogo.pc/play.sh` (apague o `.prefix` antes) |
| falta `.dll` da Microsoft | jogo espera runtime instalado | `WINEPREFIX=$PWD/Jogo.pc/.prefix winetricks vcrun2019` (ou o que faltar) |
| animação em tela preta, som e tempo certos | Unity entrega o quadro decodificado pelo `dxgi`, que o wine deixa como stub | DXVK no prefixo (logo abaixo) |
| jogo pede instalação de verdade (registro, DirectX) | não é portátil | instale sob wine e empacote a pasta depois |
| jogo de 32 bits fecha ao tocar som | faltam os plugins gstreamer de 32 bits | `gstreamer-plugins-{libav,good,ugly}-32bit` — o núcleo de 32 bits carrega sozinho e não decodifica nada |

No fim de cada empacotamento o `build.sh` diz o que **este sistema** ainda não
tem para **aquele jogo** — DXVK, o motor LÖVE, os plugins de 32 bits, o próprio
wine — com o nome dos pacotes. Descobrir isso por um dump de erro custa uma
noite.

### Se você estiver no wine, sem umu

Quase tudo acima só acontece no recuo ao wine da distro: o Proton traz DXVK,
VKD3D e os codecs já montados, e o `play.sh` nem mexe no prefixo.

Sem umu, para a animação preta o `build.sh` escreve
`ENV=WINEDLLOVERRIDES="d3d11,dxgi=n,b"` no `autorun.cmd` e o `play.sh` liga o
DXVK do sistema no prefixo. Aí é preciso o pacote da distro (`dxvk`), e vale
conferir o que o `setup_dxvk.sh` dele fez — o do openSUSE entrega DLLs de **32
bits** para um prefixo de 64, e o wine volta ao builtin sem dizer nada:

```bash
file -L .prefix/drive_c/windows/system32/d3d11.dll   # tem que dizer x86-64
```

Animação em `.webm` é VP8, que o Unity decodifica sozinho: nada disso se aplica.

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
