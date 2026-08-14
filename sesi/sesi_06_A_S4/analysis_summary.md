# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 21.0 menit |
| Direkam watch | 1261 |
| Ditandai terkirim (synced) | 1249 |
| Diterima phone | 1249 |
| Cocok | 1249 |
| Hilang | 12 |
| — di antaranya *false-sent* (synced=1) | 0 |
| — di antaranya *pending* (synced=0) | 12 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **99.05%** |
| CI 95% (Wilson) | 98.34% – 99.45% |

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1261 | 1249 | 99.05% | 98.34–99.45% |
| Hanya pembacaan segar (fresh=1) | 1256 | 1244 | 99.04% | 98.34–99.45% |
| Eksklusi accuracy ≤ 0 | 1261 | 1249 | 99.05% | 98.34–99.45% |
| Hanya accuracy = 3 | 1261 | 1249 | 99.05% | 98.34–99.45% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| 3 | 1261 | 100.0% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1261 | 89 | 116 | 99.4 | 4.6 |
| akurasi≥1 | 1261 | 89 | 116 | 99.4 | 4.6 |
