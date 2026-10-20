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
local T = require "texto"
local Entrada = require "entrada"

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
    v.objetos = C.OBJETOS_DIST[n]
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

-- Pausa (v0.98): qualquer jogador aperta o botao de pausa; a corrida congela e aparece um
-- quadro com CONTINUAR, RECOMECAR (mesma pista e carros) e SAIR (volta ao menu da corrida).
-- O botao de voltar ou o de pausa de novo tambem continuam.
local PAUSA = { "CONTINUAR", "RECOMEÇAR", "SAIR" }

function Tela:atualizar_pausa()
  local p = self.pausa
  if Entrada.cima() then p.sel = (p.sel - 2) % #PAUSA + 1 end
  if Entrada.baixo() then p.sel = p.sel % #PAUSA + 1 end
  p.t = p.t + 1
  if p.t < 5 then return end   -- o aperto que pausou nao vale aqui
  if Entrada.voltar() or Entrada.pausar() then
    self.pausa = nil
  elseif Entrada.confirmar() then
    if p.sel == 1 then self.pausa = nil
    elseif p.sel == 2 then Jogo.ir("corrida", self.opcoes)
    elseif self.opcoes.campeonato then
      Jogo.campeonato = nil                -- sair no meio do campeonato desiste dele
      Jogo.ir("menu", "campeonato")
    else Jogo.ir("menu", "corrida") end
  end
end

function Tela:atualizar()
  if self.pausa then return self:atualizar_pausa() end
  if Entrada.pausar() and self.corrida.estado ~= "fim" then
    self.pausa = { sel = 1, t = 0 }
    return
  end
  self.quadro = self.quadro + 1
  self.corrida:atualizar()
  if self.corrida:acabou() then
    Jogo.ir("resultado", self.corrida, self.opcoes)
  end
end

function Tela:desenhar()
  local corrida = self.corrida
  local varios = #corrida.humanos > 1
  R.fundos(corrida.pista, self.visoes, corrida.humanos)
  for j, carro in ipairs(corrida.humanos) do
    local v = self.visoes[j]
    R.visao(corrida, carro, v, self.quadro)
    T.fila(v.x, v.y)   -- os numeros do painel vao para a fila (desenhados juntos no fim)
    Hud.desenhar(corrida, carro, v, varios)
  end
  ui.camera()
  ui.clip()
  if self.painel then Hud.classificacao(corrida, self.painel) end
  local W, H = C.LARGURA, C.ALTURA
  if #corrida.humanos >= 2 then ui.rectfill(0, H // 2 - 1, W, H // 2 + 1, Cores.preto) end
  if #corrida.humanos == 3 then ui.rectfill(W // 2 - 1, 0, W // 2 + 1, H, Cores.preto) end
  T.fila_desenhar()
  if self.pausa then
    local x, y, w, h = 150, 64, 180, 132
    ui.rectfill(x, y, x + w, y + h, Cores.painel)
    ui.rect(x, y, x + w, y + h, Cores.amarelo)
    T.grande_centro("PAUSA", 240, y + 10, 3, Cores.amarelo)
    for i, s in ipairs(PAUSA) do
      local yy = y + 46 + (i - 1) * 26
      local ativo = i == self.pausa.sel
      if ativo then ui.rectfill(x + 12, yy - 5, x + w - 12, yy + 17, Cores.nitro) end
      T.grande_centro(s, 240, yy, 2, ativo and Cores.amarelo or Cores.branco)
    end
  end
end

return Tela
