# Jogando

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

Jogo nativo costuma gravar **fora** da pasta do jogo, e isso também entra no
backup, voltando ao lugar certo no `restore`:

- **Steam rip com Goldberg** — se houver um `local_save.txt`, ele nomeia uma
  pasta dentro do jogo (que raramente se chama "save", então só esse arquivo a
  encontra). Sem ele, os saves vão para
  `~/.local/share/Goldberg SteamEmu Saves/<AppID>/`, e o AppID sai do
  `steam_appid.txt` que vem junto.
- **Ren'Py** — `~/.renpy/<Nome>/`, numa pasta com o nome que o jogo usa, não o
  nosso. O `saves.sh` descobre qual é pelo launcher que o jogo traz.

Enquanto estiver aí: no Goldberg, `settings/language.txt` define o idioma e
`settings/account_name.txt` o nome do jogador. Um Steam rip com `activated.ini`
usa `Language` e `UserName` para o mesmo fim.

O `uninstall.sh` faz o backup antes de apagar qualquer coisa, e com `-y` faz sem
perguntar. O jogo você recupera do instalador; o save, não.

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

## A máquina não dorme durante o jogo

Por padrão o `play.sh` roda o jogo dentro de um `systemd-inhibit --what=idle`.
Jogo no wine não mexe no protetor de tela nem fala o protocolo de ociosidade,
então sem isso o contador do desktop continua correndo e a máquina entra em
espera no meio da partida. A trava dura só enquanto o jogo roda.

Jogo nativo recebe a mesma trava. O SDL se anuncia sozinho — um jogo Unity
registra "Playing a game" assim que abre a janela —, mas **o Ren'Py não registra
nada**, e de fora não há como saber qual motor está na pasta. Numa visual novel,
onde se passa minutos lendo sem tocar no teclado, é exatamente onde a tela
apagaria. Onde o SDL já trava, a segunda trava não custa nada.

Para desligar: `GOG2LINUX_INHIBIT=no`. Sem systemd, não há o que travar.
