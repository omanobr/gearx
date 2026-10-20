-- Ajustes gerais do jogo. Mude um numero, salve, e veja o efeito no simulador.
local C = {}

C.VERSAO = "v0.98e"                -- aparece no titulo e no menu
C.LARGURA, C.ALTURA = 480, 270

-- Estrada (medidas no "mundo 3D", nao em pixels)
C.SEG = 200                      -- comprimento de cada pedaco (segmento) da pista
C.ESTRADA = 1100                 -- METADE da largura da estrada
C.FAIXAS = 3                     -- quantas faixas a estrada tem
C.ZEBRA = 3                      -- quantos segmentos cada listra da zebra ocupa
C.CAM_ALTURA = 1000              -- altura da camera
C.CAM_PROF = 1 / math.tan(math.rad(50))   -- campo de visao de 100 graus
C.JOGADOR_Z = C.CAM_ALTURA * C.CAM_PROF   -- distancia entre a camera e o carro
C.HORIZONTE = 0.45               -- altura do horizonte (fracao da altura da tela)

-- Como desenhar a estrada (render.lua): "linhas" = por linha da tela, com tabelas prontas,
-- como o Out Run e o Top Gear (v0.94; muito menos contas), com fatias em tiles; "linhas2" =
-- igual, com retangulos em faixas de 2 linhas (telas divididas: as folhas de tiles passariam
-- do limite de 32 imagens por quadro). Os jeitos antigos (cada segmento projetado em 3D):
-- "tiles" (v0.91), "retangulos" (v0.8). O teste de desempenho (menu) compara.
C.ESTRADA_DESENHO = "linhas"
C.ESTRADA_DIVIDIDA = "linhas2"

-- Mostra FPS e tempo de cada quadro no canto da tela e manda para o log do console
-- (cabo USB). Temporario, enquanto deixamos o jogo leve no aparelho.
C.DIAGNOSTICO = true

-- Paleta: a documentacao do Lupi manda registrar as cores (ui.palset) todo quadro. E
-- obrigatorio: na v0.97f (false: so ao trocar de tela e a cada PALETA_A_CADA quadros) o
-- console mostrou tudo preto menos a estrada (que tem cores proprias, enviadas todo quadro),
-- piscando a cada 5 s. O console zera a paleta a cada quadro. Deixe true.
C.PALETA_TODO_QUADRO = true
C.PALETA_A_CADA = 300

-- Quantos segmentos desenhar para frente, conforme o numero de jogadores, e ate quantos
-- segmentos aparecem os objetos da beira (palmeiras, postes...). Menos = jogo mais leve.
-- No aparelho o Lua faz so umas 20 mil instrucoes por quadro a 60 FPS (teste de desempenho
-- da v0.91): confira com o medidor do simulador (Modo de teste > desempenho) ao mudar.
-- (Os ultimos segmentos ficam a 1 ou 2 pixels do horizonte: 100 em vez de 150 quase nao muda a tela.)
C.DISTANCIA = { 70, 80, 40 }       -- 1 jogador: 100 ate a v0.97e, 80 na v0.97f, 70 na v0.97j
C.OBJETOS_DIST = { 50, 50, 30 }   -- v0.97c: 1 jogador de 70 para 50
-- Linhas duplas (v0.97h; o Felipe comparou no simulador e nao notou diferenca): na parte de
-- baixo da estrada (a partir desta fracao da altura, contando do horizonte) cada linha
-- calculada e desenhada duas vezes: metade das contas ali (~5% da corrida em 1 jogador); a
-- borda da pista fica em degraus de 2 pixels perto do carro. false desliga.
C.LINHAS_DUPLAS = true
C.LINHAS_DUPLAS_DESDE = 0.25   -- v0.97j: era 0.4

