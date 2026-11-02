#!/usr/bin/env bash
# connect.sh — sisi OPERATOR: buka shell SSH ke komputer/sandbox agen.
#
# Pemakaian:
#   TARGET_IP=100.x.x.x ./connect.sh                # shell interaktif
#   TARGET_IP=100.x.x.x ./connect.sh "hostname; df -h /"   # satu perintah
#
# Variabel lingkungan:
#   TARGET_IP     (wajib) alamat Tailscale sandbox, bentuk 100.x.x.x
#   TARGET_USER   user SSH di sandbox        (bawaan: ubuntu)
#   TARGET_PORT   port sshd                  (bawaan: 22)
#   KEY           berkas kunci privat khusus (bawaan: ~/.ssh/agent-access)
#   PROXY_HELPER  path ke ts-connect.py bila lingkunganmu mewajibkan proxy
#                 (bawaan: kosong = koneksi Tailscale langsung)
#
# Dua pelajaran dari kasus nyata yang sudah tertanam di skrip ini:
#   - ConnectTimeout panjang (280 dtk): permintaan pertama ke alamat baru
#     bisa tertahan menunggu persetujuan alamat dari pemilik jaringan.
#     Timeout pendek membuat koneksi yang sebenarnya sehat terlihat mati.
#   - Satu kali coba-ulang otomatis pada kegagalan koneksi pertama.
set -euo pipefail

TARGET_IP="${TARGET_IP:?isi TARGET_IP dengan alamat 100.x.x.x sandbox}"
TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_PORT="${TARGET_PORT:-22}"
KEY="${KEY:-$HOME/.ssh/agent-access}"
PROXY_HELPER="${PROXY_HELPER:-}"

SSH_OPTS=(
  -i "$KEY"
  -p "$TARGET_PORT"
  -o BatchMode=yes
  -o ConnectTimeout=280
  -o StrictHostKeyChecking=accept-new
)
if [ -n "$PROXY_HELPER" ]; then
  SSH_OPTS+=(-o "ProxyCommand=python3 $PROXY_HELPER %h %p")
fi

attempt() {
  if [ $# -gt 0 ]; then
    ssh "${SSH_OPTS[@]}" "$TARGET_USER@$TARGET_IP" "$*"
  else
    ssh "${SSH_OPTS[@]}" "$TARGET_USER@$TARGET_IP"
  fi
}

if ! attempt "$@"; then
  echo "percobaan pertama gagal; menunggu 5 detik lalu mencoba sekali lagi..." >&2
  sleep 5
  attempt "$@"
fi
