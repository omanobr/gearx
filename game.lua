-- GearX - corrida estilo Top Gear (SNES) para ate 3 jogadores.
-- Ponto de entrada: o Lupi chama update() 60 vezes por segundo.
collectgarbage("generational")

require "palette"      -- gerado pela ferramenta de construcao (todas as cores do jogo)
require "sprites"      -- tabela Sprites com todas as imagens
require "dados_arte"   -- gerado por ferramentas/preparar_arte.py
require "dados_efeitos" -- gerado por ferramentas/gerar_efeitos.py
require "dados_musica"  -- gerado por ferramentas/compor_musica.py
require "dados_fonte"   -- gerado por ferramentas/gerar_fonte.py
require "dados_estrada" -- gerado por ferramentas/gerar_estrada.py

-- Opcoes de teste vindas do simulador (o arquivo nao existe no console).
local ok, dev = pcall(require, "dev_config")
DEV = (ok and type(dev) == "table") and dev or {}

local C = require "config"
local R = require "render"
local Som = require "som"
local Tempo = require "tempo"

local TELAS = {
  titulo = require "telas.titulo",
  menu = require "telas.menu",
  escolha = require "telas.escolha",
  corrida = require "telas.corrida",
  resultado = require "telas.resultado",
  teste = require "telas.teste",
  desempenho = require "telas.desempenho",
}

Jogo = {
  opcoes = { jogadores = 1, pista = 1, voltas = 3 },
  tela = nil,
}

local paleta_falta = 0   -- quadros ate reenviar a paleta (C.PALETA_A_CADA)

function Jogo.ir(nome, ...)
  paleta_falta = 0
  Jogo.nome_tela = nome
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
Som.musica()

-- medidor dos limites do aparelho (so no modo de teste do simulador, opcao "desempenho")
local Medidor = DEV.desempenho and require "medidor"
-- FPS e tempo de cada quadro, no aparelho (rodape e log do console, se C.DIAGNOSTICO;
-- o teste de desempenho usa as medidas sempre)
local Diag = require "diagnostico"
Diag.ligado = C.DIAGNOSTICO

-- DEV.lento (so no simulador): o jogo anda 1 de cada N quadros, como o console quando o
-- quadro demora (frameskip); nos outros so redesenha a mesma cena (o simulador apaga a tela
-- se um quadro nao desenhar nada). Serve para conferir que o jogo anda na velocidade certa.
local pulados = 0

function update(frame)
  local anda = true
  if DEV.lento then
    pulados = (pulados + 1) % DEV.lento
    anda = pulados == 0
  end
  if anda then
    Tempo.atualizar(frame)
    if DEV.lento then Tempo.passo = DEV.lento end
  end
  Diag.inicio()
  if Medidor then Medidor.inicio() end

  -- paleta: so ao trocar de tela e a cada C.PALETA_A_CADA quadros (config.lua); o teste de
  -- desempenho testa sem nenhuma
  if not Jogo.sem_paleta then
    if C.PALETA_TODO_QUADRO or paleta_falta <= 0 then
      local palset, paleta = ui.palset, Palette
      for i = 1, #paleta do palset(i - 1, paleta[i]) end
      paleta_falta = C.PALETA_A_CADA
    end
    paleta_falta = paleta_falta - 1
  end
  ui.camera()
  ui.clip()
  R.novo_quadro()

  if anda then
    for _ = 1, DEV.turbo or 1 do Jogo.tela:atualizar() end   -- turbo: so no modo de teste
  end
  Jogo.tela:desenhar()

  if Medidor then
    Medidor.fim()
    Medidor.desenhar()
  end
  Diag.fim()
  if Diag.ligado then Diag.desenhar() end
end
