-- Desenho de imagens: todo ui.spr do jogo passa por Desenho.spr, e toda sequencia de
-- ui.tile de uma folha comeca com Desenho.lote.
--
-- No console, desenhar a MESMA imagem varias vezes em seguida forma um "lote": a imagem e
-- carregada uma vez so e cada desenho a mais custa 4 bytes na lista de desenho (e assim que
-- os tilemaps funcionam). Quando uma imagem igual a anterior vem de outro lugar do jogo
-- (outra visao da tela dividida, por exemplo), pomos antes o "separador" (1 pixel
-- transparente): foi o que destravou os 2 jogadores na v0.6 (a pagina 3 da tela de teste
-- mostrou depois que repetir a imagem nao trava, mas o separador e barato e fica).
local Desenho = {}

local ultima, SEPARADOR

function Desenho.preparar()
  SEPARADOR = Sprites.img.efeitos.separador
end

function Desenho.novo_quadro()
  ultima = nil
end

function Desenho.spr(img, x, y)
  if img == ultima then ui.spr(SEPARADOR, 0, 0) end
  ui.spr(img, x, y)
  ultima = img
end

-- antes de uma sequencia de ui.tile da folha img (os tiles seguidos formam o lote)
function Desenho.lote(img)
  ultima = img
end

return Desenho
