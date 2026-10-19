-- Tela de teste (temporaria, para descobrir como o console funciona). Abra pelo menu
-- (ultima opcao, TESTE DE TELA). So usa o direcional para navegar: SEGURE para a direita
-- ou para a esquerda por 1 segundo para trocar de pagina (assim da para apertar qualquer
-- botao na pagina de controles sem sair dela).
--   Pagina 1: controles - mostra qual botao do Lupi (BTN_Z, BTN_X...) cada botao do controle aciona.
--   Pagina 2: blocos que deviam ficar cheios; os com listras pretas mostram o que o console
--             deixa de preencher (as linhas verdes da pista).
--   Pagina 3: jeitos de desenhar imagens; cada teste escreve a letra ANTES de desenhar, entao
--             se o console travar, a ultima letra que apareceu sem a imagem e a culpada.
local Cores = require "cores"
local T = require "texto"

local Tela = {}
Tela.__index = Tela

local PAGINAS = 3
local SEGURAR = 60   -- quadros segurando o direcional para trocar de pagina

function Tela.nova()
  return setmetatable({ pagina = 1, dir = 0, esq = 0 }, Tela)
end

local function segurando(botao)
  for p = 0, 2 do
    if ui.btn(botao, p) then return true end
  end
  return false
end

function Tela:atualizar()
  self.dir = segurando(RIGHT) and self.dir + 1 or 0
  self.esq = segurando(LEFT) and self.esq + 1 or 0
  if self.dir >= SEGURAR and self.pagina < PAGINAS then
    self.pagina, self.dir = self.pagina + 1, -9999   -- solte o botao antes de trocar de novo
  elseif self.esq >= SEGURAR then
    if self.pagina == 1 then Jogo.ir("menu") return end
    self.pagina, self.esq = self.pagina - 1, -9999
  end
end

-- pagina 1: um quadrado por botao do Lupi, para cada jogador; acende quando apertado
local BOTOES = {
  { "CIMA", "UP" }, { "BAIXO", "DOWN" }, { "ESQ", "LEFT" }, { "DIR", "RIGHT" },
  { "Z", "BTN_Z" }, { "X", "BTN_X" }, { "Q", "BTN_Q" }, { "E", "BTN_E" }, { "F", "BTN_F" }, { "G", "BTN_G" },
}
local SNES = { BTN_Z = "B", BTN_X = "A", BTN_Q = "X", BTN_E = "Y", BTN_F = "L", BTN_G = "R" }

local function pagina_controles()
  T.p("TESTE 1/3: CONTROLES", 8, 6, Cores.amarelo)
  T.p("Aperte cada botao do controle e veja qual quadrado acende.", 8, 20, Cores.branco)
  T.p("Me diga qual botao acende cada letra (ex.: o botao B acende o Z).", 8, 30, Cores.branco)
  for c, b in ipairs(BOTOES) do
    local x = 70 + (c - 1) * 40
    T.p_centro(b[1], x + 14, 56, Cores.branco)
    if SNES[b[2]] then T.p_centro("(" .. SNES[b[2]] .. "?)", x + 14, 160, Cores.cinza) end
    for j = 0, 2 do
      local y = 70 + j * 28
      if c == 1 then T.p("J" .. (j + 1), 40, y + 6, Cores.jogador[j + 1]) end
      local apertado = ui.btn(_ENV[b[2]], j)
      ui.rectfill(x, y, x + 29, y + 21, apertado and Cores.verde or Cores.cinza_escuro)
    end
  end
  T.p("Entre parenteses: o botao que o jogo acha que e (controle Super Nintendo).", 8, 176, Cores.cinza)
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

local function pagina_preenchimento()
  T.p("TESTE 2/3: PREENCHIMENTO", 8, 6, Cores.amarelo)
  T.p("Cada bloco amarelo devia ser CHEIO. Anote os que tiverem listras pretas.", 8, 18, Cores.branco)
  for k, b in ipairs(BLOCOS) do
    local x = 14 + (k - 1) * 52
    b[4](x, Cores.amarelo)
    T.grande(b[1], x + 12, FUNDO + 8, 2, Cores.branco)
    T.p(b[2], x, FUNDO + 26, Cores.cinza)
    T.p(b[3], x, FUNDO + 36, Cores.cinza)
  end
  T.p("No simulador so o bloco A fica vazio (o retangulo de la nao inclui a borda).", 8, 214, Cores.cinza)
end

-- Pagina 3: a letra vem antes do desenho; a ordem vai do mais seguro ao mais suspeito.
local function pagina_imagens()
  T.p("TESTE 3/3: IMAGENS. Se travar, anote a ULTIMA letra que apareceu.", 8, 6, Cores.amarelo)
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
  T.p("Chegou ate aqui sem travar: tudo certo!", 8, 236, Cores.verde)
end

local PAGINA = { pagina_controles, pagina_preenchimento, pagina_imagens }

function Tela:desenhar()
  ui.rectfill(0, 0, 480, 270, Cores.preto)
  PAGINA[self.pagina]()
  -- rodape: como navegar, e a barrinha de "segurando"
  local proxima = self.pagina < PAGINAS and "SEGURE DIREITA: PROXIMA PAGINA    " or ""
  local voltar = self.pagina == 1 and "SEGURE ESQUERDA: SAIR" or "SEGURE ESQUERDA: PAGINA ANTERIOR"
  T.p(proxima .. voltar, 8, 252, Cores.branco)
  local segurado = math.max(self.dir, self.esq, 0)
  if segurado > 0 then ui.rectfill(8, 264, 8 + segurado * 464 // SEGURAR, 268, Cores.amarelo) end
end

return Tela
