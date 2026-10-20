-- Monta a pista: transforma a lista de trechos (pistas.lua) em segmentos.
--
-- A pista e uma fila de segmentos. Para cada segmento i guardamos:
--   curva[i]    : o quanto a estrada vira neste segmento
--   y[i]        : a altura do comeco do segmento (o fim e y[i + 1])
--   objetos[i]  : lista de objetos na beira (ou nil)
local C = require "config"

local Estrada = {}

local function suave_entrada(a, b, p) return a + (b - a) * p * p end
local function suave(a, b, p) return a + (b - a) * (0.5 - math.cos(p * math.pi) / 2) end

-- Horario do dia h de uma pista (pistas.lua): { nome, fundo, cores, noite }. Pistas com um
-- horario so (as da costa) devolvem o delas.
function Estrada.horario(def, h)
  if def.horarios then return def.horarios[h or def.horario or 1] or def.horarios[1] end
  return { nome = def.hora, fundo = def.fundo, cores = def.cores, noite = def.noite }
end

function Estrada.construir(def, h)
  local hor = Estrada.horario(def, h)
  local curva, y, objetos = {}, {}, {}
  local n, altura_atual = 0, 0
  local curvas_fortes = {}

  local function segmento(c, altura_fim)
    n = n + 1
    curva[n] = c
    y[n] = altura_atual
    altura_atual = altura_fim
  end

  local function trecho(comprimento, c, altura)
    local entra = math.floor(comprimento / 4)
    local sai = entra
    local meio = comprimento - entra - sai
    local y0 = altura_atual
    local y1 = y0 + (altura or 0) * C.SEG
    local inicio = n + 1
    for k = 0, entra - 1 do segmento(suave_entrada(0, c, k / entra), suave(y0, y1, (k + 1) / comprimento)) end
    for k = 0, meio - 1 do segmento(c, suave(y0, y1, (entra + k + 1) / comprimento)) end
    for k = 0, sai - 1 do segmento(suave(c, 0, k / sai), suave(y0, y1, (entra + meio + k + 1) / comprimento)) end
    if math.abs(c) >= 3 then
      curvas_fortes[#curvas_fortes + 1] = { inicio, n, c }
    end
  end

  for _, t in ipairs(def.trechos) do
    trecho(t.comprimento, t.curva or 0, t.altura or 0)
  end
  if math.abs(altura_atual) > 1 then
    trecho(80, 0, -altura_atual / C.SEG)
  end
  altura_atual = 0

  local function colocar(i, objeto)
    i = (i - 1) % n + 1
    objetos[i] = objetos[i] or {}
    table.insert(objetos[i], objeto)
  end

  -- objetos da beira (sorteio sempre igual para a mesma pista)
  math.randomseed(#def.trechos * 7919 + n)
  for _, regra in ipairs(def.objetos or {}) do
    local lados = regra.lado == 2 and { -1, 1 } or { regra.lado }
    for i = 12, n - 4, regra.a_cada do
      for _, lado in ipairs(lados) do
        local x = regra.x + math.random() * (regra.variacao or 0)
        colocar(i, { tipo = regra.tipo, x = lado * x })
      end
    end
  end

  -- placas nas curvas fortes, do lado de fora da curva, apontando para onde a pista vira
  for _, faixa in ipairs(curvas_fortes) do
    local ini, fim, c = faixa[1], faixa[2], faixa[3]
    local lado = c > 0 and -1 or 1
    for i = ini + 4, fim - 4, 6 do
      colocar(i, { tipo = "placa", x = lado * 1.3, seta = c > 0 and 1 or -1 })
    end
  end

  -- portico de largada e chegada
  colocar(2, { tipo = "portico", x = 0 })

  return {
    nome = def.nome,
    n = n,
    comprimento = n * C.SEG,
    curva = curva,
    y = y,
    objetos = objetos,
    cores = hor.cores,
    noite = hor.noite,
    fundo = hor.fundo,
    aderencia = def.aderencia or 1,
    dificuldade = def.dificuldade,
  }
end

return Estrada
