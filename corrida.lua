-- Regras da corrida: movimento dos carros, pilotos do computador, batidas,
-- voltas e classificacao. Nao desenha nada (quem desenha e render.lua e hud.lua).
local C = require "config"
local Estrada = require "estrada"
local Pistas = require "pistas"
local Entrada = require "entrada"
local Objetos = require "objetos"
local Carros = require "carros"
local Tempo = require "tempo"

local Corrida = {}
Corrida.__index = Corrida

local NOMES = { "RAIO", "FAISCA", "TROVAO", "COMETA", "TUFAO", "BALA", "FOGUETE" }
local FAIXAS_X = { -2 / 3, 0, 2 / 3 }   -- centro de cada faixa
local LARGADA = 180                      -- quadros de contagem antes do "VAI!"

local floor, abs, min, max = math.floor, math.abs, math.min, math.max
local DT = 1 / 60
-- Tudo aqui conta em 1/60 de segundo. Por quadro, o jogo anda self.passo deles (tempo.lua):
-- 1 a 60 FPS, 2 a 30 FPS... Assim a corrida tem a velocidade certa mesmo com o console lento.

function Corrida.nova(op)
  local self = setmetatable({}, Corrida)
  self.pista = Estrada.construir(Pistas[op.pista])
  self.voltas = op.voltas
  self.jogadores = op.jogadores
  self.estado = "contagem"   -- "contagem" -> "correndo" -> "fim"
  self.largada = LARGADA
  self.tempo = 0
  self.passo = 1
  self.pensa = 0             -- os pilotos do computador pensam em quadros alternados
  self.chegadas = 0
  self.fim_em = nil
  self.carros, self.humanos, self.ranking = {}, {}, {}
  self.itens, self.item_seg = {}, {}   -- nitros na pista (lista e por segmento, para desenhar)
  self.prox_item = C.ITEM_INTERVALO

  -- carro de cada jogador (indice em carros.lua), pintado na cor do jogador. O computador
  -- usa outros modelos e cores (dados_arte.lua): modelo e cor nunca repetem juntos.
  local escolhidos = op.carros or { 1, 2, 3 }
  local A = Arte.carros
  local cores_jogador, modelos_cpu, cores_cpu = A.cores_jogador, A.modelos_cpu, A.cores_cpu

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
      dano = 0, pegou = 0,                       -- dano das batidas (0 a 1); pisca ao pegar nitro
      mult_vel = 1, mult_acel = 1, aderencia = 1,  -- jeito de dirigir (carros.lua)
    }
    if humano then
      local modelo = Carros[escolhidos[k]]
      carro.humano, carro.jogador = true, k - 1
      carro.modelo, carro.cor, carro.nome = modelo.modelo, cores_jogador[k], "J" .. k
      carro.mult_vel, carro.mult_acel, carro.aderencia = modelo.vel, modelo.acel, modelo.aderencia
      carro.auto = op.autopiloto and op.autopiloto[k] or false
      carro.habilidade = 0.97
      self.humanos[k] = carro
    else
      carro.modelo = modelos_cpu[(k - 1) % #modelos_cpu + 1]
      carro.cor, carro.nome = cores_cpu[(k - 1) % #cores_cpu + 1], NOMES[k]
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
-- carro mais proximo a frente na faixa x (ou nil), e a distancia ate ele.
-- (Laco com numero e a distancia calculada aqui mesmo: roda varias vezes por carro em todo
-- quadro, e o console executa poucas instrucoes Lua por quadro.)
local ALCANCE = 14 * C.SEG
local FAIXA_OCUPADA = C.CARRO_X * 1.1
function Corrida:carro_na_faixa(carro, x)
  local perto, menor = nil, ALCANCE
  local carros, L = self.carros, self.pista.comprimento
  local meio, cz = L / 2, carro.z
  for k = 1, #carros do
    local outro = carros[k]
    if outro ~= carro and abs(outro.x - x) < FAIXA_OCUPADA then
      local dz = outro.z - cz
      if dz < -meio then dz = dz + L elseif dz > meio then dz = dz - L end
      if dz > -C.CARRO_COMP and dz < menor then perto, menor = outro, dz end
    end
  end
  return perto, menor
end

-- pensar = fazer a parte cara (olhar as curvas e os carros a frente). Nos outros quadros o
-- piloto so segue o que decidiu (velocidade alvo e faixa): metade do trabalho no console.
function Corrida:ia(carro, pensar)
  carro.troca = carro.troca - self.passo
  if pensar or not carro.ia_vel then self:ia_pensar(carro) end
  local alvo_vel = carro.ia_vel
  local erro = carro.alvo_x - carro.x
  local acel = carro.vel < alvo_vel
  local freia = carro.vel > alvo_vel * 1.1
  local nitro = carro.humano and carro.ia_pior == 0 and carro.nitro > 0 and math.random(1, 400) == 1
  return acel, freia, erro < -0.03, erro > 0.03, nitro
end

function Corrida:ia_pensar(carro)
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
  carro.ia_vel, carro.ia_pior = alvo_vel, pior
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
      if carro.batida <= 0 then
        carro.dano = min(1, carro.dano + C.DANO_OBJETO * min(1, carro.vel / C.VEL_MAX))
        recuar(carro, C.SEG * 0.6, self.pista.comprimento)
        carro.batida = 30
      end
      carro.vel = min(carro.vel, C.VEL_MAX / 10)
      carro.x = carro.x - (carro.x > 0 and 0.04 or -0.04)
      return true
    end
  end
end

function Corrida:mover(carro, acel, freia, esq, dir, nitro)
  local pista = self.pista
  local i = self:segmento(carro.z)
  local p = self.passo
  local dt = DT * p

  if nitro and carro.nitro > 0 and carro.nitro_t <= 0 then
    carro.nitro = carro.nitro - 1
    carro.nitro_t = C.NITRO_QUADROS
  end
  -- velocidade maxima: do carro, menos o dano, menos o arrasto dos pneus na curva
  -- (curva forte = mais perda; carro com mais aderencia perde menos)
  local curva = pista.curva[i]
  local vmax = C.VEL_MAX * carro.mult_vel * (1 - C.DANO_VEL * carro.dano)
    * (1 - C.CURVA_PERDA * abs(curva) / carro.aderencia)
  if carro.nitro_t > 0 then
    carro.nitro_t = max(0, carro.nitro_t - p)
    vmax = vmax * C.NITRO_VEL
  end

  -- a curva empurra para fora; a toda, numa curva forte e longa, so virar nao segura
  local pct = carro.vel / C.VEL_MAX
  local dx = dt * 2 * pct
  carro.direcao = 0
  if esq then carro.x = carro.x - dx; carro.direcao = -1
  elseif dir then carro.x = carro.x + dx; carro.direcao = 1 end
  carro.x = carro.x - dx * pct * curva * C.CENTRIFUGA / carro.aderencia

  local acel_carro = C.ACEL * carro.mult_acel * (1 - C.DANO_ACEL * carro.dano)
  if acel then carro.vel = carro.vel + acel_carro * dt * (carro.nitro_t > 0 and 2 or 1)
  elseif freia then carro.vel = carro.vel - C.FREIO * dt
  else carro.vel = carro.vel - C.SOLTO * dt end

  if abs(carro.x) > 1 then
    if carro.vel > C.FORA_LIMITE then carro.vel = carro.vel - C.FORA_FREIO * dt end
    -- objetos dos segmentos por onde o carro passa neste quadro (com o console lento ele
    -- anda mais de um segmento por quadro e passaria "por dentro" dos postes)
    for k = 0, (carro.vel * dt) // C.SEG do
      if self:bater_objetos(carro, (i - 1 + k) % pista.n + 1) then break end
    end
  end
  if carro.vel > vmax then carro.vel = max(vmax, carro.vel - C.SOLTO * dt * 2) end
  if carro.vel < 0 then carro.vel = 0 end
  carro.x = max(-2.5, min(2.5, carro.x))

  carro.z = carro.z + carro.vel * dt
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
    carro.fundo_x = carro.fundo_x + c * pct * C.FUNDO_VEL * p
    if abs(c) < 0.5 then
      if carro.fundo_x > 0 then carro.fundo_x = max(0, carro.fundo_x - C.FUNDO_VOLTA * p)
      else carro.fundo_x = min(0, carro.fundo_x + C.FUNDO_VOLTA * p) end
    end
  end
  if carro.batida > 0 then carro.batida = max(0, carro.batida - p) end
  if carro.pegou > 0 then carro.pegou = max(0, carro.pegou - p) end
end

-- ---------------------------------------------------------------------------
-- Nitros na pista: aparecem so na frente de jogadores que NAO estao em 1o lugar, com
-- mais chance para quem esta mais atras. Quem lidera ja passou por aquele trecho, entao
-- o nitro ajuda quem vem atras (o computador nao pega).
-- ---------------------------------------------------------------------------
function Corrida:quem_ganha_item()
  local lider = self.ranking[1]
  local total = 0
  for _, h in ipairs(self.humanos) do
    if not h.terminou and h ~= lider then total = total + (lider.dist - h.dist) / C.SEG + 10 end
  end
  if total <= 0 then return nil end
  local sorteio = math.random() * total
  for _, h in ipairs(self.humanos) do
    if not h.terminou and h ~= lider then
      sorteio = sorteio - ((lider.dist - h.dist) / C.SEG + 10)
      if sorteio <= 0 then return h end
    end
  end
end

local function tirar_item(self, k)
  local it = table.remove(self.itens, k)
  if self.item_seg[it.seg] == it then self.item_seg[it.seg] = nil end
end

function Corrida:itens_atualizar()
  local itens, N, L = self.itens, self.pista.n, self.pista.comprimento
  local p = self.passo
  for k = #itens, 1, -1 do
    local it = itens[k]
    it.vida = it.vida - p
    local pegou = false
    for _, h in ipairs(self.humanos) do
      local dz = (it.z - h.z) % L
      if dz > L / 2 then dz = dz - L end
      -- (o carro pode ter passado da lata neste quadro: ate vel * tempo do quadro para tras)
      if not pegou and dz < C.CARRO_COMP and dz > -(C.CARRO_COMP + h.vel * DT * p) and abs(it.x - h.x) < C.CARRO_X then
        if h.nitro < C.NITRO_MAX then h.nitro = h.nitro + 1 end
        h.pegou = 40
        pegou = true
      end
    end
    if pegou or it.vida <= 0 then tirar_item(self, k) end
  end
  self.prox_item = self.prox_item - p
  if self.prox_item <= 0 then
    self.prox_item = C.ITEM_INTERVALO // 2 + math.random(0, C.ITEM_INTERVALO)
    local alvo = #itens < C.ITEM_MAX and self:quem_ganha_item()
    if alvo then
      local seg = (self:segmento(alvo.z) + math.random(C.ITEM_DIST[1], C.ITEM_DIST[2]) - 1) % N + 1
      if not self.item_seg[seg] then
        local it = { seg = seg, z = (seg - 1) * C.SEG + C.SEG / 2, x = FAIXAS_X[math.random(1, 3)], vida = C.ITEM_VIDA }
        itens[#itens + 1] = it
        self.item_seg[seg] = it
      end
    end
  end
end

function Corrida:colisoes()
  local L = self.pista.comprimento
  local meio, perto = L / 2, C.CARRO_X * 0.9
  local dt = DT * self.passo
  local carros = self.carros
  local n = #carros
  for i = 1, n do
    local a = carros[i]
    for j = 1, n do
      local b = carros[j]
      if a ~= b and abs(a.x - b.x) < perto then
        local dz = b.z - a.z   -- distancia de a ate b ao longo da pista (como Corrida:distancia)
        if dz < -meio then dz = dz + L elseif dz > meio then dz = dz - L end
        -- dz negativo pequeno: "a" passou por dentro de "b" neste quadro (quadro longo)
        if dz >= -(a.vel - b.vel) * dt and dz < C.CARRO_COMP and a.vel >= b.vel then
          -- "a" bateu na traseira de "b": dano conforme a diferenca de velocidade
          a.dano = min(1, a.dano + C.DANO_BATIDA * (a.vel - b.vel) / C.VEL_MAX)
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
  local p = Tempo.passo
  self.passo = p
  if self.estado == "contagem" then
    self.largada = self.largada - p
    if self.largada <= 0 then self.estado = "correndo" end
    return
  end
  self.tempo = self.tempo + p
  self.pensa = 1 - self.pensa

  local carros = self.carros
  for k = 1, #carros do
    local carro = carros[k]
    local a, f, e, d, n
    if carro.humano and not carro.auto then
      local p = carro.jogador
      a, f, e, d, n = Entrada.acelera(p), Entrada.freia(p), Entrada.esquerda(p), Entrada.direita(p), Entrada.nitro(p)
    else
      a, f, e, d, n = self:ia(carro, k % 2 == self.pensa)
    end
    self:mover(carro, a, f, e, d, n)
  end
  self:colisoes()
  self:classificar()
  if self.estado == "correndo" then self:itens_atualizar() end

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
