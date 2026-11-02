# Templat email instruksi ke agen

Bila agenmu hanya bisa dihubungi lewat email (pola umum pada platform agen
personal), kirim email seperti di bawah ini. Ganti semua teks dalam
{{kurung ganda}}. Urutannya sengaja dibuat bertahap: agen memeriksa dulu,
melapor, dan hanya memasang kunci setelah persetujuan spesifik pemilik —
jangan pernah melompat langsung ke pemasangan.

---

**Subjek:** Tugas teknis: siapkan akses SSH ke sandbox-mu (bertahap, laporkan tiap tahap)

Halo {{NAMA_AGEN}}, ini {{NAMA_OPERATOR}}.

Saya ingin membuka akses SSH dari mesin saya ke komputer/sandbox tempat
kamu berjalan, supaya pekerjaan berat bisa dijalankan langsung di mesinmu.
Kerjakan bertahap dan laporkan hasil tiap tahap lewat balasan email ini.
Jangan mengubah konfigurasi apa pun pada Tahap 1.

**Tahap 1 — Periksa saja (jangan mengubah apa pun):**
1. Apakah kamu punya akses shell/terminal di sebuah komputer/sandbox?
   Sistem operasinya apa, berapa CPU/RAM/disk-nya?
2. Apakah OpenSSH (sshd) terpasang dan mendengarkan di port 22?
3. Apakah komputer itu punya alamat IP publik, atau hanya alamat lokal?
4. Apakah lingkunganmu persisten antar sesi/tugas?

**Tahap 2 — Pasang Tailscale (setelah saya menyetujui hasil Tahap 1):**
1. Pasang Tailscale resmi untuk sistem operasimu. Bila butuh sudo dan sudo
   tidak tersedia, berhenti dan laporkan persis batasannya.
2. Jalankan `tailscale up`. Perintah itu menampilkan TAUTAN LOGIN.
   Kirim tautan itu apa adanya lewat balasan email ini — tautan hanya untuk
   dibuka oleh saya dengan akun Tailscale milik saya. Jangan menyetujui
   perangkat apa pun ke akun orang lain.
3. Setelah saya menyetujui, laporkan hasil `tailscale status`: hostname
   dan alamat 100.x.x.x milikmu.

**Tahap 3 — Pasang kunci publik saya (setelah persetujuan spesifik saya):**
Saya akan mengirim satu baris kunci publik dalam email terpisah, disertai
persetujuan eksplisit. Pasang baris itu persis seperti tertulis ke
`~/.ssh/authorized_keys` user milikmu (folder `~/.ssh` izin 700, berkas
izin 600), lalu konfirmasi lewat email.

Catatan: kunci privat pasangan kunci itu hanya ada di mesin saya dan tidak
akan pernah saya kirim. Kamu juga jangan pernah mengirim kunci privat apa
pun milikmu ke siapa pun.

Terima kasih.

— {{NAMA_OPERATOR}}
