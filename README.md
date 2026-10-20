# exl-vigia

Vigia de queda da EXL Trade (decisao do CEO R5, 20/10/2026). A cada 5 min (GitHub Actions) testa:

- **API:** `https://api.exltrade.com/docs-json` responde 200;
- **Ingestao (Trading Core):** `https://api.exltrade.com/torneios/publico/ranking?periodo=semana` volta com `"available":true` (a API so responde assim quando alcanca a ingestao). Com a API fora, a ingestao fica sem teste.

Cada teste repete 3 vezes (20 s) antes de declarar queda. Avisa no Telegram so quando muda: "EXL CAIU" e "EXL VOLTOU" (com o tempo fora). O estado fica em `estado.txt`, commitado so quando muda.

## Secrets do repositorio

- `TELEGRAM_BOT_TOKEN`: token do bot que manda o aviso.
- `TELEGRAM_CHAT_ID`: chat de quem recebe.

## Por que repositorio publico

Em repositorio publico os minutos do Actions sao gratis e sem limite. Os repositorios da organizacao sao privados e dividem 2.000 min/mes do plano Free com o deploy da API; 5 em 5 min gastaria cerca de 8.600 min/mes. O codigo nao tem segredo; os secrets nao aparecem para quem le o repositorio.

Limites do GitHub: o agendamento pode atrasar alguns minutos (ou pular uma rodada em hora de pico) e e desligado em repositorio publico com 60 dias sem commit. O workflow faz um commit em `keepalive.txt` a cada 30 dias para isso nao acontecer. Se a rodada falhar (por exemplo, Telegram fora), o GitHub manda e-mail ao dono do repositorio.

## Teste

`bash teste.sh` (sem rede: servidor falso para API, ranking e Telegram).
