-- Medidor dos limites do aparelho real (issue oficial lupi-org-br/lupinho#12).
-- So e carregado no simulador, com "desempenho" ligado no Modo de teste: o simulador
-- roda no PC e nao tem esses limites, entao contamos aqui o que o Lupi aguentaria.
--
--   instrucoes Lua ......... ~50-60 mil por quadro (contadas com debug.sethook)
--   drawlist ............... 18 KB de comandos de desenho por quadro (custos abaixo)
--   cargas de imagem (SD) .. 32 por quadro e 150 KB por quadro
--
-- Os quadros se alternam: um conta as instrucoes e o seguinte conta a drawlist e as
-- imagens, porque os "espioes" colocados nas funcoes ui.* gastam instrucoes tambem.
-- Cargas: contamos uma carga sempre que o desenho troca de imagem (o pior caso; o
-- aparelho pode guardar mais de uma imagem pequena no sprite bank de 46 KB).
local T = require "texto"
local Cores = require "cores"

local M = {}

local LIMITE = { instr = 55000, drawlist = 18 * 1024, cargas = 32, sd = 150 * 1024 }
local CUSTO_FIXO = { line = 12, rect = 12, rectfill = 12, circ = 12, circfill = 12, trisfill = 20, cls = 16 }

local q = { drawlist = 0, cargas = 0, sd = 0 }   -- quadro atual
local ultima_imagem
local originais, espioes = {}, {}

for nome, custo in pairs(CUSTO_FIXO) do
  local f = ui[nome]
  if f then
    originais[nome] = f
    espioes[nome] = function(...)
      q.drawlist = q.drawlist + custo
      return f(...)
    end
  end
end
for _, nome in ipairs({ "clip", "fillp" }) do      -- definir custa 12; resetar, 4
  local f = ui[nome]
  originais[nome] = f
  espioes[nome] = function(...)
    q.drawlist = q.drawlist + (select("#", ...) == 0 and 4 or 12)
    return f(...)
  end
end
do
  local f = ui.print
  originais.print = f
  espioes.print = function(texto, ...)
    q.drawlist = q.drawlist + 16 + math.ceil(#tostring(texto) / 4) * 4
    return f(texto, ...)
  end
end
do
  local f = ui.spr
  originais.spr = f
  espioes.spr = function(img, ...)
    if img == ultima_imagem then
      q.drawlist = q.drawlist + 4                -- continua o lote da mesma imagem
    else
      q.drawlist = q.drawlist + 8
      q.cargas = q.cargas + 1
      q.sd = q.sd + (img.width or 0) * (img.height or 0)   -- so o simulador traz largura/altura
      ultima_imagem = img
    end
    return f(img, ...)
  end
end

-- estatisticas a cada 60 quadros (30 de cada tipo)
local NOMES = { "instr", "drawlist", "cargas", "sd" }
local soma, pico, n = {}, {}, { instr = 0, drawlist = 0 }
local resultado = nil
local function zerar()
  for _, k in ipairs(NOMES) do soma[k], pico[k] = 0, 0 end
  n.instr, n.drawlist = 0, 0
end
zerar()
local function registrar(k, v)
  soma[k], pico[k] = soma[k] + v, math.max(pico[k], v)
end

local contar_instrucoes = true
local centenas = 0   -- o gancho e chamado a cada 100 instrucoes
local function gancho() centenas = centenas + 1 end

function M.inicio()
  if contar_instrucoes then
    centenas = 0
    debug.sethook(gancho, "", 100)
  else
    q.drawlist, q.cargas, q.sd, ultima_imagem = 0, 0, 0, nil
    for nome, f in pairs(espioes) do ui[nome] = f end
  end
end

function M.fim()
  if contar_instrucoes then
    debug.sethook()
    registrar("instr", centenas * 100)
    n.instr = n.instr + 1
  else
    for nome, f in pairs(originais) do ui[nome] = f end
    registrar("drawlist", q.drawlist); registrar("cargas", q.cargas); registrar("sd", q.sd)
    n.drawlist = n.drawlist + 1
  end
  contar_instrucoes = not contar_instrucoes
  if n.instr + n.drawlist == 60 then
    resultado = {}
    for _, k in ipairs(NOMES) do
      local quantos = k == "instr" and n.instr or n.drawlist
      resultado[k] = { media = soma[k] / quantos, pico = pico[k] }
    end
    if ui.log then
      local r = resultado
      local f = math.floor
      ui.log(string.format("LIMITES instr=%d/%d drawlist=%d/%d cargas=%d/%d sd=%d/%d (media/pico)",
        f(r.instr.media), r.instr.pico, f(r.drawlist.media), r.drawlist.pico,
        f(r.cargas.media), r.cargas.pico, f(r.sd.media), r.sd.pico))
    end
    zerar()
  end
end

local function linha(y, rotulo, k, formato, divisor)
  local r = resultado[k]
  local cor = r.pico > LIMITE[k] and Cores.vermelho or (r.pico > LIMITE[k] * 0.8 and Cores.amarelo or Cores.verde)
  local texto = string.format("%s " .. formato .. "  PICO " .. formato .. "  LIMITE " .. formato, rotulo,
    r.media / divisor, r.pico / divisor, LIMITE[k] / divisor)
  T.p_centro(texto, 240, y, cor, Cores.preto)
end

function M.desenhar()
  if not resultado then return end
  ui.camera()
  ui.clip()
  linha(104, "LUA (MIL INSTR.)", "instr", "%.1f", 1000)
  linha(114, "DRAWLIST (KB)   ", "drawlist", "%.1f", 1024)
  linha(124, "SD (KB/QUADRO)  ", "sd", "%.0f", 1024)
  linha(134, "CARGAS DE IMAGEM", "cargas", "%.0f", 1)
end

return M
