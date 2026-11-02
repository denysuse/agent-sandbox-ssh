#!/usr/bin/env bash
# health-check.sh — diagnosis cepat ±30 detik: jalur mana ke sandbox yang
# hidup, dan di mana putusnya. Dibuat setelah kegagalan nyata di mana tiga
# sebab berbeda (jalur mesh putus di proxy, perintah bersarang keliru,
# sandbox mati) tampil persis sama dari luar.
#
# Pemakaian:
#   RELAY_HOST=relay.example.com RELAY_KEY=~/.ssh/relay KEY=~/.ssh/agent-access \
#     ./health-check.sh
#   TARGET_IP=100.x.x.x ./health-check.sh     # sekalian probe jalur mesh
#
# Variabel mengikuti connect-tunnel.sh; TARGET_IP opsional untuk cek mesh.
set +e
HERE="$(cd "$(dirname "$0")" && pwd)"
RELAY_HOST="${RELAY_HOST:?isi RELAY_HOST dengan host server relay}"
RELAY_USER="${RELAY_USER:-ubuntu}"
RELAY_KEY="${RELAY_KEY:-${KEY:-$HOME/.ssh/agent-access}}"
TUNNEL_PORT="${TUNNEL_PORT:-2222}"

echo "== 1. Port balik $TUNNEL_PORT di relay =="
OUT=$(ssh -i "$RELAY_KEY" -o BatchMode=yes -o ConnectTimeout=30 \
  "$RELAY_USER@$RELAY_HOST" "ss -ltn | grep 127.0.0.1:$TUNNEL_PORT" 2>&1)
echo "$OUT" | grep -q LISTEN \
  && echo "LISTEN - tunnel tersambung dari sandbox" \
  || echo "TIDAK LISTEN - sandbox mati ATAU service tunnel di sandbox mati"

echo
echo "== 2. Login via tunnel =="
RELAY_HOST="$RELAY_HOST" RELAY_KEY="$RELAY_KEY" \
  "$HERE/connect-tunnel.sh" 'echo LOGIN-OK $(hostname)' 2>&1 | tail -2

if [ -n "${TARGET_IP:-}" ]; then
  echo
  echo "== 3. Probe jalur mesh (TCP ke $TARGET_IP:22, timeout 15 dtk) =="
  timeout 15 bash -c "echo > /dev/tcp/$TARGET_IP/22" 2>/dev/null \
    && echo "port 22 mesh bisa dijangkau" \
    || echo "tidak terjangkau (bisa berarti jalur mesh/proxy bermasalah; ICMP/TCP tidak selalu diteruskan relay, jadi ini petunjuk, bukan vonis)"
fi
