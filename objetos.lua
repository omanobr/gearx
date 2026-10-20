-- Objetos da beira da estrada, desenhados com formas simples (retangulos e
-- triangulos). Por serem formas, eles crescem e diminuem com a distancia sem
-- precisar de imagens em varios tamanhos.
--
-- Medidas em unidades do mundo (a estrada tem 2200 de largura, o carro 360).
-- kx / ky = quantos pixels vale 1 unidade do mundo naquela distancia.
local C = require "config"
local Cores = require "cores"
local T = require "texto"
local Desenho = require "desenho"

local O = {}

-- enfeites: nas telas divididas so metade deles e desenhada (deixa o jogo mais leve)
O.enfeite = { palmeira = true, arbusto = true, pedra = true, pinheiro = true, pinheiro_neve = true, cacto = true }

-- largura de cada objeto para as batidas (em "unidades de pista"; nil = nao bate)
O.largura = { poste = 0.12, palmeira = 0.18, placa = 0.3, arbusto = 0.3, pedra = 0.35, pinheiro = 0.2,
              pinheiro_neve = 0.2, cacto = 0.15 }

local floor, max, min = math.floor, math.max, math.min

-- retangulo com pelo menos 1 pixel (// 1 arredonda para baixo, mais barato que math.floor)
local function ret(x0, y0, x1, y1, cor)
  x0, y0, x1, y1 = x0 // 1, y0 // 1, x1 // 1, y1 // 1
  if x1 <= x0 then x1 = x0 + 1 end
  if y1 <= y0 then y1 = y0 + 1 end
  ui.rectfill(x0, y0, x1, y1, cor)
end

-- triangulo com coordenadas arredondadas: o console desenha errado numeros com casas decimais
local function tri(x1, y1, x2, y2, x3, y3, cor)
  ui.trisfill(x1 // 1, y1 // 1, x2 // 1, y2 // 1, x3 // 1, y3 // 1, cor)
end

local LUZ = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 }   -- padrao xadrez (meio transparente)

-- Longe, os objetos tem poucos pixels: desenhamos versoes simplificadas (menos comandos
-- na drawlist do aparelho, que aceita 18 KB por quadro) e pulamos os que somem.
local MINIMO_PX = 3    -- objetos mais baixos que isto nao sao desenhados
local SIMPLES_PX = 14  -- abaixo desta altura, versao simplificada
local MEDIO_PX = 40    -- coqueiro: abaixo desta altura, versao de meia distancia

local function poste(o, sx, sy, kx, ky, noite)
  local h = 1500 * ky
  if h < MINIMO_PX then return end
  ret(sx - 25 * kx, sy - h, sx + 25 * kx, sy, Cores.poste)
  local lado = -o.lado                      -- o braco aponta para a pista
  if h < SIMPLES_PX then
    if noite then   -- longe, de noite: so o ponto de luz da lampada
      local ax = sx + lado * 330 * kx
      ret(ax - 1, sy - h, ax + 1, sy - h + 2, Cores.lampada)
    end
    return
  end
  local ax = sx + lado * 330 * kx
  local esp = max(1, 35 * ky)
  ret(min(sx, ax), sy - h, max(sx, ax), sy - h + esp, Cores.poste)
  ret(ax - 90 * kx, sy - h + esp, ax + 90 * kx, sy - h + esp * 2, Cores.lampada)
  if noite and kx < 0.25 then
    ui.fillp(table.unpack(LUZ))
    tri(ax, sy - h + esp * 2, ax - 260 * kx, sy, ax + 260 * kx, sy, Cores.luz)
    ui.fillp()
  end
end

-- folhas: pares de pontas (dx1, dy1, dx2, dy2) a partir do topo do tronco e a cor. Na ordem
-- em que entram no detalhe: as 2 de baixo, a de cima, as 2 do meio.
local FOLHAS = {
  { -650, 160, -480, 330, Cores.folha }, { 650, 160, 480, 330, Cores.folha },
  { -160, -280, 160, -280, Cores.folha_clara },
  { -560, -90, -420, 60, Cores.folha_clara }, { 560, -90, 420, 60, Cores.folha_clara },
}
local TRONCO = Cores.tronco

-- Coqueiros pequenos ja desenhados (ferramentas/gerar_efeitos.py), pela altura do tronco
-- em pixels: { imagem, tile da folha (ou false), dx, dy }. IMAGENS_COQUEIRO[1] inclina para a
-- direita, [-1] para a esquerda (espelhados). Longe vem da folha de tiles "longe".
-- (Sem Efeitos.coqueiro_longe, isto e, gerar_efeitos.py com COQUEIROS = False, os coqueiros
-- sao todos de triangulos.)
local IMAGENS_COQUEIRO = Efeitos.coqueiro_longe and { [1] = {}, [-1] = {} }
if IMAGENS_COQUEIRO then
  local pasta = Sprites.img.coqueiro
  for h, t in pairs(Efeitos.coqueiro_longe) do
    IMAGENS_COQUEIRO[1][h] = { pasta.longe, t[1], t[2], t[3] }
    IMAGENS_COQUEIRO[-1][h] = { pasta.longe, t[1] + 1024, t[4], t[3] }
  end
  for h, t in pairs(Efeitos.coqueiro_meio) do
    IMAGENS_COQUEIRO[1][h] = { pasta["d" .. h], false, t[1], t[3] }
    IMAGENS_COQUEIRO[-1][h] = { pasta["e" .. h], false, t[2], t[3] }
  end
end
-- so em 1 jogador: render.lua acerta a cada visao
O.coqueiro_imagem = false
O.tem_coqueiro_imagem = IMAGENS_COQUEIRO and true or false

-- Coqueiro: abaixo de MEDIO_PX de altura, uma imagem pronta (1 comando, poucas contas: a
-- folha "longe" e carregada uma vez para todos os coqueiros longe em seguida). Perto, ou em
-- 2 jogadores, triangulos em 3 niveis de detalhe (LOD):
--   longe (menos de SIMPLES_PX): tronco de 1 linha e as 2 folhas de baixo (3 comandos)
--   meia distancia (menos de MEDIO_PX): tronco de 1 triangulo e 3 folhas (4 comandos)
--   perto: tronco de 2 triangulos e as 5 folhas (7 comandos)
-- As contas ficam aqui mesmo (sem chamar tri): roda para cada coqueiro em todo quadro.
local function palmeira(o, sx, sy, kx, ky)
  local h = 1400 * ky
  if h < MINIMO_PX then return end
  if h < MEDIO_PX and O.coqueiro_imagem then
    local im = o.imagens[h // 1]
    if im[2] then
      Desenho.lote(im[1])
      ui.tile(im[1], im[2], (sx + im[3]) // 1, (sy + im[4]) // 1)
    else
      Desenho.spr(im[1], (sx + im[3]) // 1, (sy + im[4]) // 1)
    end
    return
  end
  local trisfill = ui.trisfill
  local tx, ty = sx + o.lado * 140 * kx, sy - h
  local txi, tyi, syi = tx // 1, ty // 1, sy // 1
  local folhas
  if h < SIMPLES_PX then
    ui.line(sx // 1, syi, txi, tyi, TRONCO)
    folhas = 2
  elseif h < MEDIO_PX then
    trisfill((sx - 45 * kx) // 1, syi, (sx + 45 * kx) // 1, syi, txi, tyi, TRONCO)
    folhas = 3
  else
    local a, b = (sx - 45 * kx) // 1, (sx + 45 * kx) // 1
    local c, d = (tx + 25 * kx) // 1, (tx - 25 * kx) // 1
    trisfill(a, syi, b, syi, c, tyi, TRONCO)
    trisfill(a, syi, c, tyi, d, tyi, TRONCO)
    folhas = 5
  end
  for k = 1, folhas do
    local f = FOLHAS[k]
    trisfill(txi, tyi, (tx + f[1] * kx) // 1, (ty + f[2] * ky) // 1, (tx + f[3] * kx) // 1, (ty + f[4] * ky) // 1, f[5])
  end
end

-- Pinheiro (floresta) e pinheiro com neve (o.neve, Castelo de Gelo): tronco e camadas de
-- triangulos empilhadas; a de cima e mais clara (ou branca de neve). Em niveis de detalhe:
-- longe 1 triangulo; meia distancia tronco e 2 camadas; perto tronco e 3 camadas.
-- Camadas: { altura da base, meia largura, altura } em unidades do mundo (topo em 1700).
local CAMADAS_2 = { { 220, 360, 800 }, { 800, 250, 900 } }
local CAMADAS_3 = { { 220, 380, 700 }, { 650, 300, 600 }, { 1050, 210, 650 } }
local function pinheiro(o, sx, sy, kx, ky)
  local h = 1700 * ky
  if h < MINIMO_PX then return end
  local trisfill = ui.trisfill
  local corpo = o.neve and Cores.pinheiro_neve or Cores.pinheiro
  local topo = o.neve and Cores.neve or Cores.pinheiro_claro
  local syi, sxi = sy // 1, sx // 1
  if h < SIMPLES_PX then
    trisfill((sx - 320 * kx) // 1, syi, (sx + 320 * kx) // 1, syi, sxi, (sy - h) // 1, corpo)
    return
  end
  ret(sx - 40 * kx, sy - 260 * ky, sx + 40 * kx, sy, Cores.tronco)
  local camadas = h < MEDIO_PX and CAMADAS_2 or CAMADAS_3
  for i = 1, #camadas do
    local c = camadas[i]
    local base = (sy - c[1] * ky) // 1
    trisfill((sx - c[2] * kx) // 1, base, (sx + c[2] * kx) // 1, base, sxi, (sy - (c[1] + c[3]) * ky) // 1,
      i == #camadas and topo or corpo)
  end
end

-- Cacto (deserto): coluna e bracos de retangulos (baratos no console). Longe so a coluna;
-- meia distancia com 1 braco; perto com 2 e o brilho.
local function cacto(o, sx, sy, kx, ky)
  local h = 1100 * ky
  if h < MINIMO_PX then return end
  local cor = Cores.cacto
  ret(sx - 70 * kx, sy - h, sx + 70 * kx, sy, cor)
  if h < SIMPLES_PX then return end
  local lado = o.lado
  local by, bx = sy - 520 * ky, sx + lado * 210 * kx          -- braco de fora (mais alto)
  ret(min(sx, bx), by - 50 * ky, max(sx, bx), by + 50 * ky, cor)
  ret(bx - 45 * kx, by - 360 * ky, bx + 45 * kx, by + 50 * ky, cor)
  if h < MEDIO_PX then return end
  by, bx = sy - 380 * ky, sx - lado * 190 * kx                 -- braco de dentro (mais baixo)
  ret(min(sx, bx), by - 45 * ky, max(sx, bx), by + 45 * ky, cor)
  ret(bx - 40 * kx, by - 260 * ky, bx + 40 * kx, by + 45 * ky, cor)
  ret(sx - 25 * kx, sy - h + 60 * ky, sx + 5 * kx, sy - 80 * ky, Cores.cacto_claro)
end

local function placa(o, sx, sy, kx, ky)
  if 760 * ky < MINIMO_PX then return end
  if 760 * ky < SIMPLES_PX then
    ret(sx - 260 * kx, sy - 760 * ky, sx + 260 * kx, sy - 420 * ky, Cores.placa)   -- longe: so a placa
    return
  end
  ret(sx - 20 * kx, sy - 420 * ky, sx + 20 * kx, sy, Cores.poste)
  ret(sx - 260 * kx, sy - 760 * ky, sx + 260 * kx, sy - 420 * ky, Cores.placa)
  local s = o.seta
  tri(sx - 120 * s * kx, sy - 720 * ky, sx + 150 * s * kx, sy - 590 * ky, sx - 120 * s * kx, sy - 460 * ky, Cores.preto)
end

local function arbusto(o, sx, sy, kx, ky)
  local r = 230 * kx
  if 2 * r < MINIMO_PX then return end
  ui.circfill(floor(sx), floor(sy - r * 0.7), floor(r), Cores.folha)
  if 2 * r < SIMPLES_PX then return end
  ui.circfill(floor(sx - r * 0.6), floor(sy - r * 0.4), floor(r * 0.7), Cores.folha_clara)
end

local function pedra(o, sx, sy, kx, ky)
  if 280 * ky < MINIMO_PX then return end
  tri(sx - 260 * kx, sy, sx + 260 * kx, sy, sx + 60 * kx, sy - 280 * ky, Cores.pedra)
  if 280 * ky < SIMPLES_PX then return end
  tri(sx - 260 * kx, sy, sx + 60 * kx, sy - 280 * ky, sx - 120 * kx, sy - 200 * ky, Cores.cinza)
end

local function portico(o, sx, sy, kx, ky)
  local meia = 1.3 * C.ESTRADA * kx
  local topo, base = sy - 1800 * ky, sy - 1450 * ky
  ret(sx - meia - 30 * kx, topo, sx - meia + 30 * kx, sy, Cores.poste)
  ret(sx + meia - 30 * kx, topo, sx + meia + 30 * kx, sy, Cores.poste)
  ret(sx - meia, topo, sx + meia, base, Cores.vermelho)
  if base - topo >= 10 then
    T.p_centro("GEARX", sx, floor((topo + base) / 2) - 4, Cores.branco)
  end
end

local DESENHOS = { poste = poste, palmeira = palmeira, placa = placa, arbusto = arbusto, pedra = pedra, portico = portico,
                   pinheiro = pinheiro, pinheiro_neve = pinheiro, cacto = cacto }

-- Ate onde cada objeto vai para os lados e para cima (unidades do mundo). Serve para pular
-- os que estao fora da tela: economiza desenho e evita mandar ao console coordenadas
-- gigantes (um objeto colado na camera daria centenas de milhares de pixels).
local ALCANCE = { poste = 600, palmeira = 800, placa = 260, arbusto = 400, pedra = 260, portico = 1500,
                  pinheiro = 400, pinheiro_neve = 400, cacto = 300 }
local ALTURA = { poste = 1550, palmeira = 1700, placa = 760, arbusto = 700, pedra = 280, portico = 1800,
                 pinheiro = 1750, pinheiro_neve = 1750, cacto = 1150 }
local ESCALA_MAX = 8   -- mais perto que isto, o objeto esta praticamente dentro da camera
O.ESCALA_MAX = ESCALA_MAX

-- Nitro na pista: uma lata (azul, faixa branca, tampa vermelha) feita so de retangulos.
-- Pisca para chamar atencao. (sx, sy) = base na tela; W x H = tamanho da visao.
function O.nitro(sx, sy, kx, ky, W, H, quadro)
  local h, meia = 300 * ky, 80 * kx
  if h < 2 or kx > ESCALA_MAX or sy < 0 or sy - h * 1.2 > H or sx + meia < 0 or sx - meia > W then return end
  local corpo, faixa = Cores.nitro, Cores.branco
  if (quadro // 8) % 2 == 0 then corpo, faixa = faixa, corpo end
  ret(sx - meia, sy - h, sx + meia, sy, corpo)
  if h >= 6 then
    ret(sx - meia, sy - h * 0.62, sx + meia, sy - h * 0.42, faixa)
    ret(sx - meia * 0.45, sy - h * 1.18, sx + meia * 0.45, sy - h, Cores.vermelho)
  end
end

-- Dados de cada objeto que nao mudam, guardados nele quando a pista e montada (render.lua):
-- a funcao que o desenha, ate onde vai para cima e para os lados, o lado da pista e se e
-- enfeite. Assim o desenho de cada quadro nao procura nada em tabelas.
function O.preparar(o)
  o.desenho = DESENHOS[o.tipo]
  o.alt, o.alc = ALTURA[o.tipo] or 0, ALCANCE[o.tipo] or 0
  o.lado = o.x > 0 and 1 or -1
  o.enfeite = O.enfeite[o.tipo] or false
  o.neve = o.tipo == "pinheiro_neve"
  if o.tipo == "palmeira" and IMAGENS_COQUEIRO then o.imagens = IMAGENS_COQUEIRO[o.lado] end
end

-- (sx, sy) = base do objeto na tela; W x H = tamanho da visao
function O.desenhar(o, sx, sy, kx, ky, noite, W, H)
  local f = o.desenho
  if not f or kx > ESCALA_MAX or sy < 0 or sy - o.alt * ky > H then return end
  local alcance = o.alc * kx
  if sx + alcance < 0 or sx - alcance > W then return end
  f(o, sx, sy, kx, ky, noite)
end

return O
