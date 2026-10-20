## GearX 🏎️

Corrida pseudo-3D no estilo do Top Gear (Super Nintendo) para o console **Lupi**: de 1 a 3 jogadores em tela dividida, com música própria, nitro, campeonato, recordes e pilotos controlados pelo computador.

- **4 pistas, da mais fácil para a mais difícil**, cada uma em 4 horários do dia (amanhecer, dia, pôr do sol e noite, com os postes acesos): Vale da Floresta (fácil), Orla da Cidade (médio), Dunas do Tigre (médio) e Castelo de Gelo (difícil, com neve escorregadia).
- **5 carros brasileiros** com jeitos diferentes de dirigir (velocidade, aceleração e curvas): Ka, Fusca, Gol bola, Monza e o **lendário Uno com escada**, o melhor em tudo. Cada jogador corre com o carro pintado na sua cor.
- **Campeonato**: as 4 pistas em sequência, horário sorteado em cada corrida, pontos por chegada (10-8-6-5-4-3-2-1) e o computador também pontua.
- **Recordes**: as 5 melhores voltas de cada pista e os 5 maiores campeonatos, com as iniciais de 3 letras, como nos fliperamas (ficam guardados enquanto o jogo está aberto).
- **Curvas**: segurar a direção por muito tempo faz o carro perder velocidade; nas curvas fortes, só virar não segura o carro a toda: é preciso aliviar o acelerador (mais nos carros de pouca aderência).
- **Nitro**: começa com 3; latas de nitro aparecem na pista só na frente de quem está atrás (quem lidera não pega).
- **Dano**: batidas diminuem a velocidade máxima e a aceleração (barra DANO no painel).

Comece pelo arquivo `game.lua`, função `update`. A estrada é desenhada em `render.lua`; as pistas ficam em `pistas.lua`, os carros em `carros.lua`, o campeonato em `campeonato.lua` e os recordes em `recordes.lua`. Na pasta `img` estão os gráficos no formato entendido pelo compilador da plataforma, e em `music` a música.

> Documentação do Lupi: <https://lupi.api.br/docs>. Este repositório é um fork do [primeiro-jogo](https://github.com/lupi-org-br/primeiro-jogo).

## Como jogar

| Controle | Na corrida | Nos menus |
|---|---|---|
| Direcional | Virar | Escolher e mudar opções |
| B | Acelerar | Confirmar |
| A | Frear | Voltar |
| X, Y ou R | Nitro | |
| START | Pausa (continuar, recomeçar ou sair) | |

## Créditos

Ideia, arte e direção: Felipe. Música original composta em código (`ferramentas/compor_musica.py`, fora deste repositório).
