-- GearX - corrida estilo Top Gear (SNES) para ate 3 jogadores.
-- Ponto de entrada: o Lupi chama update() 60 vezes por segundo.
collectgarbage("generational")

require "palette"      -- gerado pela ferramenta de construcao (todas as cores do jogo)
require "sprites"      -- tabela Sprites com todas as imagens
require "dados_arte"   -- gerado por ferramentas/preparar_arte.py

-- Opcoes de teste vindas do simulador (o arquivo nao existe no console).
local ok, dev = pcall(require, "dev_config")
DEV = (ok and type(dev) == "table") and dev or {}

local R = require "render"
local T = require "texto"
local Cores = require "cores"

local TELAS = {
  titulo = require "telas.titulo",
  menu = require "telas.menu",
  corrida = require "telas.corrida",
  resultado = require "telas.resultado",
}

Jogo = {
  opcoes = { jogadores = 1, pista = 1, voltas = 3 },
  tela = nil,
}

function Jogo.ir(nome, ...)
  Jogo.tela = TELAS[nome].nova(...)
  collectgarbage("collect")
end

R.preparar()

if DEV.cena == "corrida" then
  Jogo.opcoes = { jogadores = DEV.jogadores or 1, pista = DEV.pista or 1, voltas = DEV.voltas or 3 }
  Jogo.ir("corrida", {
    jogadores = Jogo.opcoes.jogadores, pista = Jogo.opcoes.pista, voltas = Jogo.opcoes.voltas,
    autopiloto = DEV.autopiloto,
  })
else
  Jogo.ir("titulo")
end

-- medidor de desempenho (so no modo de teste do simulador)
local relogio = os and os.clock
local soma_ms, pico_ms, quadros = 0, 0, 0
local texto_desempenho = ""

function update()
  local inicio = DEV.desempenho and relogio and relogio()

  for i = 1, #Palette do ui.palset(i - 1, Palette[i]) end
  ui.camera()
  ui.clip()

  for _ = 1, DEV.turbo or 1 do Jogo.tela:atualizar() end   -- turbo: so no modo de teste
  Jogo.tela:desenhar()

  if inicio then
    local ms = (relogio() - inicio) * 1000
    soma_ms, pico_ms, quadros = soma_ms + ms, math.max(pico_ms, ms), quadros + 1
    if quadros == 60 then
      texto_desempenho = string.format("LUA %.1fms (pico %.1f) MEM %dKB", soma_ms / 60, pico_ms, math.floor(collectgarbage("count")))
      soma_ms, pico_ms, quadros = 0, 0, 0
    end
    ui.camera()
    ui.clip()
    T.p_centro(texto_desempenho, 240, 125, Cores.verde, Cores.preto)
  end
end
