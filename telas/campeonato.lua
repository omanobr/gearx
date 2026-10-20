-- Classificacao do campeonato (v0.99b), depois de cada corrida: pontos de cada carro (e quanto
-- ganhou nesta corrida). B continua: proxima pista, ou, depois da ultima, o campeao e os
-- recordes de campeonato (iniciais dos jogadores que entraram na tabela).
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"
local Pistas = require "pistas"
local Estrada = require "estrada"
local Camp = require "campeonato"
local Rec = require "recordes"
local Carros = require "carros"

local Tela = {}
Tela.__index = Tela

local NOME_DO_MODELO = {}
for _, c in ipairs(Carros) do NOME_DO_MODELO[c.modelo] = c.nome end

function Tela.nova()
  local c = Jogo.campeonato
  return setmetatable({ c = c, lista = Camp.classificacao(c), ultima = Camp.ultima_corrida(c), t = 0 }, Tela)
end

function Tela:atualizar()
  self.t = self.t + 1
  if self.t < 20 or not Entrada.confirmar() then return end
  local c = self.c
  if not self.ultima then
    c.corrida = c.corrida + 1
    Jogo.ir("corrida", Camp.opcoes(c))
    return
  end
  -- fim do campeonato: recordes de pontos dos jogadores (se entrarem na tabela)
  Jogo.campeonato = nil
  local fila = {}
  for _, l in ipairs(self.lista) do
    if l.humano and Rec.posicao_campeonato(l.pontos) then
      fila[#fila + 1] = { tipo = "campeonato", jogador = l.jogador + 1, valor = l.pontos,
                          carro = NOME_DO_MODELO[l.modelo] or "" }
    end
  end
  if #fila > 0 then
    Jogo.ir("iniciais", fila, { "menu", "principal" })
  else
    Jogo.ir("menu", "principal")
  end
end

function Tela:desenhar()
  local c = self.c
  ui.rectfill(0, 0, 480, 270, Cores.preto)
  ui.rectfill(0, 0, 480, 32, Cores.painel)
  ui.rectfill(0, 33, 480, 34, Cores.amarelo)
  T.grande("GEARX", 12, 6, 3, Cores.amarelo)
  T.grande("CAMPEONATO", 12 + T.largura("GEARX", 3) + 16, 11, 2, Cores.cinza)
  local pista = Pistas[c.pistas[c.corrida]]
  T.p_centro("CORRIDA " .. c.corrida .. " DE " .. #c.pistas .. "  -  " .. pista.nome, 240, 40, Cores.branco)

  for i, l in ipairs(self.lista) do
    local y = 54 + (i - 1) * 20
    local cor = l.humano and Cores.jogador[l.jogador + 1] or Cores.branco
    if l.humano then ui.rectfill(96, y - 3, 384, y + 15, Cores.cinza_escuro) end
    T.grande(i .. "º", 104, y, 2, i == 1 and Cores.amarelo or Cores.cinza)
    T.grande(l.nome, 150, y, 2, cor)
    if l.ultima > 0 then T.p("+" .. l.ultima, 252, y + 4, Cores.verde) end
    local pts = l.pontos .. " PTS"
    T.grande(pts, 376 - T.largura(pts, 2), y, 2, cor)
  end

  ui.rectfill(0, 220, 480, 270, Cores.painel)
  if self.ultima then
    local campeao = self.lista[1]
    T.grande_centro("CAMPEÃO: " .. campeao.nome, 240, 226, 3, Cores.amarelo)
  else
    local prox = Pistas[c.pistas[c.corrida + 1]]
    local hora = Estrada.horario(prox, c.horarios[c.corrida + 1]).nome
    T.grande_centro("PRÓXIMA: " .. prox.nome, 240, 226, 2, Cores.amarelo)
    T.p_centro(hora .. "  -  " .. prox.dificuldade, 240, 244, Cores.branco)
  end
  if (self.t // 30) % 2 == 0 then
    T.p_centro(Entrada.NOME.confirmar .. ": CONTINUAR", 240, 257, Cores.cinza)
  end
end

return Tela
