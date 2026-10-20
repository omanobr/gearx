-- Teste de desempenho (menu > TESTE DE DESEMPENHO). Temporario.
-- Roda sozinho uma lista de testes, uns 2,5 segundos cada, e mede no console quanto tempo
-- leva cada quadro (diagnostico.lua). No fim mostra uma tabela: tire uma foto e mande.
-- Cada linha da tabela tambem vai para o log do console (cabo USB).
--
-- Os primeiros testes medem uma coisa so (retangulos, tiles, imagens, texto...); os ultimos
-- sao a corrida com uma parte desligada de cada vez (R.sem, em render.lua). Comparando,
-- da para saber o que pesa no aparelho (o simulador do PC nao mostra isso).
local C = require "config"
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"
local Demo = require "demo"
local R = require "render"
local Desenho = require "desenho"
local Diag = require "diagnostico"
local TelaCorrida = require "telas.corrida"

local Tela = {}
Tela.__index = Tela

local AQUECER, MEDIR = 30, 120   -- quadros de cada teste: os primeiros nao contam

local function fundo()
  ui.rectfill(0, 0, 479, 269, Cores.painel)
end

local function corrida(t)
  Demo.atualizar()
  Demo.desenhar()
end

local TESTES = {
  { "VAZIO (SO O FUNDO)", fundo },
  { "LUA: 20 MIL INSTRUCOES", function()
    fundo()
    local s = 0
    for i = 1, 6700 do s = s + i * 2 end
  end },
  { "300 RETANGULOS 8X4", function()
    fundo()
    for k = 0, 299 do
      local x, y = (k % 30) * 16, 30 + (k // 30) * 8
      ui.rectfill(x, y, x + 7, y + 3, Cores.amarelo)
    end
  end },
  { "300 RETANGULOS 480X1", function()
    fundo()
    for k = 0, 299 do
      local y = 30 + k % 230
      ui.rectfill(0, y, 479, y, k % 2 == 0 and Cores.cinza or Cores.cinza_escuro)
    end
  end },
  { "4 RETANGULOS DA TELA TODA", function()
    fundo()
    for k = 1, 4 do ui.rectfill(0, 0, 479, 269, k % 2 == 0 and Cores.cinza or Cores.painel) end
  end },
  { "300 TILES DE ESTRADA, 1 FOLHA", function()
    fundo()
    local f = Sprites.img.estrada.l128
    Desenho.lote(f)
    for k = 0, 149 do
      local id = (k % 64) * 2
      ui.tile(f, id, 240, 40 + k)
      ui.tile(f, id + 1024, 112, 40 + k)
    end
  end },
  { "300 TILES, 2 FOLHAS", function()
    fundo()
    local a, b = Sprites.img.estrada.l128, Sprites.img.estrada.l256_1
    for k = 0, 149 do
      ui.tile(a, (k % 64) * 2, 240, 40 + k)
      ui.tile(b, (k % 32) * 2, 0, 40 + k)
    end
  end },
  { "1 IMAGEM GRANDE (45 KB)", function()
    fundo()
    Desenho.spr(Sprites.img.fundos.amanhecer_1, 0, 40)
  end },
  { "3 IMAGENS GRANDES (135 KB)", function()
    fundo()
    local f = Sprites.img.fundos
    Desenho.spr(f.amanhecer_1, 0, 30)
    Desenho.spr(f.amanhecer_2, 60, 90)
    Desenho.spr(f.crepusculo_1, 0, 150)
  end },
  { "30 CARROS, MESMA IMAGEM", function()
    fundo()
    local img = Sprites.img.carros.vermelho.reto5
    for k = 0, 29 do ui.spr(img, (k % 10) * 46, 40 + (k // 10) * 50) end
  end },
  { "30 CARROS, 2 IMAGENS", function()
    fundo()
    local a, b = Sprites.img.carros.vermelho.reto5, Sprites.img.carros.azul.reto5
    for k = 0, 29 do ui.spr(k % 2 == 0 and a or b, (k % 10) * 46, 40 + (k // 10) * 50) end
  end },
  { "100 TEXTOS PEQUENOS", function()
    fundo()
    for k = 0, 99 do ui.print("TESTE 12345", (k % 5) * 90, 30 + (k // 5) * 11, Cores.branco) end
  end },
  { "100 TRIANGULOS", function()
    fundo()
    for k = 0, 99 do
      local x, y = (k % 20) * 24, 40 + (k // 20) * 40
      ui.trisfill(x, y + 30, x + 20, y + 30, x + 10, y, Cores.verde)
    end
  end },
  { "10 TEXTOS GRANDES, RETANGULOS", function()
    fundo()
    for k = 0, 9 do T.grande("1234567890", 20, 30 + k * 20, 2, Cores.laranja) end
  end },
  { "10 TEXTOS GRANDES, TILES", function()
    fundo()
    for k = 0, 9 do T.grande("1234567890", 20, 30 + k * 20, 2, Cores.branco) end
  end },
  { "CORRIDA, ESTRADA DE TILES", corrida, { estrada = "tiles" } },
  { "CORRIDA, ESTRADA DE RETANGULOS", corrida, { estrada = "retangulos" } },
  { "CORRIDA SEM PANORAMA", corrida, { sem = "fundo" } },
  { "CORRIDA SEM OBJETOS", corrida, { sem = "objetos" } },
  { "CORRIDA SEM CARROS", corrida, { sem = "carros" } },
  { "CORRIDA SEM ESTRADA", corrida, { sem = "estrada" } },
  { "CORRIDA 3 JOGADORES", function(self)
    self.c3:atualizar()
    self.c3:desenhar()
  end, { tres = true } },
}

local function restaurar()
  R.sem = {}
  R.estrada, R.estrada_dividida = C.ESTRADA_DESENHO, C.ESTRADA_DIVIDIDA
end

function Tela.nova()
  restaurar()
  Demo.iniciar(Jogo.opcoes.pista)
  local self = setmetatable({ teste = 1, q = 0, resultados = {} }, Tela)
  self:comecar()
  print("GEARX TESTE DE DESEMPENHO: " .. #TESTES .. " testes; relogio " .. (Diag.tem_relogio and "sim" or "nao"))
  return self
end

function Tela:comecar()
  restaurar()
  self.q, self.soma_quadro, self.soma_lua, self.soma7, self.n7 = 0, 0, 0, 0, 0
  local teste = TESTES[self.teste]
  local op = teste and teste[3]
  if not op then return end
  if op.estrada then R.estrada = op.estrada end
  if op.sem then R.sem[op.sem] = true end
  if op.tres then
    self.c3 = TelaCorrida.nova({ jogadores = 3, pista = Jogo.opcoes.pista, voltas = 99, autopiloto = { true, true, true } })
    self.c3.corrida.estado, self.c3.corrida.largada = "correndo", 0
  end
end

function Tela:terminar()
  local n = MEDIR
  local r = {
    nome = TESTES[self.teste][1],
    fps = self.soma_quadro > 0 and n / self.soma_quadro or nil,
    quadro = self.soma_quadro / n * 1000,
    lua = self.soma_lua / n * 1000,
    stat7 = self.n7 > 0 and self.soma7 / self.n7 or nil,
  }
  self.resultados[self.teste] = r
  print(string.format("GEARX TESTE %d %s: fps=%s quadro=%.1fms lua=%.1fms stat7=%s", self.teste, r.nome,
    r.fps and string.format("%.1f", r.fps) or "?", r.quadro, r.lua, r.stat7 and string.format("%.0f", r.stat7) or "?"))
  self.c3 = nil
  self.teste = self.teste + 1
  if self.teste > #TESTES then
    restaurar()
    print("GEARX TESTE DE DESEMPENHO: fim")
  end
  self:comecar()
end

function Tela:atualizar()
  if Entrada.voltar() then
    restaurar()
    Jogo.ir("menu")
    return
  end
  if self.teste > #TESTES then
    if Entrada.confirmar() then
      self.teste, self.resultados = 1, {}
      self:comecar()
    end
    return
  end
  self.q = self.q + 1
  if self.q > AQUECER then
    -- Diag mede o quadro anterior: o tempo dele ja e deste teste
    self.soma_quadro = self.soma_quadro + Diag.ultimo_quadro
    self.soma_lua = self.soma_lua + Diag.ultimo_lua
    if ui.stat then
      local ok, v = pcall(ui.stat, 7)
      if ok and type(v) == "number" then self.soma7, self.n7 = self.soma7 + v, self.n7 + 1 end
    end
  end
  if self.q >= AQUECER + MEDIR then self:terminar() end
end

local function numero(v, formato)
  return v and string.format(formato, v) or "?"
end

local function tabela(self)
  ui.rectfill(0, 0, 479, 269, Cores.preto)
  T.p("TESTE DE DESEMPENHO: TIRE UMA FOTO DESTA TELA E MANDE", 8, 4, Cores.amarelo)
  T.p("TESTE                              FPS   QUADRO MS   LUA MS   STAT7", 8, 16, Cores.cinza)
  for i, teste in ipairs(TESTES) do
    local r = self.resultados[i]
    local y = 27 + (i - 1) * 10
    local cor = i == self.teste and Cores.amarelo or Cores.branco
    T.p(string.format("%2d %s", i, teste[1]), 8, y, cor)
    if r then
      T.p(string.format("%5s %10s %8s %7s", numero(r.fps, "%.1f"), numero(r.fps and r.quadro, "%.1f"),
        numero(r.fps and r.lua, "%.1f"), numero(r.stat7, "%.0f")), 212, y, cor)
    end
  end
end

function Tela:desenhar()
  local teste = TESTES[self.teste]
  if not teste then
    tabela(self)
    local nome = Entrada.NOME
    T.p(nome.confirmar .. ": REPETIR   " .. nome.voltar .. ": SAIR", 8, 252, Cores.cinza)
    return
  end
  teste[2](self)
  ui.camera()
  ui.clip()
  -- cabecalho do teste em andamento
  ui.rectfill(0, 0, 479, 20, Cores.preto)
  T.p(string.format("TESTE %d DE %d: %s", self.teste, #TESTES, teste[1]), 6, 2, Cores.amarelo)
  T.p(Entrada.NOME.voltar .. ": SAIR", 420, 2, Cores.cinza)
  ui.rectfill(6, 13, 6 + (468 * self.q) // (AQUECER + MEDIR), 16, Cores.amarelo)
end

return Tela
