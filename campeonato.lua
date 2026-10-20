-- Campeonato (v0.99b): as 4 pistas em ordem, da facil para a dificil (pistas.lua), cada corrida
-- num horario sorteado. Pontos por chegada, como na Formula 1 (o computador tambem pontua).
-- O campeonato em andamento fica em Jogo.campeonato; os carros sao os mesmos em todas as
-- corridas (escolhidos uma vez so), e cada um soma pontos pelo nome (J1, RAIO, FAISCA...).
local Pistas = require "pistas"

local Camp = {}

Camp.PONTOS = { 10, 8, 6, 5, 4, 3, 2, 1 }

-- comeca um campeonato (op: jogadores, voltas, carros, autopiloto)
function Camp.novo(op)
  local c = { corrida = 1, pistas = {}, horarios = {}, pontos = {}, ultima = {}, carros = {}, op = op }
  for i, def in ipairs(Pistas) do
    c.pistas[i] = i
    c.horarios[i] = def.horarios and math.random(1, #def.horarios) or nil
  end
  Jogo.campeonato = c
  return c
end

-- opcoes da corrida atual do campeonato (para Jogo.ir("corrida", ...))
function Camp.opcoes(c)
  local op = c.op
  return { jogadores = op.jogadores, voltas = op.voltas, carros = op.carros, autopiloto = op.autopiloto,
           pista = c.pistas[c.corrida], horario = c.horarios[c.corrida], campeonato = true }
end

-- soma os pontos de uma corrida que acabou (uma vez por corrida: telas/resultado.lua)
function Camp.pontuar(c, corrida)
  c.ultima = {}
  for pos, carro in ipairs(corrida.ranking) do
    local pts = Camp.PONTOS[pos] or 0
    c.pontos[carro.nome] = (c.pontos[carro.nome] or 0) + pts
    c.ultima[carro.nome] = pts
    c.carros[carro.nome] = { humano = carro.humano, jogador = carro.jogador, modelo = carro.modelo }
  end
end

-- classificacao: { nome, pontos, ultima (pontos da ultima corrida), humano, jogador, modelo },
-- do primeiro ao ultimo (empate: quem foi melhor na ultima corrida)
function Camp.classificacao(c)
  local lista = {}
  for nome, pts in pairs(c.pontos) do
    local info = c.carros[nome] or {}
    lista[#lista + 1] = { nome = nome, pontos = pts, ultima = c.ultima[nome] or 0, humano = info.humano,
                          jogador = info.jogador, modelo = info.modelo }
  end
  table.sort(lista, function(a, b)
    if a.pontos ~= b.pontos then return a.pontos > b.pontos end
    if a.ultima ~= b.ultima then return a.ultima > b.ultima end
    return a.nome < b.nome
  end)
  return lista
end

-- foi a ultima corrida?
function Camp.ultima_corrida(c)
  return c.corrida >= #c.pistas
end

return Camp
