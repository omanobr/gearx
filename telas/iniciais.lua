-- Iniciais do recorde (v0.99b), como nos fliperamas: 3 letras escolhidas uma a uma.
--   cima/baixo: troca a letra    esq/dir: vai para outra letra
--   B: confirma (na 3a letra, grava)    A: volta uma letra
-- Cada jogador usa o proprio controle. Comeca com as iniciais da ultima vez dele.
-- fila: lista de { tipo = "volta" | "campeonato", jogador (1 a 3), pista, valor, carro }
-- (um por recorde novo); depois = { tela, argumentos... } para onde ir no fim (passando pela
-- tabela de recordes, com os novos marcados).
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"
local Pistas = require "pistas"
local Rec = require "recordes"

local Tela = {}
Tela.__index = Tela

local LETRAS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local N = #LETRAS

local function indices(iniciais)
  local t = {}
  for i = 1, 3 do t[i] = LETRAS:find(iniciais:sub(i, i), 1, true) or 1 end
  return t
end

-- o recorde ainda entra na tabela? (outro jogador pode ter passado na frente)
local function ainda_entra(e)
  if e.tipo == "volta" then return Rec.posicao_volta(e.pista, e.valor) end
  return Rec.posicao_campeonato(e.valor)
end

function Tela.nova(fila, depois)
  local self = setmetatable({ fila = fila, depois = depois, i = 0, t = 0, destaques = {} }, Tela)
  self:proximo()
  return self
end

-- passa para o proximo recorde da fila; no fim marca self.fim (a troca de tela e feita em
-- atualizar: Jogo.ir dentro de Tela.nova seria desfeito)
function Tela:proximo()
  repeat
    self.i = self.i + 1
    if not self.fila[self.i] then
      self.fim = true
      return
    end
  until ainda_entra(self.fila[self.i])
  local e = self.fila[self.i]
  self.letras = indices(Rec.iniciais[e.jogador] or "AAA")
  self.casa, self.t = 1, 0
end

function Tela:atualizar()
  if self.fim then
    local primeiro = self.fila[1]
    local aba = primeiro.tipo == "volta" and primeiro.pista or (#Pistas + 1)
    Jogo.ir("recordes", aba, self.destaques, self.depois)
    return
  end
  self.t = self.t + 1
  if self.t < 10 then return end   -- o aperto que abriu a tela nao vale aqui
  local e = self.fila[self.i]
  local p = e.jogador - 1
  local l = self.letras
  if Entrada.cima_de(p) then l[self.casa] = l[self.casa] % N + 1 end
  if Entrada.baixo_de(p) then l[self.casa] = (l[self.casa] - 2) % N + 1 end
  if Entrada.dir_de(p) then self.casa = math.min(3, self.casa + 1) end
  if Entrada.esq_de(p) then self.casa = math.max(1, self.casa - 1) end
  if Entrada.voltar_de(p) then self.casa = math.max(1, self.casa - 1) end
  if Entrada.confirmar_de(p) then
    if self.casa < 3 then
      self.casa = self.casa + 1
    else
      local nome = LETRAS:sub(l[1], l[1]) .. LETRAS:sub(l[2], l[2]) .. LETRAS:sub(l[3], l[3])
      Rec.iniciais[e.jogador] = nome
      if e.tipo == "volta" then Rec.inserir_volta(e.pista, nome, e.valor, e.carro)
      else Rec.inserir_campeonato(nome, e.valor, e.carro) end
      self.destaques[#self.destaques + 1] = { nome, e.valor }
      self:proximo()
    end
  end
end

function Tela:desenhar()
  local e = self.fila[self.i]
  if self.fim or not e then
    ui.rectfill(0, 0, 480, 270, Cores.preto)
    return
  end
  ui.rectfill(0, 0, 480, 270, Cores.preto)
  ui.rectfill(0, 0, 480, 32, Cores.painel)
  ui.rectfill(0, 33, 480, 34, Cores.amarelo)
  T.grande("GEARX", 12, 6, 3, Cores.amarelo)
  T.grande("RECORDE", 12 + T.largura("GEARX", 3) + 16, 11, 2, Cores.cinza)

  if (self.t // 20) % 2 == 0 then T.grande_centro("NOVO RECORDE!", 240, 44, 4, Cores.amarelo) end
  local pos = ainda_entra(e) or 1
  local linha1, valor
  if e.tipo == "volta" then
    linha1 = "MELHOR VOLTA - " .. Pistas[e.pista].nome
    valor = T.tempo(e.valor)
  else
    linha1 = "CAMPEONATO"
    valor = e.valor .. " PONTOS"
  end
  T.grande_centro("J" .. e.jogador, 240, 80, 2, Cores.jogador[e.jogador])
  T.p_centro(linha1, 240, 100, Cores.branco)
  T.grande_centro(valor .. "  -  " .. pos .. "º LUGAR", 240, 112, 2, Cores.branco)

  -- as 3 letras: a escolhida fica num quadro azul, com setas em cima e embaixo
  local l = self.letras
  for i = 1, 3 do
    local x = 240 - 75 + (i - 1) * 50
    local y = 150
    if i == self.casa then
      ui.rectfill(x - 4, y - 4, x + 28, y + 32, Cores.nitro)
      ui.trisfill(x + 4, y - 8, x + 20, y - 8, x + 12, y - 16, Cores.branco)
      ui.trisfill(x + 4, y + 36, x + 20, y + 36, x + 12, y + 44, Cores.branco)
    end
    T.grande(LETRAS:sub(l[i], l[i]), x, y, 4, Cores.amarelo)
  end

  ui.rectfill(0, 238, 480, 270, Cores.painel)
  T.p_centro("CIMA/BAIXO: LETRA   ESQ/DIR: MUDAR   " .. Entrada.NOME.confirmar .. ": OK   " ..
    Entrada.NOME.voltar .. ": VOLTAR UMA LETRA", 240, 243, Cores.cinza)
  T.p_centro("(com o controle do J" .. e.jogador .. ")", 240, 253, Cores.cinza)
end

return Tela
