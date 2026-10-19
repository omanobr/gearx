# GearX: guia do projeto

Jogo de corrida pseudo-3D estilo Top Gear (SNES) para o console **Lupi** (480x270, Lua 5.4, paleta única de 256 cores), de 1 a 3 jogadores em tela dividida. O dono do projeto é iniciante em desenvolvimento de jogos: explique as mudanças em português simples.

Referência da API do Lupi e diferenças do simulador: @AGENTS.md

## Comandos

- `python ferramentas/servidor.py` (ou `INICIAR.bat`): constrói, serve o simulador em http://localhost:8000 e reconstrói quando um arquivo do jogo é salvo. A página recarrega o jogo sozinha.
- `python ferramentas/construir.py`: só constrói (`build/jogo/` descompactado + `build/gearx.lupi`). Sai com erro se a paleta passar de 256 cores.
- `python ferramentas/preparar_arte.py` (ou `PREPARAR_ARTE.bat`): regenera `img/{fundos,carros,titulo}` e `dados_arte.lua` a partir de `arte-original/`. Prévia em `build/previa_arte.png`.
- Dependência: Python 3 + Pillow. O simulador (`ferramentas/simulador/game.js|wasm`) é o Lupinho compilado (MIT) e não precisa de Emscripten.

## Estrutura

- A **raiz** do repositório é o cartucho-fonte, no mesmo formato dos jogos oficiais (Lua + PNG + `lupi.yaml` na raiz, como `lupi-org-br/balao-gatinho`).
  - `game.lua`: entrada; troca de telas com `Jogo.ir(nome, ...)`; `DEV` vem de `dev_config.lua` (só existe no simulador).
  - `config.lua` (constantes), `pistas.lua` (trechos e objetos de cada pista), `estrada.lua` (monta segmentos),
    `corrida.lua` (física, IA, colisões, voltas, ranking), `render.lua` (pseudo-3D), `objetos.lua` (beira da estrada),
    `hud.lua`, `texto.lua` (fonte grande própria + `ui.print`), `entrada.lua`, `cores.lua`, `telas/*.lua`,
    `demo.lua` (corrida automática de fundo do título/menu/resultado; `Demo.parar()` ao entrar numa corrida).
- `ferramentas/`, `build/` e `arte-original/` ficam fora do cartucho (`FORA_DO_CARTUCHO` em `construir.py`).
- Arquivos **gerados** (não editar à mão): `img/fundos|carros/*`, `img/cores.png`, `dados_arte.lua`, `build/*`.
- `ferramentas/construir.py` replica o `lupi-codec` oficial (validado: saída idêntica pixel a pixel e mesma paleta).

## Regras

