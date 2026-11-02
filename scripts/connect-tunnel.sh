#!/usr/bin/env bash
# connect-tunnel.sh — sisi OPERATOR: masuk ke sandbox agen lewat TUNNEL BALIK
# di server relay milikmu sendiri (pola DEFAULT yang direkomendasikan sejak
# pembaruan 3 Nov 2026 — tanpa bergantung pada layanan mesh pihak ketiga).
#
# Prasyarat pola ini:
#   - Di sandbox berjalan tunnel keluar: ssh -N -R 127.0.0.1:TUNNEL_PORT:127.0.0.1:22
#     menuju akun khusus di server relay (dibatasi forwarding-only).
#   - Kamu login ke relay, lalu diteruskan ke port balik itu.
#
# Pemakaian:
#   RELAY_HOST=relay.example.com RELAY_KEY=~/.ssh/relay KEY=~/.ssh/agent-access \
#     ./connect-tunnel.sh "echo LOGIN-OK; hostname"
#
# Variabel lingkungan:
#   RELAY_HOST   (wajib) host server relay publik milikmu
#   RELAY_USER   user di relay                 (bawaan: ubuntu)
#   RELAY_KEY    kunci untuk login ke relay    (bawaan: sama dengan KEY)
#   TUNNEL_PORT  port balik di relay           (bawaan: 2222)
#   TARGET_USER  user SSH di sandbox           (bawaan: ubuntu)
#   KEY          kunci khusus ke sandbox       (bawaan: ~/.ssh/agent-access)
#   JUMP_CMD     ProxyCommand opsional untuk mencapai relay (mis. lewat jump
#                host). PENTING: token %h:%p di dalamnya WAJIB ditulis
#                %%h:%%p — lihat jebakan nomor 8 di README.
#   KH_DIR       folder known_hosts khusus     (bawaan: ~/.ssh/agent-sandbox-kh)
#                Jangan pakai known_hosts bawaan di lokasi yang tidak
#                persisten; berkas khusus ini tidak tertukar dengan host lain.
#
# Jebakan utama pola ini (terbukti di kasus nyata): perintah SSH-nya
# BERSARANG. ssh terluar meng-expand token %h/%p di SELURUH string
# ProxyCommand-nya, termasuk token yang sebenarnya milik lompatan dalam.
# Tanpa penggandaan %%h:%%p, lompatan dalam mendarat di sshd mesin
# lompatan dan autentikasi gagal "publickey denied" padahal kunci benar —
# gejala yang sangat menyesatkan.
set -euo pipefail

RELAY_HOST="${RELAY_HOST:?isi RELAY_HOST dengan host server relay}"
RELAY_USER="${RELAY_USER:-ubuntu}"
TUNNEL_PORT="${TUNNEL_PORT:-2222}"
TARGET_USER="${TARGET_USER:-ubuntu}"
KEY="${KEY:-$HOME/.ssh/agent-access}"
RELAY_KEY="${RELAY_KEY:-$KEY}"
JUMP_CMD="${JUMP_CMD:-}"
KH_DIR="${KH_DIR:-$HOME/.ssh/agent-sandbox-kh}"
mkdir -p "$KH_DIR"

INNER_OPTS=(
  -i "$RELAY_KEY"
  -o BatchMode=yes
  -o ConnectTimeout=60
  -o UserKnownHostsFile="$KH_DIR/relay.kh"
  -o StrictHostKeyChecking=accept-new
)
if [ -n "$JUMP_CMD" ]; then
  INNER_OPTS+=(-o "ProxyCommand=$JUMP_CMD")
fi

exec ssh -i "$KEY" \
  -o ProxyCommand="ssh ${INNER_OPTS[*]} $RELAY_USER@$RELAY_HOST -W 127.0.0.1:$TUNNEL_PORT" \
  -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile="$KH_DIR/target.kh" \
  -o ConnectTimeout=120 \
  "$TARGET_USER@127.0.0.1" "$@"
