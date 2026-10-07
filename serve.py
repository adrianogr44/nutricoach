"""Servidor local do NutriCoach — serve o build web (build/web) na porta 8080."""
import http.server
import os
import sys

WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")
PORT = int(os.environ.get("PORT", "8080"))
HOST = os.environ.get("HOST", "0.0.0.0")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def _lan_ip():
    try:
        import socket
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "IP_DA_MAQUINA"


if __name__ == "__main__":
    server = http.server.ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"NutriCoach em http://localhost:{PORT}")
    print(f"Na rede: http://{_lan_ip()}:{PORT}")
    server.serve_forever()
