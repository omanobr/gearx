-- Tela de titulo.
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"
local Demo = require "demo"

local Tela = {}
Tela.__index = Tela

function Tela.nova()
  Demo.iniciar(Jogo.opcoes.pista)
  return setmetatable({ t = 0 }, Tela)
end

function Tela:atualizar()
  self.t = self.t + 1
  Demo.atualizar()
  if self.t > 20 and Entrada.confirmar() then Jogo.ir("menu") end
end

function Tela:desenhar()
  Demo.desenhar()
  local y = 30 + math.floor(math.sin(self.t / 25) * 3)
  T.grande_centro("GEARX", 246, y + 6, 9, Cores.preto)
  T.grande_centro("GEARX", 240, y, 9, Cores.amarelo, Cores.laranja)
  T.p_centro("CORRIDA PARA ATÉ 3 JOGADORES", 240, y + 76, Cores.branco, Cores.preto)
  if (self.t // 30) % 2 == 0 then
    T.grande_centro("APERTE Z", 240, 176, 3, Cores.branco, Cores.preto)
  end
  T.p("v0.2", 6, 258, Cores.cinza, Cores.preto)
end

return Tela
