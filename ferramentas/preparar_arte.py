"""
Prepara a arte do jogo: transforma as imagens grandes de arte-original/ em
imagens pequenas, com poucas cores, no formato que o Lupi aceita.

  arte-original/  --(este script)-->  img/  +  dados_arte.lua

O que ele faz:
  - FUNDOS: recorta cada panoramica numa faixa larga (ceu + montanhas + cidade + mar)
    e divide em pedacos de no maximo 512 px de largura (limite do Lupi).
  - CARROS: recorta os 3 carros (reto, virando para a esquerda e para a direita),
    pinta em varias cores e gera varios tamanhos (para o carro "diminuir" ao longe).
  - PALETA: todas as imagens do jogo dividem uma paleta de no maximo 256 cores.
    O script escolhe as melhores cores para caber nesse limite (ou reaproveita as
    cores ja publicadas: veja MANTER_CORES).
  - MEMORIA: cada pixel ocupa 1 byte da memoria grafica do console, que e limitada
    (veja LIMITE_MEMORIA_GRAFICA em construir.py). Por isso nao ha mais imagem de
    tela de titulo: o titulo mostra uma corrida de demonstracao.

Rode de novo sempre que mudar algo em arte-original/ ou nas configuracoes abaixo:
    python ferramentas/preparar_arte.py
"""
import os
import sys
import shutil
import colorsys
from collections import deque

try:
    from PIL import Image
except ImportError:
    print("ERRO: falta a biblioteca Pillow. Instale com:  python -m pip install pillow")
    sys.exit(1)

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORIGEM = os.path.join(RAIZ, "arte-original")
DESTINO_IMG = os.path.join(RAIZ, "img")
DADOS_LUA = os.path.join(RAIZ, "dados_arte.lua")
PREVIA = os.path.join(RAIZ, "build", "previa_arte.png")

# ----------------------------------------------------------------------------
# Configuracoes
# ----------------------------------------------------------------------------

# Quantas cores cada grupo pode usar (o resto da paleta fica para as cores do codigo).
CORES_FUNDOS = 118
CORES_CARROS = 92

# O servidor do Lupi so ACUMULA cores na paleta entre uma versao e outra: uma cor que
# sai do jogo continua ocupando lugar. Com MANTER_CORES ligado, a arte nova reaproveita
# as cores das imagens que ja estao em img/ (nenhuma cor nova entra na paleta).
# Desligue (False) so se for trocar a arte por outra bem diferente.
MANTER_CORES = True

# Altura da faixa de fundo no jogo (em pixels da tela do Lupi). Cada panoramica ocupa
# cerca de largura x altura bytes de memoria grafica: 125 deixava as 5 com 536 KB.
ALTURA_FUNDO = 110

# Fundos: nome usado no codigo, arquivo, e recorte (x0, y0, x1, y1) na imagem original.
# A borda de baixo do recorte fica um pouco abaixo da linha do mar.
FUNDOS = [
    ("amanhecer",  "Horizonte Pixelado ao Amanhecer.png",   (0, 187, 2172, 517)),
    ("tarde",      "Panorama Costeiro em Dia e Noite.png",  (0, 0, 2172, 320)),
    ("por_do_sol", "Pôr do Sol Pixelado na Costa.png",      (0, 242, 2172, 572)),
    ("crepusculo", "Panorama Costeiro em Dia e Noite.png",  (0, 369, 2172, 648)),
    ("lua_cheia",  "Cidade Costeira sob a Lua Cheia.png",   (0, 185, 2172, 515)),
]

ARQUIVO_CARROS = "Sprites de Carro Esportivo em Pixel Art.png"
GRADE_CARROS = 5            # a arte dos carros foi desenhada em blocos de 5x5 pixels
VISTAS = ["reto", "esq", "dir"]   # ordem dos carros na imagem, da esquerda para a direita

# Cores dos carros. None = cor original (prata).
CORES_CARROS_LISTA = [
    ("vermelho", (214, 36, 36)),
    ("azul",     (36, 92, 226)),
    ("amarelo",  (242, 194, 28)),
    ("prata",    None),
    ("verde",    (36, 166, 70)),
    ("laranja",  (240, 116, 20)),
    ("roxo",     (140, 60, 200)),
    ("ciano",    (24, 180, 196)),
]
CORES_DE_JOGADOR = {"vermelho", "azul", "amarelo"}   # estes ganham as vistas de curva

