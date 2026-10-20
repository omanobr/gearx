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
-- Estrada: "tiles" (fatias prontas, como no Super Nintendo; ferramentas/gerar_estrada.py)
-- ou "retangulos" (3 ou 4 retangulos por linha da tela, o jeito da v0.8 e v0.9).
-- ("retangulos2": retangulos com faixas de 2 linhas tambem em 1 jogador, para comparar)
R.estrada = C.ESTRADA_DESENHO
R.estrada_dividida = C.ESTRADA_DIVIDIDA

local floor, min, max, log = math.floor, math.min, math.max, math.log

-- projecoes guardadas durante a passada da estrada (reaproveitadas a cada quadro):
-- ponto de perto de cada segmento (o de longe e o ponto do segmento seguinte)
local PX1, PY1, PS1, PCLIP, PSEG = {}, {}, {}, {}, {}
-- trapezios da estrada desta visao (bordas de perto e de longe, cor, segmento)
local TX1, TY1, TW1, TX2, TY2, TW2, TCLARO, TIDX = {}, {}, {}, {}, {}, {}, {}, {}
-- carros visiveis nesta visao
local VIS_N, VIS_C = {}, {}

-- sprites dos carros: SPR[cor].reto[nivel], .esq[nivel], .dir[nivel]
-- Tamanhos vem de Arte.carros.tamanho (TAM.reto[nivel] = { largura, altura }): no console,
-- as imagens de Sprites nao trazem largura e altura (so servem para passar ao ui.spr).
local SPR, LARGURA_NIVEL1 = {}, 1
local TAM
local CHAMA = { g = {}, p = {} }   -- chamas do nitro (ferramentas/gerar_efeitos.py)
-- estrada em tiles: folha, tile e largura do tile de cada largura Z (dados_estrada.lua)
local EF, ET, EW = {}, {}, {}
local Z_MAX = Estrada.z_max

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
  for _, cor in ipairs(Arte.carros.cores) do
    local pasta = Sprites.img.carros[cor]
    local t = { reto = {}, esq = {}, dir = {} }
    for k = 1, Arte.carros.niveis do
      t.reto[k] = pasta["reto" .. k]
      t.esq[k] = pasta["esq" .. k]
      t.dir[k] = pasta["dir" .. k]
    end
    SPR[cor] = t
  end
  LARGURA_NIVEL1 = TAM.reto[1][1]
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

  -- 1) estrada, de perto para longe. Cada ponto da pista e projetado uma vez so: a borda
  --    de longe de um segmento e a borda de perto do seguinte. O trapezio "aberto" (a*)
  --    junta segmentos pequenos. (Constantes em variaveis locais: o Lupi executa so
  --    ~50-60 mil instrucoes Lua por quadro, e este laco roda para cada segmento.)
  local CAM_PROF, ZEBRA, larg = C.CAM_PROF, C.ZEBRA, C.ESTRADA * hw
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
  local modo = H < C.ALTURA and R.estrada_dividida or R.estrada
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

  -- 3) objetos e carros, de longe para perto
  local vc = 1
  local recorte = H
  local objetos, noite, larg_carro = pista.objetos, pista.noite, C.CARRO_LARGURA * hw
  local itens = corrida.item_seg
  local enfeite = H < C.ALTURA and Objetos.enfeite   -- telas divididas: metade dos enfeites
  local sem_objetos = R.sem.objetos
  local alcance_objetos = v.objetos or v.dist   -- mais longe que isto, so carros e latas de nitro
  for n = v.dist - 1, 1, -1 do
    while vc <= nv and VIS_N[vc] > n do vc = vc + 1 end
    local s1 = PS1[n]
    local tem_carro = vc <= nv and VIS_N[vc] == n
    local lista, item = objetos[PSEG[n]], itens[PSEG[n]]
    if sem_objetos then lista, item = nil, nil elseif n >= alcance_objetos then lista = nil end
    if s1 and (lista or tem_carro or item) then
      local px, py = PX1[n], PY1[n]
      -- so recorta quando a base do segmento ficou atras de um morro (no plano nao precisa)
      local clip = py > PCLIP[n] + 1 and PCLIP[n] or H
      if clip ~= recorte then
        ui.clip(v.x, v.y, W, max(1, clip))
        recorte = clip
      end
      local kx, ky, ox = s1 * hw, s1 * fy, s1 * larg
      if lista then
        local pula = enfeite and PSEG[n] % 2 == 1
        for k = 1, #lista do
          local o = lista[k]
          if not (pula and enfeite[o.tipo]) then
            Objetos.desenhar(o, px + ox * o.x, py, kx, ky, noite, W, H)
          end
        end
      end
      if item then Objetos.nitro(px + ox * item.x, py, kx, ky, W, H, quadro) end
      while vc <= nv and VIS_N[vc] == n do
        local outro = VIS_C[vc]
        local pct = (outro.z % SEG) / SEG
        local s = s1 + (PS1[n + 1] - s1) * pct
        local sx = px + (PX1[n + 1] - px) * pct + s * outro.x * larg
        local sy = py + (PY1[n + 1] - py) * pct
        local largura = s * larg_carro
        if largura >= 3 then
          local k = nivel(largura)
          local tam = TAM.reto[k]
          local w, h = tam[1], tam[2]
          local cx, cy = floor(sx - w / 2), floor(sy - h)
          -- so se aparecer: fora da tela (ou todo atras do morro) nao manda nada ao console
          -- (carros atras da camera dariam coordenadas gigantes)
          if cx < W and cx + w > 0 and cy < recorte and cy + h > 0 then
            R.spr(SPR[outro.cor].reto[k], cx, cy)
          end
        end
        vc = vc + 1
      end
    end
  end
  if recorte ~= H then ui.clip(v.x, v.y, W, H) end

  -- 4) o carro do jogador
  if R.sem.carros then return end
  local k = nivel(C.CARRO_LARGURA / C.CAM_ALTURA * hw)
  local vistas = SPR[carro.cor]
  local vista = "reto"   -- virando so se existir a vista de curva neste tamanho
  if carro.direcao < 0 and vistas.esq[k] then vista = "esq" elseif carro.direcao > 0 and vistas.dir[k] then vista = "dir" end
  local spr, sw, sh = vistas[vista][k], TAM[vista][k][1], TAM[vista][k][2]
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
