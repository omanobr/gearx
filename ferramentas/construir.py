"""
Constroi o jogo: pega os arquivos do jogo (na raiz do projeto, como nos jogos oficiais)
e gera o "cartucho" que o Lupi entende.

Faz o mesmo trabalho do lupi-codec oficial (github.com/lupi-org-br/lupi-codec):
  - cada PNG vira um arquivo de bytes (1 byte por pixel = indice da cor, 0 = transparente)
  - junta as cores de TODAS as imagens numa unica paleta (maximo 256 cores)
  - gera palette.lua e lupi_manifest.txt
  - copia os arquivos .lua
  - empacota tudo em build/<nome>.lupi (um zip)

Antes disso, gera img/cores.png: uma "amostra" com todas as cores que o codigo
usa via Palette.hex(0xRRGGBB). Assim essas cores entram na paleta oficial tambem.

Uso:  python ferramentas/construir.py
"""
import os
import re
import sys
import json
import time
import shutil
import zipfile

try:
    from PIL import Image
except ImportError:
    print("ERRO: falta a biblioteca Pillow. Instale com:  python -m pip install pillow")
    sys.exit(1)

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PASTA_JOGO = RAIZ  # o jogo fica na raiz, igual aos jogos oficiais (balao-gatinho, primeiro-jogo)
# pastas do projeto que nao fazem parte do cartucho (arte-original nem vai para o GitHub: ver .gitignore)
FORA_DO_CARTUCHO = {"build", "ferramentas", "arte-original", "__pycache__"}
PASTA_BUILD = os.path.join(RAIZ, "build")
SAIDA_DESCOMPACTADA = os.path.join(PASTA_BUILD, "jogo")

LIMITE_CORES = 256
# Memoria grafica do console: cada imagem "linear" (que nao e sprite sheet) ocupa
# largura x altura bytes e nao pode passar deste limite. Vem do log do servidor do Lupi:
# "Capacity check failed ... ultrapassando o limite de 46059 bytes da memoria grafica".
# Exemplo: 418x110 cabe; 428x110 nao.
LIMITE_BYTES_IMAGEM = 46059
LIMITE_LADO = 512
COR_MAGICA_TILES = 8456  # BGR555 que o codec usa para detectar sprite sheets (pixel 0,0)
ARQUIVOS_SO_DE_DESENVOLVIMENTO = {"dev_config.lua"}
REGEX_HEX = re.compile(r"hex\(\s*0x([0-9A-Fa-f]{6})\s*\)")


def rgb_para_bgr555(r, g, b):
    return ((b >> 3) << 10) | ((g >> 3) << 5) | (r >> 3)


def pixels_de(img):
    if hasattr(img, "get_flattened_data"):
        return list(img.get_flattened_data())
    return list(img.getdata())


def listar_arquivos(pasta, ignorar=()):
    resultado = []
    for atual, subpastas, arquivos in os.walk(pasta):
        subpastas[:] = sorted(s for s in subpastas if not s.startswith(".") and s not in ignorar)
        for nome in sorted(arquivos):
            if nome.startswith("."):
                continue
            caminho = os.path.join(atual, nome)
            resultado.append(os.path.relpath(caminho, pasta).replace("\\", "/"))
    return resultado


def ler_nome_do_jogo():
    caminho = os.path.join(PASTA_JOGO, "lupi.yaml")
    if os.path.exists(caminho):
        with open(caminho, encoding="utf-8") as f:
            for linha in f:
                if linha.strip().startswith("name:"):
                    nome = linha.split(":", 1)[1].strip().strip("\"'")
                    slug = re.sub(r"[^a-z0-9]+", "-", nome.lower()).strip("-")
                    return slug or "jogo"
    return "jogo"


