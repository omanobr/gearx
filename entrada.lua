-- Controles. "p" e o numero do jogador: 0, 1 ou 2.
--
-- No console: direcional + botoes Z, X, Q, E, F, G.
-- No simulador (teclado): W A S D, K = Z, J = X, L = Q, M = E, G = F, H = G.
local E = {}

-- Botao do controle (estilo Super Nintendo) -> constante do Lupi. No simulador a ligacao e
-- pela posicao (BTN_Z = o de baixo, B; BTN_X = o da direita, A...). No console e outra:
-- o Felipe apertou cada botao na pagina 1 da tela de teste (v0.97f) e so o B batia.
-- (ui.log so existe no simulador.)
local NO_CONSOLE = ui.log == nil
local BOTAO = NO_CONSOLE
  and { B = BTN_Z, A = BTN_G, X = BTN_X, Y = BTN_F, L = BTN_Q, R = BTN_E }
  or { B = BTN_Z, A = BTN_X, X = BTN_Q, Y = BTN_E, L = BTN_F, R = BTN_G }
E.BOTAO = BOTAO
local B, A, X, Y, R = BOTAO.B, BOTAO.A, BOTAO.X, BOTAO.Y, BOTAO.R

function E.acelera(p) return ui.btn(B, p) or ui.btn(UP, p) end
function E.freia(p) return ui.btn(A, p) or ui.btn(DOWN, p) end
function E.esquerda(p) return ui.btn(LEFT, p) end
function E.direita(p) return ui.btn(RIGHT, p) end

-- nitro: X, Y ou R. O L ficou de fora: no controle 1 ele faz o console parar uns segundos
-- (o sistema do console usa o L para outra coisa; veja o log de 20/10/2026).
function E.nitro(p)
  return ui.btnp(X, p) or ui.btnp(Y, p) or ui.btnp(R, p)
end

-- Para menus: qualquer jogador pode mexer.
local function algum(botao)
  for p = 0, 2 do
    if ui.btnp(botao, p) then return true end
  end
  return false
end

-- Nomes dos botoes do controle, para os textos da tela.
E.NOME = { confirmar = "B", voltar = "A", acelerar = "B", frear = "A", nitro = "X/Y/R" }

function E.confirmar() return algum(B) end
function E.voltar() return algum(A) end
function E.cima() return algum(UP) end
function E.baixo() return algum(DOWN) end
function E.esq() return algum(LEFT) end
function E.dir() return algum(RIGHT) end

-- Para a escolha de carros: cada jogador (p = 0, 1, 2) com o seu controle.
function E.esq_de(p) return ui.btnp(LEFT, p) end
function E.dir_de(p) return ui.btnp(RIGHT, p) end
function E.confirmar_de(p) return ui.btnp(B, p) end
function E.voltar_de(p) return ui.btnp(A, p) end

return E
