-- Tela de abertura: a marca Lian Games antes do titulo, num dos logos de Abertura (com a elfa
-- ou com o elfo), sorteado cada vez que o jogo abre. Clareia, fica um pouco e escurece
-- (fade): o jogo manda a paleta escurecida (Jogo.brilho, em game.lua), entao todas as cores
-- da tela vao juntas do preto ao normal. B, A ou START pulam (comeca a escurecer na hora).
-- Logos: ferramentas/gerar_abertura.py (img/abertura, dados_abertura.lua).
local Entrada = require "entrada"
local Desenho = require "desenho"
local Tempo = require "tempo"

local Tela = {}
Tela.__index = Tela

local ENTRA, FICA, SAI = 40, 120, 40   -- quadros (1/60 s): clareando, parada, escurecendo
local FIM = ENTRA + FICA + SAI

-- Sorteio: math.random (o Lua comeca com uma semente tirada do relogio) mais o numero do
-- quadro do console no primeiro desenho (outra fonte, caso o relogio do console nao ajude).
-- O resultado vai para o log ("GEARX ABERTURA"), para conferir no aparelho que varia.
local function sortear()
  local n = #Abertura
  local r = math.random(n) - 1
  local f = math.floor(Tempo.frame or 0)
  local logo = Abertura[(r + f) % n + 1]
  print(string.format("GEARX ABERTURA logo=%s random=%d frame=%d", logo.nome, r, f))
  return logo
end

function Tela.nova()
  Jogo.brilho = 0
  return setmetatable({ t = 0, abertura = true }, Tela)
end

function Tela:atualizar()
  local t = self.t + Tempo.passo
  -- pular: escurece a partir do brilho de agora (sem piscar)
  if t < ENTRA + FICA and (Entrada.confirmar() or Entrada.voltar() or Entrada.pausar()) then
    t = FIM - SAI * math.min(t / ENTRA, 1)
  end
  self.t = t
  if t >= FIM then
    Jogo.ir("titulo", true)
  elseif t < ENTRA then
    Jogo.brilho = t / ENTRA
  elseif t < ENTRA + FICA then
    Jogo.brilho = 1
  else
    Jogo.brilho = (FIM - t) / SAI
  end
end

function Tela:desenhar()
  local logo = self.logo
  if not logo then   -- no primeiro desenho (Tempo.frame ja tem o quadro do console)
    logo = sortear()
    self.logo = logo
    self.cima = Sprites.img.abertura[logo.nome .. "_cima"]
    self.baixo = Sprites.img.abertura[logo.nome .. "_baixo"]
  end
  ui.rectfill(0, 0, 480, 270, logo.fundo)
  local x = 240 - logo.largura // 2
  local y = 135 - (logo.altura[1] + logo.altura[2]) // 2
  Desenho.spr(self.cima, x, y)
  Desenho.spr(self.baixo, x, y + logo.altura[1])
end

return Tela
