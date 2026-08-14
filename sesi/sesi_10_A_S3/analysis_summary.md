# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 21.0 menit |
| Direkam watch | 1263 |
| Ditandai terkirim (synced) | 1258 |
| Diterima phone | 1240 |
| Cocok | 1240 |
| Hilang | 23 |
| — di antaranya *false-sent* (synced=1) | 18 |
| — di antaranya *pending* (synced=0) | 5 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **98.18%** |
| CI 95% (Wilson) | 97.28% – 98.78% |

> **18 record (78.3% dari yang hilang) ditandai terkirim padahal tidak pernah sampai** — indikasi konfirmasi diterima untuk batch yang keliru.

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1263 | 1240 | 98.18% | 97.28–98.78% |
| Hanya pembacaan segar (fresh=1) | 1247 | 1232 | 98.80% | 98.02–99.27% |
| Eksklusi accuracy ≤ 0 | 1254 | 1239 | 98.80% | 98.04–99.27% |
| Hanya accuracy = 3 | 1254 | 1239 | 98.80% | 98.04–99.27% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| -1 | 9 | 0.7% |
| 3 | 1254 | 99.3% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1263 | 80 | 106 | 91.3 | 6.0 |
| akurasi≥1 | 1254 | 80 | 106 | 91.3 | 6.1 |
