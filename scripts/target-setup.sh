#!/usr/bin/env bash
# target-setup.sh — persiapan sisi TARGET (komputer/sandbox milik agen).
#
# Jalankan skrip ini DI DALAM sandbox agen (oleh agen itu sendiri, atau oleh
# manusia yang punya akses konsol ke sandbox), sebagai user yang akan dipakai
# untuk login SSH.
#
# Yang dikerjakan:
#   1. Melaporkan kondisi lingkungan (OS, sshd, sudo) — hanya membaca.
#   2. Memasang Tailscale bila belum ada (skrip resmi Tailscale).
#   3. Memasang kunci PUBLIK operator ke ~/.ssh/authorized_keys (idempoten).
#   4. Memastikan sshd mendengarkan di port 22.
#
# Yang TIDAK dikerjakan skrip ini:
#   - Menjalankan `tailscale up` sampai selesai. Perintah itu menampilkan
#     TAUTAN LOGIN yang harus dibuka dan disetujui oleh PEMILIK akun
#     Tailscale secara pribadi. Skrip mencetak perintahnya di akhir.
#   - Mengirim apa pun ke mana pun.
#
# Pemakaian:
#   OPERATOR_PUBKEY="ssh-ed25519 AAAA... nama-kunci" ./target-setup.sh
#   atau: ./target-setup.sh "ssh-ed25519 AAAA... nama-kunci"
set -euo pipefail

PUBKEY="${1:-${OPERATOR_PUBKEY:-}}"
if [ -z "$PUBKEY" ]; then
  echo "ERROR: kunci publik operator belum diberikan." >&2
  echo "Isi env OPERATOR_PUBKEY atau berikan sebagai argumen pertama." >&2
  exit 1
fi
case "$PUBKEY" in
  ssh-ed25519\ *|ssh-rsa\ *|ecdsa-*) ;;
  *) echo "ERROR: format kunci publik tidak dikenal: ${PUBKEY%% *}" >&2; exit 1 ;;
esac

echo "=== 1. Laporan lingkungan ==="
echo "user        : $(whoami)"
echo "hostname    : $(hostname)"
uname -a | sed 's/^/sistem      : /'
if command -v lsb_release >/dev/null 2>&1; then lsb_release -d | sed 's/^/distro      : /'; fi
if sudo -n true 2>/dev/null; then echo "sudo        : tanpa kata sandi (tersedia)"; else echo "sudo        : perlu kata sandi / tidak tersedia"; fi
if command -v sshd >/dev/null 2>&1 || [ -x /usr/sbin/sshd ]; then echo "sshd        : terpasang"; else echo "sshd        : TIDAK terpasang (pasang openssh-server dulu)"; fi

echo
echo "=== 2. Tailscale ==="
if command -v tailscale >/dev/null 2>&1; then
  echo "sudah terpasang: $(tailscale version | head -1)"
else
  echo "memasang Tailscale dengan skrip resmi (butuh sudo)..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

echo
echo "=== 3. Pasang kunci publik operator ==="
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
KEYID="$(echo "$PUBKEY" | awk '{print $2}')"
if grep -qF "$KEYID" ~/.ssh/authorized_keys; then
  echo "kunci sudah terpasang sebelumnya, dilewati"
else
  echo "$PUBKEY" >> ~/.ssh/authorized_keys
  echo "kunci terpasang untuk user $(whoami)"
fi

echo
echo "=== 4. Cek sshd di port 22 ==="
if ss -tlnp 2>/dev/null | grep -q ':22 '; then
  echo "sshd mendengarkan di port 22"
else
  echo "port 22 belum terlihat; mencoba menyalakan layanan ssh..."
  sudo -n systemctl start ssh 2>/dev/null || sudo -n systemctl start sshd 2>/dev/null || \
    echo "tidak bisa menyalakan otomatis; nyalakan sshd secara manual lalu ulangi cek"
fi

cat <<'EOF'

=== SELESAI — langkah manusia terakhir ===
1. Jalankan:  sudo tailscale up
2. Perintah itu menampilkan TAUTAN LOGIN. Kirim tautan itu ke PEMILIK akun
   Tailscale (jangan ke siapa pun lain) untuk dibuka dan disetujui.
3. Setelah disetujui, jalankan:  tailscale status
   dan laporkan hostname + alamat 100.x.x.x sandbox ini ke operator.
4. Operator kemudian menguji login SSH memakai kunci privat pasangannya.
EOF
