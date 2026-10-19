-- Carros que os jogadores podem escolher. Todos usam o mesmo desenho, em cores diferentes;
-- o que muda e o jeito de dirigir. Os numeros multiplicam os valores de config.lua (1 = normal):
--   vel       = velocidade maxima
--   acel      = aceleracao
--   aderencia = curvas: quanto maior, menos o carro escorrega para fora e menos
--               velocidade perde nas curvas
-- Os carros do computador usam 1 em tudo (a dificuldade deles vem da "habilidade").
return {
  { nome = "VULCÃO",   cor = "vermelho", vel = 1.00, acel = 1.00, aderencia = 1.00, texto = "EQUILIBRADO" },
  { nome = "TUBARÃO",  cor = "azul",     vel = 1.07, acel = 0.85, aderencia = 0.95, texto = "O MAIS VELOZ" },
  { nome = "GUEPARDO", cor = "amarelo",  vel = 0.95, acel = 1.25, aderencia = 1.00, texto = "ARRANCADA FORTE" },
  { nome = "SERPENTE", cor = "verde",    vel = 0.97, acel = 1.00, aderencia = 1.20, texto = "GRUDA NAS CURVAS" },
  { nome = "FURACÃO",  cor = "laranja",  vel = 1.03, acel = 1.08, aderencia = 0.88, texto = "RÁPIDO, MAS ESCORREGA" },
  { nome = "PANTERA",  cor = "roxo",     vel = 0.99, acel = 0.95, aderencia = 1.10, texto = "FIRME" },
}
