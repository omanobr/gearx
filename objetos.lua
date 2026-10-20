-- Objetos da beira da estrada, desenhados com formas simples (retangulos e
-- triangulos). Por serem formas, eles crescem e diminuem com a distancia sem
-- precisar de imagens em varios tamanhos.
--
-- Medidas em unidades do mundo (a estrada tem 2200 de largura, o carro 360).
-- kx / ky = quantos pixels vale 1 unidade do mundo naquela distancia.
local C = require "config"
local Cores = require "cores"
local T = require "texto"

local O = {}

-- enfeites: nas telas divididas so metade deles e desenhada (deixa o jogo mais leve)
O.enfeite = { palmeira = true, arbusto = true, pedra = true }

-- largura de cada objeto para as batidas (em "unidades de pista"; nil = nao bate)
O.largura = { poste = 0.12, palmeira = 0.18, placa = 0.3, arbusto = 0.3, pedra = 0.35 }

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

-- Coqueiro em 3 niveis de detalhe (LOD), pela altura na tela:
--   longe (menos de SIMPLES_PX): tronco de 1 linha e as 2 folhas de baixo (3 comandos)
--   meia distancia (menos de MEDIO_PX): tronco de 1 triangulo e 3 folhas (4 comandos)
--   perto: tronco de 2 triangulos e as 5 folhas (7 comandos)
-- As contas ficam aqui mesmo (sem chamar tri): roda para cada coqueiro em todo quadro.
local function palmeira(o, sx, sy, kx, ky)
  local h = 1400 * ky
  if h < MINIMO_PX then return end
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

local DESENHOS = { poste = poste, palmeira = palmeira, placa = placa, arbusto = arbusto, pedra = pedra, portico = portico }

-- Ate onde cada objeto vai para os lados e para cima (unidades do mundo). Serve para pular
-- os que estao fora da tela: economiza desenho e evita mandar ao console coordenadas
-- gigantes (um objeto colado na camera daria centenas de milhares de pixels).
local ALCANCE = { poste = 600, palmeira = 800, placa = 260, arbusto = 400, pedra = 260, portico = 1500 }
local ALTURA = { poste = 1550, palmeira = 1700, placa = 760, arbusto = 700, pedra = 280, portico = 1800 }
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
