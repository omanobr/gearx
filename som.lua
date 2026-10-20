-- Musica. So toca no console (o simulador nao tem som). O arquivo e music/gearx.mp3,
-- tocado com sfx.music, como no le-pendu (jogo da equipe do Lupi). O servidor converte o
-- MP3 e o console repete a musica sozinho quando ela acaba (visto no log USB).
local Som = {}

function Som.musica()
  if not (sfx and sfx.music) then return end
  -- pcall: se algo der errado no som, o jogo continua sem musica (nao da para testar
  -- o som no simulador)
  pcall(sfx.music, Musica.arquivo)
end

return Som
