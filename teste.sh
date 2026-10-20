#!/usr/bin/env bash
# Teste local do vigia.sh sem rede: servidor HTTP falso para API, ranking e Telegram.
set -Eeuo pipefail
cd "$(dirname "$0")"
tmp=$(mktemp -d); trap 'kill $srv 2>/dev/null; rm -rf "$tmp"' EXIT
port=$((20000 + RANDOM % 20000))
cat > "$tmp/srv.py" <<'PY'
import http.server, os, sys
d = sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def reply(self):
        if self.path.startswith('/bot'):
            open(os.path.join(d, 'sent'), 'a').write(self.rfile.read(int(self.headers.get('Content-Length', 0))).decode() + '\n')
            self.send_response(200); self.end_headers(); return
        mode = open(os.path.join(d, 'mode')).read().strip()
        if self.path.startswith('/docs') and mode == 'apidown':
            self.send_response(502); self.end_headers(); return
        self.send_response(200); self.end_headers()
        if self.path.startswith('/rank'):
            self.wfile.write(b'{"available":false}' if mode == 'ingdown' else b'{"x":1,"available":true}')
    do_GET = do_POST = reply
http.server.HTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
PY
python3 -I "$tmp/srv.py" "$port" "$tmp" & srv=$!
sleep 1
export API_URL="http://127.0.0.1:$port/docs" RANK_URL="http://127.0.0.1:$port/rank" TELEGRAM_API="http://127.0.0.1:$port"
export STATE_FILE="$tmp/estado.txt" TELEGRAM_BOT_TOKEN=t TELEGRAM_CHAT_ID=1 TRIES=2 WAIT=0
step() { echo "$1" > "$tmp/mode"; NOW=$2 bash vigia.sh > /dev/null || true; wc -l < "$tmp/sent" 2>/dev/null || echo 0; }
n=$(step ok 1000);       [[ $n == 0 ]] || { echo "FALHOU: aviso sem queda"; exit 1; }
n=$(step apidown 1300);  [[ $n == 1 ]] || { echo "FALHOU: queda da API sem aviso"; exit 1; }
n=$(step apidown 1600);  [[ $n == 1 ]] || { echo "FALHOU: repetiu o aviso"; exit 1; }
n=$(step ok 2200);       [[ $n == 2 ]] || { echo "FALHOU: volta sem aviso"; exit 1; }
grep -q "15+min+fora" "$tmp/sent" || { echo "FALHOU: duracao"; exit 1; }
n=$(step ingdown 2500);  [[ $n == 3 ]] || { echo "FALHOU: queda da ingestao sem aviso"; exit 1; }
n=$(step ok 2800);       [[ $n == 4 ]] || { echo "FALHOU: volta da ingestao sem aviso"; exit 1; }
echo "OK: 4 avisos (API caiu/voltou, ingestao caiu/voltou), sem repeticao"
