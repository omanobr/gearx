-- Musica. So toca no console (o simulador nao tem som). O arquivo e music/gearx.mp3,
-- tocado com sfx.music, como no le-pendu (jogo da equipe do Lupi). Se o console nao
-- repetir a musica sozinho, ela e chamada de novo quando acaba (Musica.quadros, de
-- dados_musica.lua, gerado por ferramentas/compor_musica.py).
local Som = {}

local tocando = nil   -- quadros desde que a musica comecou

function Som.musica()
  if not (sfx and sfx.music) then return end
  -- pcall: se algo der errado no som, o jogo continua sem musica (nao da para testar
  -- o som no simulador)
  if pcall(sfx.music, Musica.arquivo) then tocando = 0 end
end

-- chamar uma vez por quadro
function Som.atualizar()
  if tocando then
    tocando = tocando + 1
    if tocando >= Musica.quadros then Som.musica() end
  end
end

return Som
