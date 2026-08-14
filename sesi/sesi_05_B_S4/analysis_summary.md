# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 21.2 menit |
| Direkam watch | 1269 |
| Ditandai terkirim (synced) | 1258 |
| Diterima phone | 1258 |
| Cocok | 1258 |
| Hilang | 11 |
| — di antaranya *false-sent* (synced=1) | 0 |
| — di antaranya *pending* (synced=0) | 11 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **99.13%** |
| CI 95% (Wilson) | 98.45% – 99.52% |

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1269 | 1258 | 99.13% | 98.45–99.52% |
| Hanya pembacaan segar (fresh=1) | 1264 | 1253 | 99.13% | 98.45–99.51% |
| Eksklusi accuracy ≤ 0 | 1265 | 1254 | 99.13% | 98.45–99.51% |
| Hanya accuracy = 3 | 1265 | 1254 | 99.13% | 98.45–99.51% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| -1 | 4 | 0.3% |
| 3 | 1265 | 99.7% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1269 | 87 | 113 | 98.5 | 4.2 |
| akurasi≥1 | 1265 | 87 | 113 | 98.6 | 4.1 |
