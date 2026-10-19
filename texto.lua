-- Texto. Duas opcoes:
--   T.p(...)       texto pequeno, com a fonte do Lupi (5x8, so letras sem acento)
--   T.grande(...)  texto grande desenhado com retangulos, aceita acentos e escala
local T = {}

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
  [">"] = {8, 4, 2, 1, 2, 4, 8}, ["+"] = {0, 4, 4, 31, 4, 4, 0}, ["º"] = {14, 10, 14, 0, 14, 0, 0},
  [" "] = {0, 0, 0, 0, 0, 0, 0},
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
for ch, linhas in pairs(FONTE) do GLIFOS[utf8.codepoint(ch)] = { tracos(linhas, 0) } end
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
  return math.max(0, utf8.len(s) * 6 * e - e)
end

-- Texto grande. e = escala (tamanho do "pixel" da letra). sombra = cor da sombra (opcional).
function T.grande(s, x, y, e, cor, sombra)
  x, y = math.floor(x), math.floor(y)
  local cx = x
  local d = math.max(1, e // 3)
  for _, cp in utf8.codes(s) do
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

-- Texto pequeno (fonte do Lupi). Tira acentos, que a fonte do console nao tem.
local SEM_ACENTO = {
  ["á"] = "a", ["à"] = "a", ["â"] = "a", ["ã"] = "a", ["é"] = "e", ["ê"] = "e", ["í"] = "i",
  ["ó"] = "o", ["ô"] = "o", ["õ"] = "o", ["ú"] = "u", ["ç"] = "c", ["Á"] = "A", ["À"] = "A",
  ["Â"] = "A", ["Ã"] = "A", ["É"] = "E", ["Ê"] = "E", ["Í"] = "I", ["Ó"] = "O", ["Ô"] = "O",
  ["Õ"] = "O", ["Ú"] = "U", ["Ç"] = "C", ["º"] = "o",
}

function T.sem_acento(s)
  return (s:gsub("[\xC2\xC3][\x80-\xBF]", SEM_ACENTO))
end

function T.p(s, x, y, cor, sombra)
  s = T.sem_acento(s)
  if sombra then ui.print(s, math.floor(x) + 1, math.floor(y) + 1, sombra) end
  ui.print(s, math.floor(x), math.floor(y), cor)
end

function T.p_centro(s, cx, y, cor, sombra)
  T.p(s, cx - (utf8.len(T.sem_acento(s)) * 6 - 1) / 2, y, cor, sombra)
end

function T.p_direita(s, xd, y, cor, sombra)
  T.p(s, xd - (utf8.len(T.sem_acento(s)) * 6 - 1), y, cor, sombra)
end

function T.tempo(quadros)
  local s = quadros / 60
  local m = math.floor(s / 60)
  return string.format("%d:%05.2f", m, s - m * 60)
end

return T
