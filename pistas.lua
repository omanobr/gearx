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
-- dificuldade: "FÁCIL", "MÉDIO" ou "DIFÍCIL" (aparece no menu). aderencia (opcional): menos
-- de 1 = pista escorregadia (a curva empurra mais e o carro perde mais virando).
-- Horario do dia: as pistas da costa tem um so (fundo, cores, noite e hora = o nome); as novas
-- tem "horarios" (lista feita com horario(...)) e "horario" (o que vem marcado no menu).
--
-- objetos: o que aparece na beira da estrada.
--   tipo     : "poste", "palmeira", "arbusto", "pedra", "pinheiro", "pinheiro_neve", "cacto"
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

-- Asfalto, zebra e faixas de cada horario (as mesmas cores das pistas da costa)
local AMANHECER = { asfalto = { hex(0x7A7A86), hex(0x72727E) }, zebra = { hex(0xF0F0F0), hex(0xD83838) }, faixa = hex(0xF0F0F0) }
local DIA = { asfalto = { hex(0x707080), hex(0x686878) }, zebra = { hex(0xF0F0F0), hex(0xD83838) }, faixa = hex(0xF0F0F0) }
local POR_DO_SOL = { asfalto = { hex(0x5E5068), hex(0x584A62) }, zebra = { hex(0xF0E0D0), hex(0xD84830) }, faixa = hex(0xF0E0D0) }
local NOITE = { asfalto = { hex(0x383848), hex(0x323242) }, zebra = { hex(0xB8B8D0), hex(0x902838) }, faixa = hex(0xE0D890),
                noite = true }

-- um horario do dia de uma pista: nome no menu, fundo (dados_arte.lua), cores da estrada e da
-- beira (grama = { clara, escura }); de noite os postes acendem
local function horario(nome, fundo, estrada, grama)
  return { nome = nome, fundo = fundo, noite = estrada.noite,
           cores = { asfalto = estrada.asfalto, zebra = estrada.zebra, faixa = estrada.faixa, grama = grama } }
end

return {
  {
    nome = "Orla do Amanhecer",
    dificuldade = "MÉDIO",
    hora = "AMANHECER",
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
    dificuldade = "MÉDIO",
    hora = "TARDE",
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
    dificuldade = "MÉDIO",
    hora = "PÔR DO SOL",
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
    dificuldade = "MÉDIO",
    hora = "CREPÚSCULO",
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
    dificuldade = "MÉDIO",
    hora = "NOITE",
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
  -- v0.99: tres pistas novas (arte-original/pistas), uma de cada dificuldade, cada uma com os
  -- 4 horarios do dia (escolhidos no menu; "horario" = o que ja vem marcado)
  {
    nome = "Vale da Floresta",
    dificuldade = "FÁCIL",
    horario = 2,
    horarios = {
      horario("AMANHECER", "floresta_am", AMANHECER, { hex(0x58B048), hex(0x4EA040) }),
      horario("DIA", "floresta_dia", DIA, { hex(0x3C9840), hex(0x348A38) }),
      horario("PÔR DO SOL", "floresta_por", POR_DO_SOL, { hex(0x6A6A30), hex(0x60602A) }),
      horario("NOITE", "floresta_noi", NOITE, { hex(0x1C3428), hex(0x182E23) }),
    },
    -- so curvas suaves (2 e 3), retas longas e morros pequenos
    trechos = {
      reta(100), curva(140, 2), reta(80, 15), curva(120, -2, -15), reta(120), curva(160, 3),
      reta(80, 20), reta(80, -20), curva(120, -3), reta(100), curva(140, 2, 15), curva(120, -2, -15),
      reta(140), curva(100, 3), reta(120), curva(120, -2), reta(100),
    },
    objetos = {
      { tipo = "pinheiro", lado = 2, x = 1.6, a_cada = 11, variacao = 1.2 },
      { tipo = "arbusto", lado = -1, x = 2.8, a_cada = 13, variacao = 1.0 },
      { tipo = "pedra", lado = 1, x = 2.3, a_cada = 23, variacao = 1.0 },
    },
  },
  {
    nome = "Dunas do Tigre",
    dificuldade = "MÉDIO",
    horario = 3,
    horarios = {
      horario("AMANHECER", "deserto_am", AMANHECER, { hex(0xEFA59C), hex(0xD69C6B) }),
      horario("DIA", "deserto_dia", DIA, { hex(0xE8D090), hex(0xDCC484) }),
      horario("PÔR DO SOL", "deserto_por", POR_DO_SOL, { hex(0xD66B39), hex(0xBD5A42) }),
      horario("NOITE", "deserto_noi", NOITE, { hex(0x39395A), hex(0x21294A) }),
    },
    -- curvas de 2 a 5, dunas (morros medios) e retas longas
    trechos = {
      reta(100), curva(100, 3), reta(80, 30), curva(120, -4, -30), reta(140), curva(80, 5),
      curva(80, -3), reta(100, 40), reta(100, -40), curva(140, -4), reta(80), curva(100, 5, 20),
      curva(100, -2, -20), reta(160), curva(120, 4), reta(80), curva(100, -5), reta(100),
    },
    objetos = {
      { tipo = "cacto", lado = 2, x = 1.7, a_cada = 14, variacao = 1.5 },
      { tipo = "pedra", lado = -1, x = 2.4, a_cada = 17, variacao = 1.0 },
    },
  },
  {
    nome = "Castelo de Gelo",
    dificuldade = "DIFÍCIL",
    aderencia = 0.85,   -- neve: escorrega
    horario = 4,
    horarios = {
      horario("AMANHECER", "neve_am", AMANHECER, { hex(0xB5C6E7), hex(0x9CA5B5) }),
      horario("DIA", "neve_dia", DIA, { hex(0xBDE7EF), hex(0xB5C6E7) }),
      horario("PÔR DO SOL", "neve_por", POR_DO_SOL, { hex(0x9C9CBD), hex(0x84849C) }),
      horario("NOITE", "neve_noi", NOITE, { hex(0x9CA5B5), hex(0x84849C) }),
    },
    -- curvas fechadas (5 e 6), em S, e morros grandes
    trechos = {
      reta(80), curva(80, 5), curva(80, -5), reta(60, 40), curva(120, 6, -40), reta(80),
      curva(60, -6), curva(60, 6), curva(60, -6), reta(100, 60), reta(100, -60), curva(140, 5),
      reta(60), curva(100, -6, 30), curva(100, 5, -30), reta(120), curva(80, -5), curva(80, 6),
      reta(80), curva(120, -6), reta(100),
    },
    objetos = {
      { tipo = "pinheiro_neve", lado = 2, x = 1.7, a_cada = 11, variacao = 1.2 },
      { tipo = "poste", lado = 1, x = 1.25, a_cada = 36 },
    },
  },
}
