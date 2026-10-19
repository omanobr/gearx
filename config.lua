-- Ajustes gerais do jogo. Mude um numero, salve, e veja o efeito no simulador.
local C = {}

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

-- Quantos segmentos desenhar para frente, conforme o numero de jogadores.
-- Menos segmentos = jogo mais leve. O console executa ~50-60 mil instrucoes Lua por
-- quadro: confira com o medidor do simulador (Modo de teste > desempenho) ao mudar.
C.DISTANCIA = { 150, 100, 60 }

-- Fisica do carro (por segundo)
C.VEL_MAX = C.SEG * 60           -- velocidade maxima: 60 segmentos por segundo
C.ACEL = C.VEL_MAX / 5           -- acelerando
C.FREIO = C.VEL_MAX              -- freando
C.SOLTO = C.VEL_MAX / 5          -- sem acelerar nem frear
C.FORA_FREIO = C.VEL_MAX / 2     -- perda de velocidade fora da pista
C.FORA_LIMITE = C.VEL_MAX / 4    -- velocidade maxima fora da pista
C.CENTRIFUGA = 0.25              -- quanto as curvas "empurram" o carro para fora
C.KMH = 290                      -- velocidade maxima mostrada no painel

C.NITRO_QTD = 3                  -- nitros por corrida
C.NITRO_QUADROS = 180            -- duracao do nitro (60 quadros = 1 segundo)
C.NITRO_VEL = 1.3                -- nitro aumenta a velocidade maxima em 30%

C.CARRO_LARGURA = 360            -- largura do carro no mundo
C.CARRO_X = C.CARRO_LARGURA / C.ESTRADA   -- largura do carro em "unidades de pista"
C.CARRO_COMP = 300               -- comprimento do carro (para batidas)
C.TOTAL_CARROS = 8

-- Fundo (panorama): quanto ele desliza nas curvas e a velocidade de volta ao centro.
C.FUNDO_VEL = 0.7
C.FUNDO_VOLTA = 0.12

return C
