# Panduan Praktis: Memanfaatkan Mesin Sandbox Agen AI Secara Gratis

Resep lengkap menjalankan komputer sandbox milik agen AI (agen personal
yang berjalan di platform cloud) seperti komputer pribadi: masuk lewat
SSH, memasang LLM lokal, sampai memakai mesinnya untuk build beneran —
semuanya di tingkat gratis.

Ditulis dari kasus nyata yang terverifikasi ujung ke ujung: sebuah agen
yang awalnya hanya bisa dihubungi lewat email, dalam satu malam terbuka
akses SSH ke sandbox-nya (Ubuntu, 8 vCPU, RAM 23 GiB), lalu mesin itu
dipakai memasang LLM lokal 14B dan menjalankan build Android.

> English summary: see [../README.en.md](../README.en.md). Skrip siap
> pakai ada di folder [`../scripts/`](../scripts/).

## Inti resepnya

Mesinnya sudah ada dan bukan itu masalahnya. Dua masalah sebenarnya:

1. **Tidak ada jalur masuk.** Sandbox agen biasanya tidak punya IP
   publik (hanya alamat link-local), tidak menerima koneksi masuk, dan
   login kata sandinya terkunci. SSH langsung jelas mustahil.
2. **Mesinnya tidur.** Akses mesin 24/7 adalah fitur berbayar di
   kebanyakan platform. Di tingkat gratis, mesin berhenti/tidur saat
   tidak dipakai — dan itu wajar, bukan kerusakan.

Solusinya juga dua: buat **jalur masuk** (jaringan mesh atau tunnel
balik ke server milikmu), dan terima **pola bangunkan dulu** sebagai
cara kerja normal. Sisanya detail.

## Bahan

- Satu agen AI dengan sandbox yang **persisten** (berkas tetap ada antar
  sesi selama mesin berjalan). Tanyakan ini ke platform/agenmu sejak
  awal — sandbox sekali pakai membuat resep ini sia-sia.
- OpenSSH client di mesin operator; OpenSSH server di sandbox (umumnya
  sudah ada).
