-- Resultado da corrida. Na corrida avulsa: B corre de novo, A volta ao menu. No campeonato
-- (v0.99b): mostra os pontos ganhos e B vai para a classificacao. Antes, quem fez uma volta que
-- entra nos recordes (recordes.lua) poe as iniciais (telas/iniciais.lua).
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"
local Camp = require "campeonato"
local Rec = require "recordes"
local Carros = require "carros"

local Tela = {}
Tela.__index = Tela

local NOME_DO_MODELO = {}
for _, c in ipairs(Carros) do NOME_DO_MODELO[c.modelo] = c.nome end

function Tela.nova(corrida, opcoes)
  local self = setmetatable({ t = 0, opcoes = opcoes, linhas = {}, fila = {} }, Tela)
  self.pista = corrida.pista.nome
  self.campeonato = opcoes.campeonato and Jogo.campeonato
  if self.campeonato then Camp.pontuar(self.campeonato, corrida) end
  for p, carro in ipairs(corrida.ranking) do
    self.linhas[p] = {
      nome = carro.nome,
      humano = carro.humano,
      cor = carro.humano and Cores.jogador[carro.jogador + 1] or Cores.branco,
      tempo = carro.terminou and T.tempo(carro.tempo_final) or "--",
      pontos = Camp.PONTOS[p] or 0,
    }
  end
  -- voltas que entram nos recordes desta pista (uma por jogador: a melhor dele)
  for j, carro in ipairs(corrida.humanos) do
    if carro.melhor_volta and Rec.posicao_volta(opcoes.pista, carro.melhor_volta) then
      self.fila[#self.fila + 1] = { tipo = "volta", jogador = j, pista = opcoes.pista, valor = carro.melhor_volta,
                                    carro = NOME_DO_MODELO[carro.modelo] or "" }
      for _, l in ipairs(self.linhas) do
        if l.nome == carro.nome then l.recorde = true end
      end
    end
  end
  return self
end

-- vai para "destino" ({ tela, argumentos... }), passando antes pelas iniciais dos recordes
function Tela:seguir(destino)
  if #self.fila > 0 then
    Jogo.ir("iniciais", self.fila, destino)
  else
    Jogo.ir(table.unpack(destino))
  end
end

function Tela:atualizar()
  self.t = self.t + 1
  if self.t < 30 then return end
  if self.campeonato then
    if Entrada.confirmar() then self:seguir({ "campeonato" }) end
  elseif Entrada.confirmar() then
    self:seguir({ "corrida", self.opcoes })
  elseif Entrada.voltar() then
    self:seguir({ "menu", "corrida" })
  end
end

function Tela:desenhar()
  ui.rectfill(0, 0, 480, 270, Cores.preto)   -- sem a corrida de demonstracao atras (pesava no console)
  ui.rectfill(90, 10, 390, 260, Cores.painel)
  T.grande_centro("RESULTADO", 240, 20, 4, Cores.amarelo, Cores.preto)
  T.p_centro(self.pista, 240, 52, Cores.cinza)
  local pisca = (self.t // 15) % 2 == 0
  for p, l in ipairs(self.linhas) do
    local y = 68 + (p - 1) * 19
    local cor = l.humano and l.cor or Cores.branco
    if l.humano then ui.rectfill(104, y - 3, 376, y + 13, Cores.cinza_escuro) end
    T.grande(p .. "º", 112, y, 2, l.humano and Cores.amarelo or Cores.cinza)
    T.grande(l.nome, 160, y, 2, cor)
    T.grande(l.tempo, 368 - T.largura(l.tempo, 2), y, 2, cor)
    if self.campeonato and l.pontos > 0 then T.p("+" .. l.pontos, 396, y + 4, Cores.verde) end
    if l.recorde and pisca then T.p("RECORDE!", 30, y + 4, Cores.amarelo) end
  end
  if (self.t // 30) % 2 == 0 then
    local texto = self.campeonato and (Entrada.NOME.confirmar .. ": CONTINUAR")
      or (Entrada.NOME.confirmar .. ": CORRER DE NOVO     " .. Entrada.NOME.voltar .. ": MENU")
    T.p_centro(texto, 240, 246, Cores.branco)
  end
end

return Tela
