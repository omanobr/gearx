-- Tela de teste do desenho (temporaria, para descobrir como o console desenha).
-- Abra com R no titulo. Pagina 1: blocos que deviam ficar cheios; os que aparecerem com
-- listras pretas mostram o que o console deixa de preencher (as linhas verdes da pista).
-- Pagina 2: jeitos de desenhar imagens; cada teste escreve a letra ANTES de desenhar, entao
-- se o console travar, a ultima letra que apareceu sem a imagem e a culpada.
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"

local Tela = {}
Tela.__index = Tela

function Tela.nova()
  return setmetatable({ t = 0, pagina = 1 }, Tela)
end

function Tela:atualizar()
  self.t = self.t + 1
  if self.t < 20 then return end
  if Entrada.voltar() then
    Jogo.ir("titulo")
  elseif Entrada.confirmar() and self.pagina == 1 then
    self.pagina, self.t = 2, 0
  end
end

local TOPO, FUNDO = 44, 140   -- faixa vertical dos blocos (96 linhas)
local LARG = 36

-- trapezio retangular como os blocos da pista: linhas y2 (topo) a y1 (base), 2 triangulos
local function trapezio(x, y2, y1, cor)
  ui.trisfill(x, y1, x + LARG, y1, x + LARG, y2, cor)
  ui.trisfill(x, y1, x + LARG, y2, x, y2, cor)
end

local BLOCOS = {
  { "A", "RET", "1 LINHA", function(x, c) for y = TOPO, FUNDO - 1 do ui.rectfill(x, y, x + LARG, y, c) end end },
  { "B", "RET", "2 LINHAS", function(x, c) for y = TOPO, FUNDO - 1 do ui.rectfill(x, y, x + LARG, y + 1, c) end end },
  { "C", "TRI", "ALT 2", function(x, c) for y = TOPO, FUNDO - 1, 2 do trapezio(x, y, y + 1, c) end end },
  { "D", "TRI", "ALT 4", function(x, c) for y = TOPO, FUNDO - 1, 4 do trapezio(x, y, y + 3, c) end end },
  { "E", "TRI", "ALT 8", function(x, c) for y = TOPO, FUNDO - 1, 8 do trapezio(x, y, y + 7, c) end end },
  { "F", "TRI", "V0.5", function(x, c) for y = TOPO, FUNDO - 1, 2 do trapezio(x, y, y + 2, c) end end },
  { "G", "TRI", "V0.6", function(x, c) for y = TOPO, FUNDO - 1, 2 do trapezio(x, y - 1, y + 3, c) end end },
  { "H", "TRI", "X FRAC.", function(x, c) for y = TOPO, FUNDO - 1, 4 do trapezio(x + 0.5, y, y + 3, c) end end },
  { "I", "LINHA", "1 LINHA", function(x, c) for y = TOPO, FUNDO - 1 do ui.line(x, y, x + LARG, y, c) end end },
}

local function pagina1()
  T.p("TESTE DE TELA 1/2: PREENCHIMENTO", 8, 6, Cores.amarelo)
  T.p("Cada bloco amarelo devia ser CHEIO. Anote os que tiverem listras pretas.", 8, 18, Cores.branco)
  for k, b in ipairs(BLOCOS) do
    local x = 14 + (k - 1) * 52
    b[4](x, Cores.amarelo)
    T.grande(b[1], x + 12, FUNDO + 8, 2, Cores.branco)
    T.p(b[2], x, FUNDO + 26, Cores.cinza)
    T.p(b[3], x, FUNDO + 36, Cores.cinza)
  end
  T.p("No simulador so o bloco A fica vazio (o retangulo de la nao inclui a borda).", 8, 214, Cores.cinza)
  T.p(Entrada.NOME.confirmar .. ": PAGINA 2 (IMAGENS, PODE TRAVAR)    " .. Entrada.NOME.voltar .. ": VOLTAR", 8, 250, Cores.branco)
end

-- Pagina 2: a letra vem antes do desenho; a ordem vai do mais seguro ao mais suspeito.
local function pagina2()
  T.p("TESTE DE TELA 2/2: IMAGENS. Se travar, anote a ULTIMA letra que apareceu.", 8, 6, Cores.amarelo)
  local carro, pano = Sprites.img.carros, Sprites.img.fundos
  local function celula(k, letra, texto)
    local x, y = 10 + ((k - 1) % 3) * 158, 30 + ((k - 1) // 3) * 110
    T.grande(letra, x, y, 2, Cores.branco)
    T.p(texto, x + 16, y + 2, Cores.cinza)
    return x, y + 18
  end
  local x, y = celula(1, "A", "1 IMAGEM")
  ui.spr(carro.vermelho.reto3, x, y)
  x, y = celula(2, "B", "MESMA 2X SEGUIDAS")
  ui.spr(carro.azul.reto3, x, y)
  ui.spr(carro.azul.reto3, x + 70, y + 20)
  x, y = celula(3, "C", "2X, RETANGULO NO MEIO")
  ui.spr(carro.amarelo.reto3, x, y)
  ui.rectfill(x + 66, y, x + 70, y + 30, Cores.branco)
  ui.spr(carro.amarelo.reto3, x + 74, y + 20)
  x, y = celula(4, "D", "PANORAMA 2X SEGUIDAS")
  ui.spr(pano.amanhecer_baixo_1, x, y)
  ui.spr(pano.amanhecer_baixo_1, x + 20, y + 30)
  x, y = celula(5, "E", "CAMERA NEGATIVA")
  ui.camera(-x, -y)
  ui.spr(carro.verde.reto3, 0, 0)
  ui.camera()
  x, y = celula(6, "F", "2X, RECORTE NO MEIO")
  ui.spr(carro.roxo.reto3, x, y)
  ui.clip(x + 60, y, 90, 80)
  ui.spr(carro.roxo.reto3, x + 60, y + 20)
  ui.clip()
  T.p("Chegou ate aqui sem travar: tudo certo! " .. Entrada.NOME.voltar .. ": VOLTAR", 8, 250, Cores.verde)
end

function Tela:desenhar()
  ui.rectfill(0, 0, 480, 270, Cores.preto)
  if self.pagina == 1 then pagina1() else pagina2() end
end

return Tela
