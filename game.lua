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

-- medidor dos limites do aparelho (so no modo de teste do simulador, opcao "desempenho")
local Medidor = DEV.desempenho and require "medidor"

function update()
  if Medidor then Medidor.inicio() end

  local palset, paleta = ui.palset, Palette
  for i = 1, #paleta do palset(i - 1, paleta[i]) end
  ui.camera()
  ui.clip()

  for _ = 1, DEV.turbo or 1 do Jogo.tela:atualizar() end   -- turbo: so no modo de teste
  Jogo.tela:desenhar()

  if Medidor then
    Medidor.fim()
    Medidor.desenhar()
  end
end
