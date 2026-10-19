-- Regras da corrida: movimento dos carros, pilotos do computador, batidas,
-- voltas e classificacao. Nao desenha nada (quem desenha e render.lua e hud.lua).
local C = require "config"
local Estrada = require "estrada"
local Pistas = require "pistas"
local Entrada = require "entrada"
local Objetos = require "objetos"

local Corrida = {}
Corrida.__index = Corrida

local NOMES = { "RAIO", "FAISCA", "TROVAO", "COMETA", "TUFAO", "BALA", "FOGUETE" }
local CORES_JOGADOR = { "vermelho", "azul", "amarelo" }
local CORES_CPU = { "prata", "verde", "laranja", "roxo", "ciano", "prata", "verde" }
local FAIXAS_X = { -2 / 3, 0, 2 / 3 }   -- centro de cada faixa
local LARGADA = 180                      -- quadros de contagem antes do "VAI!"

local floor, abs, min, max = math.floor, math.abs, math.min, math.max
local DT = 1 / 60

function Corrida.nova(op)
  local self = setmetatable({}, Corrida)
  self.pista = Estrada.construir(Pistas[op.pista])
  self.voltas = op.voltas
  self.jogadores = op.jogadores
  self.estado = "contagem"   -- "contagem" -> "correndo" -> "fim"
  self.largada = LARGADA
  self.tempo = 0
  self.chegadas = 0
  self.fim_em = nil
  self.carros, self.humanos, self.ranking = {}, {}, {}

  -- grid: computador na frente, jogadores atras (como no Top Gear)
  local ordem = {}
  for i = 1, C.TOTAL_CARROS - op.jogadores do ordem[#ordem + 1] = { false, i } end
  for j = 1, op.jogadores do ordem[#ordem + 1] = { true, j } end

  local L = self.pista.comprimento
  for g, o in ipairs(ordem) do
    local humano, k = o[1], o[2]
    local carro = {
      z = L - (floor((g - 1) / 2) * 4 + 2) * C.SEG,
      x = (g % 2 == 1) and -0.45 or 0.45,
      vel = 0, volta = -1, dist = 0, posicao = g,
      nitro = C.NITRO_QTD, nitro_t = 0, direcao = 0, fundo_x = 0, batida = 0,
      terminou = false, troca = 60 + g * 25,
    }
    if humano then
      carro.humano, carro.jogador = true, k - 1
      carro.cor, carro.nome = CORES_JOGADOR[k], "J" .. k
      carro.auto = op.autopiloto and op.autopiloto[k] or false
      carro.habilidade = 0.97
      self.humanos[k] = carro
    else
      carro.cor, carro.nome = CORES_CPU[k], NOMES[k]
      carro.habilidade = 0.84 + 0.11 * ((k * 7) % 8) / 7
    end
    carro.alvo_x = carro.x
    self.carros[#self.carros + 1] = carro
    self.ranking[#self.ranking + 1] = carro
  end
  self:classificar()
  return self
end

function Corrida:segmento(z)
  return floor(z / C.SEG) % self.pista.n + 1
end

-- distancia de "a" ate "b" ao longo da pista (positivo = b esta na frente)
function Corrida:distancia(a, b)
  local L = self.pista.comprimento
  local dz = b.z - a.z
  if dz < -L / 2 then dz = dz + L elseif dz > L / 2 then dz = dz - L end
  return dz
end

-- move o carro para tras (batidas), desfazendo a volta se passar da linha
local function recuar(carro, quanto, L)
  carro.z = carro.z - quanto
  if carro.z < 0 then
    carro.z = carro.z + L
    carro.volta = carro.volta - 1
  end
end

-- ---------------------------------------------------------------------------
-- Piloto do computador (tambem usado no "piloto automatico" dos jogadores)
-- ---------------------------------------------------------------------------
-- carro mais proximo a frente na faixa x (ou nil), e a distancia ate ele
local ALCANCE = 14 * C.SEG
function Corrida:carro_na_faixa(carro, x)
  local perto, menor = nil, ALCANCE
  for _, outro in ipairs(self.carros) do
    if outro ~= carro then
      local dz = self:distancia(carro, outro)
      if dz > -C.CARRO_COMP and dz < menor and abs(outro.x - x) < C.CARRO_X * 1.1 then
        perto, menor = outro, dz
      end
    end
  end
  return perto, menor
end

function Corrida:ia(carro)
  local pista = self.pista
  local i = self:segmento(carro.z)

  -- olha as curvas que vem pela frente e decide a velocidade
  local pior = 0
  for k = 0, 30, 3 do
    local c = abs(pista.curva[(i - 1 + k) % pista.n + 1])
    if c > pior then pior = c end
  end
  local limite = 1
  if pior > 0 then limite = min(1, 0.9 / (C.CENTRIFUGA * pior)) end

  -- computador acelera um pouco mais se estiver muito atras dos jogadores
  local ritmo = carro.habilidade
  if not carro.humano and self.lider_humano then
    local atras = self.lider_humano.dist - carro.dist
    if atras > 30 * C.SEG then ritmo = ritmo * 1.06 elseif atras < -60 * C.SEG then ritmo = ritmo * 0.94 end
  end
  local alvo_vel = C.VEL_MAX * ritmo * limite

  -- de vez em quando troca de faixa; se tem carro lento na frente, procura faixa livre
  carro.troca = carro.troca - 1
  if carro.troca <= 0 then
    carro.troca = 150 + math.random(0, 200)
    carro.alvo_x = FAIXAS_X[math.random(1, 3)]
  end
  local frente, dz = self:carro_na_faixa(carro, carro.alvo_x)
  if frente and frente.vel < alvo_vel then
    local melhor, menor = nil, math.huge
    for _, fx in ipairs(FAIXAS_X) do
      if not self:carro_na_faixa(carro, fx) and abs(fx - carro.x) < menor then melhor, menor = fx, abs(fx - carro.x) end
    end
    if melhor then
      carro.alvo_x = melhor
    elseif dz < 4 * C.SEG then
      alvo_vel = min(alvo_vel, frente.vel)   -- sem espaco para passar: acompanha o carro da frente
    end
  end

  local erro = carro.alvo_x - carro.x
  local acel = carro.vel < alvo_vel
  local freia = carro.vel > alvo_vel * 1.1
  local nitro = carro.humano and pior == 0 and carro.nitro > 0 and math.random(1, 400) == 1
  return acel, freia, erro < -0.03, erro > 0.03, nitro
end

-- ---------------------------------------------------------------------------
-- Fisica
-- ---------------------------------------------------------------------------
function Corrida:bater_objetos(carro, i)
  local lista = self.pista.objetos[i]
  if not lista then return end
  for _, o in ipairs(lista) do
    local largura = Objetos.largura[o.tipo]
    if largura and abs(carro.x - o.x) < (C.CARRO_X + largura) / 2 then
      if carro.batida == 0 then
        recuar(carro, C.SEG * 0.6, self.pista.comprimento)
        carro.batida = 30
      end
      carro.vel = min(carro.vel, C.VEL_MAX / 10)
      carro.x = carro.x - (carro.x > 0 and 0.04 or -0.04)
      return
    end
  end
end

function Corrida:mover(carro, acel, freia, esq, dir, nitro)
  local pista = self.pista
  local i = self:segmento(carro.z)

  if nitro and carro.nitro > 0 and carro.nitro_t == 0 then
    carro.nitro = carro.nitro - 1
    carro.nitro_t = C.NITRO_QUADROS
  end
  local vmax = C.VEL_MAX
  if carro.nitro_t > 0 then
    carro.nitro_t = carro.nitro_t - 1
    vmax = vmax * C.NITRO_VEL
  end

  local pct = carro.vel / C.VEL_MAX
  local dx = DT * 2 * pct
  carro.direcao = 0
  if esq then carro.x = carro.x - dx; carro.direcao = -1
  elseif dir then carro.x = carro.x + dx; carro.direcao = 1 end
  carro.x = carro.x - dx * pct * pista.curva[i] * C.CENTRIFUGA

  if acel then carro.vel = carro.vel + C.ACEL * DT * (carro.nitro_t > 0 and 2 or 1)
  elseif freia then carro.vel = carro.vel - C.FREIO * DT
  else carro.vel = carro.vel - C.SOLTO * DT end

  if abs(carro.x) > 1 then
    if carro.vel > C.FORA_LIMITE then carro.vel = carro.vel - C.FORA_FREIO * DT end
    self:bater_objetos(carro, i)
  end
  if carro.vel > vmax then carro.vel = max(vmax, carro.vel - C.SOLTO * DT * 2) end
  if carro.vel < 0 then carro.vel = 0 end
  carro.x = max(-2.5, min(2.5, carro.x))

  carro.z = carro.z + carro.vel * DT
  if carro.z >= pista.comprimento then
    carro.z = carro.z - pista.comprimento
    carro.volta = carro.volta + 1
    if carro.volta >= self.voltas and not carro.terminou then
      self.chegadas = self.chegadas + 1
      carro.terminou = true
      carro.chegada = self.chegadas
      carro.tempo_final = self.tempo
      if carro.humano then carro.auto = true end
    end
  end
  carro.dist = carro.volta * pista.comprimento + carro.z

  -- o fundo desliza nas curvas e volta devagar ao centro nas retas
  if carro.humano then
    local c = pista.curva[i]
    carro.fundo_x = carro.fundo_x + c * pct * C.FUNDO_VEL
    if abs(c) < 0.5 then
      if carro.fundo_x > 0 then carro.fundo_x = max(0, carro.fundo_x - C.FUNDO_VOLTA)
      else carro.fundo_x = min(0, carro.fundo_x + C.FUNDO_VOLTA) end
    end
  end
  if carro.batida > 0 then carro.batida = carro.batida - 1 end
end

function Corrida:colisoes()
  local L = self.pista.comprimento
  for _, a in ipairs(self.carros) do
    for _, b in ipairs(self.carros) do
      if a ~= b and abs(a.x - b.x) < C.CARRO_X * 0.9 then
        local dz = self:distancia(a, b)
        if dz >= 0 and dz < C.CARRO_COMP and a.vel >= b.vel then
          -- "a" bateu na traseira de "b"
          a.vel = b.vel * 0.9
          recuar(a, C.CARRO_COMP - dz, L)
          if a.humano then a.batida = max(a.batida, 10) end
        elseif abs(dz) < C.CARRO_COMP * 0.5 then
          -- lado a lado: empurra um para cada lado
          local lado = a.x < b.x and -1 or 1
          a.x = a.x + lado * 0.02
        end
      end
    end
  end
end

local function ordem(a, b)
  if a.terminou and b.terminou then return a.chegada < b.chegada end
  if a.terminou ~= b.terminou then return a.terminou end
  return a.dist > b.dist
end

function Corrida:classificar()
  table.sort(self.ranking, ordem)
  self.lider_humano = nil
  for p, carro in ipairs(self.ranking) do
    carro.posicao = p
    if carro.humano and not self.lider_humano then self.lider_humano = carro end
  end
end

function Corrida:atualizar()
  if self.estado == "contagem" then
    self.largada = self.largada - 1
    if self.largada <= 0 then self.estado = "correndo" end
    return
  end
  self.tempo = self.tempo + 1

  for _, carro in ipairs(self.carros) do
    local a, f, e, d, n
    if carro.humano and not carro.auto then
      local p = carro.jogador
      a, f, e, d, n = Entrada.acelera(p), Entrada.freia(p), Entrada.esquerda(p), Entrada.direita(p), Entrada.nitro(p)
    else
      a, f, e, d, n = self:ia(carro)
    end
    self:mover(carro, a, f, e, d, n)
  end
  self:colisoes()
  self:classificar()

  if self.estado == "correndo" then
    local todos, algum = true, false
    for _, h in ipairs(self.humanos) do
      if h.terminou then algum = true else todos = false end
    end
    if algum and not self.primeira_chegada then self.primeira_chegada = self.tempo end
    if todos or (algum and self.tempo - self.primeira_chegada > 45 * 60) then
      self.estado = "fim"
      self.fim_em = self.tempo
    end
  end
end

-- Corrida acabou e ja mostrou a chegada por alguns segundos?
function Corrida:acabou()
  return self.estado == "fim" and self.tempo - self.fim_em > 150
end

return Corrida
