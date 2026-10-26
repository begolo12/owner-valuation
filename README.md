# Penilaian Owner

Aplikasi pribadi untuk menilai owner/proyek baru per kuartal, dengan dua model penilaian:
**Market Baru** dan **Market Existing**.

- Flutter (Android APK + web) di `app/`
- Backend Node.js serverless di `api/` (Vercel Functions)
- Database Postgres (Neon, region Singapore) — skema di `db/schema.sql`

## Model penilaian

| Kriteria  | Market Baru | Market Existing |
|-----------|-------------|-----------------|
| Holding   | 25%         | 35%             |
| Bayar     | 25%         | 30%             |
| Tenor     | 15%         | 20%             |
| Proyeksi  | 35%         | 15%             |

Total 0–100 → grade A (≥85), B (≥70), C (≥55), D (≥40), E (<40).

Satu owner punya satu nilai per **kuartal** per **model**. Menyimpan kuartal yang sama
akan menimpa nilai sebelumnya (`unique(owner_id, quarter, model)`), sehingga riwayat
kuartalan tetap rapi dan penilaian "saat ini" selalu kuartal berjalan.

## Alur pakai

1. Buka aplikasi → masukkan **token aplikasi** sekali per perangkat (token disimpan lokal).
2. Tambah **holding**.
3. Tambah **owner / proyek** di dalam holding.
4. Tekan **Nilai** → pilih model + kuartal, lalu jawab pilihan yang tersedia:
   - **Cara bayar** dan **tenor** menentukan skornya sendiri.
   - **Kekuatan holding** dan **proyeksi** dipilih dari 5 tingkat berlabel.
   - Field Rp (sudah dibayar, proyeksi nilai) opsional, hanya untuk catatan.
   - Menilai ulang kuartal + model yang sama akan membuka nilai lama untuk dikoreksi.
5. Dashboard menampilkan rata-rata per model, peringkat teratas, dan progres penilaian.

## Token aplikasi

Token **tidak** ikut di-build ke APK maupun bundle web. Nilainya hanya ada di
environment Vercel (`APP_TOKEN`) dan di secure storage perangkat setelah diisi.

```bash
openssl rand -hex 24 | npx vercel env add APP_TOKEN production
```

Rotasi: jalankan perintah di atas dengan `--force`, lalu isi ulang token di layar
Pengaturan tiap perangkat. Token lama langsung ditolak (401).

## API

Semua endpoint butuh header `x-app-token`, kecuali `GET /api/health`.

| Method | Path | Fungsi |
|---|---|---|
| GET | `/api/health` | cek hidup |
| GET | `/api/meta` | model, bobot, metode bayar, kuartal berjalan |
| GET/POST | `/api/holdings` | daftar / buat holding |
| GET/PATCH/DELETE | `/api/holdings/:id` | detail (dengan skor terakhir per model) |
| POST | `/api/holdings/:id/owners` | tambah owner |
| GET/PATCH/DELETE | `/api/owners/:id` | detail owner + riwayat |
| PUT | `/api/owners/:id/assessments` | simpan nilai (upsert per kuartal+model) |
| DELETE | `/api/owners/:id/assessments/:aid` | hapus nilai |
| GET | `/api/dashboard` | ringkasan + tren |

## Deploy

```bash
npm install
node scripts/db-push.js          # butuh DATABASE_URL
npx vercel env add APP_TOKEN production
npx vercel --prod
```

Web statis ada di `web-build/` (hasil `flutter build web --release --output ../web-build`).

## Rilis Android

Push tag `v*` → GitHub Actions membangun APK release dan melampirkannya ke GitHub Release.
Menu **Pengaturan → Cek pembaruan** di aplikasi membaca rilis terbaru itu dan bisa langsung
mengunduh + membuka installer.

```bash
git tag v1.0.1 && git push origin v1.0.1
```

## Tes

```bash
npm test          # matematika skor di server
cd app && flutter test
```