def atualizar_amostra_de_cores(avisos):
    """Gera img/cores.png com as cores usadas em Palette.hex(...) no codigo."""
    cores = set()
    for rel in listar_arquivos(PASTA_JOGO, FORA_DO_CARTUCHO):
        if rel.endswith(".lua") and os.path.basename(rel) not in ARQUIVOS_SO_DE_DESENVOLVIMENTO:
            with open(os.path.join(PASTA_JOGO, rel), encoding="utf-8") as f:
                for m in REGEX_HEX.finditer(f.read()):
                    cores.add(int(m.group(1), 16))
    if not cores:
        return 0
    lista = []
    for c in sorted(cores):
        r, g, b = (c >> 16) & 255, (c >> 8) & 255, c & 255
        if rgb_para_bgr555(r, g, b) == 0:
            avisos.append("A cor 0x%06X vira preto absoluto (0x0000), que o Lupi usa como transparente. Use 0x080808 ou mais claro." % c)
        # grava a cor ja "encaixada" nos 5 bits do Lupi; senao o codec oficial (que arredonda
        # ao ler as cores e trunca ao codificar) gastaria duas vagas da paleta com ela
        r, g, b = (((v >> 3) << 3) | (v >> 5) for v in (r, g, b))
        if (r, g, b, 255) not in lista:
            lista.append((r, g, b, 255))
    # o primeiro pixel nao pode ser a cor magica, senao o codec acha que e um sprite sheet
    lista.sort(key=lambda p: rgb_para_bgr555(*p[:3]) == COR_MAGICA_TILES)
    img = Image.new("RGBA", (len(lista), 1))
    img.putdata(lista)
    destino = os.path.join(PASTA_JOGO, "img", "cores.png")
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    if os.path.exists(destino):
        try:
            antiga = Image.open(destino).convert("RGBA")
            if antiga.size == img.size and pixels_de(antiga) == lista:
                return len(lista)
        except Exception:
            pass
    img.save(destino)
    return len(lista)


def detectar_tiles(pixels, largura, altura):
    """Mesma regra do codec: se o pixel (0,0) tem a cor magica, a imagem e um sprite sheet."""
    def bgr(x, y):
        r, g, b, _ = pixels[y * largura + x]
        return rgb_para_bgr555(r, g, b)
    if bgr(0, 0) != COR_MAGICA_TILES:
        return None
    tw = next((x for x in range(largura) if bgr(x, 0) != COR_MAGICA_TILES), largura)
    th = next((y for y in range(altura) if bgr(0, y) != COR_MAGICA_TILES), altura)
    if tw > 0 and th > 0:
        return tw, th
    return None


class Paleta:
    def __init__(self):
        self.cores = [0x0000]  # indice 0 = transparente
        self.indice = {}

    def indice_de(self, r, g, b, a):
        if a == 0:
            return 0
        cor = rgb_para_bgr555(r, g, b)
        i = self.indice.get(cor)
        if i is None:
            i = len(self.cores)
            self.cores.append(cor)
            self.indice[cor] = i
        return i


def codificar_png(caminho, rel, paleta, erros):
    img = Image.open(caminho).convert("RGBA")
    largura, altura = img.size
    if largura > LIMITE_LADO or altura > LIMITE_LADO:
        erros.append("%s tem %dx%d pixels; o maximo e %dx%d." % (rel, largura, altura, LIMITE_LADO, LIMITE_LADO))
        return None
    pixels = pixels_de(img)
    cores_da_imagem = {p[:3] for p in pixels if p[3] != 0}
    if len(cores_da_imagem) > LIMITE_CORES:
        erros.append("%s tem %d cores; o maximo por imagem e %d." % (rel, len(cores_da_imagem), LIMITE_CORES))
        return None
    tiles = detectar_tiles(pixels, largura, altura)
    if not tiles and largura * altura > LIMITE_BYTES_IMAGEM:
        erros.append("%s (%dx%d) ocupa %d bytes; o console aceita no maximo %d bytes por imagem. "
                     "Divida a imagem em pedacos menores ou diminua o tamanho."
                     % (rel, largura, altura, largura * altura, LIMITE_BYTES_IMAGEM))
        return None
    saida = bytearray()
    meta = {"type": "bitmap", "width": largura, "height": altura}
    if tiles:
        tw, th = tiles
        nx, ny = largura // tw, altura // th
        for ty in range(1, ny):  # a primeira linha e coluna de tiles sao margem
            for tx in range(1, nx):
                for y in range(th):
                    for x in range(tw):
                        saida.append(paleta.indice_de(*pixels[(ty * th + y) * largura + tx * tw + x]))
        meta = {"type": "bitmap", "width": tw, "height": th, "tiles": nx * ny}
    else:
        for p in pixels:
            saida.append(paleta.indice_de(*p))
    return bytes(saida), meta


