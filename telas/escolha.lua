-- Escolha dos carros. Cada jogador, com o seu controle, troca de carro com esquerda/direita
-- e confirma. O carro aparece pintado na cor do jogador (J1 vermelho, J2 azul, J3 amarelo),
-- entao dois jogadores podem escolher o mesmo modelo. Quando todos confirmam, comeca a
-- corrida. Os carros e o jeito de cada um dirigir estao em carros.lua.
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"
local Carros = require "carros"
local Camp = require "campeonato"
local R = require "render"

local Tela = {}
Tela.__index = Tela

local ESPERA = 40   -- quadros entre todos confirmarem e a corrida comecar

-- Barras dos atributos. Cada barra compara os carros entre si: o menor valor de um
-- atributo ganha a barra curta, o maior a barra cheia.
local ATRIBUTOS = { { "VELOCIDADE", "vel" }, { "ACELERAÇÃO", "acel" }, { "CURVAS", "aderencia" } }
local FAIXA = {}
for _, a in ipairs(ATRIBUTOS) do
  local menor, maior = math.huge, -math.huge
  for _, carro in ipairs(Carros) do
    menor, maior = math.min(menor, carro[a[2]]), math.max(maior, carro[a[2]])
  end
  FAIXA[a[2]] = { menor, maior }
end
local function fracao(campo, valor)
  local f = FAIXA[campo]
  if f[2] <= f[1] then return 1 end
  return 0.3 + 0.7 * (valor - f[1]) / (f[2] - f[1])
end

function Tela.nova(opcoes)
  local self = setmetatable({ t = 0, opcoes = opcoes, escolha = {}, pronto = {} }, Tela)
  local anteriores = Jogo.opcoes.carros or {}
  for j = 1, opcoes.jogadores do
    self.escolha[j] = math.min(anteriores[j] or j, #Carros)   -- comeca no carro da ultima vez
    self.pronto[j] = false
  end
  return self
end

function Tela:atualizar()
  self.t = self.t + 1
  if self.saindo then
    self.saindo = self.saindo - 1
    if self.saindo <= 0 then
      local op = self.opcoes
      op.carros = { table.unpack(self.escolha) }
      Jogo.opcoes.carros = op.carros
      if op.campeonato then
        Jogo.ir("corrida", Camp.opcoes(Camp.novo(op)))   -- 1a corrida do campeonato
      else
        Jogo.ir("corrida", op)
      end
    end
    return
  end
  if self.t < 15 then return end
  local todos = true
  for j = 1, self.opcoes.jogadores do
    local p = j - 1
    if not self.pronto[j] then
      local d = (Entrada.dir_de(p) and 1 or 0) - (Entrada.esq_de(p) and 1 or 0)
      if d ~= 0 then self.escolha[j] = (self.escolha[j] - 1 + d) % #Carros + 1 end
      if Entrada.confirmar_de(p) then
        self.pronto[j] = true
      elseif Entrada.voltar_de(p) then
        Jogo.ir("menu", self.opcoes.campeonato and "campeonato" or "corrida")
        return
      end
    elseif Entrada.voltar_de(p) then
      self.pronto[j] = false   -- desistiu: volta a escolher
    end
    todos = todos and self.pronto[j]
  end
  if todos then self.saindo = ESPERA end
end

local function coluna(self, j, x0, larg)
  local cx = x0 + larg // 2
  local modelo = Carros[self.escolha[j]]
  local pronto = self.pronto[j]
  ui.rectfill(x0 + 5, 40, x0 + larg - 6, 246, Cores.painel)
  T.p_centro("JOGADOR " .. j, cx, 46, Cores.jogador[j])
  -- o carro na cor do jogador, com a base sempre na mesma linha (o Uno e mais alto: escada)
  local tam = Arte.carros.tamanho[modelo.modelo].reto[1]
  R.spr(Sprites.img.carros[modelo.modelo][Arte.carros.cores_jogador[j]].reto1, cx - tam[1] // 2, 142 - tam[2])
  if not pronto then
    T.grande("<", x0 + 11, 96, 2, Cores.branco)
    T.grande(">", x0 + larg - 23, 96, 2, Cores.branco)
  end
  T.grande_centro(modelo.nome, cx, 148, 2, pronto and Cores.verde or Cores.amarelo, Cores.preto)
  -- lendario: o texto pisca em amarelo e laranja
  local cor_texto = Cores.cinza
  if modelo.lendario then cor_texto = (self.t // 15) % 2 == 0 and Cores.amarelo or Cores.laranja end
  T.p_centro(modelo.texto, cx, 168, cor_texto)
  local barra = larg - 34
  for a, atributo in ipairs(ATRIBUTOS) do
    local y = 180 + (a - 1) * 18
    T.p(atributo[1], x0 + 17, y, Cores.branco)
    ui.rectfill(x0 + 17, y + 9, x0 + 17 + barra, y + 13, Cores.cinza_escuro)
    local cheio = (barra * fracao(atributo[2], modelo[atributo[2]])) // 1
    ui.rectfill(x0 + 17, y + 9, x0 + 17 + cheio, y + 13, modelo.lendario and Cores.amarelo or Cores.laranja)
  end
  if pronto then
    T.grande_centro("PRONTO!", cx, 232, 2, Cores.verde, Cores.preto)
  elseif (self.t // 20) % 2 == 0 then
    T.p_centro(Entrada.NOME.confirmar .. ": ESCOLHER", cx, 236, Cores.branco)
  end
end

function Tela:desenhar()
  ui.rectfill(0, 0, 480, 270, Cores.preto)   -- sem a corrida de demonstracao atras (pesava no console)
  T.grande_centro("ESCOLHA SEU CARRO", 240, 10, 3, Cores.amarelo, Cores.preto)
  local n = self.opcoes.jogadores
  local larg = 480 // n
  if n == 1 then larg = 240 end
  local x0 = (480 - larg * n) // 2
  for j = 1, n do coluna(self, j, x0 + (j - 1) * larg, larg) end
  local nome = Entrada.NOME
  T.p_centro("ESQ/DIR: TROCAR   " .. nome.confirmar .. ": PRONTO   " .. nome.voltar .. ": VOLTAR",
    240, 254, Cores.cinza, Cores.preto)
end

return Tela
