-- Desenha a visao de um jogador: ceu, fundo, estrada pseudo-3D, objetos e carros.
--
-- Como funciona (o mesmo truque do Top Gear e do Out Run):
--   1. Cada segmento da pista e "projetado" na tela: quanto mais longe, mais
--      perto do horizonte e mais estreito.
--   2. A estrada e desenhada de PERTO para LONGE. Guardamos a linha mais alta ja
--      pintada (maxy); o que ficaria abaixo dela esta escondido atras de um morro.
--   3. Depois os objetos e carros sao desenhados de LONGE para PERTO, recortados
--      pela linha guardada de cada segmento.
local C = require "config"
local Cores = require "cores"
local Objetos = require "objetos"
local Desenho = require "desenho"

local R = {}

-- Partes que o teste de desempenho desliga para medir quanto cada uma pesa no console
-- (telas/desempenho.lua). No jogo fica tudo ligado.
R.sem = {}
-- Estrada: "linhas" (v0.94, por linha da tela com tabelas, fatias em tiles; "linhas2" =
-- com retangulos em faixas de 2 linhas, para as telas divididas), ou os jeitos antigos, que
-- projetam cada segmento: "tiles" (v0.91), "retangulos" (v0.8) e "retangulos2" (faixas de 2
-- linhas tambem em 1 jogador). O teste de desempenho compara.
R.estrada = C.ESTRADA_DESENHO
R.estrada_dividida = C.ESTRADA_DIVIDIDA

local floor, min, max, log = math.floor, math.min, math.max, math.log

-- projecoes guardadas durante a passada da estrada (reaproveitadas a cada quadro):
-- ponto de perto de cada segmento (o de longe e o ponto do segmento seguinte)
local PX1, PY1, PS1, PCLIP, PSEG = {}, {}, {}, {}, {}
-- trapezios da estrada desta visao (bordas de perto e de longe, cor, segmento)
local TX1, TY1, TW1, TX2, TY2, TW2, TCLARO, TIDX = {}, {}, {}, {}, {}, {}, {}, {}
-- carros visiveis nesta visao; latas de nitro desta visao
local VIS_N, VIS_C = {}, {}
local IT_N, IT_O = {}, {}

-- sprites dos carros: SPR[modelo][cor].reto[nivel], .esq[nivel], .dir[nivel]
-- Tamanhos vem de Arte.carros.tamanho (TAM[modelo].reto[nivel] = { largura, altura }): no
-- console, as imagens de Sprites nao trazem largura e altura (so servem para o ui.spr).
local SPR, LARGURA_NIVEL1 = {}, 1
local TAM
local PARECIDA = { vermelho = "laranja", original = "amarelo" }   -- cor que substitui (veja R.preparar)
local CHAMA = { g = {}, p = {} }   -- chamas do nitro (ferramentas/gerar_efeitos.py)
-- estrada em tiles: folha, tile e largura do tile de cada largura Z (dados_estrada.lua)
local EF, ET, EW = {}, {}, {}
local Z_MAX = Estrada.z_max
local ESCALA_OBJ = Objetos.ESCALA_MAX   -- objeto mais perto que isto esta dentro da camera

-- Toda imagem do jogo passa por Desenho.spr (desenho.lua)
R.spr = Desenho.spr
R.novo_quadro = Desenho.novo_quadro

function R.preparar()
  Desenho.preparar()
  for z = 1, Z_MAX do
    local f = Estrada.folha[z]
    EF[z], ET[z], EW[z] = Sprites.img.estrada[Estrada.folhas[f]], Estrada.tile[z], Estrada.largura[f]
  end
  for tam, lista in pairs(CHAMA) do
    for q = 1, Efeitos.quadros_chama do lista[q] = Sprites.img.efeitos["chama_" .. tam .. q] end
  end
  TAM = Arte.carros.tamanho
  for _, modelo in ipairs(Arte.carros.modelos) do
    SPR[modelo] = {}
    for cor, pasta in pairs(Sprites.img.carros[modelo]) do
      local t = { reto = {}, esq = {}, dir = {} }
      for k = 1, Arte.carros.niveis do
        t.reto[k] = pasta["reto" .. k]
        t.esq[k] = pasta["esq" .. k]
        t.dir[k] = pasta["dir" .. k]
      end
      SPR[modelo][cor] = t
    end
    -- Niveis que nao existem no console (nome com mais de 31 caracteres: fusca/monza nas cores
    -- "original" e "vermelho", niveis 10 a 17, ferramentas/preparar_arte.py nao gera): usa o
    -- mesmo nivel de outra cor do mesmo modelo (sao carros longe, pequenos na tela).
    for cor, t in pairs(SPR[modelo]) do
      for k = 1, Arte.carros.niveis do
        if not t.reto[k] then
          local parecida = SPR[modelo][PARECIDA[cor]]
          t.reto[k] = parecida and parecida.reto[k]
          for _, outra in pairs(SPR[modelo]) do t.reto[k] = t.reto[k] or outra.reto[k] end
          t.reto[k] = t.reto[k] or t.reto[k - 1]
        end
      end
    end
  end
  LARGURA_NIVEL1 = TAM[Arte.carros.modelos[1]].reto[1][1]   -- igual em todos os modelos
  for nome, f in pairs(Arte.fundos) do
    for _, p in ipairs({ f, f.baixo }) do   -- panoramica inteira e a versao baixa (telas divididas)
      p.sprites, p.inicio = {}, {}
      local x = 0
      for i, peca in ipairs(p.pecas) do
        p.sprites[i], p.inicio[i] = Sprites.img.fundos[peca], x
        x = x + p.larguras[i]
      end
    end
    f.cor_ceu, f.cor_mar = Palette.hex(f.ceu), Palette.hex(f.mar)
  end
