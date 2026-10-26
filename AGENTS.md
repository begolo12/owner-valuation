# AGENTS.md

Panduan kerja agen di repo ini.

## Aturan wajib: web dan APK harus selalu sinkron

Ada dua klien untuk backend yang sama:

| Klien | Folder | Teknologi |
|---|---|---|
| Web | `web-app/` (build → `web-build/`) | React + Vite |
| Android APK | `app/` | Flutter |

**Setiap perubahan perilaku harus diterapkan ke keduanya dalam satu commit.**
Jangan pernah commit perubahan `web-app/` saja lalu push, karena APK akan
berperilaku beda terhadap server yang sama.

Peta file yang harus berubah bersamaan:

| Yang berubah | Web | Flutter | Server |
|---|---|---|---|
| Skema bayar | `web-app/src/labels.js` (`paymentLabels`, `paymentHints`) | `app/lib/criteria.dart` (`paymentScore`, `paymentHint`), `app/lib/theme.dart` (`paymentLabels`) | `server/score.js` (`PAYMENT_METHODS`, `PAYMENT_SCORES`) |
| Band skor tenor | `web-app/src/labels.js` (`tenorBands`) | `app/lib/criteria.dart` (`tenorScore`) | `server/score.js` (`tenorScore`) |
| Rubrik kriteria | `web-app/src/labels.js` (`criteria`) | `app/lib/criteria.dart` (`criteria`) | — |
| Bobot model / grade | dibaca dari `/api/meta` | dibaca dari `/api/meta` | `server/score.js` (`WEIGHTS`, `gradeOf`) |
| Field payload / endpoint | `web-app/src/api.js` | `app/lib/api.dart` | `server/router.js` |
| Validasi input | validasi di form | validasi di form | `server/router.js` |

Nilai skor dan label level **harus identik** di ketiga tempat. Label level dipakai
sebagai kunci prefill, jadi teks label tidak boleh diubah sepihak.

Kalau satu klien sengaja belum diperbarui, sebutkan di commit message apa yang
masih tertinggal. Jangan diam-diam.

## Skor dihitung server

`paymentScore` dan `tenorScore` hanya dihitung server. Klien mengirim:

```json
{ "paymentMethod": "scf", "paymentTenor": 45, "scores": { "holding": 80, "projection": 80 } }
```

Skor di klien hanya untuk pratinjau. Jangan kirim `scores.payment` atau `scores.tenor`.

## Jangan hardcode rahasia

Repo publik. Token hanya di env Vercel (`APP_TOKEN`) dan di perangkat pengguna
(localStorage + cookie di web, secure storage di APK). Dilarang menaruh token,
`DATABASE_URL`, atau kredensial apa pun di kode, test, atau fixture.

Cek sebelum commit:

```bash
grep -rn "APP_TOKEN\|postgres://\|postgresql://" --include='*.js' --include='*.jsx' --include='*.dart' . | grep -v node_modules
```

## Backend

- `server/router.js` — route + validasi. `server/score.js` — matematika skor.
- `api/**` — pembungkus tipis Vercel. Satu file per path nyata; catch-all
  `api/[...path].js` **tidak** cocok untuk path multi-segmen.
- `db/schema.sql` — idempoten, aman dijalankan berulang, termasuk blok migrasi.

## Perintah

```bash
npm test                          # skor server
cd app && flutter analyze && flutter test
cd web-app && npm run build       # → web-build/

node scripts/dev-api.js           # API lokal :5198
cd web-app && npm run dev         # web :5199, /api → :5198
```

## Rilis

Satu tag untuk keduanya: `git tag v1.x.y && git push origin master --tags`.
CI membangun APK; web dideploy dengan `npx vercel --prod`.
