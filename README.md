# SSH ke Komputer Sandbox Agen AI

Panduan + skrip untuk memasang akses SSH dari mesinmu ke **komputer/sandbox
milik agen AI** — misalnya agen personal yang berjalan di platform seperti
Cue by Manus — padahal sandbox itu:

- tidak punya alamat IP publik (hanya alamat link-local),
- tidak bisa menerima koneksi masuk dari internet,
- login kata sandinya terkunci,

sehingga SSH langsung jelas mustahil. Solusinya: pertemukan kedua mesin di
**jaringan pribadi Tailscale** (WireGuard), lalu SSH seperti biasa di dalam
jaringan itu.

Ditulis dari kasus nyata yang terverifikasi ujung ke ujung pada 2 November
2026: sebuah agen personal di sandbox cloud (Ubuntu 24.04, 8 vCPU, RAM
23 GiB) yang awalnya hanya bisa dihubungi lewat email, dalam satu malam
berhasil dibuka akses SSH-nya — dan langsung dipakai untuk pekerjaan nyata
(memasang JDK + Android SDK lalu menjalankan build di mesin agen).

> English summary: [README.en.md](README.en.md)

## Route koneksinya

```
Mesin operator                                  Sandbox agen
──────────────                                  ────────────
ssh -i kunci-khusus ──┐
                      │   jaringan pribadi (tailnet)
                      ├──► pertemukan perangkat + tukar kunci publik
                      │   (server koordinasi Tailscale)
                      │
                      └──► tunnel WireGuard terenkripsi ═══════► sshd :22
                           (tanpa port publik terbuka)      authorized_keys
                                                            = kunci publikmu
Hasil: shell di komputer agen.                              │
```

Poin penting: isi koneksi berjalan **terenkripsi ujung ke ujung antar
perangkat** (WireGuard). Server koordinasi hanya mempertemukan perangkat;
ia tidak membaca isi lalu lintas.

## Syarat

- Akun Tailscale (tingkat gratis cukup) milik **kamu**, pemilik kedua mesin.
- Agen punya akses shell di sandbox-nya dan bisa memasang perangkat lunak
  (sudo tersedia), atau platformnya memang memberi akses itu.
- Di mesin operator: OpenSSH client + Python 3 (hanya untuk mode proxy).
- Satu pasangan kunci SSH **khusus** untuk hubungan ini (jangan pakai kunci
  harianmu):

  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/agent-access -C "operator-ke-sandbox-agen"
  ```

## Langkah pemasangan

### 1. Sisi sandbox (sekali, idempoten)

Salin repo ini ke dalam sandbox (atau unduh berkasnya), lalu jalankan oleh
agen/pengelola sandbox:

```bash
OPERATOR_PUBKEY="ssh-ed25519 AAAA... operator-ke-sandbox-agen" \
  bash scripts/target-setup.sh
