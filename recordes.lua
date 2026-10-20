-- Recordes (v0.99b): as 5 melhores voltas de cada pista e as 5 maiores pontuacoes de
-- campeonato, com as iniciais (3 letras) de quem fez, como nos fliperamas.
-- O console nao deixa o jogo gravar arquivos (v0.97k: sem io.open): os recordes duram
-- enquanto o jogo esta aberto e comecam com os "de fabrica" (para ter o que bater).
local Rec = {}

Rec.TAMANHO = 5   -- quantos recordes cada tabela guarda

-- De fabrica. Voltas em quadros (60 = 1 s): do piloto automatico (Ka) de cada pista, de 2%
-- mais rapido (desafio) a 13% mais lento (facil de bater).
local function volta(segundos) return math.floor(segundos * 60 + 0.5) end
Rec.voltas = {
  { { "GRX", volta(32.96), "UNO" }, { "LUP", volta(33.97), "MONZA" }, { "ACE", volta(34.98), "GOL BOLA" },
    { "ZAP", volta(36.32), "FUSCA" }, { "TOP", volta(38.00), "KA" } },      -- Vale da Floresta
  { { "LUP", volta(33.59), "MONZA" }, { "GRX", volta(34.62), "UNO" }, { "TOP", volta(35.65), "KA" },
    { "ACE", volta(37.02), "GOL BOLA" }, { "ZAP", volta(38.74), "FUSCA" } },  -- Orla da Cidade
  { { "ACE", volta(35.05), "GOL BOLA" }, { "ZAP", volta(36.13), "FUSCA" }, { "GRX", volta(37.20), "UNO" },
    { "LUP", volta(38.63), "MONZA" }, { "TOP", volta(40.42), "KA" } },     -- Dunas do Tigre
  { { "ZAP", volta(48.61), "FUSCA" }, { "TOP", volta(50.10), "KA" }, { "LUP", volta(51.58), "MONZA" },
    { "GRX", volta(53.57), "UNO" }, { "ACE", volta(56.05), "GOL BOLA" } },  -- Castelo de Gelo
}
-- campeonato: pontos (o maximo e 40: 10 em cada uma das 4 corridas)
Rec.campeonato = {
  { "GRX", 36, "UNO" }, { "LUP", 31, "MONZA" }, { "ACE", 26, "GOL BOLA" }, { "ZAP", 21, "FUSCA" }, { "TOP", 16, "KA" },
}

-- Em que posicao um valor entraria na tabela (1 a 5), ou nil se nao entra. melhor(a, b) diz se
-- a e melhor que b; empate fica abaixo do recorde que ja existia.
local function posicao(tabela, valor, melhor)
  for i = 1, Rec.TAMANHO do
    local r = tabela[i]
    if not r or melhor(valor, r[2]) then return i end
  end
  return nil
end
local function menor(a, b) return a < b end
local function maior(a, b) return a > b end

local function inserir(tabela, i, nome, valor, carro)
  table.insert(tabela, i, { nome, valor, carro })
  while #tabela > Rec.TAMANHO do table.remove(tabela) end
end

function Rec.posicao_volta(pista, quadros)
  return posicao(Rec.voltas[pista], quadros, menor)
end
function Rec.inserir_volta(pista, nome, quadros, carro)
  local i = Rec.posicao_volta(pista, quadros)
  if i then inserir(Rec.voltas[pista], i, nome, quadros, carro) end
  return i
end

function Rec.posicao_campeonato(pontos)
  return posicao(Rec.campeonato, pontos, maior)
end
function Rec.inserir_campeonato(nome, pontos, carro)
  local i = Rec.posicao_campeonato(pontos)
  if i then inserir(Rec.campeonato, i, nome, pontos, carro) end
  return i
end

-- Iniciais da ultima vez de cada jogador (1 a 3): o proximo recorde ja comeca com elas.
Rec.iniciais = { "AAA", "BBB", "CCC" }

return Rec
