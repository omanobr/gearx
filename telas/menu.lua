-- Menu: escolher numero de jogadores, pista e voltas.
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"
local Pistas = require "pistas"
local R = require "render"

local Tela = {}
Tela.__index = Tela

-- "teste" e "desempenho" (telas de teste, temporarias) ficam depois de CORRER: so se chega
-- nelas descendo
local LINHAS = { "jogadores", "pista", "voltas", "correr", "teste", "desempenho" }
local TESTES = { teste = "TESTE DE TELA", desempenho = "TESTE DE DESEMPENHO" }

-- O menu nao tem mais a corrida de demonstracao atras do painel (quase nao aparecia e
-- custava uma corrida inteira por quadro no console).
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
    if TESTES[linha] then
      Jogo.ir(linha)
    elseif linha == "correr" then
      Jogo.ir("escolha", {
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

-- previa: o meio do panorama da pista (so os pedacos que aparecem: cada imagem desenhada e
-- lida do cartao)
local function previa_pista(op, x, y, w, h)
  local f = Arte.fundos[Pistas[op.pista].fundo]
  ui.clip(x, y, w, h)
  local px = math.floor(x - (f.largura - w) / 2)
  for i, spr in ipairs(f.sprites) do
    if px < x + w and px + f.larguras[i] > x then R.spr(spr, px, y + h - f.altura) end
    px = px + f.larguras[i]
  end
  ui.clip()
  ui.rect(x - 1, y - 1, x + w + 1, y + h + 1, Cores.branco)
end

function Tela:desenhar()
  local op = Jogo.opcoes
  ui.rectfill(0, 0, 480, 270, Cores.preto)
  ui.rectfill(30, 14, 450, 256, Cores.painel)
  T.grande_centro("CORRIDA", 240, 24, 4, Cores.amarelo, Cores.preto)

  local nomes = { jogadores = "JOGADORES", pista = "PISTA", voltas = "VOLTAS", correr = "CORRER!" }
  for i, linha in ipairs(LINHAS) do
    local y = 66 + (i - 1) * 24
    if linha == "correr" then y = y + 70 end
    local ativo = i == self.sel
    local cor = ativo and Cores.amarelo or Cores.branco
    if TESTES[linha] then
      T.p((ativo and "> " or "") .. TESTES[linha], 40, linha == "teste" and 208 or 220, ativo and Cores.amarelo or Cores.cinza)
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
