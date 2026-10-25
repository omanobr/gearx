-- Musica. So toca no console (o simulador nao tem som). O arquivo e music/gearx.mp3,
-- tocado com sfx.music, como no le-pendu (jogo da equipe do Lupi). O servidor converte o
-- MP3 e o console repete a musica sozinho quando ela acaba (visto no log USB).
--
-- sfx.music e chamado UMA vez so, na primeira vez que a musica liga: no aparelho, cada
-- sfx.music prende memoria do console e nao solta a da anterior (Racing Rock, 25/10/2026:
-- depois de ~10 chamadas, "No RAM left for sample load" e a musica falhando, e so desligar o
-- console resolvia). Desligar e religar no menu Opcoes so muda o volume (sfx.volume de 0 a 1,
-- como no balao-gatinho da equipe do Lupi). O "parar" da documentacao, sfx.music(-1), nao
-- serve: o firmware tenta abrir um arquivo "-1.wav" umas 40 vezes por segundo.
local Som = {}

local carregada = false   -- sfx.music ja foi chamado (a musica segue tocando, talvez sem volume)

-- (o log mostra cada troca, para conferir no aparelho que o sfx.music foi chamado uma vez so)
local function volume(v)
  print("GEARX MUSICA volume=" .. v)
  if sfx.volume then pcall(sfx.volume, v) end
end

function Som.musica()
  if not (sfx and sfx.music) or Jogo.opcoes.musica == false then return end
  -- volume 1 tambem na primeira vez: se um jogo anterior deixou o volume baixo
  volume(1)
  if carregada then return end
  carregada = true
  print("GEARX MUSICA sfx.music " .. Musica.arquivo)
  -- pcall: se algo der errado no som, o jogo continua sem musica (nao da para testar
  -- o som no simulador)
  pcall(sfx.music, Musica.arquivo)
end

-- menu de opcoes: a musica continua tocando, so que sem volume
function Som.parar()
  if not (sfx and sfx.music) or not carregada then return end
  volume(0)
end

return Som
