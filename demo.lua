-- Corrida de demonstracao: roda sozinha atras do titulo, do menu e do resultado,
-- como no Top Gear. Substitui a imagem de 480x270 que ficava ali: ela ocupava 130 KB
-- e nao cabia na memoria grafica do console. Aqui so reaproveitamos a pista, o fundo
-- e os carros que o jogo ja tem.
local C = require "config"
local Corrida = require "corrida"
local R = require "render"

local Demo = {}

local VISAO = {
  x = 0, y = 0, w = C.LARGURA, h = C.ALTURA,
  hy = math.floor(C.ALTURA * C.HORIZONTE), dist = C.DISTANCIA[1],
}

local corrida, pista_atual = nil, nil
local quadro = 0

-- Garante uma demonstracao rodando na pista pedida (se ja estiver nela, continua de onde estava).
function Demo.iniciar(pista)
  pista = pista or pista_atual or 1
  if corrida and pista == pista_atual then return end
  corrida = Corrida.nova({ jogadores = 1, pista = pista, voltas = 99, autopiloto = { true } })
  corrida.estado, corrida.largada = "correndo", 0   -- sem contagem: ja sai acelerando
  pista_atual = pista
end

-- Libera a memoria da demonstracao (chamado quando comeca uma corrida de verdade).
function Demo.parar()
  corrida = nil
end

function Demo.atualizar()
  if not corrida then Demo.iniciar() end
  quadro = quadro + 1
  corrida:atualizar()
end

function Demo.desenhar()
  if not corrida then Demo.iniciar() end
  R.visao(corrida, corrida.humanos[1], VISAO, quadro)
  ui.camera()
  ui.clip()
end

return Demo