```

Skrip memeriksa lingkungan, memasang Tailscale, memasang kunci publikmu ke
`authorized_keys` dengan izin yang benar, dan mengecek sshd.

### 2. Persetujuan pemilik (langkah manusia, tidak bisa diotomatiskan)

Di sandbox:

```bash
sudo tailscale up
```

Perintah menampilkan **tautan login**. Tautan itu hanya boleh dibuka oleh
pemilik akun Tailscale untuk menyetujui perangkat sandbox masuk ke jaringan
pribadinya. Bila agen yang menjalankan sandbox, ia mengirim tautan itu ke
pemilik lewat kanal resminya (email/aplikasi) — persis seperti pada templat
di `templates/email-ke-agen.md`.

Di mesin operator, daftarkan juga mesinmu ke tailnet yang sama
(`tailscale up`, setujui dengan akun yang sama).

### 3. Sisi operator: uji login

```bash
TARGET_IP=100.x.x.x bash scripts/connect.sh "echo LOGIN-OK; hostname; nproc; free -g | head -2"
```

`connect.sh` sudah membawa dua pelajaran penting: `ConnectTimeout` panjang
(permintaan pertama ke alamat baru bisa tertahan menunggu persetujuan
alamat) dan satu kali coba-ulang otomatis.

Bila lingkungan operator mewajibkan lalu lintas Tailscale keluar lewat
proxy HTTP (mis. VM terkelola), pakai helper ProxyCommand yang disertakan:

```bash
PROXY_HELPER=$PWD/scripts/ts-connect.py TARGET_IP=100.x.x.x bash scripts/connect.sh
```

### 4. Kirim berkas (cara cepat)

```bash
TARGET_IP=100.x.x.x bash scripts/send-files.sh ./folder-proyek /home/ubuntu/proyek
```

Satu arsip terkompresi + satu checksum SHA-256 yang diverifikasi di kedua
sisi. Lihat "Jebakan" nomor 5 untuk alasannya.

## Berkas di repo ini

| Berkas | Fungsi |
| --- | --- |
| `scripts/target-setup.sh` | Persiapan sisi sandbox: cek lingkungan, pasang Tailscale, pasang kunci publik, cek sshd |
| `scripts/connect.sh` | Sisi operator: login SSH dengan timeout panjang + coba-ulang sekali |
| `scripts/ts-connect.py` | Helper ProxyCommand untuk lingkungan yang wajib keluar lewat proxy HTTP |
| `scripts/send-files.sh` | Kirim folder sebagai satu arsip terverifikasi checksum |
| `templates/email-ke-agen.md` | Templat instruksi bertahap untuk agen yang hanya bisa dihubungi lewat email |

## Jebakan yang ditemukan di kasus nyata

1. **Timeout pendek menipu.** Koneksi pertama ke alamat tailnet baru dapat
   tertahan menunggu persetujuan pemilik; SSH dengan timeout 30–60 detik
   akan melaporkan gagal padahal jalurnya sehat. Pakai timeout panjang
   (kami memakai 280 detik) dan ulangi sekali.
2. **Ping bukan bukti apa-apa.** Pada beberapa jalur (proxy/relay), ICMP
   tidak diteruskan. Ping timeout tidak berarti perangkat mati; buktinya
   adalah login SSH yang berhasil.
3. **Sandbox tanpa IP publik itu normal.** Jangan buang waktu mencari port
   forwarding; justru itulah alasan memakai jaringan mesh seperti
   Tailscale — kedua sisi menyambung *keluar*, tidak ada yang membuka port
   ke internet.
4. **Kunci tidak terbaca karena path.** Kegagalan klasik: `~` ter-expand ke
   home pengguna lain di dalam string perintah bersarang (rsync -e, cron,
   systemd). Gunakan path absolut untuk berkas kunci pada perintah
   bersarang.
5. **Transfer per berkas bisa merangkak.** Banyak berkas kecil lewat jalur
   relay = latensi per berkas. Satu arsip `tar.gz` + verifikasi SHA-256
   terbukti jauh lebih cepat dan lebih aman daripada rsync per berkas
   (yang juga bisa belum terpasang di sandbox — jebakan tersendiri).
6. **Agen yang berhati-hati itu bagus.** Dalam kasus nyata, agen menolak
   memasang kunci publik sebelum ada persetujuan spesifik pemilik yang
   diteruskan secara eksplisit. Itu perilaku yang benar: rancang alurmu
   dengan tahap persetujuan, bukan sekali tembak.
7. **Persistensi harus ditanyakan, bukan ditebak.** Sandbox yang persisten
   antar tugas sangat berharga (hasil pemasangan tetap ada); sandbox yang
   dibuang tiap sesi membuat seluruh pemasangan ini sia-sia. Tanyakan ke
   platform/agenmu sejak awal.

## Keamanan

- Buat pasangan kunci **khusus** untuk hubungan ini; kunci privat tidak
  pernah meninggalkan mesin operator, dan tidak pernah dikirim lewat
  email/chat dalam bentuk apa pun.
- Yang berpindah tangan hanya: tautan login Tailscale (dibuka pemilik
  sendiri) dan satu baris kunci **publik**.
- `StrictHostKeyChecking=accept-new` pada skrip = TOFU (percaya pada
  kontak pertama). Untuk paranoia yang sehat, verifikasi sidik jari host
  lewat kanal lain sebelum login pertama.
- Cabut akses semudah memasangnya: hapus baris kunci dari
  `authorized_keys` di sandbox, atau keluarkan perangkatnya dari tailnet.

## Alternatif bila tidak mau bergantung pada Tailscale

- **Headscale**: server koordinasi open-source peniru Tailscale, jalankan
  di server milikmu sendiri; klien di semua perangkat tetap sama, hanya
  alamat server koordinasinya yang diganti. Ketergantungan pada perusahaan
  Tailscale hilang, pekerjaan pemasangannya bertambah.
- **Tunnel balik SSH murni**: sandbox menyambung keluar ke server publik
  milikmu (mis. VPS) dan membuka port balik; kamu masuk lewat server itu.
  Tanpa pihak ketiga sama sekali, tapi kamu mengelola sendiri kunci,
  keepalive, dan pengamanannya.

## Lisensi

MIT — lihat [LICENSE](LICENSE). Silakan pakai, ubah, dan bagikan.
