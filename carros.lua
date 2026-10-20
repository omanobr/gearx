-- Carros que os jogadores podem escolher (arte em arte-original/novos, preparada por
-- ferramentas/preparar_arte.py). Cada jogador corre com o modelo escolhido pintado na cor
-- dele (J1 vermelho, J2 azul, J3 amarelo): dois jogadores podem escolher o mesmo modelo.
-- Os numeros multiplicam os valores de config.lua (1 = normal):
--   vel       = velocidade maxima
--   acel      = aceleracao
--   aderencia = curvas: quanto maior, menos o carro escorrega para fora e menos
--               velocidade perde nas curvas
-- O Uno e lendario: o melhor em tudo (as barras da escolha ficam cheias).
-- Os carros do computador usam 1 em tudo (a dificuldade deles vem da "habilidade").
return {
  { modelo = "ka",    nome = "KA",       vel = 1.00, acel = 1.12, aderencia = 1.05, texto = "PEQUENO E ESPERTO" },
  { modelo = "fusca", nome = "FUSCA",    vel = 0.94, acel = 1.00, aderencia = 1.15, texto = "GUERREIRO NAS CURVAS" },
  { modelo = "gol",   nome = "GOL BOLA", vel = 1.02, acel = 1.02, aderencia = 1.00, texto = "EQUILIBRADO" },
  { modelo = "monza", nome = "MONZA",    vel = 1.07, acel = 0.88, aderencia = 0.95, texto = "O MAIS VELOZ" },
  { modelo = "uno",   nome = "UNO",      vel = 1.10, acel = 1.15, aderencia = 1.18, texto = "LENDÁRIO: TUDO NO MÁXIMO",
    lendario = true },
}
