# Load Balancer dan Replicated App — Sistem Tiga Container dengan Nginx, Flask, dan Redis

**Mata kuliah:** Sistem Paralel dan Terdistribusi (MKKL1030) · Semester 7
**Program Studi Ilmu Komputer — Fakultas Sains, Teknologi dan Ilmu Kesehatan**
**Universitas Bina Bangsa Getsempena**
**Dosen Pengampu:** Ahmad Mujahid Abdurrahman, S.Kom, M.T.

Purwarupa sistem terdistribusi berisi empat container Docker: Nginx sebagai load balancer, dua app server Flask yang identik, dan Redis sebagai penyimpanan status bersama. Klien hanya mengenal satu alamat, sementara Nginx membagi permintaan ke kedua app server dan memeriksa kesehatannya secara berkala. Sistem ini diuji dengan mematikan salah satu app server saat permintaan sedang berjalan, memberi beban tinggi, dan memulai ulang penyimpanan bersama, untuk membuktikan toleransi kegagalan serta konsistensi data.

## Anggota Kelompok

| No | Nama | NIM | Peran |
|---|---|---|---|
| 1 | Yogi Prasetya Sadewa | 23210060 | Ketua kelompok; berkas Docker Compose, konfigurasi Nginx, dan skenario pengujian kegagalan |
| 2 | Asmarudin | 23210133 | Aplikasi Flask dan titik akhir pemeriksaan kesehatan |
| 3 | Deski Taiza | 23210003 | Konfigurasi Redis sebagai penyimpanan status bersama dan pengujian ketahanan data |
| 4 | Akhsanul Taqwim | 23210006 | Penyiapan lingkungan Docker dan pembuatan berkas image |
| 5 | Wira | 23210045 | Pengujian beban dan pencatatan hasil pengalihan trafik |
| 6 | Abadi | 23210004 | Penyusunan skrip pengujian kegagalan yang dapat dijalankan ulang |
| 7 | Ferdyan Ardhani | 23210039 | Pencatatan dan pengolahan hasil pengujian beban menjadi tabel laporan |
| 8 | Muhammad Iqbal | 23210142 | Pemeriksaan keamanan dasar: pemisahan jaringan container dan penanganan kredensial |
| 9 | Meriandi Wahyu Kurniawan | [NIM] | Dokumentasi, README, dan pengelolaan repository |

> Kelompok berjumlah 9 orang; panduan menetapkan 4–5 orang sehingga jumlah ini
> dimintakan persetujuan dosen pada pertemuan ke-2. Setiap anggota melakukan
> commit dari akun masing-masing.

## Rencana Proyek

- Google Docs (dibagikan kepada dosen dengan akses komentar) — tautan: [MKKL1030 — Load Balancer dan Replicated App](https://docs.google.com/document/d/11KX6rlOrZWmQWi_vplcNos2axfwvxbLx_SRCl610EkU/edit)
- Salinan di repository: [`docs/rencana-proyek.md`](docs/rencana-proyek.md)

## Cara Menjalankan

### Kebutuhan

- Docker dan Docker Compose
- Perkakas uji beban (opsional): hey atau ApacheBench

### 1. Menjalankan seluruh sistem

```bash
docker compose up --build -d
docker compose ps
```

### 2. Menguji layanan melalui load balancer

```bash
# Perhatikan field "server" pada respons: bergantian antara app1 dan app2
curl -s http://localhost:8080/ | jq
# Header pembukti node mana yang melayani:
curl -s -D- -o /dev/null http://localhost:8080/ | grep -i x-served-by
```

> Port 8080 dipakai pada *host* karena port 80 sering sudah ditempati layanan
> lain. Di dalam jaringan Docker, Nginx tetap mendengarkan port 80.

### 3. Menguji kegagalan satu app server

```bash
docker compose stop app1
curl -s http://localhost:8080/ | jq   # harus tetap dijawab app2
docker compose start app1
```

### 4. Menguji beban dan ketahanan status

```bash
hey -n 1000 -c 50 http://localhost:8080/
docker compose restart redis
curl -s http://localhost:8080/state | jq
```

### 5. Seluruh skenario uji kegagalan sekaligus

```bash
bash src/tests/uji_kegagalan.sh
```

Hasil setiap skenario beserta penjelasannya ada di
[`docs/hasil-uji-kegagalan.md`](docs/hasil-uji-kegagalan.md).

## Struktur Repository

```
mkkl1030-loadbalancer-redis/
├── README.md
├── docker-compose.yml
├── docs/
│   ├── rencana-proyek.md
│   ├── arsitektur.md
│   ├── hasil-uji-kegagalan.md
│   ├── diagrams/
│   └── MKKL1030-Load-Balancer-Replicated-App.docx
├── src/
│   ├── app/             # aplikasi Flask (dipakai kedua container)
│   │   ├── app.py
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   └── tests/           # skrip pengujian beban dan kegagalan
└── nginx/
    └── nginx.conf       # pengaturan upstream + health check
```

## Dokumentasi

| Berkas | Isi |
|---|---|
| `docs/rencana-proyek.md` | Rencana proyek, target UTS dan UAS, pembagian kerja per minggu, risiko |
| `docs/arsitektur.md` | Penjelasan komponen, alur permintaan, dan keputusan teknis |
| `docs/hasil-uji-kegagalan.md` | Catatan hasil setiap skenario pengujian kegagalan |
| `docs/diagrams/` | Diagram arsitektur dan alur permintaan |

## Pemenuhan Ketentuan Mata Kuliah

- **Minimal dua proses terpisah**: empat container yang saling berkomunikasi melalui jaringan Docker.
- **Mekanisme komunikasi**: HTTP antar-container dan protokol Redis untuk penyimpanan status bersama.
- **Isu terdistribusi yang ditangani**: penyeimbangan beban, replikasi dan konsistensi status, serta toleransi kegagalan.
- **Skenario uji kegagalan**: mematikan app server saat beban berjalan dan memulai ulang penyimpanan bersama.

## Aturan Kerja Kelompok

- Commit dilakukan dari akun GitHub masing-masing anggota, bukan satu akun untuk seluruh kelompok.
- Pesan commit deskriptif dan menunjukkan kemajuan; dikerjakan minimal sekali per minggu per anggota.
- Pekerjaan bersama menggunakan branch dan pull request; pembagian tugas dicatat pada Issues.
- Kredensial, token, dan berkas `.env` tidak boleh masuk repository.

## Status

| Tahap | Target | Status |
|---|---|---|
| Pertemuan 2 | Rencana proyek, repository, undangan kolaborator | Selesai |
| Pertemuan 8 (UTS) | Seluruh container berjalan dan klien mengakses layanan melalui load balancer | Selesai |
| Pertemuan 16 (UAS) | Sistem berjalan penuh dan dapat dijalankan ulang dari satu berkas Compose | Sebagian |

Pertemuan 8 sudah terpenuhi dan **terukur**: enam skenario pada
[`docs/hasil-uji-kegagalan.md`](docs/hasil-uji-kegagalan.md) dijalankan pada
perangkat sungguhan (Docker Desktop, empat container), dengan bukti berupa
angka — bukan pembacaan konfigurasi.

Untuk UAS yang masih perlu ditambahkan: pengujian **antar-mesin** (container
dipecah ke dua host agar latensi dan throughput mewakili jaringan sungguhan),
serta pencatatan waktu peralihan saat satu node dimatikan.
