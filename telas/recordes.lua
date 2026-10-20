-- Tabela de recordes (v0.99b): as 5 melhores voltas de cada pista e as 5 maiores pontuacoes de
-- campeonato (recordes.lua). Esquerda/direita troca a tabela; B ou A sai.
-- aba: 1 a #Pistas = pista; #Pistas + 1 = campeonato. destaques: lista de { nome, valor } dos
-- recordes novos (piscam). depois: { tela, argumentos... } para onde ir ao sair (padrao: menu).
local Cores = require "cores"
local T = require "texto"
local Entrada = require "entrada"
local Pistas = require "pistas"
local Rec = require "recordes"

local Tela = {}
Tela.__index = Tela

local COR_DIFICULDADE = { ["FÁCIL"] = Cores.verde, ["MÉDIO"] = Cores.amarelo, ["DIFÍCIL"] = Cores.vermelho }

function Tela.nova(aba, destaques, depois)
  return setmetatable({ aba = aba or 1, destaques = destaques or {}, depois = depois or { "menu", "principal" }, t = 0 },
    Tela)
end

function Tela:atualizar()
  self.t = self.t + 1
  local abas = #Pistas + 1
  if Entrada.dir() then self.aba = self.aba % abas + 1 end
  if Entrada.esq() then self.aba = (self.aba - 2) % abas + 1 end
  if self.t > 10 and (Entrada.confirmar() or Entrada.voltar()) then
    Jogo.ir(table.unpack(self.depois))
  end
end

local function destacado(self, r)
  for _, d in ipairs(self.destaques) do
    if d[1] == r[1] and d[2] == r[2] then return true end
  end
  return false
end

function Tela:desenhar()
  ui.rectfill(0, 0, 480, 270, Cores.preto)
  ui.rectfill(0, 0, 480, 32, Cores.painel)
  ui.rectfill(0, 33, 480, 34, Cores.amarelo)
  T.grande("GEARX", 12, 6, 3, Cores.amarelo)
  T.grande("RECORDES", 12 + T.largura("GEARX", 3) + 16, 11, 2, Cores.cinza)

  local campeonato = self.aba > #Pistas
  local titulo, sub, cor_sub, tabela
  if campeonato then
    titulo, sub, cor_sub, tabela = "CAMPEONATO", "MAIS PONTOS (MÁXIMO 40)", Cores.cinza, Rec.campeonato
  else
    local def = Pistas[self.aba]
    titulo, sub, tabela = def.nome, "MELHOR VOLTA - " .. def.dificuldade, Rec.voltas[self.aba]
    cor_sub = COR_DIFICULDADE[def.dificuldade] or Cores.cinza
  end
  T.grande_centro(titulo, 240, 46, 2, Cores.amarelo)
  T.grande("<", 40, 46, 2, Cores.branco)
  T.grande(">", 428, 46, 2, Cores.branco)
  T.p_centro(sub, 240, 66, cor_sub)

  for i = 1, Rec.TAMANHO do
    local r = tabela[i]
    local y = 86 + (i - 1) * 28
    if r then
      local novo = destacado(self, r)
      if novo and (self.t // 15) % 2 == 0 then ui.rectfill(70, y - 5, 410, y + 19, Cores.nitro) end
      T.grande(i .. "º", 84, y, 2, i == 1 and Cores.amarelo or Cores.cinza)
      T.grande(r[1], 140, y, 2, novo and Cores.amarelo or Cores.branco)
      local valor = campeonato and (r[2] .. " PTS") or T.tempo(r[2])
      T.grande(valor, 300 - T.largura(valor, 2), y, 2, Cores.branco)
      T.p(r[3] or "", 316, y + 4, Cores.cinza)
    end
  end

  ui.rectfill(0, 238, 480, 270, Cores.painel)
  T.p_centro("ESQ/DIR: OUTRA TABELA   " .. Entrada.NOME.confirmar .. ": CONTINUAR", 240, 243, Cores.cinza)
  T.p_centro("Os recordes ficam guardados até fechar o jogo ou desligar o console.", 240, 253, Cores.cinza)
end

return Tela
