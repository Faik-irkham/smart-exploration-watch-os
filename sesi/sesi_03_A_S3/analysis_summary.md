# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 21.0 menit |
| Direkam watch | 1263 |
| Ditandai terkirim (synced) | 1258 |
| Diterima phone | 856 |
| Cocok | 856 |
| Hilang | 407 |
| — di antaranya *false-sent* (synced=1) | 402 |
| — di antaranya *pending* (synced=0) | 5 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **67.78%** |
| CI 95% (Wilson) | 65.15% – 70.30% |

> **402 record (98.8% dari yang hilang) ditandai terkirim padahal tidak pernah sampai** — indikasi konfirmasi diterima untuk batch yang keliru.

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1263 | 856 | 67.78% | 65.15–70.30% |
| Hanya pembacaan segar (fresh=1) | 1256 | 851 | 67.75% | 65.12–70.28% |
| Eksklusi accuracy ≤ 0 | 1261 | 854 | 67.72% | 65.09–70.25% |
| Hanya accuracy = 3 | 1261 | 854 | 67.72% | 65.09–70.25% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| -1 | 2 | 0.2% |
| 3 | 1261 | 99.8% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1263 | 76 | 106 | 89.0 | 5.9 |
| akurasi≥1 | 1261 | 76 | 106 | 89.0 | 5.9 |
