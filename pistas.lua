-- As pistas do jogo.
--
-- Cada pista e uma lista de TRECHOS. Cada trecho tem:
--   comprimento : quantos segmentos (60 segmentos = 1 segundo na velocidade maxima)
--   curva       : 0 = reta, positivo = curva para a DIREITA, negativo = para a ESQUERDA
--                 (2 = suave, 4 = media, 6 = fechada)
--   altura      : quanto a pista sobe (positivo) ou desce (negativo) no trecho
--                 (20 = morro pequeno, 40 = medio, 60 = grande)
--
-- No fim, se a pista nao terminar na mesma altura em que comecou, o jogo cria
-- sozinho um trecho final para fechar o circuito.
--
-- objetos: o que aparece na beira da estrada.
--   tipo     : "poste", "palmeira", "arbusto", "pedra"
--   lado     : -1 = esquerda, 1 = direita, 2 = os dois lados
--   x        : distancia do centro (1 = beira da pista)
--   a_cada   : a cada quantos segmentos aparece um
--   variacao : sorteia uma distancia extra (deixa mais natural)
-- Placas de curva sao colocadas sozinhas nas curvas fortes.
-- (v0.92: menos palmeiras e 1/3 dos postes: cada objeto custa processamento no console.)
local hex = Palette.hex

local function reta(comprimento, altura)
  return { comprimento = comprimento, curva = 0, altura = altura or 0 }
end

local function curva(comprimento, forca, altura)
  return { comprimento = comprimento, curva = forca, altura = altura or 0 }
end

return {
  {
    nome = "Orla do Amanhecer",
    fundo = "amanhecer",
    trechos = {
      reta(80), curva(100, 2), reta(60, 15), curva(120, -3, -15), reta(80), curva(80, 3),
      curva(80, -3), reta(120, 20), curva(140, 4, -20), reta(80), curva(100, -2, 10),
      curva(100, 3, -10), reta(140), curva(120, -4), reta(80), curva(140, 3), reta(100),
      curva(80, -2), reta(100),
    },
    objetos = {
      { tipo = "palmeira", lado = -1, x = 1.5, a_cada = 10, variacao = 0.8 },
      { tipo = "poste", lado = 1, x = 1.25, a_cada = 42 },
      { tipo = "arbusto", lado = -1, x = 2.6, a_cada = 9, variacao = 1.5 },
    },
    cores = {
      asfalto = { hex(0x7A7A86), hex(0x72727E) },
      zebra = { hex(0xF0F0F0), hex(0xD83838) },
      faixa = hex(0xF0F0F0),
      grama = { hex(0x58B048), hex(0x4EA040) },
      direita = { hex(0xE8D090), hex(0xDCC484) },   -- areia da praia
    },
  },
  {
    nome = "Serra da Tarde",
    fundo = "tarde",
    trechos = {
      reta(80), curva(80, 2, 30), curva(80, -3, -30), reta(60, 40), curva(120, 4, -20),
      curva(80, -4, -20), reta(100, 50), reta(100, -50), curva(140, -3), curva(100, 5, 20),
      reta(80, -20), curva(80, -2, 30), curva(120, 3, -30), reta(120), curva(100, -5),
      curva(100, 4), reta(140, 20), reta(100, -20),
    },
    objetos = {
      { tipo = "arbusto", lado = 2, x = 1.6, a_cada = 5, variacao = 1.2 },
      { tipo = "pedra", lado = -1, x = 2.2, a_cada = 11, variacao = 1.0 },
      { tipo = "poste", lado = 1, x = 1.25, a_cada = 48 },
    },
    cores = {
      asfalto = { hex(0x707080), hex(0x686878) },
      zebra = { hex(0xF0F0F0), hex(0xD83838) },
      faixa = hex(0xF0F0F0),
      grama = { hex(0x3C9840), hex(0x348A38) },
    },
  },
  {
    nome = "Pôr do Sol",
    fundo = "por_do_sol",
    trechos = {
      reta(80), curva(100, 3), curva(100, -3), reta(60), curva(160, 4, 10), reta(80, -10),
      curva(100, -5), curva(80, 2), reta(120, 15), curva(120, -4, -15), curva(120, 5), reta(100),
      curva(80, -3), curva(80, 3), curva(80, -3), reta(120), curva(140, -4, 20), reta(100, -20),
    },
    objetos = {
      { tipo = "palmeira", lado = 2, x = 1.45, a_cada = 12, variacao = 0.6 },
      { tipo = "poste", lado = 1, x = 1.25, a_cada = 36 },
    },
    cores = {
      asfalto = { hex(0x5E5068), hex(0x584A62) },
      zebra = { hex(0xF0E0D0), hex(0xD84830) },
      faixa = hex(0xF0E0D0),
      grama = { hex(0x6A6A30), hex(0x60602A) },
      direita = { hex(0xD09868), hex(0xC48C5E) },
    },
  },
  {
    nome = "Crepúsculo",
    fundo = "crepusculo",
    trechos = {
      reta(80), curva(60, -4), curva(60, 4), curva(60, -4), reta(100, 30), curva(140, 5, -30),
      reta(80), curva(100, -3, 20), curva(100, -5, -20), reta(120), curva(80, 4), curva(80, -4),
      curva(80, 4), reta(100, 40), reta(100, -40), curva(160, -4), reta(80), curva(120, 5),
      reta(100),
    },
    objetos = {
      { tipo = "palmeira", lado = -1, x = 1.5, a_cada = 10, variacao = 1.0 },
      { tipo = "arbusto", lado = -1, x = 2.4, a_cada = 8, variacao = 1.2 },
      { tipo = "poste", lado = 1, x = 1.25, a_cada = 36 },
    },
    cores = {
      asfalto = { hex(0x4C4864), hex(0x46425E) },
      zebra = { hex(0xE0E0F0), hex(0xC83040) },
      faixa = hex(0xE0E0F0),
      grama = { hex(0x3A5240), hex(0x344A3A) },
      direita = { hex(0x283C78), hex(0x24366E) },   -- mar
    },
  },
  {
    nome = "Noite de Lua Cheia",
    fundo = "lua_cheia",
    noite = true,
    trechos = {
      reta(80), curva(120, 5), reta(60, 20), curva(100, -6, -20), curva(80, 4), reta(100),
      curva(140, -5, 30), reta(80, -30), curva(60, 6), curva(60, -6), reta(120, 20),
      curva(120, 5, -20), reta(80), curva(100, -4, 30), curva(100, 6, -30), reta(140),
      curva(140, -5), reta(100), curva(80, 3), reta(100),
    },
    objetos = {
      { tipo = "poste", lado = 2, x = 1.25, a_cada = 30 },
      { tipo = "palmeira", lado = -1, x = 1.8, a_cada = 12, variacao = 1.0 },
    },
    cores = {
      asfalto = { hex(0x383848), hex(0x323242) },
      zebra = { hex(0xB8B8D0), hex(0x902838) },
      faixa = hex(0xE0D890),
      grama = { hex(0x1C3428), hex(0x182E23) },
      direita = { hex(0x1A2450), hex(0x172048) },   -- mar a noite
    },
  },
}