-- Fisica do carro (por segundo)
C.VEL_MAX = C.SEG * 60           -- velocidade maxima: 60 segmentos por segundo
C.ACEL = C.VEL_MAX / 5           -- acelerando
C.FREIO = C.VEL_MAX              -- freando
C.SOLTO = C.VEL_MAX / 5          -- sem acelerar nem frear
C.FORA_FREIO = C.VEL_MAX / 2     -- perda de velocidade fora da pista
C.FORA_LIMITE = C.VEL_MAX / 4    -- velocidade maxima fora da pista
C.CENTRIFUGA = 0.28              -- quanto as curvas "empurram" o carro para fora: em curva
                                 -- forte e longa, a toda, so virar nao segura (tem que aliviar)
C.CURVA_PERDA = 0.025            -- computador: em curva a velocidade maxima cai |curva| x isto
                                 -- (curva 4 = -10%). Os jogadores usam o arrasto do volante:
-- Arrasto do volante (so jogadores, ideia do Felipe): um medidor escondido enche enquanto o
-- jogador segura esquerda ou direita e esvazia aos poucos quando solta. Enquanto vira, a
-- velocidade maxima cai (mais quanto mais cheio o medidor) e a velocidade desce devagar ate
-- ela; ao soltar, o limite some e o carro volta a acelerar. v0.98c: o medidor ja comeca em
-- ARRASTO_INICIO (as curvas sao curtas: na v0.98b, com a aceleracao, demorava ~1 s para a
-- velocidade comecar a cair), com uma queda mais lenta. v0.98d: arrasto leve (ate 10%): ele
-- nao freia mais pelo jogador; nas curvas fortes (5 e 6) so virar nao segura o carro a toda
-- (CENTRIFUGA) e e preciso aliviar o acelerador, mais nos carros de pouca aderencia (Monza).
C.ARRASTO_INICIO = 0.3           -- ao comecar a virar, o medidor vai na hora para pelo menos isto
C.ARRASTO_ENCHE = 1.2            -- segundos segurando a curva para o medidor encher
C.ARRASTO_ESVAZIA = 1.0          -- segundos sem virar para ele esvaziar
C.ARRASTO_PERDA = 0.10           -- com o medidor cheio, a velocidade maxima cai 10% enquanto vira
C.ARRASTO_FREIO = C.VEL_MAX * 0.10   -- quanto a velocidade desce por segundo ate esse limite
C.KMH = 290                      -- velocidade maxima mostrada no painel

C.NITRO_QTD = 3                  -- nitros no comeco da corrida
C.NITRO_MAX = 5                  -- maximo de nitros guardados (pegando os da pista)
C.NITRO_QUADROS = 180            -- duracao do nitro (60 quadros = 1 segundo)
C.NITRO_VEL = 1.3                -- nitro aumenta a velocidade maxima em 30%

-- Nitros que aparecem na pista: so na frente de quem esta ATRAS (o lider nao pega todos)
C.ITEM_INTERVALO = 9 * 60        -- quadros entre um nitro e outro (em media)
C.ITEM_MAX = 3                   -- quantos podem estar na pista ao mesmo tempo
C.ITEM_DIST = { 90, 130 }        -- aparece entre 90 e 130 segmentos a frente (uns 2 s de antecedencia a toda)
C.ITEM_VIDA = 25 * 60            -- some depois de 25 segundos

-- Dano das batidas: diminui a velocidade maxima e a aceleracao (indicador no painel)
C.DANO_BATIDA = 0.08             -- batida na traseira de outro carro (a 100% da velocidade)
C.DANO_OBJETO = 0.12             -- batida em poste, arvore, placa...
C.DANO_VEL = 0.25                -- com dano total, a velocidade maxima cai 25%
C.DANO_ACEL = 0.40               -- e a aceleracao cai 40%

C.CARRO_LARGURA = 360            -- largura do carro no mundo
C.CARRO_X = C.CARRO_LARGURA / C.ESTRADA   -- largura do carro em "unidades de pista"
C.CARRO_COMP = 300               -- comprimento do carro (para batidas)
C.TOTAL_CARROS = 8

-- Fundo (panorama): quanto ele desliza nas curvas e a velocidade de volta ao centro.
C.FUNDO_VEL = 0.7
C.FUNDO_VOLTA = 0.12

return C
