# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 21.0 menit |
| Direkam watch | 1261 |
| Ditandai terkirim (synced) | 1258 |
| Diterima phone | 1258 |
| Cocok | 1258 |
| Hilang | 3 |
| — di antaranya *false-sent* (synced=1) | 0 |
| — di antaranya *pending* (synced=0) | 3 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **99.76%** |
| CI 95% (Wilson) | 99.30% – 99.92% |

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1261 | 1258 | 99.76% | 99.30–99.92% |
| Hanya pembacaan segar (fresh=1) | 1252 | 1249 | 99.76% | 99.30–99.92% |
| Eksklusi accuracy ≤ 0 | 1258 | 1255 | 99.76% | 99.30–99.92% |
| Hanya accuracy = 3 | 1258 | 1255 | 99.76% | 99.30–99.92% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| -1 | 3 | 0.2% |
| 3 | 1258 | 99.8% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1261 | 83 | 104 | 91.7 | 3.6 |
| akurasi≥1 | 1258 | 83 | 104 | 91.8 | 3.6 |
