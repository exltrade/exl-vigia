#!/usr/bin/env bash
# Vigia de queda da EXL Trade: testa a API e a ingestao (Trading Core) e avisa no Telegram
# so quando muda de estado (caiu / voltou). Estado guardado em $STATE_FILE (uma linha por item).
# Variaveis: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID (secrets). Nao imprime segredos.
set -Euo pipefail

# Rota publica e leve: o docs-json passava de 20 s vindo de fora e gerou um CAIU falso (20/10 00:49 UTC).
API_URL="${API_URL:-https://api.exltrade.com/product/store?type=programa}"
# Rota publica que a API so responde com "available":true quando alcanca a ingestao.
RANK_URL="${RANK_URL:-https://api.exltrade.com/torneios/publico/ranking?periodo=semana}"
STATE_FILE="${STATE_FILE:-estado.txt}"
TELEGRAM_API="${TELEGRAM_API:-https://api.telegram.org}"
TRIES="${TRIES:-3}"
WAIT="${WAIT:-20}"
NOW="${NOW:-$(date -u +%s)}"

api_ok() { [[ $(curl -s -o /dev/null -m 20 -w '%{http_code}' "$API_URL") == 200 ]]; }
ing_ok() { curl -s -m 25 "$RANK_URL" | grep -q '"available":true'; }

# Repete antes de declarar queda: um erro isolado nao vira aviso.
check() {
  local i
  for ((i = 1; i <= TRIES; i++)); do
    "$1" && { echo up; return; }
    ((i < TRIES)) && sleep "$WAIT"
  done
  echo down
}

send() {
  [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]] || { echo "sem secrets do Telegram; aviso: $1"; return 1; }
  curl -s -o /dev/null -m 20 -w '%{http_code}' "$TELEGRAM_API/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" --data-urlencode "text=$1" | grep -q 200
}

hhmm() { date -u -d "@$1" '+%d/%m %H:%M UTC'; }

declare -A prev_status prev_since
[[ -f $STATE_FILE ]] && while read -r k s t; do prev_status[$k]=$s; prev_since[$k]=$t; done < "$STATE_FILE"

api=$(check api_ok)
# Com a API fora, nao da para saber da ingestao: mantem o estado anterior dela.
if [[ $api == up ]]; then ing=$(check ing_ok); else ing=${prev_status[ingestao]:-up}; fi

declare -A label=([api]="API (api.exltrade.com)" [ingestao]="Ingestao / Trading Core (ranking sem dados)")
fail=0
: > "$STATE_FILE.new"
for k in api ingestao; do
  [[ $k == api ]] && cur=$api || cur=$ing
  old=${prev_status[$k]:-up}
  since=${prev_since[$k]:-$NOW}
  if [[ $cur != "$old" ]]; then
    if [[ $cur == down ]]; then msg="EXL CAIU: ${label[$k]} fora desde $(hhmm "$NOW")."
    else msg="EXL VOLTOU: ${label[$k]} no ar de novo ($(( (NOW - since + 59) / 60 )) min fora, desde $(hhmm "$since"))."; fi
    echo "$msg"
    if send "$msg"; then since=$NOW; else echo "falha ao avisar no Telegram"; fail=1; cur=$old; fi
  fi
  echo "$k $cur $since" >> "$STATE_FILE.new"
done
mv "$STATE_FILE.new" "$STATE_FILE"
echo "api=$api ingestao=$ing"
exit $fail
