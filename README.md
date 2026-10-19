# GearX: corrida estilo Top Gear para o Lupi

Jogo de corrida pseudo-3D para o console **Lupi**, inspirado no Top Gear do Super Nintendo, para **1 a 3 jogadores** com tela dividida.

Comece pelo arquivo `game.lua`, função `update`. Na pasta `img` estão os gráficos no formato entendido pelo compilador da plataforma.

> Documentação do Lupi: <https://lupi.api.br/docs>. Este repositório é um fork do [primeiro-jogo](https://github.com/lupi-org-br/primeiro-jogo), o jogo base da equipe do Lupi.

---

## 1. Como testar (o dia a dia)

1. Dê **dois cliques em `INICIAR.bat`**.
2. O navegador abre o **simulador do Lupi** em `http://localhost:8000`.
3. Edite qualquer arquivo `.lua` do jogo e **salve**. O jogo recarrega sozinho em 1 ou 2 segundos.
4. Para parar, feche a janela preta (ou aperte `Ctrl+C` nela).

**Teclado no simulador:**

| Tecla | Botão do Lupi | No jogo |
|---|---|---|
| `W` `A` `S` `D` | Direcional | `A`/`D` vira, `W` também acelera, `S` também freia |
| `K` | Z | Acelerar / confirmar |
| `J` | X | Frear / voltar |
| `L` `M` `G` `H` | Q, E, F, G | Nitro |

> No simulador, o teclado aperta os botões de **todos os jogadores ao mesmo tempo**. Para testar 2 ou 3 pessoas de verdade, ligue controles USB/Bluetooth no PC (1º controle = J1, 2º = J2...). Outra opção é deixar o computador pilotar J2 e J3 no painel **"Modo de teste"** da página.

**Painel "Modo de teste"** (lado direito da página): pula direto para a corrida, escolhe a pista e o número de jogadores, liga o piloto automático e mede os **limites do aparelho** (instruções Lua, lista de desenho e imagens lidas por quadro), mostrando média, pico e limite de cada um (verde: folgado; amarelo: perto; vermelho: passou). Essas opções só existem no simulador; não vão para o console.

**Erros:** se o código Lua tiver um erro, ele aparece numa **caixa vermelha** acima da tela do jogo, com o arquivo e a linha.

---

## 2. As pastas

