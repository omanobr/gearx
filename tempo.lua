-- Tempo do jogo. O console chama update() ate 60 vezes por segundo, mas quando o quadro
-- demora (o Lua do aparelho e lento) ele pula quadros: a v0.9 rodava a ~25 e o jogo ficava
-- em camera lenta ("1 segundo demorando 2"). Tempo.passo diz quantos 1/60 de segundo se
-- passaram neste quadro (1 a 60 FPS, 2 a 30 FPS...): a fisica, os cronometros e as
-- contagens andam passo vezes mais. Assim 1 segundo do jogo dura 1 segundo, so com
-- menos quadros (menos suave).
--
-- De onde vem: do contador de quadros que o console passa para update(frame), se ele
-- contar tambem os quadros pulados; senao, do FPS medido pelo console (ui.stat(7)).
local Tempo = { passo = 1, fonte = "-" }

local MAX_PASSO = 4   -- abaixo de 15 FPS o jogo fica lento de verdade (evita saltos enormes)

local ultimo_frame
local soma_d, n_d = 0, 0
local frame_conta_pulos = false

local function fps_do_console()
  if not ui.stat then return nil end
  local ok, v = pcall(ui.stat, 7)
  if ok and type(v) == "number" and v >= 1 then return v end
  return nil
end

-- chamar uma vez no comeco de cada update(frame)
function Tempo.atualizar(frame)
  local d
  if type(frame) == "number" and ultimo_frame then d = frame - ultimo_frame end
  ultimo_frame = frame
  -- o contador do console pula quando perde quadros? (media de 1 segundo acima de 1,1)
  if d and d >= 1 and d <= 10 then
    soma_d, n_d = soma_d + d, n_d + 1
    if n_d >= 60 then
      frame_conta_pulos = soma_d / n_d > 1.1
      Tempo.media_frame = soma_d / n_d
      soma_d, n_d = 0, 0
    end
  end
  local passo = 1
  if frame_conta_pulos and d and d >= 1 then
    passo, Tempo.fonte = d, "frame"
  else
    local fps = fps_do_console()
    if fps then passo, Tempo.fonte = 60 / fps, "stat7" end
  end
  if passo < 1 then passo = 1 elseif passo > MAX_PASSO then passo = MAX_PASSO end
  Tempo.passo = passo
end

return Tempo