REGEX_UTF8_LIB = re.compile(r"\butf8\s*\.")


def conferir_texto_lua(caminho, rel, erros):
    """O console guarda os .lua em Latin-9 (1 byte por letra) e nao tem a biblioteca utf8
    completa: utf8.* quebra la ("invalid UTF-8 code"). As letras acentuadas sao tratadas em
    texto.lua, que entende os dois jeitos."""
    with open(caminho, encoding="utf-8") as f:
        linhas = f.read().split("\n")
    for n, linha in enumerate(linhas, start=1):
        codigo = linha.split("--", 1)[0]
        if REGEX_UTF8_LIB.search(codigo):
            erros.append("%s:%d usa utf8.*, que quebra no console (texto em Latin-9). "
                         "Use as funcoes de texto.lua." % (rel, n))
        try:
            linha.encode("iso-8859-15")
        except UnicodeEncodeError as e:
            erros.append("%s:%d tem o caractere '%s', que nao existe no Latin-9 do console."
                         % (rel, n, linha[e.start]))


def gerar_palette_lua(paleta):
    linhas = ["-- Gerado automaticamente por ferramentas/construir.py. Nao edite.", "Palette = {"]
    for i, cor in enumerate(paleta.cores):
        linhas.append("  [%d] = 0x%04X," % (i + 1, cor))
    linhas.append("}")
    linhas.append("""
-- Palette.hex(0xRRGGBB) devolve o indice da cor na paleta (para usar em ui.rectfill, ui.print...)
local function _bgr555(rgb)
  local r, g, b = (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF
  return ((b >> 3) << 10) | ((g >> 3) << 5) | (r >> 3)
end

function Palette.hex(rgb)
  local alvo = _bgr555(rgb)
  local melhor, menor = 1, math.huge
  for i = 2, #Palette do
    local c = Palette[i]
    if c == alvo then return i - 1 end
    local dr = (c & 0x1F) - (alvo & 0x1F)
    local dg = ((c >> 5) & 0x1F) - ((alvo >> 5) & 0x1F)
    local db = ((c >> 10) & 0x1F) - ((alvo >> 10) & 0x1F)
    local d = dr * dr + dg * dg + db * db
    if d < menor then melhor, menor = i, d end
  end
  return melhor - 1
end
""")
    return "\n".join(linhas)


