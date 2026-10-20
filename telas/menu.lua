-- Menu (v0.98): pagina principal e submenus, em lista + painel.
--   esquerda: as opcoes da pagina (a escolhida fica azul, com ">")
--   direita : painel com a previa da pista e a explicacao da opcao escolhida
--   em cima : GEARX e o nome da pagina; embaixo: os botoes
-- Paginas: principal (CORRIDA, CAMPEONATO, RECORDES, OPCOES), corrida (jogadores, pista,
-- voltas, CORRER!) e opcoes (musica, FPS, testes). A volta para a pagina anterior; na
-- principal, para o titulo. So usa cores e folhas de letras que o jogo ja tem.
local C = require "config"
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"
local Pistas = require "pistas"
local R = require "render"
local Som = require "som"

local Tela = {}
Tela.__index = Tela

local PAGINAS = {
  principal = {
    titulo = "MENU",
    itens = {
      { nome = "CORRIDA", ir = "corrida" },
      { nome = "CAMPEONATO", breve = true },
      { nome = "RECORDES", breve = true },
      { nome = "OPÇÕES", ir = "opcoes" },
    },
  },
  corrida = {
    titulo = "CORRIDA",
    volta = "principal",
    itens = {
      { nome = "JOGADORES", valor = "jogadores" },
      { nome = "PISTA", valor = "pista" },
      { nome = "VOLTAS", valor = "voltas" },
      { nome = "CORRER!", acao = "correr" },
    },
  },
  opcoes = {
    titulo = "OPÇÕES",
    volta = "principal",
    itens = {
      { nome = "MÚSICA", valor = "musica" },
      { nome = "FPS", valor = "fps" },
      { nome = "TESTE DE TELA", acao = "teste" },
      { nome = "DESEMPENHO", acao = "desempenho" },
    },
  },
}

-- opcao escolhida em cada pagina: lembrada enquanto o jogo esta aberto
local escolhido = { principal = 1, corrida = 1, opcoes = 1 }

function Tela.nova(pagina)
  return setmetatable({ pagina = PAGINAS[pagina] and pagina or "principal", t = 0 }, Tela)
end

local function circular(valor, delta, maximo)
  return (valor - 1 + delta) % maximo + 1
end

