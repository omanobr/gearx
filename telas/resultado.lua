-- Resultado da corrida.
local C = require "config"
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"

local Tela = {}
Tela.__index = Tela

function Tela.nova(corrida, opcoes)
  local self = setmetatable({ t = 0, opcoes = opcoes, linhas = {} }, Tela)
  self.pista = corrida.pista.nome
  for p, carro in ipairs(corrida.ranking) do
    self.linhas[p] = {
      nome = carro.nome,
      humano = carro.humano,
      cor = carro.humano and Cores.jogador[carro.jogador + 1] or Cores.branco,
      tempo = carro.terminou and T.tempo(carro.tempo_final) or "--",
    }
  end
  return self
end

function Tela:atualizar()
  self.t = self.t + 1
  if self.t < 30 then return end
  if Entrada.confirmar() then Jogo.ir("corrida", self.opcoes)
  elseif Entrada.voltar() then Jogo.ir("menu") end
end

function Tela:desenhar()
  ui.rectfill(0, 0, 480, 270, Cores.preto)   -- sem a corrida de demonstracao atras (pesava no console)
  ui.rectfill(90, 10, 390, 260, Cores.painel)
  T.grande_centro("RESULTADO", 240, 20, 4, Cores.amarelo, Cores.preto)
  T.p_centro(self.pista, 240, 52, Cores.cinza)
  for p, l in ipairs(self.linhas) do
    local y = 68 + (p - 1) * 19
    local cor = l.humano and l.cor or Cores.branco
    if l.humano then ui.rectfill(104, y - 3, 376, y + 13, Cores.cinza_escuro) end
    T.grande(p .. "º", 112, y, 2, l.humano and Cores.amarelo or Cores.cinza)
    T.grande(l.nome, 160, y, 2, cor)
    T.grande(l.tempo, 368 - T.largura(l.tempo, 2), y, 2, cor)
  end
  if (self.t // 30) % 2 == 0 then
    T.p_centro(Entrada.NOME.confirmar .. ": CORRER DE NOVO     " .. Entrada.NOME.voltar .. ": MENU", 240, 246, Cores.branco)
  end
end

return Tela
