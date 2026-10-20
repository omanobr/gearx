-- Tela de titulo.
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"
local Demo = require "demo"
local Desenho = require "desenho"
local Tempo = require "tempo"

local Tela = {}
Tela.__index = Tela

function Tela.nova()
  Demo.iniciar(Jogo.opcoes.pista)
  return setmetatable({ t = 0 }, Tela)
end

function Tela:atualizar()
  self.t = self.t + Tempo.passo   -- o "APERTE" pisca no ritmo certo mesmo com o console lento
  Demo.atualizar()
  if self.t > 20 and Entrada.confirmar() then Jogo.ir("menu") end
end

function Tela:desenhar()
  Demo.desenhar()
  local y = 30 + math.floor(math.sin(self.t / 25) * 3)
  -- logo: uma imagem so (ferramentas/gerar_fonte.py); feito de retangulos eram uns 100
  local largura = Fonte.logo[1] - 6   -- sem a sombra
  Desenho.spr(Sprites.img.titulo.logo, 240 - largura // 2, y)
  T.p_centro("CORRIDA PARA ATÉ 3 JOGADORES", 240, y + 76, Cores.branco, Cores.preto)
  if (self.t // 30) % 2 == 0 then
    T.grande_centro("APERTE " .. Entrada.NOME.confirmar, 240, 176, 3, Cores.branco, Cores.preto)
  end
  T.p("v0.97i", 6, 258, Cores.cinza, Cores.preto)
end

return Tela
