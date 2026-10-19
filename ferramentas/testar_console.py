"""
Testa o jogo como o console roda: Lua 5.4 (o simulador usa 5.5) e arquivos .lua em
Latin-9 (o console guarda o texto assim; foi o que quebrou a v0.2 com "invalid UTF-8 code").

  1. constroi o jogo (construir.py)
  2. copia build/jogo para build/console convertendo os .lua para Latin-9
  3. roda o jogo sem tela, com funcoes ui.* de mentira que conferem os argumentos:
     titulo -> menu -> corrida (comandos simulados) e corridas inteiras no piloto
     automatico em 1, 2 e 3 jogadores, ate a tela de resultado
  4. mede as instrucoes Lua 5.4 por quadro (limite do console: ~50-60 mil)

Precisa de Lua 5.4 instalado (comando lua5.4) ou do Docker (baixa uma imagem pequena).
Uso:  python ferramentas/testar_console.py
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import construir  # noqa: E402

PASTA_TESTE = os.path.join(construir.PASTA_BUILD, "console")
ROTEIRO = os.path.join(construir.PASTA_BUILD, "console_teste.lua")

# (descricao, argumentos, medir instrucoes com funcoes nativas)
CENARIOS = [
    ("titulo, menu e corrida de 3 (comandos simulados)", "menu", False),
    ("1 jogador, Por do Sol, 2 voltas", "corrida 1 3 2", False),
    ("3 jogadores, Crepusculo", "corrida 3 4 1", False),
    ("instrucoes: 1 jogador, noite", "corrida 1 5 1", True),
    ("instrucoes: 2 jogadores, noite", "corrida 2 5 1", True),
    ("instrucoes: 3 jogadores, noite", "corrida 3 5 1", True),
]

HARNESS = r'''-- Gerado por ferramentas/testar_console.py: roda o GearX sem tela.
package.path = "./?.lua;" .. package.path
local cenario = arg[1] or "menu"

LEFT, RIGHT, UP, DOWN, BTN_Z, BTN_X, BTN_F, BTN_G, BTN_Q, BTN_E = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10

local quadro = 0
local apertos, segurados = {}, {}

local function numeros(...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) ~= "number" or v ~= v then error("argumento " .. i .. " invalido: " .. tostring(v), 3) end
  end
end
ui = {}
for _, nome in ipairs({ "rectfill", "rect", "line", "circfill", "circ", "trisfill", "clip", "camera", "fillp" }) do
  ui[nome] = function(...) numeros(...) end
end
ui.cls = function() end
ui.palset = function(i, c)
  numeros(i, c)
  if i < 0 or i > 255 then error("palset fora da faixa: " .. i, 2) end
end
ui.print = function(s, x, y, c)
  if type(s) ~= "string" then error("print sem texto", 2) end
  numeros(x, y, c)
  if s:find("[\x80-\xFF]") then error("print recebeu letra acentuada: " .. s, 2) end
end
-- No console, as imagens de Sprites nao trazem largura/altura (a v0.3 quebrou lendo .width).
-- Aqui elas sao "opacas": ler qualquer campo de uma imagem da erro.
local IMAGENS = setmetatable({}, { __mode = "k" })
local OPACA = { __index = function(_, campo)
  error("o jogo leu o campo '" .. tostring(campo) .. "' de uma imagem; no console as imagens nao tem esse campo", 2)
end }
ui.spr = function(s, x, y)
  if not IMAGENS[s] then error("sprite invalido: " .. tostring(s), 2) end
  numeros(x, y)
end
ui.btn = function(b) return segurados[b] == true end
ui.btnp = function(b) local l = apertos[quadro]; return l ~= nil and l[b] == true end
ui.log = print
-- MEDIR=1: funcoes de desenho nativas (C), como no console, para contar as instrucoes do jogo
if os.getenv("MEDIR") then
  local nativa = math.max                  -- C: confere que os argumentos sao numeros
  for _, nome in ipairs({ "rectfill", "rect", "line", "circfill", "circ", "trisfill", "palset" }) do ui[nome] = nativa end
  local qualquer = coroutine.running       -- C: ignora os argumentos (clip/camera/fillp podem vir vazios)
  ui.clip, ui.camera, ui.fillp = qualquer, qualquer, qualquer
  ui.print = string.len
  ui.spr = rawequal
end

-- tabela Sprites a partir do manifesto (o console monta igual)
package.preload["sprites"] = function()
  Sprites = {}
  for linha in io.lines("lupi_manifest.txt") do
    local caminho, json = linha:match("^%d+ %d+ (%S+) (.*)$")
    if json and json:find('"bitmap"') then
      local t, partes = Sprites, {}
      for p in caminho:gmatch("[^/]+") do partes[#partes + 1] = p end
      for k = 1, #partes - 1 do t[partes[k]] = t[partes[k]] or {}; t = t[partes[k]] end
      local imagem = setmetatable({}, OPACA)
      IMAGENS[imagem] = true
      t[partes[#partes]] = imagem
    end
  end
  return Sprites
end

local max_quadros
if cenario == "menu" then
  local roteiro = { [40] = BTN_Z, [60] = RIGHT, [70] = RIGHT, [80] = DOWN, [90] = RIGHT, [100] = DOWN,
                    [110] = LEFT, [120] = LEFT, [130] = DOWN, [140] = BTN_Z }
  for q, b in pairs(roteiro) do apertos[q] = { [b] = true } end
  max_quadros = 1500
else
  local n, pista, voltas = tonumber(arg[2]) or 3, tonumber(arg[3]) or 5, tonumber(arg[4]) or 1
  package.preload["dev_config"] = function()
    return { cena = "corrida", jogadores = n, pista = pista, voltas = voltas, autopiloto = { true, true, true } }
  end
  max_quadros = 60 * 300
end

dofile("game.lua")

local centenas = 0
local function gancho() centenas = centenas + 1 end
local soma, pico, medidos, telas = 0, 0, 0, {}
local fim_em
while quadro < max_quadros do
  quadro = quadro + 1
  if cenario == "menu" and quadro > 150 then segurados[BTN_Z] = true end
  centenas = 0
  debug.sethook(gancho, "", 100)
  local ok, erro = xpcall(update, debug.traceback, quadro)
  debug.sethook()
  if not ok then
    print("ERRO no quadro " .. quadro .. ":\n" .. erro)
    os.exit(1)
  end
  local tela = Jogo.tela
  local nome = (tela.corrida and "corrida") or (tela.linhas and "resultado") or (tela.sel and "menu") or "titulo"
  telas[nome] = (telas[nome] or 0) + 1
  if nome == "corrida" and tela.corrida.estado == "correndo" then
    soma, pico, medidos = soma + centenas * 100, math.max(pico, centenas * 100), medidos + 1
  end
  if nome == "resultado" then
    fim_em = fim_em or quadro
    if quadro - fim_em > 120 then break end
  end
end
local resumo = {}
for k, v in pairs(telas) do resumo[#resumo + 1] = k .. "=" .. v end
table.sort(resumo)
local medida = ""
if os.getenv("MEDIR") and medidos > 0 then
  medida = string.format(" | instrucoes por quadro: media %.1f mil, pico %.1f mil", soma / medidos / 1000, pico / 1000)
end
print(string.format("OK: %d quadros sem erro (%s)%s", quadro, table.concat(resumo, " "), medida))
'''


def preparar():
    relatorio = construir.construir(silencioso=True)
    if not relatorio["ok"]:
        construir.imprimir_relatorio(relatorio)
        sys.exit(1)
    shutil.rmtree(PASTA_TESTE, ignore_errors=True)
    shutil.copytree(construir.SAIDA_DESCOMPACTADA, PASTA_TESTE)
    for atual, _, nomes in os.walk(PASTA_TESTE):
        for nome in nomes:
            if nome.endswith(".lua"):
                caminho = os.path.join(atual, nome)
                with open(caminho, "rb") as f:
                    dados = f.read()
                with open(caminho, "wb") as f:
                    f.write(dados.decode("utf-8").encode("iso-8859-15"))
    with open(ROTEIRO, "w", encoding="utf-8", newline="\n") as f:
        f.write(HARNESS)


def comandos():
    """Cada cenario vira um comando de shell (rodado por lua5.4 local ou dentro do Docker)."""
    linhas = []
    for descricao, args, medir in CENARIOS:
        prefixo = "MEDIR=1 " if medir else ""
        linhas.append('echo "== %s"; %slua5.4 ../console_teste.lua %s 2>&1 | tail -12' % (descricao, prefixo, args))
    return "; ".join(linhas)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(line_buffering=True)
    print("Construindo e convertendo os .lua para Latin-9 ...")
    preparar()
    if shutil.which("lua5.4") and shutil.which("sh"):
        cmd = ["sh", "-c", comandos()]
        cwd = PASTA_TESTE
    elif shutil.which("docker"):
        print("Rodando em Lua 5.4 dentro do Docker (alpine) ...")
        cmd = ["docker", "run", "--rm", "-v", os.path.abspath(construir.PASTA_BUILD) + ":/w", "-w", "/w/console",
               "alpine:3.20", "sh", "-c", "apk add --no-cache lua5.4 >/dev/null 2>&1; " + comandos()]
        cwd = None
    else:
        print("Precisa de Lua 5.4 (lua5.4) ou do Docker para este teste.")
        sys.exit(2)
    saida = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    texto = saida.stdout + saida.stderr
    print(texto.strip())
    falhou = "ERRO" in texto or "lua5.4:" in texto or saida.returncode != 0
    print("\nRESULTADO:", "FALHOU" if falhou else "tudo certo em Lua 5.4 com Latin-9")
    sys.exit(1 if falhou else 0)


if __name__ == "__main__":
    main()
