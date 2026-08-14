# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 21.0 menit |
| Direkam watch | 1261 |
| Ditandai terkirim (synced) | 1258 |
| Diterima phone | 1255 |
| Cocok | 1255 |
| Hilang | 6 |
| — di antaranya *false-sent* (synced=1) | 3 |
| — di antaranya *pending* (synced=0) | 3 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **99.52%** |
| CI 95% (Wilson) | 98.97% – 99.78% |

> **3 record (50.0% dari yang hilang) ditandai terkirim padahal tidak pernah sampai** — indikasi konfirmasi diterima untuk batch yang keliru.

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1261 | 1255 | 99.52% | 98.97–99.78% |
| Hanya pembacaan segar (fresh=1) | 1248 | 1244 | 99.68% | 99.18–99.88% |
| Eksklusi accuracy ≤ 0 | 1254 | 1250 | 99.68% | 99.18–99.88% |
| Hanya accuracy = 3 | 1254 | 1250 | 99.68% | 99.18–99.88% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| -1 | 7 | 0.6% |
| 3 | 1254 | 99.4% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1261 | 88 | 115 | 98.0 | 5.0 |
| akurasi≥1 | 1254 | 88 | 115 | 98.0 | 5.0 |
