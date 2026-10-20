-- Gerado por ferramentas/gerar_fonte.py. Nao edite a mao: rode o script de novo.
-- Fonte grande em tiles: folhas[escala][cor] = { imagem, tiles }; tiles[codigo da letra] = numero do tile
-- (acentos pelo nome). Cada tile tem 5*escala + sombra de largura (sombra preta ja desenhada).
local hex = Palette.hex
Fonte = {
  conjuntos = {
    completo = { [65] = 0, [66] = 1, [67] = 2, [68] = 3, [69] = 4, [70] = 5, [71] = 6, [72] = 7, [73] = 8, [74] = 9, [75] = 10, [76] = 11, [77] = 12, [78] = 13, [79] = 14, [80] = 15, [81] = 16, [82] = 17, [83] = 18, [84] = 19, [85] = 20, [86] = 21, [87] = 22, [88] = 23, [89] = 24, [90] = 25, [48] = 26, [49] = 27, [50] = 28, [51] = 29, [52] = 30, [53] = 31, [54] = 32, [55] = 33, [56] = 34, [57] = 35, [33] = 36, [63] = 37, [46] = 38, [44] = 39, [58] = 40, [45] = 41, [47] = 42, [39] = 43, [60] = 44, [62] = 45, [43] = 46, [186] = 47, agudo = 48, grave = 49, circ = 50, til = 51, cedilha = 52 },
    numeros = { [48] = 0, [49] = 1, [50] = 2, [51] = 3, [52] = 4, [53] = 5, [54] = 6, [55] = 7, [56] = 8, [57] = 9, [47] = 10 },
  },
  folhas = {
    { escala = 2, cor = hex(0xF8F8F8), imagem = "e2_branco", conjunto = "completo" },   -- 77x150, 53 tiles de 11x15
    { escala = 2, cor = hex(0xF8C838), imagem = "e2_amarelo", conjunto = "completo" },   -- 77x150, 53 tiles de 11x15
    { escala = 2, cor = hex(0x48D060), imagem = "e2_verde", conjunto = "completo" },   -- 77x150, 53 tiles de 11x15
    { escala = 2, cor = hex(0x9CA0B0), imagem = "e2_cinza", conjunto = "completo" },   -- 77x150, 53 tiles de 11x15
    { escala = 2, cor = hex(0xE03030), imagem = "e2_vermelho", conjunto = "completo" },   -- 77x150, 53 tiles de 11x15
    { escala = 2, cor = hex(0x3870F0), imagem = "e2_azul", conjunto = "completo" },   -- 77x150, 53 tiles de 11x15
    { escala = 3, cor = hex(0xF8F8F8), imagem = "e3_branco", conjunto = "completo" },   -- 112x220, 53 tiles de 16x22
    { escala = 3, cor = hex(0xF8C838), imagem = "e3_amarelo", conjunto = "completo" },   -- 112x220, 53 tiles de 16x22
    { escala = 4, cor = hex(0xF8C838), imagem = "e4_amarelo", conjunto = "completo" },   -- 147x290, 53 tiles de 21x29
    { escala = 2, cor = hex(0xF8F8F8), imagem = "n2_branco", conjunto = "numeros" },   -- 44x75, 11 tiles de 11x15
    { escala = 3, cor = hex(0xF8F8F8), imagem = "n3_branco", conjunto = "numeros" },   -- 64x110, 11 tiles de 16x22
    { escala = 3, cor = hex(0xF8C838), imagem = "n3_amarelo", conjunto = "numeros" },   -- 64x110, 11 tiles de 16x22
    { escala = 5, cor = hex(0xF8C838), imagem = "n5_amarelo", conjunto = "numeros" },   -- 104x180, 11 tiles de 26x36
  },
  logo = { 267, 69 },   -- img/titulo/logo.png (GEARX do titulo)
}
