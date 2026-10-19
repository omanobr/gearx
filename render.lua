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

-- projecoes guardadas durante a passada da estrada (reaproveitadas a cada quadro)
local PX1, PY1, PS1, PX2, PY2, PS2, PCLIP, PSEG = {}, {}, {}, {}, {}, {}, {}, {}
-- carros visiveis nesta visao
local VIS_N, VIS_C = {}, {}

-- sprites dos carros: SPR[cor].reto[nivel], .esq[nivel], .dir[nivel]
local SPR, LARGURA_NIVEL1 = {}, 1
function R.preparar()
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
  LARGURA_NIVEL1 = SPR.prata.reto[1].width
  for nome, f in pairs(Arte.fundos) do
    f.sprites = {}
    for i, peca in ipairs(f.pecas) do f.sprites[i] = Sprites.img.fundos[peca] end
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

local function segmento(W, cores, claro, x1, y1, w1, x2, y2, w2, indice)
  local k = claro and 1 or 2
  local r1, r2 = w1 / 6, w2 / 6
  ui.rectfill(0, y2, W, y1 + 1, cores.grama[k])
  if cores.direita then
    ui.rectfill(floor(min(x1 + w1 + r1, x2 + w2 + r2)), y2, W, y1 + 1, cores.direita[k])
  end
  quad(x1 - w1 - r1, y1, x1 + w1 + r1, y1, x2 + w2 + r2, y2, x2 - w2 - r2, y2, cores.zebra[k])
  if indice <= 2 then
    -- linha de largada/chegada quadriculada
    quad(x1 - w1, y1, x1 + w1, y1, x2 + w2, y2, x2 - w2, y2, Cores.branco)
    ui.fillp(table.unpack(XADREZ))
    quad(x1 - w1, y1, x1 + w1, y1, x2 + w2, y2, x2 - w2, y2, Cores.preto)
    ui.fillp()
    return
  end
  quad(x1 - w1, y1, x1 + w1, y1, x2 + w2, y2, x2 - w2, y2, cores.asfalto[k])
  if claro then
    local l1, l2 = w1 / 60, w2 / 60
    local lw1, lw2 = w1 * 2 / C.FAIXAS, w2 * 2 / C.FAIXAS
    local lx1, lx2 = x1 - w1 + lw1, x2 - w2 + lw2
    for _ = 1, C.FAIXAS - 1 do
      quad(lx1 - l1, y1, lx1 + l1, y1, lx2 + l2, y2, lx2 - l2, y2, cores.faixa)
      lx1, lx2 = lx1 + lw1, lx2 + lw2
    end
  end
end

-- ceu + panorama (que desliza nas curvas ate o limite da imagem)
local function fundo(pista, carro, W, H, hy)
  local f = Arte.fundos[pista.fundo]
  local margem = max(0, (f.largura - W) / 2)
  carro.fundo_x = max(-margem, min(margem, carro.fundo_x))
  local x = floor(-(margem + carro.fundo_x))
  local y = floor(hy - f.altura + 3)
  if y > 0 then ui.rectfill(0, 0, W, y, f.cor_ceu) end
  for i, spr in ipairs(f.sprites) do
    local lp = f.larguras[i]
    if x + lp > 0 and x < W then ui.spr(spr, x, y) end
    x = x + lp
  end
  return y + f.altura, f.cor_mar
end

