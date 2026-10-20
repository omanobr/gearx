-- Diagnostico de desempenho no aparelho (ligado com C.DIAGNOSTICO em config.lua).
--
-- A cada quadro mede, com o relogio do Lua (os.clock):
--   lua    = tempo gasto dentro de update() (a logica e a montagem da lista de desenho)
--   quadro = tempo entre um update() e o seguinte (o quadro inteiro; 16,7 ms = 60 FPS)
-- Se "quadro" for bem maior que "lua", quem atrasa e o desenho na tela (ou o cartao SD);
-- se os dois forem parecidos, e o processamento do Lua.
-- A cada segundo mostra o resultado no rodape e manda uma linha para o log do console
-- (print), que aparece no computador com o cabo USB (ferramentas/LOG_CONSOLE.bat).
local Cores = require "cores"
local Tempo = require "tempo"

local D = {}

-- relogio: os.clock, se o console tiver (protegido: pode nao existir)
local relogio
do
  local ok, t = pcall(function() return os.clock() end)
  if ok and type(t) == "number" then relogio = os.clock end
end
local function stat(n)
  if not ui.stat then return nil end
  local ok, v = pcall(ui.stat, n)
  if ok and type(v) == "number" then return v end
  return nil
end

D.tem_relogio = relogio ~= nil
D.ultimo_lua, D.ultimo_quadro = 0, 0   -- segundos, do ultimo quadro (para o teste de desempenho)
D.quadros = 0                           -- quantos update() desde que o jogo abriu

local inicio, anterior
local soma_lua, soma_quadro, n = 0, 0, 0
local texto = "MEDINDO..."
-- rodape: o texto muda uma vez por segundo; a posicao e calculada so entao
local rodape_x, rodape_w = (480 - (#texto * 6 + 3)) // 2, #texto * 6 + 3

function D.inicio()
  D.quadros = D.quadros + 1
  if not relogio then return end
  local t = relogio()
  if anterior then
    D.ultimo_quadro = t - anterior
    soma_quadro = soma_quadro + D.ultimo_quadro
  end
  anterior, inicio = t, t
end

function D.fim()
  if relogio then
    D.ultimo_lua = relogio() - inicio
    soma_lua = soma_lua + D.ultimo_lua
  end
  n = n + 1
  if n < 60 then return end
  local fps7 = stat(7)
  local partes = {}
  if relogio and soma_quadro > 0 then
    partes[#partes + 1] = string.format("FPS %.0f  LUA %.1fMS  QUADRO %.1fMS",
      n / soma_quadro, soma_lua / n * 1000, soma_quadro / n * 1000)
  end
  if fps7 then partes[#partes + 1] = string.format("STAT7 %.0f", fps7) end
  if #partes == 0 then partes[1] = "SEM RELOGIO" end
  texto = table.concat(partes, "  ")
  rodape_w = #texto * 6 + 3
  rodape_x = (480 - rodape_w) // 2
  -- passo: quantos 1/60 s o jogo anda por quadro (tempo.lua); dframe: quanto o contador de
  -- quadros do console anda entre dois update() (1 = nao conta os quadros pulados)
  if D.ligado then print(string.format("GEARX %s tela=%s mem=%dKB quadro=%d passo=%.2f (%s) dframe=%s",
    texto, Jogo.nome_tela or "?", collectgarbage("count") // 1, D.quadros, Tempo.passo, Tempo.fonte,
    Tempo.media_frame and string.format("%.2f", Tempo.media_frame) or "?")) end
  soma_lua, soma_quadro, n = 0, 0, 0
end

-- rodape com o resultado (v0.97f: sem o numero do quadro, que mudava todo quadro e obrigava a
-- montar o texto de novo; o log tem "quadro=")
function D.desenhar()
  ui.camera()
  ui.clip()
  ui.rectfill(rodape_x, 262, rodape_x + rodape_w, 269, Cores.preto)
  ui.print(texto, rodape_x + 2, 262, Cores.branco)
end

return D
