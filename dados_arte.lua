-- Gerado por ferramentas/preparar_arte.py. Nao edite a mao: rode o script de novo.
Arte = {
  fundos = {
    amanhecer = { pecas = { "amanhecer_1", "amanhecer_2" }, larguras = { 362, 362 }, largura = 724, altura = 110, ceu = 0x42B5FF, mar = 0x31A5F7, baixo = { pecas = { "amanhecer_baixo_1", "amanhecer_baixo_2", "amanhecer_baixo_3", "amanhecer_baixo_4" }, larguras = { 181, 181, 181, 181 }, altura = 63 } },
    tarde = { pecas = { "tarde_1", "tarde_2" }, larguras = { 373, 374 }, largura = 747, altura = 110, ceu = 0x188CF7, mar = 0x217BD6, baixo = { pecas = { "tarde_baixo_1", "tarde_baixo_2", "tarde_baixo_3", "tarde_baixo_4" }, larguras = { 186, 187, 187, 187 }, altura = 63 } },
    por_do_sol = { pecas = { "por_do_sol_1", "por_do_sol_2" }, larguras = { 362, 362 }, largura = 724, altura = 110, ceu = 0x4A299C, mar = 0x392984, baixo = { pecas = { "por_do_sol_baixo_1", "por_do_sol_baixo_2", "por_do_sol_baixo_3", "por_do_sol_baixo_4" }, larguras = { 181, 181, 181, 181 }, altura = 63 } },
    crepusculo = { pecas = { "crepusculo_1", "crepusculo_2", "crepusculo_3" }, larguras = { 285, 285, 286 }, largura = 856, altura = 110, ceu = 0x001873, mar = 0x392984, baixo = { pecas = { "crepusculo_baixo_1", "crepusculo_baixo_2", "crepusculo_baixo_3", "crepusculo_baixo_4" }, larguras = { 214, 214, 214, 214 }, altura = 63 } },
    lua_cheia = { pecas = { "lua_cheia_1", "lua_cheia_2" }, larguras = { 362, 362 }, largura = 724, altura = 110, ceu = 0x00217B, mar = 0x2929A5, baixo = { pecas = { "lua_cheia_baixo_1", "lua_cheia_baixo_2", "lua_cheia_baixo_3", "lua_cheia_baixo_4" }, larguras = { 181, 181, 181, 181 }, altura = 63 } },
  },
  carros = {
    modelos = { "ka", "fusca", "gol", "monza", "uno" },
    cores_jogador = { "vermelho", "azul", "amarelo" },
    modelos_cpu = { "ka", "fusca", "gol", "monza" },
    cores_cpu = { "original", "verde", "laranja", "roxo", "ciano" },
    niveis = 17,
    tamanho = {
      ka = {
        reto = { [1] = { 87, 71 }, [2] = { 74, 60 }, [3] = { 63, 51 }, [4] = { 53, 43 }, [5] = { 45, 37 }, [6] = { 39, 32 }, [7] = { 33, 27 }, [8] = { 28, 23 }, [9] = { 24, 20 }, [10] = { 20, 16 }, [11] = { 17, 14 }, [12] = { 15, 12 }, [13] = { 12, 10 }, [14] = { 11, 9 }, [15] = { 9, 7 }, [16] = { 8, 7 }, [17] = { 6, 5 } },
        esq = { [1] = { 110, 69 }, [5] = { 57, 36 } },
        dir = { [1] = { 111, 71 }, [5] = { 57, 37 } },
      },
      fusca = {
        reto = { [1] = { 87, 81 }, [2] = { 74, 69 }, [3] = { 63, 59 }, [4] = { 53, 49 }, [5] = { 45, 42 }, [6] = { 39, 36 }, [7] = { 33, 31 }, [8] = { 28, 26 }, [9] = { 24, 22 }, [10] = { 20, 19 }, [11] = { 17, 16 }, [12] = { 15, 14 }, [13] = { 12, 11 }, [14] = { 11, 10 }, [15] = { 9, 8 }, [16] = { 8, 7 }, [17] = { 6, 6 } },
        esq = { [1] = { 129, 77 }, [5] = { 67, 40 } },
        dir = { [1] = { 133, 77 }, [5] = { 69, 40 } },
      },
      gol = {
        reto = { [1] = { 87, 62 }, [2] = { 74, 53 }, [3] = { 63, 45 }, [4] = { 53, 38 }, [5] = { 45, 32 }, [6] = { 39, 28 }, [7] = { 33, 24 }, [8] = { 28, 20 }, [9] = { 24, 17 }, [10] = { 20, 14 }, [11] = { 17, 12 }, [12] = { 15, 11 }, [13] = { 12, 9 }, [14] = { 11, 8 }, [15] = { 9, 6 }, [16] = { 8, 6 }, [17] = { 6, 4 } },
        esq = { [1] = { 108, 62 }, [5] = { 56, 32 } },
        dir = { [1] = { 105, 62 }, [5] = { 54, 32 } },
      },
      monza = {
        reto = { [1] = { 87, 62 }, [2] = { 74, 53 }, [3] = { 63, 45 }, [4] = { 53, 38 }, [5] = { 45, 32 }, [6] = { 39, 28 }, [7] = { 33, 24 }, [8] = { 28, 20 }, [9] = { 24, 17 }, [10] = { 20, 14 }, [11] = { 17, 12 }, [12] = { 15, 11 }, [13] = { 12, 9 }, [14] = { 11, 8 }, [15] = { 9, 6 }, [16] = { 8, 6 }, [17] = { 6, 4 } },
        esq = { [1] = { 126, 62 }, [5] = { 65, 32 } },
        dir = { [1] = { 123, 62 }, [5] = { 64, 32 } },
      },
      uno = {
        reto = { [1] = { 87, 88 }, [2] = { 74, 75 }, [3] = { 63, 64 }, [4] = { 53, 54 }, [5] = { 45, 46 }, [6] = { 39, 39 }, [7] = { 33, 33 }, [8] = { 28, 28 }, [9] = { 24, 24 }, [10] = { 20, 20 }, [11] = { 17, 17 }, [12] = { 15, 15 }, [13] = { 12, 12 }, [14] = { 11, 11 }, [15] = { 9, 9 }, [16] = { 8, 8 }, [17] = { 6, 6 } },
        esq = { [1] = { 113, 83 }, [5] = { 58, 43 } },
        dir = { [1] = { 113, 83 }, [5] = { 58, 43 } },
      },
    },
  },
}
