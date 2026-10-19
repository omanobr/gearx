-- Menu: escolher numero de jogadores, pista e voltas.
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"
local Pistas = require "pistas"
local Demo = require "demo"

local Tela = {}
Tela.__index = Tela

-- "teste" (tela de teste, temporaria) fica depois de CORRER: so se chega nela descendo
local LINHAS = { "jogadores", "pista", "voltas", "correr", "teste" }
local MEIO_TOM = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 }

function Tela.nova()
  Demo.iniciar(Jogo.opcoes.pista)
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
  Demo.iniciar(op.pista)   -- a demonstracao do fundo acompanha a pista escolhida
  Demo.atualizar()
  if Entrada.confirmar() then
    if linha == "teste" then
      Jogo.ir("teste")
    elseif linha == "correr" then
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
  Demo.desenhar()
  ui.fillp(table.unpack(MEIO_TOM))
  ui.rectfill(0, 0, 480, 270, Cores.preto)
  ui.fillp()
  ui.rectfill(30, 14, 450, 256, Cores.painel)
  T.grande_centro("CORRIDA", 240, 24, 4, Cores.amarelo, Cores.preto)

  local nomes = { jogadores = "JOGADORES", pista = "PISTA", voltas = "VOLTAS", correr = "CORRER!" }
  for i, linha in ipairs(LINHAS) do
    local y = 66 + (i - 1) * 24
    if linha == "correr" then y = y + 70 end
    local ativo = i == self.sel
    local cor = ativo and Cores.amarelo or Cores.branco
    if linha == "teste" then
      T.p((ativo and "> " or "") .. "TESTE DE TELA", 40, 216, ativo and Cores.amarelo or Cores.cinza)
    elseif linha == "correr" then
      if ativo and (self.t // 15) % 2 == 0 then cor = Cores.branco end
      T.grande_centro(nomes[linha], 240, y, 3, cor, Cores.preto)
    else
      T.grande(nomes[linha], 50, y, 2, cor)
      T.grande_centro(valor(op, linha), 312, y, 2, cor)
      if ativo then
        T.grande("<", 180, y, 2, cor)
        T.grande(">", 432, y, 2, cor)
      end
    end
  end
  previa_pista(op, 120, 140, 240, 56)

  local nome = Entrada.NOME
  T.p_centro("CIMA/BAIXO ESCOLHE   ESQ/DIR MUDA   " .. nome.confirmar .. " CONFIRMA   " .. nome.voltar .. " VOLTA",
    240, 236, Cores.cinza)
  T.p_centro("NA CORRIDA: " .. nome.acelerar .. " ACELERA  " .. nome.frear .. " FREIA  " .. nome.nitro .. " NITRO",
    240, 246, Cores.cinza)
end

return Tela
