"""
Servidor de desenvolvimento do jogo.

  - constroi o jogo (ferramentas/construir.py)
  - abre o simulador do Lupi no navegador (http://localhost:8000)
  - fica olhando os arquivos do jogo: quando voce salva um, reconstroi e o
    simulador recarrega o jogo sozinho

Uso:  python ferramentas/servidor.py          (ou de dois cliques em INICIAR.bat)
Para parar: feche a janela ou aperte Ctrl+C.
"""
import os
import sys
import json
import time
import threading
import webbrowser
import http.server
import socketserver
from urllib.parse import urlparse, unquote

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import construir  # noqa: E402

RAIZ = construir.RAIZ
PASTA_SIMULADOR = os.path.join(RAIZ, "ferramentas", "simulador")
PORTA_INICIAL = 8000

estado = {"versao": 0, "construindo": False, "relatorio": None}
trava = threading.Lock()


def foto_da_pasta():
    foto = {}
    for rel in construir.listar_arquivos(construir.PASTA_JOGO, construir.FORA_DO_CARTUCHO):
        if rel == "img/cores.png":
            continue
        caminho = os.path.join(construir.PASTA_JOGO, rel)
        try:
            foto[caminho] = os.path.getmtime(caminho)
        except OSError:
            pass
    return foto


def reconstruir():
    with trava:
        estado["construindo"] = True
        try:
            relatorio = construir.construir(silencioso=True)
        except Exception as e:  # erro inesperado na ferramenta: mostra no navegador em vez de derrubar o servidor
            relatorio = {"ok": False, "erros": ["Falha na ferramenta de construcao: %r" % e], "avisos": []}
        estado["relatorio"] = relatorio
        estado["versao"] += 1
        estado["construindo"] = False
    hora = time.strftime("%H:%M:%S")
    print("[%s] Construcao #%d: %s" % (hora, estado["versao"], "OK" if relatorio["ok"] else "COM ERROS"))
    for e in relatorio["erros"]:
        print("    ERRO:", e)
    for a in relatorio["avisos"]:
        print("    AVISO:", a)


def vigiar():
    anterior = foto_da_pasta()
    while True:
        time.sleep(0.5)
        atual = foto_da_pasta()
        if atual != anterior:
            time.sleep(0.3)  # espera o editor terminar de salvar
            anterior = foto_da_pasta()
            reconstruir()


class Manipulador(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=PASTA_SIMULADOR, **kwargs)

    def log_message(self, *args):
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def responder_json(self, dados):
        corpo = json.dumps(dados).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo)))
        self.end_headers()
        self.wfile.write(corpo)

    def do_GET(self):
        caminho = unquote(urlparse(self.path).path)
        if caminho == "/api/estado":
            relatorio = estado["relatorio"] or {}
            self.responder_json({
                "versao": estado["versao"],
                "construindo": estado["construindo"],
                "ok": relatorio.get("ok", False),
                "erros": relatorio.get("erros", []),
                "avisos": relatorio.get("avisos", []),
                "arquivos": relatorio.get("arquivos", []),
                "cores": relatorio.get("cores", 0),
                "lupi": relatorio.get("lupi", ""),
            })
            return
        if caminho == "/baixar":
            rel = (estado["relatorio"] or {}).get("lupi", "")
            arquivo = os.path.join(RAIZ, rel)
            if not rel or not os.path.isfile(arquivo):
                self.send_error(404)
                return
            with open(arquivo, "rb") as f:
                corpo = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "application/zip")
            self.send_header("Content-Disposition", 'attachment; filename="%s"' % os.path.basename(arquivo))
            self.send_header("Content-Length", str(len(corpo)))
            self.end_headers()
            self.wfile.write(corpo)
            return
        if caminho.startswith("/cartucho/"):
            rel = caminho[len("/cartucho/"):]
            arquivo = os.path.normpath(os.path.join(construir.SAIDA_DESCOMPACTADA, rel))
            if not arquivo.startswith(construir.SAIDA_DESCOMPACTADA) or not os.path.isfile(arquivo):
                self.send_error(404)
                return
            with open(arquivo, "rb") as f:
                corpo = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(len(corpo)))
            self.end_headers()
            self.wfile.write(corpo)
            return
        if caminho.endswith(".wasm"):
            self.extensions_map[".wasm"] = "application/wasm"
        super().do_GET()


class Servidor(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = False


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(line_buffering=True)
    abrir_navegador = "--sem-navegador" not in sys.argv
    reconstruir()
    servidor = None
    for porta in range(PORTA_INICIAL, PORTA_INICIAL + 20):
        try:
            servidor = Servidor(("127.0.0.1", porta), Manipulador)
            break
        except OSError:
            continue
    if servidor is None:
        print("Nao consegui abrir nenhuma porta entre %d e %d." % (PORTA_INICIAL, PORTA_INICIAL + 19))
        sys.exit(1)
    endereco = "http://localhost:%d/" % servidor.server_address[1]
    print()
    print("  Simulador rodando em:  " + endereco)
    print("  Edite os arquivos do jogo (.lua) e salve: o jogo recarrega sozinho.")
    print("  Para parar: Ctrl+C (ou feche esta janela).")
    print()
    threading.Thread(target=vigiar, daemon=True).start()
    if abrir_navegador:
        threading.Timer(0.8, lambda: webbrowser.open(endereco)).start()
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        print("Servidor parado.")


if __name__ == "__main__":
    main()