def construir(silencioso=False):
    inicio = time.time()
    erros, avisos = [], []
    if not os.path.exists(os.path.join(PASTA_JOGO, "game.lua")):
        erros.append("Nao encontrei game.lua na pasta do projeto")
        return {"ok": False, "erros": erros, "avisos": avisos}

    cores_codigo = atualizar_amostra_de_cores(avisos)

    if os.path.exists(SAIDA_DESCOMPACTADA):
        shutil.rmtree(SAIDA_DESCOMPACTADA)
    os.makedirs(SAIDA_DESCOMPACTADA)

    paleta = Paleta()
    memoria, maior = 0, 0
    itens = []  # (caminho_no_cartucho, tamanho, metadados)
    for rel in listar_arquivos(PASTA_JOGO, FORA_DO_CARTUCHO):
        origem = os.path.join(PASTA_JOGO, rel)
        nome = os.path.basename(rel)
        if rel.endswith(".png"):
            resultado = codificar_png(origem, rel, paleta, erros)
            if resultado is None:
                continue
            dados, meta = resultado
            memoria += len(dados)
            maior = max(maior, len(dados))
            destino_rel = rel[:-4]
            destino = os.path.join(SAIDA_DESCOMPACTADA, destino_rel)
            os.makedirs(os.path.dirname(destino), exist_ok=True)
            with open(destino, "wb") as f:
                f.write(dados)
            itens.append((destino_rel, len(dados), meta, os.path.getmtime(origem)))
        elif rel.endswith(".lua"):
            if nome == "palette.lua" or nome in ARQUIVOS_SO_DE_DESENVOLVIMENTO:
                continue
            conferir_texto_lua(origem, rel, erros)
            destino = os.path.join(SAIDA_DESCOMPACTADA, rel)
            os.makedirs(os.path.dirname(destino), exist_ok=True)
            shutil.copyfile(origem, destino)
            itens.append((rel, os.path.getsize(origem), {"type": "lua_code"}, os.path.getmtime(origem)))

    if len(paleta.cores) > LIMITE_CORES:
        erros.append("A paleta do jogo ficou com %d cores; o Lupi aceita no maximo %d. "
                     "Rode ferramentas/preparar_arte.py com menos cores ou use menos cores no codigo."
                     % (len(paleta.cores), LIMITE_CORES))

    texto_paleta = gerar_palette_lua(paleta)
    with open(os.path.join(SAIDA_DESCOMPACTADA, "palette.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(texto_paleta)
    itens.append(("palette.lua", len(texto_paleta.encode()), {"type": "lua_code"}, 1))

    itens.sort(key=lambda it: (int(it[3]), it[0]))
    contagem = {}
    linhas = []
    for caminho, tamanho, meta, ts in itens:
        ts = int(ts)
        n = contagem.get(ts, 0)
        contagem[ts] = n + 1
        linhas.append("%d %d %s %s" % (ts * 10000 + n, tamanho, caminho, json.dumps(meta, separators=(",", ":"))))
    with open(os.path.join(SAIDA_DESCOMPACTADA, "lupi_manifest.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(linhas) + "\n")

    nome_lupi = ler_nome_do_jogo() + ".lupi"
    caminho_lupi = os.path.join(PASTA_BUILD, nome_lupi)
    with zipfile.ZipFile(caminho_lupi, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in listar_arquivos(SAIDA_DESCOMPACTADA):
            z.write(os.path.join(SAIDA_DESCOMPACTADA, rel), rel)

    relatorio = {
        "ok": not erros,
        "erros": erros,
        "avisos": avisos,
        "cores": len(paleta.cores),
        "cores_codigo": cores_codigo,
        "memoria_kb": memoria // 1024,
        "maior_imagem": maior,
        "arquivos": listar_arquivos(SAIDA_DESCOMPACTADA),
        "lupi": os.path.relpath(caminho_lupi, RAIZ).replace("\\", "/"),
        "tamanho_kb": round(os.path.getsize(caminho_lupi) / 1024),
        "segundos": round(time.time() - inicio, 2),
    }
    if not silencioso:
        imprimir_relatorio(relatorio)
    return relatorio


def imprimir_relatorio(r):
    for e in r["erros"]:
        print("ERRO:", e)
    for a in r["avisos"]:
        print("AVISO:", a)
    if "cores" in r:
        print("Paleta: %d de %d cores (%d usadas pelo codigo)" % (r["cores"], LIMITE_CORES, r["cores_codigo"]))
        print("Imagens: %d KB no total; a maior tem %d de %d bytes permitidos por imagem"
              % (r["memoria_kb"], r["maior_imagem"], LIMITE_BYTES_IMAGEM))
        print("Cartucho: %s (%d KB, %d arquivos) em %.2fs" % (r["lupi"], r["tamanho_kb"], len(r["arquivos"]), r["segundos"]))
    print("OK!" if r["ok"] else "FALHOU.")


if __name__ == "__main__":
    sys.exit(0 if construir()["ok"] else 1)