- Satu pasangan kunci SSH **khusus** untuk hubungan ini:

  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/agent-access -C "operator-ke-sandbox-agen"
  ```

- Satu jalur masuk, pilih salah satu (atau dua-duanya):
  - **Jalur mesh** (mis. Tailscale, tingkat gratis cukup), atau
  - **Server relay milikmu** (VPS murah apa pun) untuk tunnel balik.
- Persetujuan eksplisit pemilik untuk memasang kunci publik di sandbox.
  Agen yang berhati-hati akan menolak sebelum persetujuan itu ada — itu
  perilaku yang benar, rancang alurmu dengan tahap ini.
- Opsional: [Ollama](https://ollama.com) bila mau LLM lokal di sandbox.

## Langkah 1 — Siapkan sisi sandbox (sekali)

Jalankan oleh agen/pengelola sandbox (skrip: `scripts/target-setup.sh`):

- pastikan sshd benar-benar mendengarkan (di banyak sistem ia aktif
  lewat socket systemd),
- pasang kunci **publik** operator ke `~/.ssh/authorized_keys` user
  target, dengan izin berkas yang benar,
- laporkan hostname dan status persistensi sandbox.

Yang berpindah tangan hanya kunci publik. Kunci privat tidak pernah
meninggalkan mesin operator, tidak pernah lewat email/chat.

## Langkah 2 — Pilih jalur masuk

### Jalur A: jaringan mesh (cepat dipasang)

Kedua mesin masuk jaringan pribadi yang sama; SSH berjalan di dalam
jaringan itu, terenkripsi ujung ke ujung, tanpa port publik terbuka.

- Pemilik membuka tautan login dan menyetujui perangkat sandbox masuk
  jaringannya — langkah manusia, tidak bisa diotomatiskan.
- Koneksi pertama ke alamat baru bisa tertahan menunggu persetujuan
  alamat: pakai `ConnectTimeout` panjang (kami memakai 280 detik) dan
  ulangi sekali sebelum menyimpulkan gagal.
- Kelemahan terbukti: jalur ini bisa gagal total di lapisan proxy/relay
  pihak ketiga (percobaan ditutup sebelum mencapai sshd, tanpa satu pun
  entri di log target, padahal kedua node "online"). Segmen itu bukan
  milikmu dan tidak bisa kamu perbaiki.

### Jalur B: tunnel balik SSH (yang disarankan sebagai DEFAULT)

Sandbox menyambung **keluar** ke server relay milikmu dan membuka port
balik; kamu masuk lewat server itu.

- Di relay: akun khusus yang dibatasi
  `restrict,port-forwarding,permitlisten="127.0.0.1:2222"` — tidak bisa
  shell, hanya boleh membuka tunnel itu.
- Port balik hanya mengikat `127.0.0.1` di relay; tidak terekspos
  internet.
- Di sandbox: service systemd user menjalankan `ssh -N -R` dengan
  keepalive, `Restart=always`, dan linger aktif, supaya tunnel
  menyambung ulang sendiri setelah putus.
- Login dari operator memakai `scripts/connect-tunnel.sh` (perintah
  bersarang yang sudah teruji — jangan rakit ulang dari ingatan).

Dua jebakan perintah bersarang yang sudah terbukti:

1. Token `%h`/`%p` milik lompatan dalam wajib ditulis `%%h:%%p`. ssh
   terluar meng-expand token di seluruh string ProxyCommand; tanpa
   penggandaan, lompatan mendarat di mesin yang salah dan autentikasi
   gagal "publickey denied" padahal semua kunci benar.
2. known_hosts untuk rantai ini simpan di berkas khusus yang persisten.
   known_hosts bawaan di lokasi yang hilang saat lingkungan berganti
   akan membuatmu mengulang TOFU dan mengira ada serangan/kerusakan.

## Langkah 3 — Pola bangunkan dulu (konsekuensi tingkat gratis)

Karena mesin gratis tidur, urutan baku setiap sesi kerja:

1. **Bangunkan sandbox** dari aplikasi platform (pemilik yang melakukan).
2. **Tunggu service siap**: tunnel tersambung (port balik listen di
   relay) atau daemon mesh berstatus Running dan sshd listen.
3. **Baru mulai koneksi** dari operator.
4. **Verifikasi**: perintah uji sederhana harus mengembalikan hostname
   sandbox yang benar.

Percobaan koneksi **sebelum** mesin bangun akan gagal dengan gejala yang
menyesatkan (timeout, connection refused, port tidak listen) dan **bukan**
bukti jalurmu rusak. Diagnosis 30 detik yang membedakan sebabnya ada di
`scripts/health-check.sh`: cek port balik, coba login, probe jalur mesh.

Kapan pola ini cukup dan kapan harus bayar? Untuk eksperimen, riset,
dan kerja berbasis sesi, pola gratis ini cukup dan terbukti. Bayar
hanya masuk akal bila mesin itu harus menjalankan pekerjaan terjadwal
yang tidak bisa menunggu dibangunkan.

## Langkah 4 — Pakai mesinnya

Begitu shell didapat, sandbox adalah komputer Linux biasa:

- **LLM lokal:** pasang Ollama, tarik model yang muat nyaman di RAM
  (di mesin 23 GiB dengan ±14 GiB bebas, model 14B kuantisasi Q4_K_M
  ±9,3 GB berjalan baik). Akses API-nya hanya dari jaringan pribadi atau
  lewat terusan port SSH — **jangan pernah** mengekspos port LLM ke
  internet publik.
- **Mesin build:** JDK + SDK bisa dipasang dan build sungguhan berjalan
  di sana (kasus nyata: build release aplikasi Android ±5,5 menit untuk
  build dingin pertama). Mesin agen yang 8 vCPU bisa lebih kencang dari
  mesin operator yang 4 vCPU.
- **Kirim berkas:** satu arsip `tar.gz` + verifikasi SHA-256 di kedua
  sisi (`scripts/send-files.sh`), bukan rsync per berkas yang merangkak
  di jalur relay.

## Keamanan

- Kunci khusus per hubungan; kunci privat tidak pernah berpindah.
- Yang dibagikan hanya: tautan login mesh (dibuka pemilik sendiri) dan
  satu baris kunci publik.
- Akun tunnel di relay dibatasi forwarding-only; port balik hanya
  localhost.
- Cabut akses semudah memasangnya: hapus baris kunci dari
  `authorized_keys` di sandbox, atau keluarkan perangkat dari jaringan
  mesh.
- `StrictHostKeyChecking=accept-new` berarti TOFU; untuk kehati-hatian
  ekstra, verifikasi sidik jari host lewat kanal lain sebelum login
  pertama.

## Troubleshooting

| Gejala | Sebab paling mungkin | Cek pertama |
| --- | --- | --- |
| Port balik tidak listen di relay | Sandbox mati, atau service tunnel mati | Mesin sudah dibangunkan? `systemctl --user status` service tunnel di sandbox |
| Koneksi ditutup sebelum banner SSH terbaca (jalur mesh) | Lapisan proxy/relay mesh bermasalah, bukan target | Log sshd di target: bila nol entri, percobaan memang tidak pernah sampai |
| `publickey denied` pada perintah bersarang | Token `%h:%p` ter-expand lompatan luar | Tulis token dalam sebagai `%%h:%%p`; pakai skrip helper |
| Host key verification failed berulang | known_hosts tersimpan di lokasi tidak persisten | Pindah ke berkas known_hosts khusus yang persisten |
| Hostname sandbox berubah antar sesi | Sandbox tidak persisten / dibuat ulang | Ulangi langkah 1; tanyakan persistensi ke platform |
| Ping ke mesin timeout tapi SSH bisa | ICMP tidak diteruskan jalur proxy/relay | Abaikan ping; bukti satu-satunya adalah login SSH |

## Penutup

Resep ini sengaja tidak bergantung pada satu vendor: jalur mesh bisa
diganti Headscale (server koordinasi open-source yang kamu jalankan
sendiri), dan tunnel balik murni OpenSSH. Yang tidak bisa diganti
adalah disiplinnya: persetujuan pemilik yang eksplisit, kunci khusus,
dan perintah yang sudah terbukti disimpan sebagai skrip, bukan dirakit
ulang dari ingatan.
