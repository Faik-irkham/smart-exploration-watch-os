# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 23.9 menit |
| Direkam watch | 1436 |
| Ditandai terkirim (synced) | 1435 |
| Diterima phone | 1418 |
| Cocok | 1418 |
| Hilang | 18 |
| — di antaranya *false-sent* (synced=1) | 17 |
| — di antaranya *pending* (synced=0) | 1 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **98.75%** |
| CI 95% (Wilson) | 98.03% – 99.21% |

> **17 record (94.4% dari yang hilang) ditandai terkirim padahal tidak pernah sampai** — indikasi konfirmasi diterima untuk batch yang keliru.

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1436 | 1418 | 98.75% | 98.03–99.21% |
| Hanya pembacaan segar (fresh=1) | 1429 | 1411 | 98.74% | 98.02–99.20% |
| Eksklusi accuracy ≤ 0 | 1436 | 1418 | 98.75% | 98.03–99.21% |
| Hanya accuracy = 3 | 1436 | 1418 | 98.75% | 98.03–99.21% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| 3 | 1436 | 100.0% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1436 | 86 | 117 | 94.6 | 4.4 |
| akurasi≥1 | 1436 | 86 | 117 | 94.6 | 4.4 |
