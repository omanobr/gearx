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

local R = {}

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
function R.preparar()
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

local function quad(x1, y1, x2, y2, x3, y3, x4, y4, cor)
  ui.trisfill(x1, y1, x2, y2, x3, y3, cor)
  ui.trisfill(x1, y1, x3, y3, x4, y4, cor)
end

local XADREZ = { 0xCC, 0xCC, 0x33, 0x33, 0xCC, 0xCC, 0x33, 0x33 }

-- Um trapezio da estrada: grama, zebra, asfalto e faixas. Os trapezios viram dois
-- triangulos direto aqui (sem chamar quad): este e o trecho mais repetido do quadro.
local function segmento(W, cores, claro, x1, y1, w1, x2, y2, w2, indice)
  local tri = ui.trisfill
  local k = claro and 1 or 2
  local r1, r2 = w1 / 6, w2 / 6
  ui.rectfill(0, y2, W, y1 + 1, cores.grama[k])
  if cores.direita then
    ui.rectfill(floor(min(x1 + w1 + r1, x2 + w2 + r2)), y2, W, y1 + 1, cores.direita[k])
  end
  local a, b, c, d, cor = x1 - w1 - r1, x1 + w1 + r1, x2 + w2 + r2, x2 - w2 - r2, cores.zebra[k]
  tri(a, y1, b, y1, c, y2, cor)
  tri(a, y1, c, y2, d, y2, cor)
  if indice <= 2 then
    -- linha de largada/chegada quadriculada
    quad(x1 - w1, y1, x1 + w1, y1, x2 + w2, y2, x2 - w2, y2, Cores.branco)
    ui.fillp(table.unpack(XADREZ))
    quad(x1 - w1, y1, x1 + w1, y1, x2 + w2, y2, x2 - w2, y2, Cores.preto)
    ui.fillp()
    return
  end
  a, b, c, d, cor = x1 - w1, x1 + w1, x2 + w2, x2 - w2, cores.asfalto[k]
  tri(a, y1, b, y1, c, y2, cor)
  tri(a, y1, c, y2, d, y2, cor)
  if claro then
    local l1, l2 = w1 / 60, w2 / 60
    local lw1, lw2 = w1 * 2 / C.FAIXAS, w2 * 2 / C.FAIXAS
    local lx1, lx2 = x1 - w1 + lw1, x2 - w2 + lw2
    cor = cores.faixa
    for _ = 1, C.FAIXAS - 1 do
      if l1 < 0.8 then
        ui.line(floor(lx1), y1, floor(lx2), y2, cor)   -- faixa fininha (longe): uma linha basta
      else
        tri(lx1 - l1, y1, lx1 + l1, y1, lx2 + l2, y2, cor)
        tri(lx1 - l1, y1, lx2 + l2, y2, lx2 - l2, y2, cor)
      end
      lx1, lx2 = lx1 + lw1, lx2 + lw2
    end
  end
end

-- topo do panorama numa visao com horizonte em hy
local function topo_fundo(f, hy)
  return floor(hy - f.altura + 3)
end

-- Qual panoramica usar numa visao: nas telas divididas o topo da inteira ficaria acima da
-- visao, e o console TRAVA ao desenhar uma imagem cortada pelo topo da janela de recorte
-- (ui.clip). A versao "baixo" (so a parte de baixo) comeca exatamente no topo da visao.
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
    if y > 0 then ui.rectfill(0, 0, v.w, y, f.cor_ceu) end
    local i1, i2                           -- primeiro e ultimo pedaco que aparecem
    for i = 1, #p.sprites do
      local x = x0 + p.inicio[i]
      if x + p.larguras[i] > 0 and x < v.w then
        i1 = i1 or i
        i2 = i
      end
    end
    if i1 then
      local de, ate, passo = i1, i2, 1
      if p.sprites[i1] == ultima then de, ate, passo = i2, i1, -1 end   -- evita repetir a imagem
      for i = de, ate, passo do ui.spr(p.sprites[i], x0 + p.inicio[i], y) end
      ultima = p.sprites[ate]
    end
  end
end

local CHAMAS = { 0.3, 0.7 }   -- posicao das chamas do nitro (fracao da largura do carro)

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
  -- bordas desta visao que sao bordas da tela (uma imagem so pode ser cortada por elas)
  local tela_esq, tela_dir = v.x == 0, v.x + W >= C.LARGURA
  local tela_cima, tela_baixo = v.y == 0, v.y + H >= C.ALTURA

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
  -- Os trapezios sao desenhados de LONGE para PERTO, cada um com 1 linha a mais em cima e
  -- 2 embaixo: o de perto, desenhado depois, cobre a sobra. O triangulo do console deixa de
  -- fora a linha de cima e a de baixo (apareciam linhas verdes da grama entre os blocos,
  -- maiores ao longe, onde cada bloco tem poucas linhas); com a sobra nao fica fresta.
  for t = nt, 1, -1 do
    segmento(W, cores, TCLARO[t], TX1[t], TY1[t] + 2, TW1[t], TX2[t], TY2[t] - 1, TW2[t], TIDX[t])
  end

  -- 2) quais carros estao na frente desta camera
  local nv = 0
  for _, outro in ipairs(corrida.carros) do
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
  for n = v.dist - 1, 1, -1 do
    while vc <= nv and VIS_N[vc] > n do vc = vc + 1 end
    local s1 = PS1[n]
    local tem_carro = vc <= nv and VIS_N[vc] == n
    local lista = objetos[PSEG[n]]
    if s1 and (lista or tem_carro) then
      local px, py = PX1[n], PY1[n]
      -- so recorta quando a base do segmento ficou atras de um morro (no plano nao precisa)
      local clip = py > PCLIP[n] + 1 and PCLIP[n] or H
      if clip ~= recorte then
        ui.clip(v.x, v.y, W, max(1, clip))
        recorte = clip
      end
      if lista then
        local kx, ky, ox = s1 * hw, s1 * fy, s1 * larg
        for _, o in ipairs(lista) do
          Objetos.desenhar(o, px + ox * o.x, py, kx, ky, noite, W, H)
        end
      end
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
          -- So desenha se nenhuma borda da janela de recorte cortar a imagem (bordas da
          -- visao que nao sao bordas da tela, ou a linha de um morro): no console, imagem
          -- cortada pelo recorte travou o jogo. Fora da tela tambem nao (coordenadas gigantes).
          local cabe = cx < W and cx + w > 0 and cy < H and cy + h > 0
            and (cx >= 0 or tela_esq) and (cx + w <= W or tela_dir) and (cy >= 0 or tela_cima)
            and (cy + h <= recorte or (recorte == H and tela_baixo))
          if cabe then ui.spr(SPR[outro.cor].reto[k], cx, cy) end
        end
        vc = vc + 1
      end
    end
  end
  if recorte ~= H then ui.clip(v.x, v.y, W, H) end

  -- 4) o carro do jogador
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
  if carro.nitro_t > 0 then
    local f = 4 + (quadro % 3) * 2
    local cy = by + floor(sh * 0.82)
    for _, ex in ipairs(CHAMAS) do
      local fx = bx + floor(sw * ex)
      ui.trisfill(fx - 3, cy, fx + 3, cy, fx, cy + f, Cores.laranja)
      ui.trisfill(fx - 1, cy, fx + 1, cy, fx, cy + f - 2, Cores.amarelo)
    end
  end
  ui.spr(spr, bx, by)
end

return R
