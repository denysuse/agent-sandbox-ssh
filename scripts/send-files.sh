#!/usr/bin/env bash
# send-files.sh — sisi OPERATOR: kirim satu folder ke sandbox sebagai SATU
# arsip, lalu ekstrak di sana.
#
# Kenapa bukan rsync/scp per berkas? Pelajaran kasus nyata: lewat jalur
# relay/proxy yang latensinya tinggi, transfer banyak berkas kecil bisa
# merangkak (dalam kasus asal skrip ini: ±1,6 MB setelah beberapa menit),
# sedangkan satu arsip terkompresi yang sama melesat dalam hitungan detik.
# Arsip tunggal juga mudah diverifikasi utuh dengan satu checksum.
#
# Pemakaian:
#   TARGET_IP=100.x.x.x ./send-files.sh <folder-lokal> <folder-tujuan-remote>
#
# Variabel: sama seperti connect.sh (TARGET_IP, TARGET_USER, TARGET_PORT,
# KEY, PROXY_HELPER) ditambah:
#   EXCLUDES   pola tar --exclude tambahan, pisahkan dengan spasi
#              (bawaan mengecualikan hasil build & cache umum)
set -euo pipefail

SRC="${1:?pemakaian: send-files.sh <folder-lokal> <folder-tujuan-remote>}"
DST="${2:?pemakaian: send-files.sh <folder-lokal> <folder-tujuan-remote>}"

TARGET_IP="${TARGET_IP:?isi TARGET_IP dengan alamat 100.x.x.x sandbox}"
TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_PORT="${TARGET_PORT:-22}"
KEY="${KEY:-$HOME/.ssh/agent-access}"
PROXY_HELPER="${PROXY_HELPER:-}"
EXCLUDES="${EXCLUDES:-}"

SSH_OPTS=(-i "$KEY" -o BatchMode=yes -o ConnectTimeout=280 -o StrictHostKeyChecking=accept-new)
if [ -n "$PROXY_HELPER" ]; then
  SSH_OPTS+=(-o "ProxyCommand=python3 $PROXY_HELPER %h %p")
fi
REMOTE="$TARGET_USER@$TARGET_IP"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ARCHIVE="$TMP/paket.tar.gz"

EXARGS=(--exclude '.git' --exclude 'build' --exclude '.gradle' --exclude 'node_modules' --exclude '__pycache__')
for p in $EXCLUDES; do EXARGS+=(--exclude "$p"); done

echo "mengemas $SRC ..."
tar czf "$ARCHIVE" "${EXARGS[@]}" -C "$SRC" .
LOCAL_SUM="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
echo "arsip: $(du -h "$ARCHIVE" | cut -f1), sha256 ${LOCAL_SUM:0:16}..."

echo "mengirim satu berkas ..."
scp "${SSH_OPTS[@]}" -P "$TARGET_PORT" "$ARCHIVE" "$REMOTE:/tmp/paket-masuk.tar.gz"

echo "memverifikasi + mengekstrak di sandbox ..."
ssh "${SSH_OPTS[@]}" "$REMOTE" "
  set -e
  REMOTE_SUM=\$(sha256sum /tmp/paket-masuk.tar.gz | awk '{print \$1}')
  if [ \"\$REMOTE_SUM\" != \"$LOCAL_SUM\" ]; then
    echo 'CHECKSUM TIDAK SAMA — transfer rusak, berhenti' >&2; exit 1
  fi
  echo 'checksum sama, arsip utuh'
  mkdir -p '$DST'
  tar xzf /tmp/paket-masuk.tar.gz -C '$DST'
  rm -f /tmp/paket-masuk.tar.gz
  du -sh '$DST'
"
echo "SELESAI: $SRC -> $REMOTE:$DST"
