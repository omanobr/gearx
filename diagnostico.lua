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

-- O que a tabela de arquivos do console tem para o GearX (a tabela Sprites sai dela). Ela
-- guarda no maximo 1024 arquivos por jogo e nunca apaga os antigos (a v0.97b encheu). Se o
-- jogo for reinstalado do zero, os restos de versoes antigas somem: as pastas de cor direto
-- em img/carros (v0.9) e os r1/e1/d1 da v0.97b. Escreve uma linha no log (cabo USB).
local function chaves(t)
  local n = 0
  if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
  return n
end
-- imagens na tabela: se cada imagem e uma tabela, conta as tabelas sem tabelas dentro; senao,
-- conta os valores que nao sao tabela
local function imagens(t, em_tabela)
  local n = 0
  for _, v in pairs(t) do
    if type(v) == "table" then
      local folha = em_tabela
      if folha then for _, w in pairs(v) do if type(w) == "table" then folha = false break end end end
      n = n + (folha and 1 or imagens(v, em_tabela))
    elseif not em_tabela then
      n = n + 1
    end
  end
  return n
end
function D.arquivos()
  local carros = Sprites.img and Sprites.img.carros or {}
  local fa = carros.fusca and carros.fusca.amarelo
  local e = carros.ka and carros.ka.vermelho and carros.ka.vermelho.reto1
  local campos = {}
  if type(e) == "table" then for k in pairs(e) do campos[#campos + 1] = tostring(k) end end
  print(string.format("GEARX ARQUIVOS imagens=%d (limpo: 680) pastas em img/carros=%d (limpo: 5) "
    .. "fusca/amarelo=%d (limpo: 21) resto v0.9=%s resto v0.97b=%s imagem=%s{%s}",
    imagens(Sprites, type(e) == "table"), chaves(carros), chaves(fa), tostring(carros.amarelo ~= nil),
    tostring(fa ~= nil and fa.r1 ~= nil), type(e), table.concat(campos, ",")))
end

-- Teste de gravacao (v0.97k, autorizado pelo Felipe): o console deixa o jogo gravar um
-- arquivo na pasta dele? (Os recordes do campeonato precisam disso.) Le o que ficou da vez
-- anterior (sobreviveu a fechar o jogo e desligar?), grava de novo e confere. So no log.
local function gravar_em(nome)
  local antes = "(nenhum)"
  local f = io.open(nome, "r")
  if f then
    antes = f:read("a") or "?"
    f:close()
  end
  local vezes = (tonumber(antes:match("vezes=(%d+)")) or 0) + 1
  local g, erro = io.open(nome, "w")
  if not g then return false, "nao abriu para gravar: " .. tostring(erro) .. " | antes: " .. antes end
  g:write("vezes=" .. vezes)
  g:close()
  local h = io.open(nome, "r")
  local depois = h and h:read("a") or "(nao leu)"
  if h then h:close() end
  return true, "antes: " .. antes .. " | depois: " .. depois
end
function D.gravar_teste()
  if not (io and io.open) then
    print("GEARX GRAVAR nao ha io.open no console")
    return
  end
  for _, nome in ipairs({ "gearx_teste.txt", "/apps/1426073318/gearx_teste.txt" }) do
    local ok, deu, msg = pcall(gravar_em, nome)
    print("GEARX GRAVAR " .. nome .. ": " .. (ok and ((deu and "OK " or "ERRO ") .. msg) or ("falhou: " .. tostring(deu))))
    if ok and deu then return end
  end
end

function D.fim()
  if D.quadros == 120 then
    pcall(D.arquivos)
    pcall(D.gravar_teste)
  end
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