- **Cores**: sempre `Palette.hex(0xRRGGBB)` (alias local `hex`) com o literal de 6 dígitos dentro de `hex(...)`. O `construir.py` procura esses literais para montar `img/cores.png`, e é assim que a cor entra na paleta oficial. Nunca use índices fixos: a ordem da paleta muda a cada build e no servidor oficial.
- **Limites do aparelho** (fonte oficial: https://github.com/lupi-org-br/lupinho/issues/12, resumo em AGENTS.md):
  - cada imagem linear até **46059 bytes** (largura x altura): a esteira online recusa a build acima disso (`LIMITE_BYTES_IMAGEM` em `construir.py`, que também falha). Panorâmicas são cortadas em pedaços de até `46059 // ALTURA_FUNDO` px. Nada de imagens de tela inteira.
  - por quadro: até **150 KB** de imagens lidas do SD, até **32** cargas de sprite, drawlist até **18 KB** (comandos além disso são ignorados) e **~50-60 mil instruções Lua** (watchdog fecha o jogo se travar). O simulador não aplica esses limites: `medidor.lua` (opção "desempenho" do Modo de teste) conta instruções (`debug.sethook`), bytes de drawlist e cargas/KB de imagem por quadro e mostra média/pico. Medido em out/2026, picos: 1P 38k instr/10 KB/10 cargas/94 KB; 2P 47k/12 KB/18/110 KB; 3P 52-55k/15-16 KB/26/101 KB (pista 5 à noite é a mais pesada). Meça de novo depois de mexer em render, objetos, HUD ou `C.DISTANCIA`.
- Paleta total hoje: ~229 de 256 (arte ~176). `preparar_arte.py` usa `MANTER_CORES = True`: a arte regenerada só usa cores que já estão em `img/`, porque a paleta do servidor só acumula. Se estourar, baixe `CORES_FUNDOS`/`CORES_CARROS` em `preparar_arte.py` ou reaproveite cores.
- Lua 5.4: sem recursos exclusivos do 5.5. Nada de alocar tabelas por quadro no caminho quente (`render.lua` usa buffers pré-alocados). O console é um ESP32-S3 a 240 MHz e o desempenho real ainda não foi medido. `C.DISTANCIA` controla o custo.
- Texto pequeno (`ui.print`) é só ASCII: use `T.p*`, que remove acentos. A fonte grande `T.grande*` aceita acentos e º.
- Use os nomes dos botões (`BTN_Z`...), nunca os números. `sfx`/`ui.stat` podem não existir: proteja com `if`.
- Imagens: até 512x512, alfa só 0 ou 255. Evite preto puro (vira transparente) e a cor (66,66,66) no pixel (0,0), que o codec trata como sprite sheet.

## GitHub (publicação)

- Repositório: https://github.com/omanobr/gearx (público), fork de `lupi-org-br/primeiro-jogo`, como os jogos da game jam do Lupi. `ENVIAR_GITHUB.bat` constrói, faz commit e push.
- A plataforma roda o `lupi-codec` sobre **todo** o repositório: todo `.png` entra na paleta (sem filtro de tamanho, antes de validar) e todo `.lua` vai para o cartucho; o resto é ignorado. Nunca versione PNG fora de `img/` nem `.lua` em `ferramentas/`. `arte-original/` está no `.gitignore` por isso.
- A paleta do servidor (`master_palette.json`) só acumula cores entre versões. Evite trocar muito as cores da arte depois de publicada.
- O `palette.lua` oficial não define `Palette.hex` (só o nosso local define); no aparelho ele vem do sistema, como no `primeiro-jogo`. Se as cores saírem erradas no console, comece por aí.

## Como o render funciona

Segmentos de `C.SEG` unidades. Cada visão projeta `v.dist` segmentos a partir da câmera (`carro.z - C.JOGADOR_Z`), desenha a estrada de perto para longe guardando `maxy` (o que fica abaixo está atrás de um morro), corta trapézios parcialmente escondidos e depois desenha objetos e carros de longe para perto com `ui.clip` na altura guardada de cada segmento. Os carros usam sprites pré-reduzidos em 17 níveis (`reto1..17`, fator 0,85); as vistas `esq/dir` existem só nas cores de jogador e só nos níveis do próprio carro (1 em 1P/2P/demo, 5 em 3P; `NIVEIS_COM_CURVA` em `preparar_arte.py`). O panorama desliza com a curva (`carro.fundo_x`), limitado à largura da imagem.

Economias para caber nos limites do aparelho: `R.fundos` desenha o céu e o panorama de **todas** as visões antes das estradas, pedaço por pedaço (cada imagem é lida do SD uma vez por quadro); cada ponto da pista é projetado uma vez (a borda de longe de um segmento é a de perto do seguinte, `PX1[n+1]`); segmentos vizinhos da mesma cor viram um trapézio só até `JUNTAR_PX` de altura; faixas finas viram `ui.line`; objetos têm versão simplificada abaixo de 14 px (`objetos.lua`); `ui.clip` dos objetos só é usado quando a base está atrás de um morro; a fonte grande junta traços repetidos em retângulos.

## Testar

Use o painel "Modo de teste" da página ou a URL, por exemplo:
`http://localhost:8000/?direto=1&jogadores=3&pista=5&voltas=1&auto1=1&auto2=1&auto3=1&desempenho=1`
(`captura=1&zoom=2` esconde a interface para prints). Erros de Lua aparecem numa caixa vermelha na página.