-- muda o valor de uma opcao (d = -1 ou +1)
local function mudar(valor, d)
  local op = Jogo.opcoes
  if valor == "jogadores" then op.jogadores = circular(op.jogadores, d, 3)
  elseif valor == "pista" then op.pista = circular(op.pista, d, #Pistas)
  elseif valor == "voltas" then op.voltas = math.max(1, math.min(9, op.voltas + d))
  elseif valor == "musica" then
    op.musica = not op.musica
    if op.musica then Som.musica() else Som.parar() end
  elseif valor == "fps" then
    Jogo.diagnostico_rodape = not Jogo.diagnostico_rodape
  end
end

function Tela:atualizar()
  self.t = self.t + 1
  local pagina = PAGINAS[self.pagina]
  local itens = pagina.itens
  local sel = escolhido[self.pagina]
  if Entrada.cima() then sel = circular(sel, -1, #itens) end
  if Entrada.baixo() then sel = circular(sel, 1, #itens) end
  escolhido[self.pagina] = sel
  local item = itens[sel]
  local d = (Entrada.dir() and 1 or 0) - (Entrada.esq() and 1 or 0)
  if d ~= 0 and item.valor then mudar(item.valor, d) end
  if self.t < 5 then return end   -- o aperto que abriu esta pagina nao vale aqui
  if Entrada.confirmar() then
    if item.ir then
      self.pagina, self.t = item.ir, 0
    elseif item.acao == "correr" then
      local op = Jogo.opcoes
      Jogo.ir("escolha", {
        jogadores = op.jogadores, pista = op.pista, voltas = op.voltas,
        autopiloto = DEV.autopiloto,
      })
    elseif item.acao then
      Jogo.ir(item.acao)
    elseif item.valor then
      mudar(item.valor, 1)
    end
  elseif Entrada.voltar() then
    if pagina.volta then
      self.pagina, self.t = pagina.volta, 0
    else
      Jogo.ir("titulo")
    end
  end
end

-- ---------------------------------------------------------------------------
-- Desenho
-- ---------------------------------------------------------------------------
local LISTA_X, LISTA_W = 10, 186          -- coluna das opcoes
local ITEM_Y, ITEM_H, ITEM_PASSO = 46, 26, 32
local PAINEL_X, PAINEL_Y, PAINEL_W, PAINEL_H = 206, 46, 264, 184
local PAINEL_CX = PAINEL_X + PAINEL_W // 2

-- previa: o meio do panorama da pista (so os pedacos que aparecem: cada imagem desenhada e
-- lida do cartao)
local function previa_pista(n, x, y, w, h)
  local f = Arte.fundos[Pistas[n].fundo]
  ui.clip(x, y, w, h)
  local px = math.floor(x - (f.largura - w) / 2)
  for i, spr in ipairs(f.sprites) do
    if px < x + w and px + f.larguras[i] > x then R.spr(spr, px, y + h - f.altura) end
    px = px + f.larguras[i]
  end
  ui.clip()
  ui.rect(x - 1, y - 1, x + w + 1, y + h + 1, Cores.branco)
end

local function texto_valor(valor)
  local op = Jogo.opcoes
  if valor == "jogadores" then return tostring(op.jogadores) end
  if valor == "pista" then return op.pista .. "/" .. #Pistas end
  if valor == "voltas" then return tostring(op.voltas) end
  if valor == "musica" then return op.musica and "SIM" or "NÃO" end
  if valor == "fps" then return Jogo.diagnostico_rodape and "SIM" or "NÃO" end
  return ""
end

-- linhas de texto pequeno no painel, centralizadas
local function linhas(lista, y, cor)
  for i, s in ipairs(lista) do T.p_centro(s, PAINEL_CX, y + (i - 1) * 11, cor or Cores.branco) end
end

-- a pista escolhida (previa grande, nome e numero de voltas / jogadores)
local function painel_pista(com_resumo)
  local op = Jogo.opcoes
  previa_pista(op.pista, PAINEL_X + 10, PAINEL_Y + 10, PAINEL_W - 20, 96)
  T.grande_centro(Pistas[op.pista].nome, PAINEL_CX, PAINEL_Y + 116, 2, Cores.amarelo)
  if com_resumo then
    local jog = op.jogadores == 1 and "1 JOGADOR" or (op.jogadores .. " JOGADORES")
    local vol = op.voltas == 1 and "1 VOLTA" or (op.voltas .. " VOLTAS")
    T.p_centro(vol .. "   -   " .. jog, PAINEL_CX, PAINEL_Y + 140, Cores.branco)
  end
end

local EXPLICA = {
  CAMPEONATO = { "As 5 pistas seguidas, com pontos", "por posição de chegada.", "", "Vem na próxima etapa!" },
  RECORDES = { "Os melhores tempos de cada pista,", "com as suas iniciais (3 letras),", "como nos fliperamas.", "",
               "Vem na próxima etapa!" },
}

-- conteudo do painel conforme a opcao escolhida
local function painel(pagina, item, t)
  local op = Jogo.opcoes
  local y = PAINEL_Y + 158
  if pagina == "principal" then
    if item.breve then
      T.grande_centro("EM BREVE", PAINEL_CX, PAINEL_Y + 30, 3, Cores.amarelo)
      linhas(EXPLICA[item.nome], PAINEL_Y + 80, Cores.branco)
    elseif item.ir == "corrida" then
      painel_pista(true)
      linhas({ "Corrida contra 7 carros do computador." }, y, Cores.cinza)
    else
      T.grande_centro("OPÇÕES", PAINEL_CX, PAINEL_Y + 30, 3, Cores.amarelo)
      linhas({ "Música, FPS na tela e", "os testes do console." }, PAINEL_Y + 80, Cores.branco)
    end
  elseif pagina == "corrida" then
    painel_pista(true)
    if item.valor == "jogadores" then
      -- quadradinhos com a cor de cada jogador
      for j = 1, 3 do
        local x = PAINEL_CX - 52 + (j - 1) * 36
        local cor = j <= op.jogadores and Cores.jogador[j] or Cores.cinza_escuro
        ui.rectfill(x, y, x + 28, y + 14, cor)
        T.p_centro("J" .. j, x + 14, y + 4, j <= op.jogadores and Cores.preto or Cores.cinza)
      end
    elseif item.valor == "pista" then
      linhas({ "PISTA " .. op.pista .. " DE " .. #Pistas }, y, Cores.cinza)
    elseif item.valor == "voltas" then
      linhas({ "De 1 a 9 voltas." }, y, Cores.cinza)
    elseif (t // 15) % 2 == 0 then
      linhas({ "TUDO PRONTO! APERTE " .. Entrada.NOME.confirmar }, y, Cores.amarelo)
    end
  else
    local textos = {
      musica = { "Liga ou desliga a música.", "(O simulador não tem som.)" },
      fps = { "Mostra o FPS no rodapé da tela.", "O log do cabo USB continua igual." },
      teste = { "Botões do controle, blocos de cor", "e jeitos de desenhar imagens." },
      desempenho = { "Mede no console quanto pesa cada", "parte do jogo (21 testes, 2 minutos)." },
    }
    T.grande_centro(item.nome, PAINEL_CX, PAINEL_Y + 30, 2, Cores.amarelo)
    linhas(textos[item.valor or item.acao], PAINEL_Y + 64, Cores.branco)
  end
end

function Tela:desenhar()
  local pagina = PAGINAS[self.pagina]
  local sel = escolhido[self.pagina]
  ui.rectfill(0, 0, 480, 270, Cores.preto)

  -- cabecalho
  ui.rectfill(0, 0, 480, 32, Cores.painel)
  ui.rectfill(0, 33, 480, 34, Cores.amarelo)
  T.grande("GEARX", 12, 6, 3, Cores.amarelo)
  T.grande(pagina.titulo, 12 + T.largura("GEARX", 3) + 16, 11, 2, Cores.cinza)
  T.p_direita(C.VERSAO, 470, 13, Cores.cinza)

  -- opcoes
  for i, item in ipairs(pagina.itens) do
    local y = ITEM_Y + (i - 1) * ITEM_PASSO
    local ativo = i == sel
    ui.rectfill(LISTA_X, y, LISTA_X + LISTA_W, y + ITEM_H, ativo and Cores.nitro or Cores.cinza_escuro)
    local cor = item.breve and Cores.cinza or (ativo and Cores.amarelo or Cores.branco)
    if ativo then T.grande(">", LISTA_X + 6, y + 6, 2, Cores.amarelo) end
    T.grande(item.nome, LISTA_X + 22, y + 6, 2, cor)
    if item.valor then
      local v = texto_valor(item.valor)
      if ativo then v = "<" .. v .. ">" end
      T.grande(v, LISTA_X + LISTA_W - 6 - T.largura(v, 2), y + 6, 2, cor)
    end
  end

  -- painel da direita
  ui.rectfill(PAINEL_X, PAINEL_Y, PAINEL_X + PAINEL_W, PAINEL_Y + PAINEL_H, Cores.painel)
  ui.rect(PAINEL_X, PAINEL_Y, PAINEL_X + PAINEL_W, PAINEL_Y + PAINEL_H, Cores.cinza_escuro)
  painel(self.pagina, pagina.itens[sel], self.t)

  -- rodape: botoes (acima da linha do FPS, que fica em 262)
  local nome = Entrada.NOME
  ui.rectfill(0, 238, 480, 270, Cores.painel)
  T.p_centro("CIMA/BAIXO: MOVER   ESQ/DIR: MUDAR   " .. nome.confirmar .. ": ESCOLHER   " .. nome.voltar .. ": VOLTAR",
    240, 241, Cores.cinza)
  T.p_centro("NA CORRIDA: " .. nome.acelerar .. " ACELERA   " .. nome.frear .. " FREIA   " .. nome.nitro .. " NITRO   "
    .. nome.pausa .. " PAUSA", 240, 251, Cores.cinza)
end

return Tela