end

-- escolhe o tamanho de sprite mais parecido com a largura pedida
local LOG_FATOR = log(0.85)
local function nivel(largura)
  local k = floor(log(largura / LARGURA_NIVEL1) / LOG_FATOR + 1.5)
  return max(1, min(Arte.carros.niveis, k))
end
R.nivel = nivel

local XADREZ = { 0xCC, 0xCC, 0x33, 0x33, 0xCC, 0xCC, 0x33, 0x33 }
-- medidas da estrada em fracoes da meia-largura do asfalto (w)
local ZEBRA_LARG = 7 / 6                  -- a zebra vai 1/6 alem do asfalto de cada lado
local FAIXA_LARG = 1 / 60                 -- meia-largura de cada faixa branca
local FAIXA_POS = 1 - 2 / C.FAIXAS        -- distancia do centro ate cada faixa (3 pistas: 1/3)
assert(C.FAIXAS == 3, "segmento desenha 2 faixas brancas (3 pistas)")

-- Um trapezio da estrada e desenhado em FAIXAS HORIZONTAIS, linha a linha, como o Top Gear:
-- no console o triangulo (ui.trisfill) nao preenche certo (a pista saia com linhas verdes e
-- em escadinha). y2 = linha de cima, y1 = linha de baixo, x/w = centro e meia-largura do
-- asfalto em cada uma. Coordenadas sempre inteiras (// 1), como no console. O "+ 1" no fim
-- de cada retangulo e porque no simulador o rectfill nao inclui a ultima coluna/linha.

-- grama (e areia ou mar do lado direito) atras das linhas de um trapezio
local function grama(W, cores, k, x1, y1, w1, x2, y2, w2)
  local rect = ui.rectfill
  rect(0, y2, W, y1 + 1, cores.grama[k])
  if cores.direita then
    rect(min(x1 + w1 * ZEBRA_LARG, x2 + w2 * ZEBRA_LARG) // 1, y2, W, y1 + 1, cores.direita[k])
  end
end

-- linhas com retangulos: zebra, asfalto e as 2 faixas brancas (passo = altura de cada
-- faixa: 2 nas telas divididas, para gastar menos)
local function linhas_retangulos(cores, claro, x1, y1, w1, x2, y2, w2, indice, passo)
  local rect = ui.rectfill
  local k = claro and 1 or 2
  local zebra, asfalto, faixa = cores.zebra[k], cores.asfalto[k], cores.faixa
  local largada = indice <= 2
  local passos = (y1 - y2) / passo
  if passos < 1 then passos = 1 end
  local dx, dw = (x1 - x2) / passos, (w1 - w2) / passos
  local x, w = x2, w2
  for y = y2, y1, passo do
    local fim = y + passo
    local r = w * ZEBRA_LARG
    rect((x - r) // 1, y, (x + r) // 1 + 1, fim, zebra)
    local a, b = (x - w) // 1, (x + w) // 1 + 1
    if largada then                         -- linha de largada/chegada quadriculada
      rect(a, y, b, fim, Cores.branco)
      ui.fillp(table.unpack(XADREZ))
      rect(a, y, b, fim, Cores.preto)
      ui.fillp()
    else
      rect(a, y, b, fim, asfalto)
      if claro then                         -- as 2 faixas brancas (3 pistas)
        local l, m = w * FAIXA_LARG, w * FAIXA_POS
        rect((x - m - l) // 1, y, (x - m + l) // 1 + 1, fim, faixa)
        rect((x + m - l) // 1, y, (x + m + l) // 1 + 1, fim, faixa)
      end
    end
    x, w = x + dx, w + dw
  end
end

-- linhas com tiles: cada linha e uma fatia pronta (metade direita + a mesma espelhada),
-- escolhida pela largura Z (do centro ate a ponta da zebra). As fatias tem cores coringa,
-- trocadas na paleta pelas cores da pista (cores_da_estrada).
local function linhas_tiles(cores, claro, x1, y1, w1, x2, y2, w2, indice)
  local tile = ui.tile
  local base = claro and 0 or 1
  local passos = y1 - y2
  if passos < 1 then passos = 1 end
  local dx, dw = (x1 - x2) / passos, (w1 - w2) / passos
  local x, w = x2, w2
  local folha
  for y = y2, y1 do
    local z = (w * ZEBRA_LARG + 0.5) // 1
    if z > Z_MAX then   -- pertinho da camera, mais larga que as fatias: retangulos
      linhas_retangulos(cores, claro, x, y, w, x, y, w, indice, 1)
      folha = nil
    else
      if z < 1 then z = 1 end
      local f = EF[z]
      if f ~= folha then
        Desenho.lote(f)
        folha = f
      end
      local xc, id = (x + 0.5) // 1, ET[z] + base
      tile(f, id, xc, y)
      tile(f, id + 1024, xc - EW[z], y)   -- + 1024: espelhado
    end
    x, w = x + dx, w + dw
  end
end

-- poe as cores da pista nas 5 cores coringa das fatias da estrada
local function cores_da_estrada(cores)
  local palset, P, K = ui.palset, Palette, Estrada.coringa
  palset(K.asfalto1, P[cores.asfalto[1] + 1])
  palset(K.asfalto2, P[cores.asfalto[2] + 1])
  palset(K.zebra1, P[cores.zebra[1] + 1])
  palset(K.zebra2, P[cores.zebra[2] + 1])
  palset(K.faixa, P[cores.faixa + 1])
end

-- ---------------------------------------------------------------------------
-- ESTRADA POR LINHAS (v0.94): o jeito do Out Run e do Top Gear.
-- Numa estrada plana, cada linha da tela mostra sempre a mesma distancia: a linha r abaixo
-- do horizonte esta a prof_fy * CAM_ALTURA / r. Entao a distancia, a largura da estrada e a
-- fatia de cada linha vao para TABELAS, calculadas uma vez por tamanho de visao. A cada
-- quadro, para cada linha: em que segmento ela cai (posicao da camera + distancia), a altura
-- da pista ali (morros: a linha sobe ou desce na tela, e o que fica atras do topo do morro
-- nao aparece) e o deslocamento das curvas. Antes (modos "tiles" e "retangulos"), cada um
-- dos segmentos a frente era projetado em 3D e depois a estrada era desenhada linha a
-- linha: o dobro de contas. Objetos e carros so projetam os segmentos onde estao (ponto).
-- ---------------------------------------------------------------------------
local SEG, CAM_PROF, CAM_ALTURA, ESTRADA, ZEBRA = C.SEG, C.CAM_PROF, C.CAM_ALTURA, C.ESTRADA, C.ZEBRA
local ZMIN = CAM_PROF * CAM_ALTURA   -- distancia da linha do pe da tela (estrada plana)
local FAIXAS_ATE = 30                -- segmentos com faixas de grama/areia (mais longe: 1-2 pixels
                                     -- cada; v0.97f: era 45)
local PASSO_FUNDO = 6                -- mais longe, pedacos de cor fixa a cada 6 segmentos (a areia
                                     -- acompanha a borda da estrada nas curvas)
-- no console o rectfill inclui a ultima linha (no simulador nao): ui.log so existe no simulador
local INCLUI = ui.log == nil

-- por segmento n a frente da camera (0 = o da camera): x do mundo no comeco, ja menos o x
-- da camera (XC); quanto ele anda por segmento (curvas); 0 = faixa clara, 1 = escura (VAR);
-- altura no comeco e quanto sobe no segmento, divididas pela altura da camera (HA, HD)
local XC, DXS, VAR, HA, HD = {}, {}, {}, {}, {}
-- faixas de grama (de longe para perto na hora de desenhar)
local BY1, BY2, BX, BC = {}, {}, {}, {}

local TABELAS = {}
local function tabelas(W, H, hy)
  local chave = W * 1000000 + H * 1000 + hy
  local t = TABELAS[chave]
  if t then return t end
  local hw, fy = W * 0.5, H - hy
  local prof_fy = CAM_PROF * fy
  t = { zs = {}, kx = {}, w = {}, f = {}, id = {}, tw = {}, rmax = 3 * fy }
  for r = 1, t.rmax do
    local z = prof_fy * CAM_ALTURA / r      -- distancia que a linha r mostra (estrada plana)
    local s = CAM_PROF / z                   -- escala nessa distancia
    local w = s * ESTRADA * hw               -- meia-largura do asfalto, em pixels
    t.zs[r] = z / SEG                        -- distancia em segmentos
    t.kx[r] = s * hw                         -- pixels por unidade do mundo (curvas)
    t.w[r] = w
    local zz = (w * ZEBRA_LARG + 0.5) // 1   -- largura da fatia (centro ate a ponta da zebra)
    if zz < 1 then zz = 1 end
    if zz <= Z_MAX then t.f[r], t.id[r], t.tw[r] = EF[zz], ET[zz], EW[zz] end
  end
  TABELAS[chave] = t
  return t
end

-- uma linha (ou varias, se o morro abriu um buraco) de estrada com retangulos, de y ate
-- yfim - 1: zebra, asfalto e as faixas brancas (ou o quadriculado da largada)
local function linha_retangulos(cores, claro, x, w, y, yfim, indice)
  local rect = ui.rectfill
  local k = claro and 1 or 2
  local b = INCLUI and yfim - 1 or yfim
  local r = w * ZEBRA_LARG
  rect((x - r) // 1, y, (x + r) // 1 + 1, b, cores.zebra[k])
  local a, c = (x - w) // 1, (x + w) // 1 + 1
  if indice <= 2 then                       -- linha de largada/chegada quadriculada
    rect(a, y, c, b, Cores.branco)
    ui.fillp(table.unpack(XADREZ))
    rect(a, y, c, b, Cores.preto)
    ui.fillp()
  else
    rect(a, y, c, b, cores.asfalto[k])
    if claro then                           -- as 2 faixas brancas (3 pistas)
      local l, m = w * FAIXA_LARG, w * FAIXA_POS
      rect((x - m - l) // 1, y, (x - m + l) // 1 + 1, b, cores.faixa)
      rect((x + m - l) // 1, y, (x + m + l) // 1 + 1, b, cores.faixa)
    end
  end
end

-- projecao do comeco do segmento n (so para objetos e carros): PS1, PX1, PY1
local q_off, q_hw, q_prof_hw, q_prof_fy, q_hy, q_cam_y, q_alt
local function ponto(n)
  local z = n * SEG - q_off
  if z <= CAM_PROF then
    PS1[n] = nil
    return
  end
  local inv = 1 / z
  PS1[n] = CAM_PROF * inv
  PX1[n] = q_hw + q_prof_hw * XC[n] * inv
  PY1[n] = q_hy + q_prof_fy * (q_cam_y - q_alt[PSEG[n]]) * inv
end

-- Dados de cada pista que nao mudam (calculados na primeira vez): o proximo segmento, se a
-- faixa e clara (0) ou escura (1) e quantos segmentos seguidos tem a mesma altura (plano).
local function dados_da_pista(pista)
  if pista.prox then return end
  local N, alturas = pista.n, pista.y
  local prox, var, plano = {}, {}, {}
  for i = 1, N do
    prox[i] = i == N and 1 or i + 1
    var[i] = ((i - 1) // ZEBRA) % 2
  end
  for volta = 1, 2 do                      -- duas voltas por causa da emenda do circuito
    for i = N, 1, -1 do
      plano[i] = alturas[i] == alturas[prox[i]] and (plano[prox[i]] or 0) + 1 or 1
    end
  end
  -- de cada segmento, quantos segmentos ate o anterior que tem objetos (o laco dos objetos
  -- pula os vazios); e os dados de cada objeto que nao mudam (objetos.lua)
  local ant, ultimo = {}, nil
  for volta = 1, 2 do
    for i = 1, N do
      if ultimo then
        local d = (i - ultimo) % N
        ant[i] = d == 0 and N or d
      end
      if pista.objetos[i] then ultimo = i end
    end
  end
  for i = 1, N do
    ant[i] = ant[i] or 2 * N                -- pista sem objetos
    local lista = pista.objetos[i]
    if lista then
      for _, o in ipairs(lista) do Objetos.preparar(o) end
    end
  end
  pista.prox, pista.var, pista.plano, pista.obj_ant = prox, var, plano, ant
end

-- Desenha a estrada de uma visao e prepara, para cada segmento n a frente (0 a dist):
-- PSEG (indice na pista), XC/DXS (curvas), VAR e PCLIP (linha mais alta ja pintada quando a
-- estrada chegou nele: o que fica abaixo dela esta atras de um morro). retangulos = telas
-- divididas (faixas de 2 linhas com retangulos: as folhas de tiles passariam de 32 cargas de
-- imagem por quadro). As tabelas usadas no laco ficam em variaveis locais: no console cada
-- acesso a uma tabela de fora da funcao custa uma instrucao a mais.
local function estrada_linhas(pista, cores, dist, W, H, hy, base, cam_off, cam_x, cam_y, cor_mar, fim_fundo, retangulos)
  dados_da_pista(pista)
  local N, curvas, alturas, prox, var = pista.n, pista.curva, pista.y, pista.prox, pista.var
  local hw, fy = W * 0.5, H - hy
  local prof_fy, prof_hw = CAM_PROF * fy, CAM_PROF * hw
  local T = tabelas(W, H, hy)
  local ZS, KX, LW, TF, TID, TW = T.zs, T.kx, T.w, T.f, T.id, T.tw
  local PSEG_, PCLIP_, XC_, DXS_, VAR_, HA_, HD_ = PSEG, PCLIP, XC, DXS, VAR, HA, HD
  local c0 = cam_off / SEG                 -- onde a camera esta no segmento dela (0 a 1)
  local h0 = cam_y - CAM_ALTURA            -- altura da pista embaixo da camera
  local invHc = 1 / CAM_ALTURA
  local rect = ui.rectfill
  local i = base % N + 1
  local plano = pista.plano[i] >= dist + 2 and alturas[i] == h0

  -- 1) segmentos a frente: curvas, indice, faixa clara/escura (e alturas, se tem morro)
  local x, dx = -cam_x, -(curvas[i] * c0)
  for n = 0, dist + 1 do
    PSEG_[n], XC_[n], DXS_[n], VAR_[n] = i, x, dx, var[i]
    if not plano then
      local ha = alturas[i]
      HA_[n], HD_[n] = (ha - h0) * invHc, (alturas[prox[i]] - ha) * invHc
    end
    x = x + dx
    dx = dx + curvas[i]
    i = prox[i]
  end

  -- 2) grama em faixas de ZEBRA segmentos (como a zebra), projetadas so nas bordas. Ficam
  --    guardadas de perto para longe e sao desenhadas de longe para perto.
  local nb, topo = 0, H                    -- faixas guardadas; linha mais alta de grama
  local borda = ESTRADA * ZEBRA_LARG       -- ponta da zebra, a partir do centro (no mundo)
  local yb_ant, eb_ant
  local n = 0
  local fundo = false                      -- a ultima faixa (perto do horizonte) tem cor fixa
  while true do
    local z = n * SEG - cam_off
    local yb
    if z < ZMIN then
      z, yb = ZMIN, H
    end
    local inv = 1 / z
    yb = yb or hy + prof_fy * (cam_y - alturas[PSEG_[n]]) * inv
    local eb = hw + prof_hw * (XC_[n] + borda) * inv
    if yb_ant and yb < topo then           -- faixa de yb (longe) ate topo (o que ja aparece)
      nb = nb + 1
      -- cor da faixa; a do fundo e sempre a clara (se seguisse o segmento onde comeca, trocaria
      -- de tom inteira enquanto o carro anda: o horizonte "piscava")
      BY1[nb], BY2[nb], BX[nb], BC[nb] = yb // 1, topo // 1, min(eb, eb_ant) // 1, fundo and 0 or VAR_[n - 1]
      topo = yb
    end
    if n >= dist then break end
    yb_ant, eb_ant = yb, eb
    -- proxima borda: onde a faixa troca de cor (ou o fim da estrada). Depois de FAIXAS_ATE
    -- segmentos cada faixa teria menos de 1 pixel de altura: o resto fica com cor fixa, em
    -- pedacos de PASSO_FUNDO segmentos (um pedaco so, numa curva, deixava a areia invadir o
    -- outro lado da estrada no fim da curva).
    if n >= FAIXAS_ATE then
      n, fundo = min(dist, n + PASSO_FUNDO), true
    else
      local v = VAR_[n]
      repeat n = n + 1 until n >= dist or VAR_[n] ~= v
    end
  end
  -- mar/horizonte entre o panorama e o ponto mais longe da estrada
  if topo > fim_fundo then rect(0, fim_fundo, W, topo // 1, cor_mar) end
  local grama, direita = cores.grama, cores.direita
  for b = nb, 1, -1 do                     -- de longe para perto (a de perto cobre a sobra)
    local k = BC[b] + 1
    rect(0, BY1[b], W, BY2[b], grama[k])
    if direita then rect(BX[b], BY1[b], W, BY2[b], direita[k]) end
  end
  if not retangulos then cores_da_estrada(cores) end

  -- 3) linhas da estrada, de perto para longe (cada linha pinta so acima da mais alta ja
  --    pintada: o que ficar abaixo esta atras de um morro). Linhas largas demais para as
  --    fatias (pe da tela) e as telas divididas: retangulos, em faixas de 2 linhas.
  local desenha = not R.sem.estrada
  local tile, lote = ui.tile, Desenho.lote
  local maxy, kk, folha = H, -1, nil
  local x_ant                              -- centro da ultima linha pintada (para os buracos)
  -- linhas duplas (C.LINHAS_DUPLAS): da linha "dupla" para baixo, cada linha vale por duas
  local dupla = (C.LINHAS_DUPLAS or DEV.duplas) and not retangulos and (fy * C.LINHAS_DUPLAS_DESDE) // 1
    or 1000000
  local r, r_min = fy, (prof_fy * CAM_ALTURA / (dist * SEG)) // 1 + 1
  if not plano then
    -- subida logo a frente: as linhas sobem na tela; comeca de mais baixo para cobrir o pe
    local q = c0 + ZS[fy]
    local k = q // 1
    local dh = HA_[k] + HD_[k] * (q - k)
    if dh > 0 then
      local fat = 1 - dh
      r = fat > 0.4 and min(T.rmax, (fy / fat) // 1 + 2) or T.rmax
    end
  end
  while r >= r_min do
    local q = c0 + ZS[r]
    local k = q // 1
    local t = q - k
    if k > kk then
      repeat
        kk = kk + 1
        PCLIP_[kk] = maxy
      until kk == k
    end
    local y = plano and hy + r or (hy + r - r * (HA_[k] + HD_[k] * t)) // 1
    local f = not retangulos and TF[r]
    if y < maxy then
      if desenha then
        local X = hw + (XC_[k] + DXS_[k] * t) * KX[r]
        local indice = PSEG_[k]
        if f and indice > 2 then
          if f ~= folha then
            lote(f)
            folha = f
          end
          local id, tw = TID[r] + VAR_[k], TW[r]
          local xc = (X + 0.5) // 1
          tile(f, id, xc, y)
          tile(f, id + 1024, xc - tw, y)
          if maxy - y > 1 and x_ant then
            -- o morro afastou as linhas: preenche o buraco indo do centro desta linha ate o
            -- da anterior (sem isso, as bordas ficam em escadinha nas subidas fortes)
            local passo_x = (x_ant - X) / (maxy - y)
            for yy = y + 1, maxy - 1 do
              local xi = (X + passo_x * (yy - y) + 0.5) // 1
              tile(f, id, xi, yy)
              tile(f, id + 1024, xi - tw, yy)
            end
          end
          if r >= dupla then           -- a linha de cima repete esta (sem fazer as contas dela)
            tile(f, id, xc, y - 1)
            tile(f, id + 1024, xc - tw, y - 1)
            y = y - 1
          end
        else
          linha_retangulos(cores, VAR_[k] == 0, X, LW[r], y, maxy, indice)
          folha = nil
        end
        x_ant = X
      end
      maxy = y
    end
    -- proxima linha: retangulos (pe da tela) de 3 em 3 linhas em 1 jogador e de 2 em 2 nas
    -- telas divididas; tiles de 2 em 2 da linha "dupla" para baixo; senao, 1
    if not f then r = r - (retangulos and 2 or 3)
    elseif r >= dupla then r = r - 2
    else r = r - 1 end
  end
  while kk < dist do
    kk = kk + 1
    PCLIP_[kk] = maxy
  end
end

-- topo do panorama numa visao com horizonte em hy
local function topo_fundo(f, hy)
  return floor(hy - f.altura + 3)
end

-- Qual panoramica usar numa visao: nas telas divididas so a parte de baixo da inteira
-- aparece. A versao "baixo" (so essa parte, em pedacos estreitos) comeca no topo da visao
-- e le do cartao so o que aparece (limite de 150 KB por quadro).
local function panoramica(f, hy)
  if topo_fundo(f, hy) < 0 then return f.baixo end
  return f
end

-- Ceu + panorama de todas as visoes (o panorama desliza nas curvas ate o limite da imagem).
-- Desenha visao por visao e NUNCA a mesma imagem duas vezes seguidas: no console, o jogo
-- travou em 2 jogadores logo depois de desenhar o mesmo pedaco nas duas visoes em seguida.
-- Nas telas divididas os pedacos sao estreitos (so a parte que aparece e lida do cartao).
function R.fundos(pista, visoes, carros)
  local f = Arte.fundos[pista.fundo]
  local p = panoramica(f, visoes[1].hy)   -- todas as visoes de uma tela tem a mesma altura
  local ultima                             -- ultima imagem desenhada
  for j, v in ipairs(visoes) do
    local carro = carros[j]
    local margem = max(0, (f.largura - v.w) / 2)
    carro.fundo_x = max(-margem, min(margem, carro.fundo_x))
    local x0 = floor(-(margem + carro.fundo_x))
    local y = max(0, topo_fundo(p, v.hy))
    ui.clip(v.x, v.y, v.w, v.h)
    ui.camera(-v.x, -v.y)
    if R.sem.fundo then y = y + p.altura end   -- teste de desempenho: so a cor do ceu
    if y > 0 then ui.rectfill(0, 0, v.w, y, f.cor_ceu) end
    local i1, i2                           -- primeiro e ultimo pedaco que aparecem
    for i = 1, R.sem.fundo and 0 or #p.sprites do
      local x = x0 + p.inicio[i]
      if x + p.larguras[i] > 0 and x < v.w then
        i1 = i1 or i
        i2 = i
      end
    end
    if i1 then
      local de, ate, passo = i1, i2, 1
      if p.sprites[i1] == ultima then de, ate, passo = i2, i1, -1 end   -- evita repetir a imagem
      for i = de, ate, passo do R.spr(p.sprites[i], x0 + p.inicio[i], y) end
      ultima = p.sprites[ate]
    end
  end
end

-- onde ficam os escapamentos na imagem do carro (fracao da largura e da altura)
local ESCAPE_X, ESCAPE_Y = { 0.27, 0.73 }, 0.80

-- segmentos vizinhos da mesma cor viram um trapezio so enquanto a altura somada for ate esta
-- (longe, cada segmento tem 1 ou 2 px: juntar economiza muitos comandos de desenho)
local JUNTAR_PX = 8

-- Desenha a visao de um jogador. Chame R.fundos antes (ceu e panorama de todas as visoes).
-- v = { x, y, w, h, hy (horizonte), dist (segmentos a desenhar) }
function R.visao(corrida, carro, v, quadro)
  local pista = corrida.pista
  local N, L, SEG = pista.n, pista.comprimento, C.SEG
  local curvas, alturas, cores = pista.curva, pista.y, pista.cores
  local W, H, hy = v.w, v.h, v.hy
  local hw, fy = W * 0.5, H - hy

  ui.clip(v.x, v.y, W, H)
  ui.camera(-v.x, -v.y)
  dados_da_pista(pista)
  -- coqueiros pequenos em imagem so em 1 jogador: em 2 a visao e achatada (as imagens foram
  -- feitas na proporcao de 1 jogador) e em 3 cada coqueiro de meia distancia, vezes 3 visoes,
  -- passava de 32 cargas de imagem por quadro (e la sao poucos coqueiros)
  Objetos.coqueiro_imagem = Objetos.tem_coqueiro_imagem and W > 300 and fy > hw * 0.5
  local f = Arte.fundos[pista.fundo]
  local p = panoramica(f, hy)
  local fim_fundo = max(0, topo_fundo(p, hy)) + p.altura

  -- camera fica atras do carro
  local cam = carro.z - C.JOGADOR_Z
  if cam < 0 then cam = cam + L end
  local base = floor(cam / SEG)
  local base_pct = (cam - base * SEG) / SEG
  local ps = floor(carro.z / SEG)
  local ya, yb = alturas[ps % N + 1], alturas[(ps + 1) % N + 1]
  local cam_y = ya + (yb - ya) * ((carro.z - ps * SEG) / SEG) + C.CAM_ALTURA
  local cam_x = carro.x * C.ESTRADA

  local CAM_PROF, ZEBRA, larg = C.CAM_PROF, C.ZEBRA, C.ESTRADA * hw
  local modo = H < C.ALTURA and R.estrada_dividida or R.estrada
  local por_linhas = modo == "linhas" or modo == "linhas2"
  if por_linhas then
    -- estrada por linhas (v0.94); objetos e carros projetam so os segmentos onde estao
    q_off, q_hw, q_prof_hw, q_prof_fy = base_pct * SEG, hw, CAM_PROF * hw, CAM_PROF * fy
    q_hy, q_cam_y, q_alt = hy, cam_y, alturas
    estrada_linhas(pista, cores, v.dist, W, H, hy, base, base_pct * SEG, cam_x, cam_y, f.cor_mar, fim_fundo,
      modo == "linhas2")
  else
    -- 1) estrada, de perto para longe. Cada ponto da pista e projetado uma vez so: a borda
    --    de longe de um segmento e a borda de perto do seguinte. O trapezio "aberto" (a*)
    --    junta segmentos pequenos. (Constantes em variaveis locais: o Lupi executa so
    --    ~50-60 mil instrucoes Lua por quadro, e este laco roda para cada segmento.)
    local maxy = H
    local x, dx = 0, -(curvas[base % N + 1] * base_pct)
    local aberto, escondido = false, false
    local aX1, aY1, aW1, aX2, aY2, aW2, aClaro, aIdx
    local nt = 0   -- trapezios guardados (TX1...), desenhados depois do laco
    local z = base * SEG - cam
    local s1, X1, Y1
    if z > CAM_PROF then
      s1 = CAM_PROF / z
      X1, Y1 = hw + s1 * (x - cam_x) * hw, hy + s1 * (cam_y - alturas[base % N + 1]) * fy
    end
    local prof_hw, prof_fy = CAM_PROF * hw, CAM_PROF * fy
    for n = 0, v.dist - 1 do
      local i = (base + n) % N + 1
      local i2 = i == N and 1 or i + 1
      PCLIP[n] = maxy
      PSEG[n] = i
      local z2 = z + SEG
      local s2 = CAM_PROF / z2
      local X2 = hw + prof_hw * (x + dx - cam_x) / z2
      local Y2 = hy + prof_fy * (cam_y - alturas[i2]) / z2
      PX1[n], PY1[n], PS1[n] = X1, Y1, s1
      if s1 then
        local iy1, iy2 = Y1 // 1, Y2 // 1
        if iy2 < maxy and iy2 < iy1 then
          local cX1, W1, W2 = X1, s1 * larg, s2 * larg
          if iy1 >= maxy then
            -- parte de baixo escondida atras do morro: corta o trapezio
            local t = (maxy - 1 - Y2) / (Y1 - Y2)
            cX1, W1, iy1 = X2 + (X1 - X2) * t, W2 + (W1 - W2) * t, maxy - 1
          end
          local claro = ((i - 1) // ZEBRA) % 2 == 0
          if aberto and claro == aClaro and i > 2 and aIdx > 2 and not escondido and aY1 - iy2 <= JUNTAR_PX then
            aX2, aY2, aW2 = X2, iy2, W2   -- estica o trapezio aberto ate este segmento
          else
            if aberto then
              nt = nt + 1
              TX1[nt], TY1[nt], TW1[nt], TX2[nt], TY2[nt], TW2[nt], TCLARO[nt], TIDX[nt] = aX1, aY1, aW1, aX2, aY2, aW2, aClaro, aIdx
            end
            aberto, aClaro, aIdx = true, claro, i
            aX1, aY1, aW1, aX2, aY2, aW2 = cX1, iy1, W1, X2, iy2, W2
          end
          escondido = false
          maxy = iy2
        elseif iy2 >= maxy or iy2 > iy1 then
          escondido = true   -- atras de um morro: o proximo segmento visivel nao emenda neste trapezio
        end
      end
      if z2 > CAM_PROF then s1, X1, Y1 = s2, X2, Y2 else s1 = nil end
      z = z2
      x = x + dx
      dx = dx + curvas[i]
    end
    PX1[v.dist], PY1[v.dist], PS1[v.dist] = X1, Y1, s1   -- borda de longe do ultimo segmento
    if aberto then
      nt = nt + 1
      TX1[nt], TY1[nt], TW1[nt], TX2[nt], TY2[nt], TW2[nt], TCLARO[nt], TIDX[nt] = aX1, aY1, aW1, aX2, aY2, aW2, aClaro, aIdx
    end
    -- faixa entre o panorama e o ponto mais distante da estrada (mar/horizonte)
    if maxy > fim_fundo then ui.rectfill(0, fim_fundo, W, maxy, f.cor_mar) end
    -- Os trapezios sao desenhados de LONGE para PERTO: se o retangulo do console pintar uma
    -- linha a mais embaixo (no simulador a ultima linha nao entra), o de perto cobre a sobra.
    if R.sem.estrada then
      ui.rectfill(0, maxy, W, H, cores.grama[1])
    elseif modo == "tiles" then
      -- primeiro a grama de todos os trapezios, depois as fatias: assim os tiles de uma folha
      -- saem seguidos (um lote so no console)
      for t = nt, 1, -1 do
        grama(W, cores, TCLARO[t] and 1 or 2, TX1[t], TY1[t], TW1[t], TX2[t], TY2[t], TW2[t])
      end
      cores_da_estrada(cores)
      for t = nt, 1, -1 do
        if TIDX[t] <= 2 then   -- linha de largada quadriculada: retangulos
          linhas_retangulos(cores, TCLARO[t], TX1[t], TY1[t], TW1[t], TX2[t], TY2[t], TW2[t], TIDX[t], 1)
        else
          linhas_tiles(cores, TCLARO[t], TX1[t], TY1[t], TW1[t], TX2[t], TY2[t], TW2[t], TIDX[t])
        end
      end
    else
      -- telas divididas: faixas de 2 linhas (mais leve)
      local passo = (H < C.ALTURA or modo == "retangulos2") and 2 or 1
      for t = nt, 1, -1 do
        grama(W, cores, TCLARO[t] and 1 or 2, TX1[t], TY1[t], TW1[t], TX2[t], TY2[t], TW2[t])
        linhas_retangulos(cores, TCLARO[t], TX1[t], TY1[t], TW1[t], TX2[t], TY2[t], TW2[t], TIDX[t], passo)
      end
    end
  end

  -- 2) quais carros estao na frente desta camera
  local nv = 0
  local todos = corrida.carros
  for c = 1, R.sem.carros and 0 or #todos do
    local outro = todos[c]
    if outro ~= carro then
      local n = (floor(outro.z / SEG) - base) % N
      if n >= 1 and n < v.dist then
        nv = nv + 1
        local j = nv
        while j > 1 and VIS_N[j - 1] < n do   -- ordena do mais longe para o mais perto
          VIS_N[j], VIS_C[j] = VIS_N[j - 1], VIS_C[j - 1]
          j = j - 1
        end
        VIS_N[j], VIS_C[j] = n, outro
      end
    end
  end

  -- 3) objetos e carros, de longe para perto. So os segmentos que tem algo: o laco pula
  --    direto de um segmento com objetos para o anterior (pista.obj_ant), e visita tambem os
  --    das latas de nitro e dos carros. (Antes visitava os 100 segmentos, quase todos vazios.)
  local recorte = H
  local objetos, noite, larg_carro = pista.objetos, pista.noite, C.CARRO_LARGURA * hw
  local enfeite = H < C.ALTURA   -- telas divididas: metade dos enfeites
  local PSEG_, PS1_, VIS_N_, ant = PSEG, PS1, VIS_N, pista.obj_ant
  local vc = 1                                  -- proximo carro (VIS_N esta de longe para perto)
  local no = min(v.objetos or v.dist, v.dist) - 1   -- proximo segmento com objetos
  if R.sem.objetos then
    no = 0
  elseif no >= 1 and not objetos[PSEG_[no]] then
    no = no - ant[PSEG_[no]]
  end
  local ni = 0                                  -- latas de nitro desta visao, de longe para perto
  for _, it in ipairs(corrida.itens) do
    local n = (it.seg - 1 - base) % N
    if n >= 1 and n < v.dist then
      ni = ni + 1
      local j = ni
      while j > 1 and IT_N[j - 1] < n do
        IT_N[j], IT_O[j] = IT_N[j - 1], IT_O[j - 1]
        j = j - 1
      end
      IT_N[j], IT_O[j] = n, it
    end
  end
  local ki = 1
  while true do
    local nc = vc <= nv and VIS_N_[vc] or 0
    local nit = ki <= ni and IT_N[ki] or 0
    local n = no
    if nc > n then n = nc end
    if nit > n then n = nit end
    if n < 1 then break end
    local lista = n == no and objetos[PSEG_[n]]
    local item = n == nit and IT_O[ki]
    local tem_carro = n == nc
    if por_linhas then   -- projeta so os segmentos com algo
      ponto(n)
      if tem_carro then ponto(n + 1) end
    end
    local s1 = PS1_[n]
    if s1 then
      local px, py = PX1[n], PY1[n]
      -- so recorta quando a base do segmento ficou atras de um morro (no plano nao precisa)
      local clip = py > PCLIP[n] + 1 and PCLIP[n] or H
      if clip ~= recorte then
        ui.clip(v.x, v.y, W, max(1, clip))
        recorte = clip
      end
      local kx, ky, ox = s1 * hw, s1 * fy, s1 * larg
      -- objetos: a mesma conta de Objetos.desenhar (fora da tela ou colado na camera nao
      -- desenha), feita aqui para nao chamar mais uma funcao por objeto
      if lista and kx <= ESCALA_OBJ and py >= 0 then
        local pula = enfeite and PSEG_[n] % 2 == 1
        for k = 1, #lista do
          local o = lista[k]
          local desenho = o.desenho
          if desenho and not (pula and o.enfeite) and py - o.alt * ky <= H then
            local sx, alcance = px + ox * o.x, o.alc * kx
            if sx + alcance >= 0 and sx - alcance <= W then desenho(o, sx, py, kx, ky, noite) end
          end
        end
      end
      if item then Objetos.nitro(px + ox * item.x, py, kx, ky, W, H, quadro) end
      while vc <= nv and VIS_N_[vc] == n do
        local outro = VIS_C[vc]
        local pct = (outro.z % SEG) / SEG
        local s = s1 + (PS1[n + 1] - s1) * pct
        local sx = px + (PX1[n + 1] - px) * pct + s * outro.x * larg
        local sy = py + (PY1[n + 1] - py) * pct
        local largura = s * larg_carro
        if largura >= 3 then
          local k = nivel(largura)
          local tam = TAM[outro.modelo].reto[k]
          local w, h = tam[1], tam[2]
          local cx, cy = floor(sx - w / 2), floor(sy - h)
          -- so se aparecer: fora da tela (ou todo atras do morro) nao manda nada ao console
          -- (carros atras da camera dariam coordenadas gigantes)
          if cx < W and cx + w > 0 and cy < recorte and cy + h > 0 then
            R.spr(SPR[outro.modelo][outro.cor].reto[k], cx, cy)
          end
        end
        vc = vc + 1
      end
    end
    -- o que foi visitado sai da fila (carros e latas mesmo se nao apareceram)
    while vc <= nv and VIS_N_[vc] == n do vc = vc + 1 end
    if n == nit then ki = ki + 1 end
    if n == no then no = no - ant[PSEG_[no]] end
  end
  if recorte ~= H then ui.clip(v.x, v.y, W, H) end

  -- 4) o carro do jogador
  if R.sem.carros then return end
  local k = nivel(C.CARRO_LARGURA / C.CAM_ALTURA * hw)
  local vistas, tamanhos = SPR[carro.modelo][carro.cor], TAM[carro.modelo]
  local vista = "reto"   -- virando so se existir a vista de curva neste tamanho
  if carro.direcao < 0 and vistas.esq[k] then vista = "esq" elseif carro.direcao > 0 and vistas.dir[k] then vista = "dir" end
  local spr, sw, sh = vistas[vista][k], tamanhos[vista][k][1], tamanhos[vista][k][2]
  local tremor = 0
  if carro.vel > 0 then tremor = (quadro // 3) % 2 end
  if math.abs(carro.x) > 1 and carro.vel > 0 then tremor = tremor + (quadro // 2) % 2 end
  local bx = floor(hw - sw / 2)
  if carro.batida > 0 then bx = bx + ((quadro % 4 < 2) and -2 or 2) end
  local by = floor(H - sh - 3 - tremor)
  R.spr(spr, bx, by)
  if carro.nitro_t > 0 then
    -- chamas nos dois escapamentos, em quadros diferentes (tremem e nunca repetem a imagem)
    local tam = k <= 2 and "g" or "p"
    local cw = Efeitos.chama[tam][1]
    local q = (quadro // 4) % Efeitos.quadros_chama
    local cy = by + floor(sh * ESCAPE_Y)
    R.spr(CHAMA[tam][q + 1], bx + floor(sw * ESCAPE_X[1]) - cw // 2, cy)
    R.spr(CHAMA[tam][(q + 1) % Efeitos.quadros_chama + 1], bx + floor(sw * ESCAPE_X[2]) - cw // 2, cy)
  end
end

return R
