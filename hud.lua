-- Painel de cada jogador: posicao, volta, tempo, velocidade, marcha e nitro.
-- Tambem desenha a contagem regressiva e a mensagem de chegada.
local C = require "config"
local Cores = require "cores"
local T = require "texto"

local Hud = {}

local floor = math.floor

local function marcha(pct)
  if pct < 0.12 then return 1 elseif pct < 0.3 then return 2 elseif pct < 0.5 then return 3
  elseif pct < 0.72 then return 4 end
  return 5
end

-- Nitros guardados (ate C.NITRO_MAX); piscam quando o jogador pega um na pista.
local function nitro(carro, x, y)
  local pisca = carro.pegou > 0 and (carro.pegou // 5) % 2 == 0
  T.p("NITRO", x, y, pisca and Cores.amarelo or Cores.branco, Cores.preto)
  for i = 1, C.NITRO_MAX do
    local bx = x + 32 + (i - 1) * 10
    local cor = i <= carro.nitro and Cores.laranja or Cores.cinza_escuro
    if carro.nitro_t > 0 and i == carro.nitro + 1 and (carro.nitro_t // 4) % 2 == 0 then cor = Cores.amarelo end
    if pisca and i == carro.nitro then cor = Cores.branco end
    ui.rectfill(bx, y, bx + 8, y + 8, cor)
  end
end

-- Dano das batidas: barra que vai de verde a vermelho (menos velocidade e aceleracao).
local function dano(carro, x, y, largura)
  T.p("DANO", x, y, Cores.branco, Cores.preto)
  local bx = x + 32
  ui.rectfill(bx, y + 1, bx + largura, y + 7, Cores.cinza_escuro)
  local cheio = (carro.dano * largura) // 1
  if cheio > 0 then
    local cor = carro.dano < 0.34 and Cores.verde or (carro.dano < 0.67 and Cores.amarelo or Cores.vermelho)
    ui.rectfill(bx, y + 1, bx + cheio, y + 7, cor)
  end
end

function Hud.desenhar(corrida, carro, v, varios)
  local W, H = v.w, v.h
  local grande = not varios
  local pct = carro.vel / C.VEL_MAX
  local kmh = floor(pct * C.KMH + 0.5)
  local volta = math.max(1, math.min(corrida.voltas, carro.volta + 1))

  if grande then
    T.p("POSIÇÃO", 8, 6, Cores.branco, Cores.preto)
    T.grande(tostring(carro.posicao), 8, 17, 5, Cores.amarelo, Cores.preto)
    T.grande("/" .. C.TOTAL_CARROS, 8 + T.largura(tostring(carro.posicao), 5) + 6, 35, 2, Cores.branco, Cores.preto)
    T.p_direita("VOLTA", W - 8, 6, Cores.branco, Cores.preto)
    T.grande(volta .. "/" .. corrida.voltas, W - 8 - T.largura(volta .. "/" .. corrida.voltas, 3), 17, 3, Cores.amarelo, Cores.preto)
    T.p_centro(T.tempo(corrida.tempo), W / 2, 6, Cores.branco, Cores.preto)
    nitro(carro, 8, H - 14)
    dano(carro, 8, H - 26, 48)
    local vel = string.format("%3d", kmh)
    T.grande(vel, W - 44 - T.largura(vel, 3), H - 28, 3, Cores.branco, Cores.preto)
    T.p("KM/H", W - 36, H - 14, Cores.branco, Cores.preto)
    T.p("M" .. marcha(pct), W - 36, H - 26, Cores.amarelo, Cores.preto)
  else
    T.p(carro.nome, 5, 4, Cores.jogador[carro.jogador + 1], Cores.preto)
    T.grande(tostring(carro.posicao), 5, 14, 3, Cores.amarelo, Cores.preto)
    T.p("/" .. C.TOTAL_CARROS, 5 + T.largura(tostring(carro.posicao), 3) + 3, 22, Cores.branco, Cores.preto)
    T.p_direita("VOLTA " .. volta .. "/" .. corrida.voltas, W - 5, 4, Cores.branco, Cores.preto)
    T.p_direita(T.tempo(corrida.tempo), W - 5, 14, Cores.branco, Cores.preto)
    nitro(carro, 5, H - 12)
    dano(carro, 5, H - 23, 48)
    local vel = string.format("%3d", kmh)
    T.grande(vel, W - 34 - T.largura(vel, 2), H - 17, 2, Cores.branco, Cores.preto)
    T.p("KM/H", W - 29, H - 12, Cores.branco, Cores.preto)
  end

  -- contagem regressiva e "VAI!"
  local e = grande and 9 or 5
  if corrida.estado == "contagem" then
    local n = math.ceil(corrida.largada / 60)
    T.grande_centro(tostring(n), W / 2, H * 0.22, e, n == 1 and Cores.verde or Cores.amarelo, Cores.preto)
  elseif corrida.tempo < 50 then
    T.grande_centro("VAI!", W / 2, H * 0.22, e, Cores.verde, Cores.preto)
  end

  if carro.terminou then
    local e2 = grande and 5 or 3
    T.grande_centro("CHEGADA!", W / 2, H * 0.2, e2, Cores.amarelo, Cores.preto)
    T.grande_centro(carro.chegada .. "º LUGAR", W / 2, H * 0.2 + e2 * 10, e2, Cores.branco, Cores.preto)
  elseif carro.volta == corrida.voltas - 1 and corrida.voltas > 1 and carro.z < 25 * C.SEG and carro.volta >= 0 then
    T.grande_centro("ÚLTIMA VOLTA", W / 2, H * 0.25, grande and 3 or 2, Cores.amarelo, Cores.preto)
  end
end

-- Painel do 4o quadrante (modo 3 jogadores): classificacao ao vivo.
function Hud.classificacao(corrida, v)
  ui.rectfill(v.x, v.y, v.x + v.w, v.y + v.h, Cores.painel)
  local x, y = v.x + 10, v.y + 6
  T.p(corrida.pista.nome, x, y, Cores.amarelo)
  T.p("CLASSIFICAÇÃO", x, y + 12, Cores.cinza)
  for p, carro in ipairs(corrida.ranking) do
    local ly = y + 24 + (p - 1) * 13
    local cor = carro.humano and Cores.jogador[carro.jogador + 1] or Cores.branco
    T.p(p .. "º", x, ly, Cores.cinza)
    T.p(carro.nome, x + 22, ly, cor)
    local info
    if carro.terminou then info = "CHEGOU" else info = "VOLTA " .. math.max(1, math.min(corrida.voltas, carro.volta + 1)) end
    T.p_direita(info, v.x + v.w - 10, ly, carro.humano and cor or Cores.cinza)
  end
end

return Hud
