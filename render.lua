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
    f.sprites, f.inicio = {}, {}
    local x = 0
    for i, peca in ipairs(f.pecas) do
      f.sprites[i], f.inicio[i] = Sprites.img.fundos[peca], x
      x = x + f.larguras[i]
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
      if l1 < 0.8 then
        ui.line(floor(lx1), y1, floor(lx2), y2, cores.faixa)   -- faixa fininha (longe): uma linha basta
      else
        quad(lx1 - l1, y1, lx1 + l1, y1, lx2 + l2, y2, lx2 - l2, y2, cores.faixa)
      end
      lx1, lx2 = lx1 + lw1, lx2 + lw2
    end
  end
end

-- topo do panorama numa visao com horizonte em hy
local function topo_fundo(f, hy)
  return floor(hy - f.altura + 3)
end

-- Ceu + panorama de todas as visoes (o panorama desliza nas curvas ate o limite da imagem).
-- Cada pedaco do panorama e desenhado em todas as visoes em seguida: assim o aparelho le a
-- imagem do cartao uma vez so por quadro (limites de 150 KB e 32 cargas por quadro).
local FUNDO_X = {}
function R.fundos(pista, visoes, carros)
  local f = Arte.fundos[pista.fundo]
  for j, v in ipairs(visoes) do
    local carro = carros[j]
    local margem = max(0, (f.largura - v.w) / 2)
    carro.fundo_x = max(-margem, min(margem, carro.fundo_x))
    FUNDO_X[j] = floor(-(margem + carro.fundo_x))
    local y = topo_fundo(f, v.hy)
    if y > 0 then
      ui.clip(v.x, v.y, v.w, v.h)
      ui.camera(-v.x, -v.y)
      ui.rectfill(0, 0, v.w, y, f.cor_ceu)
    end
  end
  for i, spr in ipairs(f.sprites) do
    local lp = f.larguras[i]
    for j, v in ipairs(visoes) do
      local x = FUNDO_X[j] + f.inicio[i]
      if x + lp > 0 and x < v.w then
        ui.clip(v.x, v.y, v.w, v.h)
        ui.camera(-v.x, -v.y)
        ui.spr(spr, x, topo_fundo(f, v.hy))
      end
    end
  end
end

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
  local fim_fundo = topo_fundo(f, hy) + f.altura

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
  local z = base * SEG - cam
  local s1, X1, Y1
  if z > CAM_PROF then
    s1 = CAM_PROF / z
    X1, Y1 = hw + s1 * (x - cam_x) * hw, hy + s1 * (cam_y - alturas[base % N + 1]) * fy
  end
  for n = 0, v.dist - 1 do
    local i = (base + n) % N + 1
    local i2 = i == N and 1 or i + 1
    PCLIP[n] = maxy
    PSEG[n] = i
    local z2 = z + SEG
    local s2 = CAM_PROF / z2
    local X2 = hw + s2 * (x + dx - cam_x) * hw
    local Y2 = hy + s2 * (cam_y - alturas[i2]) * fy
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
          if aberto then segmento(W, cores, aClaro, aX1, aY1, aW1, aX2, aY2, aW2, aIdx) end
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
  if aberto then segmento(W, cores, aClaro, aX1, aY1, aW1, aX2, aY2, aW2, aIdx) end
  -- faixa entre o panorama e o ponto mais distante da estrada (mar/horizonte)
  if maxy > fim_fundo then ui.rectfill(0, fim_fundo, W, maxy, f.cor_mar) end

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
          Objetos.desenhar(o, px + ox * o.x, py, kx, ky, noite)
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