O jogo fica na **pasta principal**, igual aos jogos oficiais do Lupi (como o [balao-gatinho](https://github.com/lupi-org-br/balao-gatinho)). A plataforma do Lupi lê tudo o que é `.lua` e `.png` e ignora o resto (`.md`, `.bat`, `.py`...).

```
gearx/
├── lupi.yaml              ← nome e versão do jogo
├── game.lua               ← ponto de partida (o Lupi chama update() 60x por segundo)
├── config.lua             ← números do jogo: velocidade, curvas, nitro...
├── pistas.lua             ← as 5 pistas (fácil de editar!)
├── cores.lua              ← cores usadas pelo código
├── corrida.lua            ← regras: física, pilotos do computador, voltas, classificação
├── render.lua             ← desenho da estrada 3D, fundo, carros
├── objetos.lua            ← palmeiras, postes, placas...
├── hud.lua                ← painel: posição, volta, velocidade, nitro
├── texto.lua              ← letras grandes e pequenas
├── entrada.lua            ← controles
├── estrada.lua            ← transforma a pista em segmentos
├── telas/                 ← título, menu, corrida, resultado
├── demo.lua               ← corrida de demonstração que roda atrás do título, menu e resultado
├── img/                   ← imagens já convertidas (GERADAS, não edite à mão)
├── dados_arte.lua         ← informações das imagens (GERADO)
│
├── INICIAR.bat            ← abre o simulador (use sempre)
├── ENVIAR_GITHUB.bat      ← envia a versão atual para o GitHub
├── PREPARAR_ARTE.bat      ← reprocessa as imagens de arte-original/
├── ferramentas/           ← programas de apoio (simulador, construção, arte)
├── arte-original/         ← SUAS imagens grandes (só no seu PC, não vão para o GitHub)
└── build/                 ← saída: gearx.lupi (o "cartucho") e prévias (não vai para o GitHub)
```

---

## 3. Como o Lupi funciona (o essencial)

- A tela tem **480 x 270 pixels**.
- O jogo é escrito em **Lua**. O console chama a função `update()` **60 vezes por segundo**; nela você lê os controles e desenha tudo de novo.
- Cores: o jogo inteiro tem **uma paleta de no máximo 256 cores**. Todas as imagens e o código dividem essas cores. Por isso a ferramenta `preparar_arte.py` reduz as cores das suas imagens.
- Imagens: no máximo **512 x 512** pixels cada.
- **Limites do aparelho:** cada imagem pode ter no máximo **46 mil pixels** (largura x altura; 1 byte por pixel). A construção avisa se alguma passar, e as panorâmicas são cortadas em pedaços que cabem. Por isso o título não tem mais uma imagem de tela inteira (130 mil pixels): ele mostra uma corrida de demonstração. A lista oficial de limites (imagens por quadro, instruções Lua por quadro, lista de desenho) está na [issue #12 do Lupinho](https://github.com/lupi-org-br/lupinho/issues/12).
- Documentação oficial: <https://lupi.api.br/docs/>. Os jogos de exemplo da equipe estão em <https://github.com/lupi-org-br>.

---

## 4. Receitas: como mudar coisas

**Deixar o carro mais rápido ou as curvas mais difíceis:** em `config.lua`, mude `C.VEL_MAX`, `C.ACEL` ou `C.CENTRIFUGA` (curvas empurram mais).

**Editar ou criar uma pista:** em `pistas.lua`. Cada pista é uma lista de trechos:
```lua
reta(100)            -- reta de 100 segmentos
curva(80, 4)         -- curva média para a DIREITA
curva(80, -6)        -- curva fechada para a ESQUERDA
reta(120, 40)        -- reta subindo um morro
curva(100, 3, -20)   -- curva descendo
```
Para uma pista nova, copie um bloco `{ nome = ..., fundo = ..., trechos = {...}, ... }` inteiro e mude.

**Mudar uma cor:** em `cores.lua` ou nas `cores` de cada pista. Escreva a cor em hexadecimal, como no Photoshop/GIMP, dentro de `hex(0xRRGGBB)`. A construção coloca a cor nova na paleta sozinha (pela amostra `img/cores.png`).

**Trocar ou adicionar arte:** coloque a imagem em `arte-original/`, ajuste a lista no começo de `ferramentas/preparar_arte.py` (por exemplo, `FUNDOS`) e dê dois cliques em `PREPARAR_ARTE.bat`. Confira o resultado em `build/previa_arte.png`. Por padrão (`MANTER_CORES = True`) a arte nova reaproveita as cores já publicadas, para a paleta do servidor não crescer. A altura das panorâmicas (`ALTURA_FUNDO`, hoje 110) define em quantos pedaços cada uma é cortada.

**O fundo nas curvas:** a panorâmica começa centralizada e desliza para o lado nas curvas, até a borda da imagem. Nas retas ela volta devagar ao centro. A velocidade disso fica em `C.FUNDO_VEL` e `C.FUNDO_VOLTA` (`config.lua`).

---

## 5. Enviar para o GitHub e para o console

- Para mandar uma versão nova, dê **dois cliques em `ENVIAR_GITHUB.bat`**. Ele constrói o jogo (e para se houver erro), guarda as mudanças e envia para o GitHub.
- A plataforma do Lupi converte as imagens com o `lupi-codec` oficial. Eu testei: ele gera, a partir destes arquivos, os mesmos sprites (pixel a pixel) e a mesma paleta que a nossa ferramenta.
- O cartucho pronto também fica em **`build/gearx.lupi`** (dá para baixar pelo link na página do simulador).

**Cuidados com a paleta no servidor:**
- O `lupi-codec` junta as cores de **todos** os PNGs do repositório. Por isso `arte-original/` (milhares de cores) fica de fora do GitHub (veja `.gitignore`). Não coloque PNGs grandes em outras pastas.
- A paleta do servidor **acumula** cores entre versões: uma cor que sai do jogo continua ocupando lugar. Evite reprocessar a arte com cores muito diferentes muitas vezes, senão o total pode passar de 256.

---

## 6. Avisos importantes

- **Desempenho no console real:** o simulador roda no PC, que é muito mais rápido que o Lupi (um ESP32-S3 a 240 MHz). Ainda não sabemos se o modo de 3 jogadores roda a 60 quadros por segundo no aparelho. Se ficar lento, o primeiro ajuste é diminuir `C.DISTANCIA` em `config.lua` (quantos segmentos de estrada são desenhados à frente).
- **Som:** ainda não tem. O simulador atual não implementa `sfx`, então o som só daria para testar no aparelho.
- **Cores RGB x BGR:** a documentação fala em RGB555, mas o simulador e o `lupi-codec` oficial usam BGR555 (vermelho e azul trocados). O jogo nunca escreve números de cor direto: usa sempre `Palette.hex(...)`, que funciona nos dois casos.

---

## 7. Ideias para as próximas versões

- Escolha de carro com atributos diferentes (velocidade, aceleração, aderência).
- Sons e música (motor, batida, nitro, largada).
- Combustível e pit stop, como no Top Gear.
- Campeonato com pontos somados entre as pistas.
- Chuva, neblina e corridas noturnas com faróis.
- Mini-mapa da pista.
- Placas e prédios usando sprites desenhados (hoje são formas geométricas).

---

## Créditos

Ideia, arte e direção: Felipe. Simulador em `ferramentas/simulador/`: [Lupinho](https://github.com/lupi-org-br/lupinho) (MIT).