NIVEIS_CARRO = 17          # quantos tamanhos de carro gerar
FATOR_NIVEL = 0.85         # cada nivel tem 85% da largura do anterior
NIVEIS_COM_CURVA = 6       # vistas de curva (esq/dir) so nos maiores tamanhos


# ----------------------------------------------------------------------------
# Utilidades de cor
# ----------------------------------------------------------------------------

def pixels_de(img):
    if hasattr(img, "get_flattened_data"):
        return list(img.get_flattened_data())
    return list(img.getdata())


def para_5bits(c):
    """Arredonda uma cor para o que o Lupi consegue mostrar (5 bits por canal)."""
    r, g, b = (round(v * 31 / 255) for v in c[:3])
    if (r, g, b) == (0, 0, 0):
        r, g, b = 1, 1, 1          # preto puro e reservado para "transparente"
    if (r, g, b) == (8, 8, 8):
        b = 9                      # cor magica que o codec usa para sprite sheets
    return tuple((v << 3) | (v >> 2) for v in (r, g, b))


def criar_paleta(imagens, n_cores):
    opacos = []
    for img in imagens:
        opacos.extend(p[:3] for p in pixels_de(img) if p[3] >= 128)
    mosaico = Image.new("RGB", (len(opacos), 1))
    mosaico.putdata(opacos)
    q = mosaico.quantize(colors=n_cores, method=Image.Quantize.MEDIANCUT, kmeans=4, dither=Image.Dither.NONE)
    plana = q.getpalette()[: n_cores * 3]
    cores = []
    for i in range(0, len(plana), 3):
        c = para_5bits(plana[i:i + 3])
        if c not in cores:
            cores.append(c)
    return cores


def cores_existentes(*pastas):
    """Cores ja usadas pelas imagens geradas antes (para MANTER_CORES)."""
    cores = set()
    for pasta in pastas:
        for atual, _, nomes in os.walk(os.path.join(DESTINO_IMG, pasta)):
            for nome in nomes:
                if nome.endswith(".png"):
                    img = Image.open(os.path.join(atual, nome)).convert("RGBA")
                    cores.update(p[:3] for p in pixels_de(img) if p[3] >= 128)
    return sorted(cores)


def aplicar_paleta(img, cores):
    """Troca cada pixel pela cor mais proxima da paleta. Transparente continua transparente."""
    plana = []
    for c in cores:
        plana.extend(c)
    plana += list(cores[0]) * (256 - len(cores))
    pal = Image.new("P", (1, 1))
    pal.putpalette(plana)
    rgb = img.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
    saida = Image.new("RGBA", img.size)
    alfa = [p[3] for p in pixels_de(img)]
    saida.putdata([(r, g, b, 255) if a >= 128 else (0, 0, 0, 0) for (r, g, b), a in zip(pixels_de(rgb), alfa)])
    return saida


def reduzir(img, largura, altura):
    """Reduz com boa qualidade respeitando a transparencia."""
    return img.convert("RGBa").resize((largura, altura), Image.LANCZOS).convert("RGBA")


def cor_hex(c):
    return "0x%02X%02X%02X" % c[:3]


