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

-- largura de cada objeto para as batidas (em "unidades de pista"; nil = nao bate)
O.largura = { poste = 0.12, palmeira = 0.18, placa = 0.3, arbusto = 0.3, pedra = 0.35 }

local floor, max, min = math.floor, math.max, math.min

local function ret(x0, y0, x1, y1, cor)
  x0, y0 = floor(x0), floor(y0)
  x1, y1 = max(floor(x1), x0 + 1), max(floor(y1), y0 + 1)
  ui.rectfill(x0, y0, x1, y1, cor)
end

local LUZ = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 }   -- padrao xadrez (meio transparente)

-- Longe, os objetos tem poucos pixels: desenhamos versoes simplificadas (menos comandos
-- na drawlist do aparelho, que aceita 18 KB por quadro) e pulamos os que somem.
local MINIMO_PX = 3    -- objetos mais baixos que isto nao sao desenhados
local SIMPLES_PX = 14  -- abaixo desta altura, versao simplificada

local function poste(o, sx, sy, kx, ky, noite)
  local h = 1500 * ky
  if h < MINIMO_PX then return end
  ret(sx - 25 * kx, sy - h, sx + 25 * kx, sy, Cores.poste)
  local lado = o.x > 0 and -1 or 1          -- o braco aponta para a pista
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
    ui.trisfill(ax, sy - h + esp * 2, ax - 260 * kx, sy, ax + 260 * kx, sy, Cores.luz)
    ui.fillp()
  end
end

-- folhas: pares de pontas (dx1, dy1, dx2, dy2) a partir do topo do tronco
local FOLHAS = {
  { -650, 160, -480, 330, "folha" }, { 650, 160, 480, 330, "folha" },
  { -560, -90, -420, 60, "folha_clara" }, { 560, -90, 420, 60, "folha_clara" },
  { -160, -280, 160, -280, "folha_clara" },
}

local function palmeira(o, sx, sy, kx, ky)
  local h = 1400 * ky
  if h < MINIMO_PX then return end
  local tx, ty = sx + (o.x > 0 and 1 or -1) * 140 * kx, sy - h
  if h < SIMPLES_PX then
    -- longe: tronco e as duas folhas de baixo (3 comandos em vez de 7)
    ui.line(floor(sx), floor(sy), floor(tx), floor(ty), Cores.tronco)
    for k = 1, 2 do
      local f = FOLHAS[k]
      ui.trisfill(tx, ty, tx + f[1] * kx, ty + f[2] * ky, tx + f[3] * kx, ty + f[4] * ky, Cores.folha)
    end
    return
  end
  ui.trisfill(sx - 45 * kx, sy, sx + 45 * kx, sy, tx + 25 * kx, ty, Cores.tronco)
  ui.trisfill(sx - 45 * kx, sy, tx + 25 * kx, ty, tx - 25 * kx, ty, Cores.tronco)
  for _, f in ipairs(FOLHAS) do
    ui.trisfill(tx, ty, tx + f[1] * kx, ty + f[2] * ky, tx + f[3] * kx, ty + f[4] * ky, Cores[f[5]])
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
  ui.trisfill(sx - 120 * s * kx, sy - 720 * ky, sx + 150 * s * kx, sy - 590 * ky, sx - 120 * s * kx, sy - 460 * ky, Cores.preto)
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
  ui.trisfill(sx - 260 * kx, sy, sx + 260 * kx, sy, sx + 60 * kx, sy - 280 * ky, Cores.pedra)
  if 280 * ky < SIMPLES_PX then return end
  ui.trisfill(sx - 260 * kx, sy, sx + 60 * kx, sy - 280 * ky, sx - 120 * kx, sy - 200 * ky, Cores.cinza)
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

function O.desenhar(o, sx, sy, kx, ky, noite)
  local f = DESENHOS[o.tipo]
  if f then f(o, sx, sy, kx, ky, noite) end
end

return O