-- v = { x, y, w, h, hy (horizonte), dist (segmentos a desenhar) }
function R.visao(corrida, carro, v, quadro)
  local pista = corrida.pista
  local N, L, SEG = pista.n, pista.comprimento, C.SEG
  local curvas, alturas, cores = pista.curva, pista.y, pista.cores
  local W, H, hy = v.w, v.h, v.hy
  local hw, fy = W * 0.5, H - hy

  ui.clip(v.x, v.y, W, H)
  ui.camera(-v.x, -v.y)
  local fim_fundo, cor_mar = fundo(pista, carro, W, H, hy)

  -- camera fica atras do carro
  local cam = carro.z - C.JOGADOR_Z
  if cam < 0 then cam = cam + L end
  local base = floor(cam / SEG)
  local base_pct = (cam - base * SEG) / SEG
  local ps = floor(carro.z / SEG)
  local ya, yb = alturas[ps % N + 1], alturas[(ps + 1) % N + 1]
  local cam_y = ya + (yb - ya) * ((carro.z - ps * SEG) / SEG) + C.CAM_ALTURA
  local cam_x = carro.x * C.ESTRADA

  -- 1) estrada, de perto para longe
  local maxy = H
  local x, dx = 0, -(curvas[base % N + 1] * base_pct)
  for n = 0, v.dist - 1 do
    local s = base + n
    local i, i2 = s % N + 1, (s + 1) % N + 1
    local z1 = s * SEG - cam
    PCLIP[n] = maxy
    PSEG[n] = i
    if z1 > C.CAM_PROF then
      local s1, s2 = C.CAM_PROF / z1, C.CAM_PROF / (z1 + SEG)
      local X1 = hw + s1 * (x - cam_x) * hw
      local X2 = hw + s2 * (x + dx - cam_x) * hw
      local Y1 = hy + s1 * (cam_y - alturas[i]) * fy
      local Y2 = hy + s2 * (cam_y - alturas[i2]) * fy
      PX1[n], PY1[n], PS1[n] = X1, Y1, s1
      PX2[n], PY2[n], PS2[n] = X2, Y2, s2
      local iy1, iy2 = floor(Y1), floor(Y2)
      if iy2 < maxy and iy2 < iy1 then
        local W1 = s1 * C.ESTRADA * hw
        local W2 = s2 * C.ESTRADA * hw
        if iy1 >= maxy then
          -- parte de baixo escondida atras do morro: corta o trapezio
          local t = (maxy - 1 - Y2) / (Y1 - Y2)
          X1, W1, iy1 = X2 + (X1 - X2) * t, W2 + (W1 - W2) * t, maxy - 1
        end
        segmento(W, cores, (floor((s % N) / C.ZEBRA) % 2) == 0, X1, iy1, W1, X2, iy2, W2, i)
        maxy = iy2
      end
    else
      PS1[n] = nil
    end
    x = x + dx
    dx = dx + curvas[i]
  end
  -- faixa entre o panorama e o ponto mais distante da estrada (mar/horizonte)
  if maxy > fim_fundo then ui.rectfill(0, fim_fundo, W, maxy, cor_mar) end

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
  for n = v.dist - 1, 1, -1 do
    while vc <= nv and VIS_N[vc] > n do vc = vc + 1 end
    local s1 = PS1[n]
    local tem_carro = vc <= nv and VIS_N[vc] == n
    local lista = pista.objetos[PSEG[n]]
    if s1 and (lista or tem_carro) then
      local clip = PCLIP[n]
      if clip ~= recorte then
        ui.clip(v.x, v.y, W, max(1, clip))
        recorte = clip
      end
      if lista then
        local kx, ky = s1 * hw, s1 * fy
        for _, o in ipairs(lista) do
          Objetos.desenhar(o, PX1[n] + s1 * o.x * C.ESTRADA * hw, PY1[n], kx, ky, pista.noite)
        end
      end
      while vc <= nv and VIS_N[vc] == n do
        local outro = VIS_C[vc]
        local pct = (outro.z % SEG) / SEG
        local s = s1 + (PS2[n] - s1) * pct
        local sx = PX1[n] + (PX2[n] - PX1[n]) * pct + s * outro.x * C.ESTRADA * hw
        local sy = PY1[n] + (PY2[n] - PY1[n]) * pct
        local largura = s * C.CARRO_LARGURA * hw
        if largura >= 3 then
          local spr = SPR[outro.cor].reto[nivel(largura)]
          ui.spr(spr, floor(sx - spr.width / 2), floor(sy - spr.height))
        end
        vc = vc + 1
      end
    end
  end
  if recorte ~= H then ui.clip(v.x, v.y, W, H) end

  -- 4) o carro do jogador
  local k = nivel(C.CARRO_LARGURA / C.CAM_ALTURA * hw)
  local vistas = SPR[carro.cor]
  local spr = (carro.direcao < 0 and vistas.esq[k]) or (carro.direcao > 0 and vistas.dir[k]) or vistas.reto[k]
  local tremor = 0
  if carro.vel > 0 then tremor = (quadro // 3) % 2 end
  if math.abs(carro.x) > 1 and carro.vel > 0 then tremor = tremor + (quadro // 2) % 2 end
  local bx = floor(hw - spr.width / 2)
  if carro.batida > 0 then bx = bx + ((quadro % 4 < 2) and -2 or 2) end
  local by = floor(H - spr.height - 3 - tremor)
  if carro.nitro_t > 0 then
    local f = 4 + (quadro % 3) * 2
    local cy = by + floor(spr.height * 0.82)
    for _, ex in ipairs({ 0.3, 0.7 }) do
      local fx = bx + floor(spr.width * ex)
      ui.trisfill(fx - 3, cy, fx + 3, cy, fx, cy + f, Cores.laranja)
      ui.trisfill(fx - 1, cy, fx + 1, cy, fx, cy + f - 2, Cores.amarelo)
    end
  end
  ui.spr(spr, bx, by)
end

return R
