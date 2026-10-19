-- Menu: escolher numero de jogadores, pista e voltas.
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"
local Pistas = require "pistas"

local Tela = {}
Tela.__index = Tela

local LINHAS = { "jogadores", "pista", "voltas", "correr" }
local MEIO_TOM = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 }

function Tela.nova()
  return setmetatable({ sel = 1, t = 0 }, Tela)
end

local function circular(valor, delta, maximo)
  return (valor - 1 + delta) % maximo + 1
end

function Tela:atualizar()
  self.t = self.t + 1
  local op = Jogo.opcoes
  if Entrada.cima() then self.sel = circular(self.sel, -1, #LINHAS) end
  if Entrada.baixo() then self.sel = circular(self.sel, 1, #LINHAS) end
  local d = (Entrada.dir() and 1 or 0) - (Entrada.esq() and 1 or 0)
  local linha = LINHAS[self.sel]
  if d ~= 0 then
    if linha == "jogadores" then op.jogadores = circular(op.jogadores, d, 3)
    elseif linha == "pista" then op.pista = circular(op.pista, d, #Pistas)
    elseif linha == "voltas" then op.voltas = math.max(1, math.min(9, op.voltas + d)) end
  end
  if Entrada.confirmar() then
    if linha == "correr" then
      Jogo.ir("corrida", {
        jogadores = op.jogadores, pista = op.pista, voltas = op.voltas,
        autopiloto = DEV.autopiloto,
      })
    else
      self.sel = self.sel + 1
    end
  elseif Entrada.voltar() then
    Jogo.ir("titulo")
  end
end

local function valor(op, linha)
  if linha == "jogadores" then return tostring(op.jogadores) end
  if linha == "pista" then return Pistas[op.pista].nome end
  if linha == "voltas" then return tostring(op.voltas) end
  return ""
end

local function previa_pista(op, x, y, w, h)
  local f = Arte.fundos[Pistas[op.pista].fundo]
  ui.clip(x, y, w, h)
  local px = math.floor(x - (f.largura - w) / 2)
  for i, spr in ipairs(f.sprites) do
    ui.spr(spr, px, y + h - f.altura)
    px = px + f.larguras[i]
  end
  ui.clip()
  ui.rect(x - 1, y - 1, x + w + 1, y + h + 1, Cores.branco)
end

function Tela:desenhar()
  local op = Jogo.opcoes
  ui.spr(Sprites.img.titulo.tela, 0, 0)
  ui.fillp(table.unpack(MEIO_TOM))
  ui.rectfill(0, 0, 480, 270, Cores.preto)
  ui.fillp()
  ui.rectfill(60, 14, 420, 256, Cores.painel)
  T.grande_centro("CORRIDA", 240, 24, 4, Cores.amarelo, Cores.preto)

  local nomes = { jogadores = "JOGADORES", pista = "PISTA", voltas = "VOLTAS", correr = "CORRER!" }
  for i, linha in ipairs(LINHAS) do
    local y = 66 + (i - 1) * 24
    if linha == "correr" then y = y + 70 end
    local ativo = i == self.sel
    local cor = ativo and Cores.amarelo or Cores.branco
    if linha == "correr" then
      if ativo and (self.t // 15) % 2 == 0 then cor = Cores.branco end
      T.grande_centro(nomes[linha], 240, y, 3, cor, Cores.preto)
    else
      T.grande(nomes[linha], 80, y, 2, cor)
      local v = valor(op, linha)
      if ativo then v = "< " .. v .. " >" end
      T.grande(v, 220, y, 2, cor)
    end
  end
  previa_pista(op, 120, 140, 240, 56)

  T.p_centro("CIMA/BAIXO ESCOLHE   ESQ/DIR MUDA   Z CONFIRMA   X VOLTA", 240, 236, Cores.cinza)
  T.p_centro("NA CORRIDA: Z ACELERA  X FREIA  Q/E NITRO", 240, 246, Cores.cinza)
end

return Tela
