Tentu, ini adalah draft **README.md** yang profesional, terstruktur, dan menggunakan ikon agar menarik. Dokumen ini dirancang untuk memberikan kesan "Enterprise Grade" sesuai dengan kualitas skrip v4.5 yang telah kita bangun.

Saya memilih **Lisensi MIT** karena ini adalah standar industri yang aman, sederhana, dan cocok untuk proyek skrip manajemen seperti ini (memperbolehkan penggunaan pribadi maupun komersial, tapi membebaskan Anda dari tuntutan hukum/garansi).

Silakan copy kode di bawah ini dan buat file bernama `README.md` di repository GitHub Anda.

---

```markdown
# 🚀 KasirLite Remote v4.5 (Enterprise Edition)

![Version](https://img.shields.io/badge/version-v4.5-blue?style=flat-square)
![Stability](https://img.shields.io/badge/stability-stable-success?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-orange?style=flat-square)

**KasirLite Remote** adalah sistem manajemen armada (*Fleet Management*) berbasis Termux untuk perangkat POS (Point of Sales) Android. Sistem ini memungkinkan pemilik bisnis untuk memantau, mengamankan, dan mengelola ratusan cabang toko secara terpusat melalui **Telegram Bot**, tanpa memerlukan server VPS dedicated.

---

## ✨ Fitur Unggulan

| Fitur | Deskripsi |
| :--- | :--- |
| ☁️ **Cloudflare Tunnel** | Akses web kasir lokal (localhost) dari internet secara aman (HTTPS). |
| 🛡️ **Secure Admin ACL** | Kontrol akses berbasis ID Telegram. Hanya Admin terdaftar yang bisa mengeksekusi perintah kritis. |
| 📦 **Auto & Remote Backup** | Backup database SQLite otomatis setiap 6 jam atau *on-demand* via chat, dikirim via ZIP. |
| ⚙️ **Safe Shell (`/cek`)** | Eksekusi perintah terminal untuk monitoring (RAM, IP, Storage) dengan proteksi *Command Injection*. |
| 🔄 **Tunnel Rotation** | Ganti Token Cloudflare/Domain dari jarak jauh dengan fitur *Auto-Rollback* jika gagal koneksi. |
| 📡 **Smart Polling** | Logika antrian pesan (*Queue Processing*) untuk mencegah *Race Condition* pada koneksi lambat. |

---

## 🛠️ Prasyarat Sistem

Sebelum menginstal, pastikan tablet/HP Android cabang telah terinstal:
1.  **Termux** (Disarankan versi F-Droid).
2.  **Termux:API** (Wajib untuk fitur notifikasi & status baterai).
3.  **Aplikasi Kasir** (Web-based) berjalan di port `7575`.

---

## 📥 Instalasi Baru (Deploy)

Gunakan perintah satu baris ini pada terminal Termux di tablet cabang baru. Tidak perlu konfigurasi manual, sistem akan meminta **Kode Pairing**.

```bash
pkg update -y && pkg install -y curl && curl -sL [https://raw.githubusercontent.com/tanilink/toko/main/setup.sh](https://raw.githubusercontent.com/tanilink/toko/main/setup.sh) | bash

```

**Langkah Deploy:**

1. Jalankan perintah di atas.
2. Sistem akan memberikan **Kode Unik** (misal: `A1B2`).
3. Admin membalas di Bot Telegram: `/deploy A1B2 [TOKEN_CLOUDFLARE] [NAMA_TOKO]`.
4. Sistem otomatis terkonfigurasi dan menyimpan ID Admin sebagai *Super User*.

---

## 🤖 Perintah Bot Telegram

Berikut adalah daftar perintah yang tersedia di Menu Bot:

### 🟢 Perintah Umum (Bisa Semua User)

* `/status` - Cek koneksi Tunnel, Status Bot, dan Kesehatan Sistem.
* `/backup` - Meminta file backup database (.zip) saat ini juga.
* `/msg [pesan]` - Mengirim notifikasi teks (*Toast/Notification*) ke layar tablet operator.

### 🔴 Perintah Admin (Hanya Owner)

* `/cek [perintah]` - Menjalankan diagnosa terminal (Contoh: `/cek free -h` atau `/cek ls -lh`).
* *Note: Perintah berbahaya seperti `rm`, `mv`, `reboot` diblokir otomatis.*


* `/set_tunnel [token]` - Mengganti Token Cloudflare.
* *Fitur: Jika token baru gagal connect dalam 15 detik, sistem otomatis kembali ke token lama.*


* `/update` - Memperbarui skrip sistem ke versi terbaru dari GitHub.
* `/restart` - Me-restart service bot dan tunnel dari jarak jauh.

---

## 🔄 Cara Update Manual

Jika fitur auto-update via bot bermasalah, atau Anda ingin memaksa pembaruan patch keamanan terbaru (v4.5+) secara manual lewat terminal, jalankan perintah ini:

```bash
curl -sL [https://raw.githubusercontent.com/tanilink/toko/main/setup.sh](https://raw.githubusercontent.com/tanilink/toko/main/setup.sh) > temp_v45.sh && bash temp_v45.sh mode_update

```

---

## 📂 Struktur File

Sistem akan membuat folder tersembunyi di home directory:

```text
~/.kasirlite/
├── config.conf      # Menyimpan Token, Chat ID, & Admin ID
├── manager.sh       # Skrip kontrol lokal (Menu TUI)
└── service_bot.sh   # Logic utama Bot (Daemon)

```

---

## 📄 Lisensi

Sistem ini didistribusikan di bawah lisensi **MIT License**.

> **Copyright (c) 2026 KasirLite Dev**
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.

---

<p align="center">
Built with ❤️ for Stability & Security
</p>

```

```
