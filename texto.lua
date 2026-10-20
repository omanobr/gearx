-- Texto. Duas opcoes:
--   T.p(...)       texto pequeno, com a fonte do Lupi (5x8, so letras sem acento)
--   T.grande(...)  texto grande, aceita acentos e escala. Desenhado com TILES (uma letra =
--                  um tile, sombra preta ja desenhada) quando existe folha para aquele tamanho
--                  e cor (ferramentas/gerar_fonte.py, dados_fonte.lua); senao, com retangulos.
--                  O desenvolvedor do Lupi avisou: letra de retangulos pesa no console.
--
-- Acentos: o console guarda o texto em Latin-9 (1 byte por letra) e nao tem a biblioteca
-- utf8 completa; o simulador e os editores usam UTF-8 (2 bytes por letra acentuada).
-- Este arquivo entende os dois jeitos sozinho, sem usar utf8.* (que quebra no console),
-- e o proprio codigo deste arquivo so tem caracteres ASCII.
local Cores = require "cores"
local Desenho = require "desenho"

local T = {}

local byte, char = string.byte, string.char

-- Le a letra que comeca na posicao i de s. Devolve o codigo dela (Latin-1/Latin-9,
-- iguais para as letras do portugues) e a posicao da letra seguinte.
local function codigo(s, i)
  local b = byte(s, i)
  if b == 0xC2 or b == 0xC3 then          -- UTF-8 de 2 bytes (simulador, editores)
    local b2 = byte(s, i + 1)
    if b2 and b2 >= 0x80 and b2 <= 0xBF then return (b - 0xC2) * 64 + b2, i + 2 end
  end
  return b, i + 1                          -- ASCII ou Latin-9 (console)
end

-- quantas letras tem o texto (nos dois jeitos)
local function letras(s)
  if not s:find("[\x80-\xFF]") then return #s end
  local n, i = 0, 1
  while i <= #s do
    local _
    _, i = codigo(s, i)
    n = n + 1
  end
  return n
end

-- Fonte grande: cada letra tem 7 linhas de 5 pixels (bit 16 = pixel da esquerda).
local FONTE = {
  A = {14, 17, 17, 31, 17, 17, 17}, B = {30, 17, 17, 30, 17, 17, 30}, C = {14, 17, 16, 16, 16, 17, 14},
  D = {30, 17, 17, 17, 17, 17, 30}, E = {31, 16, 16, 30, 16, 16, 31}, F = {31, 16, 16, 30, 16, 16, 16},
  G = {14, 17, 16, 23, 17, 17, 15}, H = {17, 17, 17, 31, 17, 17, 17}, I = {14, 4, 4, 4, 4, 4, 14},
  J = {7, 2, 2, 2, 2, 18, 12}, K = {17, 18, 20, 24, 20, 18, 17}, L = {16, 16, 16, 16, 16, 16, 31},
  M = {17, 27, 21, 21, 17, 17, 17}, N = {17, 17, 25, 21, 19, 17, 17}, O = {14, 17, 17, 17, 17, 17, 14},
  P = {30, 17, 17, 30, 16, 16, 16}, Q = {14, 17, 17, 17, 21, 18, 13}, R = {30, 17, 17, 30, 20, 18, 17},
  S = {15, 16, 16, 14, 1, 1, 30}, T = {31, 4, 4, 4, 4, 4, 4}, U = {17, 17, 17, 17, 17, 17, 14},
  V = {17, 17, 17, 17, 17, 10, 4}, W = {17, 17, 17, 21, 21, 21, 10}, X = {17, 17, 10, 4, 10, 17, 17},
  Y = {17, 17, 10, 4, 4, 4, 4}, Z = {31, 1, 2, 4, 8, 16, 31},
  ["0"] = {14, 17, 19, 21, 25, 17, 14}, ["1"] = {4, 12, 4, 4, 4, 4, 14}, ["2"] = {14, 17, 1, 2, 4, 8, 31},
  ["3"] = {31, 2, 4, 2, 1, 17, 14}, ["4"] = {2, 6, 10, 18, 31, 2, 2}, ["5"] = {31, 16, 30, 1, 1, 17, 14},
  ["6"] = {6, 8, 16, 30, 17, 17, 14}, ["7"] = {31, 1, 2, 4, 8, 8, 8}, ["8"] = {14, 17, 17, 14, 17, 17, 14},
  ["9"] = {14, 17, 17, 15, 1, 2, 12},
  ["!"] = {4, 4, 4, 4, 4, 0, 4}, ["?"] = {14, 17, 1, 2, 4, 0, 4}, ["."] = {0, 0, 0, 0, 0, 12, 12},
  [","] = {0, 0, 0, 0, 12, 4, 8}, [":"] = {0, 12, 12, 0, 12, 12, 0}, ["-"] = {0, 0, 0, 31, 0, 0, 0},
  ["/"] = {1, 1, 2, 4, 8, 16, 16}, ["'"] = {4, 4, 8, 0, 0, 0, 0}, ["<"] = {2, 4, 8, 16, 8, 4, 2},
  [">"] = {8, 4, 2, 1, 2, 4, 8}, ["+"] = {0, 4, 4, 31, 4, 4, 0}, [" "] = {0, 0, 0, 0, 0, 0, 0},
  [0xBA] = {14, 10, 14, 0, 14, 0, 0},   -- o "numero ordinal" (1o, 2o...), pelo codigo
}

