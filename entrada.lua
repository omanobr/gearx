-- Controles. "p" e o numero do jogador: 0, 1 ou 2.
--
-- No console: direcional + botoes Z, X, Q, E, F, G.
-- No simulador (teclado): W A S D, K = Z, J = X, L = Q, M = E, G = F, H = G.
local E = {}

function E.acelera(p) return ui.btn(BTN_Z, p) or ui.btn(UP, p) end
function E.freia(p) return ui.btn(BTN_X, p) or ui.btn(DOWN, p) end
function E.esquerda(p) return ui.btn(LEFT, p) end
function E.direita(p) return ui.btn(RIGHT, p) end

function E.nitro(p)
  return ui.btnp(BTN_Q, p) or ui.btnp(BTN_E, p) or ui.btnp(BTN_F, p) or ui.btnp(BTN_G, p)
end

-- Para menus: qualquer jogador pode mexer.
local function algum(botao)
  for p = 0, 2 do
    if ui.btnp(botao, p) then return true end
  end
  return false
end

function E.confirmar() return algum(BTN_Z) end
function E.voltar() return algum(BTN_X) end
function E.cima() return algum(UP) end
function E.baixo() return algum(DOWN) end
function E.esq() return algum(LEFT) end
function E.dir() return algum(RIGHT) end

return E
