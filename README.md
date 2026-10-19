## GearX 🏎️

Corrida pseudo-3D no estilo do Top Gear (Super Nintendo) para o console **Lupi**: de 1 a 3 jogadores em tela dividida, 5 pistas pelo litoral, do amanhecer à noite de lua cheia, com música própria, nitro e pilotos controlados pelo computador.

- **6 carros** com jeitos diferentes de dirigir (velocidade, aceleração e curvas).
- **Nitro**: começa com 3; latas de nitro aparecem na pista só na frente de quem está atrás (quem lidera não pega).
- **Curvas**: a velocidade cai nas curvas, e numa curva forte e longa, a toda, o carro é jogado para fora da pista.
- **Dano**: batidas diminuem a velocidade máxima e a aceleração (barra DANO no painel).

Comece pelo arquivo `game.lua`, função `update`. A estrada é desenhada em `render.lua`; as pistas ficam em `pistas.lua` e os carros em `carros.lua`. Na pasta `img` estão os gráficos no formato entendido pelo compilador da plataforma, e em `music` a música.

> Documentação do Lupi: <https://lupi.api.br/docs>. Este repositório é um fork do [primeiro-jogo](https://github.com/lupi-org-br/primeiro-jogo).

## Como jogar

| Controle | Na corrida | Nos menus |
|---|---|---|
| Direcional | Virar | Escolher e mudar opções |
| Botão de baixo (B) | Acelerar | Confirmar |
| Botão da direita (A) | Frear | Voltar |
| Outros botões (X, Y, L, R) | Nitro | |

## Créditos

Ideia, arte e direção: Felipe. Música original composta em código (`ferramentas/compor_musica.py`, fora deste repositório).