-- Acentos: duas linhas desenhadas acima da letra (cedilha: abaixo).
local ACENTO = { agudo = {2, 4}, grave = {8, 4}, circ = {4, 10}, til = {13, 22}, cedilha = {4, 8} }
local COMPOSTA = {
  [0xC1] = {"A", "agudo"}, [0xC0] = {"A", "grave"}, [0xC2] = {"A", "circ"}, [0xC3] = {"A", "til"},
  [0xC9] = {"E", "agudo"}, [0xCA] = {"E", "circ"}, [0xCD] = {"I", "agudo"}, [0xD3] = {"O", "agudo"},
  [0xD4] = {"O", "circ"}, [0xD5] = {"O", "til"}, [0xDA] = {"U", "agudo"}, [0xC7] = {"C", "cedilha"},
}

-- Pre-calcula os retangulos de cada letra: tracos horizontais iguais em linhas seguidas
-- viram um retangulo so ({linha, coluna inicial, coluna final, altura}). Menos comandos
-- de desenho: a drawlist do aparelho aceita 18 KB por quadro.
local function tracos(linhas, deslocamento)
  local lista, abertos = {}, {}
  for l, bits in ipairs(linhas) do
    local novos = {}
    local c = 0
    while c < 5 do
      if (bits & (16 >> c)) ~= 0 then
        local ini = c
        while c < 5 and (bits & (16 >> c)) ~= 0 do c = c + 1 end
        local chave = ini * 8 + c
        local r = abertos[chave]
        if r then
          r[4] = r[4] + 1
        else
          r = { l - 1 + deslocamento, ini, c, 1 }
          lista[#lista + 1] = r
        end
        novos[chave] = r
      else
        c = c + 1
      end
    end
    abertos = novos
  end
  return lista
end

local GLIFOS = {}
for ch, linhas in pairs(FONTE) do
  GLIFOS[type(ch) == "number" and ch or byte(ch)] = { tracos(linhas, 0) }
end
for cp, def in pairs(COMPOSTA) do
  local abaixo = def[2] == "cedilha"
  GLIFOS[cp] = { tracos(FONTE[def[1]], 0), tracos(ACENTO[def[2]], abaixo and 7 or -2) }
end

local function maiuscula(cp)
  if (cp >= 0x61 and cp <= 0x7A) or (cp >= 0xE0 and cp <= 0xFE and cp ~= 0xF7) then return cp - 32 end
  return cp
end

local function desenhar_glifo(partes, x, y, e, cor)
  for _, lista in ipairs(partes) do
    for _, t in ipairs(lista) do
      local ty = y + t[1] * e
      ui.rectfill(x + t[2] * e, ty, x + t[3] * e, ty + t[4] * e, cor)
    end
  end
end

function T.largura(s, e)
  return math.max(0, letras(s) * 6 * e - e)
end

-- Folhas de tiles da fonte: FOLHA[escala][cor] (todas as letras) e NUMEROS[escala][cor]
-- (so numeros e "/", folhas pequenas para o painel da corrida) = { imagem, tiles }.
local FOLHA, NUMEROS = {}, {}
for _, f in ipairs(Fonte.folhas) do
  local destino = f.conjunto == "numeros" and NUMEROS or FOLHA
  destino[f.escala] = destino[f.escala] or {}
  destino[f.escala][f.cor] = { Sprites.img.fonte[f.imagem], Fonte.conjuntos[f.conjunto] }
end

-- Fila: na tela dividida o painel de cada visao usa as mesmas folhas. Com a fila ligada,
-- o texto em tiles e guardado e desenhado no fim, agrupado por folha: cada folha e
-- carregada uma vez por quadro (o console aceita 32 cargas de imagem por quadro).
local fila, fila_n, fila_dx, fila_dy = {}, 0, 0, 0
local ligada = false

-- liga a fila; dx, dy = canto da visao (o mesmo deslocamento do ui.camera dela)
function T.fila(dx, dy)
  ligada, fila_dx, fila_dy = true, dx, dy
end

local function com_tiles(folha, s, x, y, e)
  if ligada then
    fila_n = fila_n + 1
    local item = fila[fila_n]
    if not item then
      item = {}
      fila[fila_n] = item
    end
    item[1], item[2], item[3], item[4], item[5] = folha, s, x + fila_dx, y + fila_dy, e
    return
  end
  local img, ids = folha[1], folha[2]
  local tile = ui.tile
  Desenho.lote(img)
  local i, n, cx, passo = 1, #s, x, 6 * e
  while i <= n do
    local cp
    cp, i = codigo(s, i)
    cp = maiuscula(cp)
    local id = ids[cp]
    if id then
      tile(img, id, cx, y)
    else
      local def = COMPOSTA[cp]
      if def then   -- letra acentuada: a letra e o acento (acima; a cedilha, abaixo)
        tile(img, ids[byte(def[1])], cx, y)
        tile(img, ids[def[2]], cx, def[2] == "cedilha" and y + 7 * e or y - 2 * e)
      end
    end
    cx = cx + passo
  end
end

-- desenha a fila (sem camera nem recorte), uma folha de cada vez, e desliga a fila
function T.fila_desenhar()
  ligada = false
  ui.camera()
  ui.clip()
  for i = 1, fila_n do
    local folha = fila[i][1]
    if folha then
      for k = i, fila_n do
        local item = fila[k]
        if item[1] == folha then
          com_tiles(folha, item[2], item[3], item[4], item[5])
          item[1] = false
        end
      end
    end
  end
  fila_n = 0
end

-- Texto grande. e = escala (tamanho do "pixel" da letra). sombra = cor da sombra (opcional).
-- Com tiles a sombra e sempre preta (ja esta desenhada na folha).
function T.grande(s, x, y, e, cor, sombra)
  x, y = math.floor(x), math.floor(y)
  if sombra == nil or sombra == Cores.preto then
    local folha = NUMEROS[e] and NUMEROS[e][cor]
    if not (folha and not s:find("[^%d/ ]")) then folha = FOLHA[e] and FOLHA[e][cor] end
    if folha then return com_tiles(folha, s, x, y, e) end
  end
  local cx = x
  local d = math.max(1, e // 3)
  local i, n = 1, #s
  while i <= n do
    local cp
    cp, i = codigo(s, i)
    local g = GLIFOS[maiuscula(cp)]
    if g then
      if sombra then desenhar_glifo(g, cx + d, y + d, e, sombra) end
      desenhar_glifo(g, cx, y, e, cor)
    end
    cx = cx + 6 * e
  end
end

function T.grande_centro(s, cx, y, e, cor, sombra)
  T.grande(s, cx - T.largura(s, e) / 2, y, e, cor, sombra)
end

-- Texto pequeno (fonte do Lupi). Tira acentos, que a fonte do simulador nao tem.
-- SEM_ACENTO[codigo da letra acentuada] = letra sem acento
local SEM_ACENTO = {}
for letra, codigos in pairs({
  a = { 0xE0, 0xE1, 0xE2, 0xE3 }, e = { 0xE9, 0xEA }, i = { 0xED }, o = { 0xF3, 0xF4, 0xF5, 0xBA },
  u = { 0xFA }, c = { 0xE7 }, A = { 0xC0, 0xC1, 0xC2, 0xC3 }, E = { 0xC9, 0xCA }, I = { 0xCD },
  O = { 0xD3, 0xD4, 0xD5 }, U = { 0xDA }, C = { 0xC7 },
}) do
  for _, cp in ipairs(codigos) do SEM_ACENTO[cp] = letra end
end

local ja_convertidos = {}   -- os textos com acento se repetem a cada quadro: guarda o resultado
function T.sem_acento(s)
  if not s:find("[\x80-\xFF]") then return s end
  local pronto = ja_convertidos[s]
  if pronto then return pronto end
  local partes, i, n = {}, 1, #s
  while i <= n do
    local cp
    cp, i = codigo(s, i)
    partes[#partes + 1] = cp < 0x80 and char(cp) or (SEM_ACENTO[cp] or "?")
  end
  pronto = table.concat(partes)
  ja_convertidos[s] = pronto
  return pronto
end

function T.p(s, x, y, cor, sombra)
  s = T.sem_acento(s)
  if sombra then ui.print(s, math.floor(x) + 1, math.floor(y) + 1, sombra) end
  ui.print(s, math.floor(x), math.floor(y), cor)
end

function T.p_centro(s, cx, y, cor, sombra)
  T.p(s, cx - (#T.sem_acento(s) * 6 - 1) / 2, y, cor, sombra)
end

function T.p_direita(s, xd, y, cor, sombra)
  T.p(s, xd - (#T.sem_acento(s) * 6 - 1), y, cor, sombra)
end

function T.tempo(quadros)
  local s = quadros / 60
  local m = math.floor(s / 60)
  return string.format("%d:%05.2f", m, s - m * 60)
end

return T
