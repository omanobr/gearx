-- Cores usadas pelo codigo (telas, painel, objetos da beira da estrada).
-- Escreva a cor em hexadecimal (0xRRGGBB, como no Photoshop/GIMP) dentro de hex(...).
-- A ferramenta de construcao coloca automaticamente cada cor nova na paleta do jogo.
local hex = Palette.hex

return {
  preto = hex(0x101018),
  branco = hex(0xF8F8F8),
  cinza = hex(0x9CA0B0),
  cinza_escuro = hex(0x40404C),
  amarelo = hex(0xF8C838),
  laranja = hex(0xF07820),
  vermelho = hex(0xE03030),
  verde = hex(0x48D060),
  azul = hex(0x3870F0),
  painel = hex(0x181828),

  -- cor de cada jogador (painel, nomes)
  jogador = { hex(0xE03030), hex(0x3870F0), hex(0xF8C838) },

  -- objetos da beira da estrada
  poste = hex(0x585868),
  lampada = hex(0xFFF0B0),
  luz = hex(0xF8E070),
  tronco = hex(0x7A5230),
  folha = hex(0x2E8A3A),
  folha_clara = hex(0x48B048),
  placa = hex(0xF8C838),
  pedra = hex(0x8A8478),
}
