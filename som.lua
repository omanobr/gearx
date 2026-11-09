-- Musica. So toca no console (o simulador nao tem som).
--
-- v1.00e (firmware 0.6.8): music/gearx.fur, uma musica do Furnace para o chip do NES (feita por
-- ferramentas/compor_musica.py com as mesmas notas do MP3 de antes). O servidor converte para
-- .las e o jogo toca com music.loop, que repete sozinho. Ate a v1.00d era um MP3 tocado com
-- sfx.music, que saiu da documentacao no firmware 0.6.8.
--
-- music.loop e chamado UMA vez so, na primeira vez que a musica liga (ela comeca desligada,
-- menu Opcoes). Desligar e religar so muda o volume (music.volume, com fade). No firmware
-- antigo cada sfx.music prendia memoria do console e nao soltava (Racing Rock, 25/10/2026:
-- "No RAM left for sample load" ate desligar o console); com o music.* nao sabemos, entao o
-- jogo nao carrega a musica de novo.
local Som = {}

local FADE = 0.5          -- segundos para a musica entrar ou sair
local carregada = false   -- music.loop ja foi chamado (a musica segue tocando, talvez sem volume)

-- (o log mostra cada troca, para conferir no aparelho que a musica foi carregada uma vez so)
local function volume(v)
  print("GEARX MUSICA volume=" .. v)
  if CH_ALL then
    pcall(music.volume, v, CH_ALL, FADE)
  else
    pcall(music.volume, v)
  end
end

function Som.musica()
  if not (music and music.loop) or Jogo.opcoes.musica == false then return end
  if carregada then
    volume(1)
    return
  end
  carregada = true
  -- volume geral cheio (se um jogo anterior deixou baixo)
  if sfx and sfx.volume then pcall(sfx.volume, 1) end
  print("GEARX MUSICA music.loop " .. Musica.arquivo)
  -- pcall: se algo der errado no som, o jogo continua sem musica (nao da para testar o som
  -- no simulador)
  pcall(music.loop, Musica.arquivo, FADE)
end

-- menu de opcoes: a musica continua tocando, so que sem volume
function Som.parar()
  if not (music and music.volume) or not carregada then return end
  volume(0)
end

return Som
