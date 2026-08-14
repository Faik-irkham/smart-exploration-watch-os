# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 21.0 menit |
| Direkam watch | 1262 |
| Ditandai terkirim (synced) | 1258 |
| Diterima phone | 1258 |
| Cocok | 1258 |
| Hilang | 4 |
| — di antaranya *false-sent* (synced=1) | 0 |
| — di antaranya *pending* (synced=0) | 4 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **99.68%** |
| CI 95% (Wilson) | 99.19% – 99.88% |

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1262 | 1258 | 99.68% | 99.19–99.88% |
| Hanya pembacaan segar (fresh=1) | 1247 | 1243 | 99.68% | 99.18–99.88% |
| Eksklusi accuracy ≤ 0 | 1253 | 1249 | 99.68% | 99.18–99.88% |
| Hanya accuracy = 3 | 1253 | 1249 | 99.68% | 99.18–99.88% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| -1 | 9 | 0.7% |
| 3 | 1253 | 99.3% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1262 | 79 | 111 | 92.1 | 7.0 |
| akurasi≥1 | 1253 | 79 | 111 | 92.1 | 7.0 |