def cor_media(img, linhas):
    soma, n = [0, 0, 0], 0
    largura = img.size[0]
    px = img.load()
    for y in linhas:
        for x in range(largura):
            r, g, b, a = px[x, y]
            if a:
                soma[0] += r; soma[1] += g; soma[2] += b; n += 1
    return tuple(v // max(n, 1) for v in soma)


def mais_proxima(c, cores):
    return min(cores, key=lambda k: sum((a - b) ** 2 for a, b in zip(c, k)))


# ----------------------------------------------------------------------------
# Fundos
# ----------------------------------------------------------------------------

def preparar_fundos():
    fundos = []
    for nome, arquivo, recorte in FUNDOS:
        img = Image.open(os.path.join(ORIGEM, arquivo)).convert("RGBA").crop(recorte)
        escala = ALTURA_FUNDO / img.size[1]
        largura = round(img.size[0] * escala)
        fundos.append((nome, reduzir(img, largura, ALTURA_FUNDO)))
    return fundos


# ----------------------------------------------------------------------------
# Carros
# ----------------------------------------------------------------------------

def recortar_carros():
    """Separa os 3 carros do fundo escuro e devolve imagens com transparencia."""
    img = Image.open(os.path.join(ORIGEM, ARQUIVO_CARROS)).convert("RGB")
    W, H = img.size
    G = GRADE_CARROS
    px = img.load()

    def fase(horizontal):
        melhor = None
        for o in range(G):
            erro = 0
            if horizontal:
                for y in range(H // 3, 2 * H // 3, 7):
                    for x in range(o, W - G, G):
                        erro += sum(abs(a - b) for a, b in zip(px[x + 1, y], px[x + 3, y]))
            else:
                for x in range(0, W, 7):
                    for y in range(o + H // 3, 2 * H // 3 - G, G):
                        erro += sum(abs(a - b) for a, b in zip(px[x, y + 1], px[x, y + 3]))
            if melhor is None or erro < melhor[0]:
                melhor = (erro, o)
        return melhor[1]

    ox, oy = fase(True), fase(False)
    w, h = (W - ox) // G, (H - oy) // G
    peq = Image.new("RGB", (w, h))
    p = peq.load()
    for y in range(h):
        for x in range(w):
            p[x, y] = px[ox + x * G + G // 2, oy + y * G + G // 2]

    # "inunda" o fundo a partir das bordas: segue pixels escuros e com variacao suave
    fundo = [[False] * w for _ in range(h)]
    fila = deque()
    for x in range(w):
        for y in (0, h - 1):
            fundo[y][x] = True; fila.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            fundo[y][x] = True; fila.append((x, y))
    while fila:
        x, y = fila.popleft()
        c = p[x, y]
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not fundo[ny][nx]:
                n = p[nx, ny]
                if sum(abs(a - b) for a, b in zip(c, n)) <= 10 and max(n) <= 80:
                    fundo[ny][nx] = True; fila.append((nx, ny))

    colunas = [any(not fundo[y][x] for y in range(h)) for x in range(w)]
    faixas, inicio = [], None
    for x, tem in enumerate(colunas + [False]):
        if tem and inicio is None:
            inicio = x
        if not tem and inicio is not None:
            if x - inicio > 20:
                faixas.append((inicio, x))
            inicio = None
    if len(faixas) != len(VISTAS):
        raise SystemExit("Esperava %d carros na imagem e encontrei %d." % (len(VISTAS), len(faixas)))

    carros = {}
    for vista, (x0, x1) in zip(VISTAS, faixas):
        linhas = [y for y in range(h) if any(not fundo[y][x] for x in range(x0, x1))]
        y0, y1 = linhas[0], linhas[-1] + 1
        carro = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        c = carro.load()
        for y in range(y0, y1):
            xs = [x for x in range(x0, x1) if not fundo[y][x]]
            if xs:
                for x in range(xs[0], xs[-1] + 1):   # preenche buracos dentro da silhueta
                    c[x - x0, y - y0] = p[x, y] + (255,)
        carros[vista] = carro
    return carros


def pintar(img, cor):
    """Troca a lataria prateada pela cor pedida, mantendo luz e sombra."""
    if cor is None:
        return img.copy()
    saida = img.copy()
    px = saida.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if not a:
                continue
            _, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s < 0.50 and v > 0.22:
                t = (v - 0.22) / 0.78
                if t < 0.55:
                    k = 0.30 + 0.70 * t / 0.55
                    novo = tuple(int(c * k) for c in cor)
                else:
                    k = (t - 0.55) / 0.45 * 0.85
                    novo = tuple(int(c + (255 - c) * k) for c in cor)
                px[x, y] = novo + (255,)
    return saida


def preparar_carros():
    vistas = recortar_carros()
    largura_base = vistas["reto"].size[0]
    niveis = []
    for k in range(NIVEIS_CARRO):
        niveis.append(max(4, round(largura_base * FATOR_NIVEL ** k)))
    imagens = {}  # (cor, vista, nivel) -> imagem
    for nome_cor, cor in CORES_CARROS_LISTA:
        pintadas = {v: pintar(img, cor) for v, img in vistas.items()}
        for k, largura in enumerate(niveis, start=1):
            fator = largura / largura_base
            for vista, img in pintadas.items():
                if vista != "reto" and (nome_cor not in CORES_DE_JOGADOR or k > NIVEIS_COM_CURVA):
                    continue
                lw = max(2, round(img.size[0] * fator))
                lh = max(2, round(img.size[1] * fator))
                imagens[(nome_cor, vista, k)] = img if fator == 1 else reduzir(img, lw, lh)
    return imagens, niveis


# ----------------------------------------------------------------------------
# Principal
# ----------------------------------------------------------------------------

def salvar(img, *partes):
    caminho = os.path.join(DESTINO_IMG, *partes)
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    img.save(caminho)


def main():
    print("Lendo arte-original/ ...")
    fundos = preparar_fundos()
    carros, niveis = preparar_carros()

    paleta_fundos = MANTER_CORES and cores_existentes("fundos", "titulo")
    paleta_carros = MANTER_CORES and cores_existentes("carros")
    if paleta_fundos and paleta_carros:
        print("Reaproveitando as cores ja publicadas (fundos: %d, carros: %d) ..." % (len(paleta_fundos), len(paleta_carros)))
    else:
        print("Escolhendo cores (fundos: %d, carros: %d) ..." % (CORES_FUNDOS, CORES_CARROS))
    paleta_fundos = paleta_fundos or criar_paleta([img for _, img in fundos], CORES_FUNDOS)
    paleta_carros = paleta_carros or criar_paleta([img for (c, v, k), img in carros.items() if k == 1], CORES_CARROS)

    for pasta in ("fundos", "carros", "titulo"):   # "titulo": apaga a imagem antiga da tela de titulo
        shutil.rmtree(os.path.join(DESTINO_IMG, pasta), ignore_errors=True)

    dados_fundos = []
    previa = []
    for nome, img in fundos:
        img = aplicar_paleta(img, paleta_fundos)
        cores_img = list({p[:3] for p in pixels_de(img)})
        largura = img.size[0]
        n_pecas = -(-largura // 512)
        pecas, larguras = [], []
        x = 0
        for i in range(n_pecas):
            lp = (largura - x) // (n_pecas - i)
            salvar(img.crop((x, 0, x + lp, ALTURA_FUNDO)), "fundos", "%s_%d.png" % (nome, i + 1))
            pecas.append("%s_%d" % (nome, i + 1)); larguras.append(lp)
            x += lp
        ceu = mais_proxima(cor_media(img, range(0, 3)), cores_img)
        mar = mais_proxima(cor_media(img, range(ALTURA_FUNDO - 3, ALTURA_FUNDO)), cores_img)
        dados_fundos.append((nome, pecas, larguras, largura, ceu, mar))
        previa.append(img)

    linha_carros = []
    for (cor, vista, k), img in sorted(carros.items()):
        img = aplicar_paleta(img, paleta_carros)
        salvar(img, "carros", cor, "%s%d.png" % (vista, k))
        if vista == "reto" and k == 1 or (cor == "vermelho" and k == 1):
            linha_carros.append(img)

    with open(DADOS_LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- Gerado por ferramentas/preparar_arte.py. Nao edite a mao: rode o script de novo.\n")
        f.write("Arte = {\n  fundos = {\n")
        for nome, pecas, larguras, largura, ceu, mar in dados_fundos:
            f.write('    %s = { pecas = { %s }, larguras = { %s }, largura = %d, altura = %d, ceu = %s, mar = %s },\n' % (
                nome, ", ".join('"%s"' % p for p in pecas), ", ".join(str(l) for l in larguras),
                largura, ALTURA_FUNDO, cor_hex(ceu), cor_hex(mar)))
        f.write("  },\n  carros = {\n")
        f.write("    cores = { %s },\n" % ", ".join('"%s"' % c for c, _ in CORES_CARROS_LISTA))
        f.write("    niveis = %d,\n" % NIVEIS_CARRO)
        f.write("    niveis_com_curva = %d,\n" % NIVEIS_COM_CURVA)
        f.write("  },\n}\n")

    # previa para conferir o resultado
    largura_p = max(max(i.size[0] for i in previa), sum(i.size[0] + 4 for i in linha_carros))
    altura_p = sum(i.size[1] + 4 for i in previa) + max(i.size[1] for i in linha_carros) + 4
    folha = Image.new("RGB", (largura_p, altura_p), (255, 0, 255))
    y = 0
    for img in previa:
        folha.paste(img, (0, y), img); y += img.size[1] + 4
    x = 0
    for img in linha_carros:
        folha.paste(img, (x, y), img); x += img.size[0] + 4
    os.makedirs(os.path.dirname(PREVIA), exist_ok=True)
    folha.save(PREVIA)

    total = len(set(paleta_fundos) | set(paleta_carros))
    print("Pronto! %d fundos e %d imagens de carro." % (len(fundos), len(carros)))
    print("Cores usadas pela arte: %d (sobram ~%d para as cores do codigo)." % (total, 255 - total))
    print("Previa em: %s" % os.path.relpath(PREVIA, RAIZ))


if __name__ == "__main__":
    main()
