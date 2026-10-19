-- Tela da corrida: divide a tela conforme o numero de jogadores.
--   1 jogador : tela inteira (480x270)
--   2 jogadores: uma em cima da outra (480x135 cada), como no Top Gear
--   3 jogadores: tres quadrantes (240x135) + painel de classificacao no quarto
local C = require "config"
local Corrida = require "corrida"
local R = require "render"
local Hud = require "hud"
local Cores = require "cores"
local Demo = require "demo"

local Tela = {}
Tela.__index = Tela

local function visoes(n)
  local W, H = C.LARGURA, C.ALTURA
  local lista, painel
  if n == 1 then
    lista = { { x = 0, y = 0, w = W, h = H } }
  elseif n == 2 then
    lista = { { x = 0, y = 0, w = W, h = H // 2 }, { x = 0, y = H // 2, w = W, h = H // 2 } }
  else
    local w, h = W // 2, H // 2
    lista = { { x = 0, y = 0, w = w, h = h }, { x = w, y = 0, w = w, h = h }, { x = 0, y = h, w = w, h = h } }
    painel = { x = w, y = h, w = w, h = h }
  end
  for _, v in ipairs(lista) do
    v.hy = math.floor(v.h * C.HORIZONTE)
    v.dist = C.DISTANCIA[n]
  end
  return lista, painel
end

function Tela.nova(opcoes)
  Demo.parar()   -- libera a memoria da demonstracao antes de montar a corrida
  local self = setmetatable({}, Tela)
  self.opcoes = opcoes
  self.corrida = Corrida.nova(opcoes)
  self.visoes, self.painel = visoes(opcoes.jogadores)
  self.quadro = 0
  return self
end

function Tela:atualizar()
  self.quadro = self.quadro + 1
  self.corrida:atualizar()
  if self.corrida:acabou() then
    Jogo.ir("resultado", self.corrida, self.opcoes)
  end
end

function Tela:desenhar()
  local corrida = self.corrida
  local varios = #corrida.humanos > 1
  for j, carro in ipairs(corrida.humanos) do
    local v = self.visoes[j]
    R.visao(corrida, carro, v, self.quadro)
    Hud.desenhar(corrida, carro, v, varios)
  end
  ui.camera()
  ui.clip()
  if self.painel then Hud.classificacao(corrida, self.painel) end
  local W, H = C.LARGURA, C.ALTURA
  if #corrida.humanos >= 2 then ui.rectfill(0, H // 2 - 1, W, H // 2 + 1, Cores.preto) end
  if #corrida.humanos == 3 then ui.rectfill(W // 2 - 1, 0, W // 2 + 1, H, Cores.preto) end
end

return Tela
