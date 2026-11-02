#!/usr/bin/env python3
"""ts-connect.py — ProxyCommand helper untuk lingkungan yang mewajibkan
lalu lintas Tailscale keluar lewat HTTP proxy (CONNECT).

Sebagian lingkungan kerja agen (mis. VM terkelola) tidak menyentuh jaringan
Tailscale secara langsung; koneksi ke alamat 100.x.x.x harus dibuka lewat
proxy HTTP yang disediakan runtime. Helper ini membaca HTTPS_PROXY dari
lingkungan, membuka tunnel CONNECT ke host:port tujuan, lalu meneruskan
stdin/stdout — persis yang dibutuhkan opsi ProxyCommand pada ssh.

Pemakaian (di connect.sh atau langsung di ~/.ssh/config):

    ProxyCommand python3 /path/ke/ts-connect.py %h %p

Variabel lingkungan:
    HTTPS_PROXY / https_proxy  alamat proxy (wajib)
    TS_PROXY_PORT              port proxy khusus Tailscale
                               (bawaan: 3130, konvensi runtime tempat
                               helper ini lahir; timpa sesuai lingkunganmu)

Catatan: permintaan pertama ke sebuah alamat tujuan bisa tertahan lama
menunggu persetujuan alamat dari pemilik jaringan. Pakai ConnectTimeout
yang panjang pada ssh (lihat connect.sh) dan ulangi sekali bila timeout.
"""
import base64
import os
import select
import socket
import sys
from urllib.parse import urlparse


def main():
    host, port = sys.argv[1], int(sys.argv[2])
    proxy = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy")
    if not proxy:
        sys.exit("HTTPS_PROXY tidak terpasang di lingkungan")
    u = urlparse(proxy)
    proxy_host = u.hostname
    proxy_port = int(os.environ.get("TS_PROXY_PORT", "3130"))
    auth = None
    if u.username:
        raw = f"{u.username}:{u.password or ''}".encode()
        auth = base64.b64encode(raw).decode()

    s = socket.create_connection((proxy_host, proxy_port), timeout=300)
    lines = [f"CONNECT {host}:{port} HTTP/1.1", f"Host: {host}:{port}"]
    if auth:
        lines.append(f"Proxy-Authorization: Basic {auth}")
    s.sendall(("\r\n".join(lines) + "\r\n\r\n").encode())

    buf = b""
    while b"\r\n\r\n" not in buf:
        chunk = s.recv(4096)
        if not chunk:
            sys.exit("proxy menutup koneksi sebelum menjawab CONNECT")
        buf += chunk
    head, _, rest = buf.partition(b"\r\n\r\n")
    status = head.split(b"\r\n", 1)[0].decode(errors="replace")
    if " 200 " not in f" {status} " and not status.rstrip().endswith("200"):
        sys.exit(f"CONNECT gagal: {status}")

    stdin = sys.stdin.buffer
    stdout = sys.stdout.buffer
    if rest:
        stdout.write(rest)
        stdout.flush()
    s.setblocking(False)
    fds = [s, stdin]
    while True:
        r, _, _ = select.select(fds, [], [])
        if s in r:
            try:
                data = s.recv(65536)
            except BlockingIOError:
                data = b""
            if not data:
                break
            stdout.write(data)
            stdout.flush()
        if stdin in r:
            data = os.read(0, 65536)
            if not data:
                try:
                    s.shutdown(socket.SHUT_WR)
                except OSError:
                    pass
                fds.remove(stdin)
            else:
                s.sendall(data)


if __name__ == "__main__":
    main()
