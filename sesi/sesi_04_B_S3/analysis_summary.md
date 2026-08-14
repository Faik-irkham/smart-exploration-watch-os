# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 21.0 menit |
| Direkam watch | 1260 |
| Ditandai terkirim (synced) | 1253 |
| Diterima phone | 1253 |
| Cocok | 1253 |
| Hilang | 7 |
| — di antaranya *false-sent* (synced=1) | 0 |
| — di antaranya *pending* (synced=0) | 7 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **99.44%** |
| CI 95% (Wilson) | 98.86% – 99.73% |

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1260 | 1253 | 99.44% | 98.86–99.73% |
| Hanya pembacaan segar (fresh=1) | 1259 | 1252 | 99.44% | 98.86–99.73% |
| Eksklusi accuracy ≤ 0 | 1260 | 1253 | 99.44% | 98.86–99.73% |
| Hanya accuracy = 3 | 1260 | 1253 | 99.44% | 98.86–99.73% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| 3 | 1260 | 100.0% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1260 | 78 | 109 | 94.2 | 5.7 |
| akurasi≥1 | 1260 | 78 | 109 | 94.2 | 5.7 |
