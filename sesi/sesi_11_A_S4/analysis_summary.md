# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 21.0 menit |
| Direkam watch | 1264 |
| Ditandai terkirim (synced) | 1258 |
| Diterima phone | 1258 |
| Cocok | 1258 |
| Hilang | 6 |
| — di antaranya *false-sent* (synced=1) | 0 |
| — di antaranya *pending* (synced=0) | 6 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **99.53%** |
| CI 95% (Wilson) | 98.97% – 99.78% |

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1264 | 1258 | 99.53% | 98.97–99.78% |
| Hanya pembacaan segar (fresh=1) | 1246 | 1240 | 99.52% | 98.95–99.78% |
| Eksklusi accuracy ≤ 0 | 1253 | 1247 | 99.52% | 98.96–99.78% |
| Hanya accuracy = 3 | 1253 | 1247 | 99.52% | 98.96–99.78% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| -1 | 11 | 0.9% |
| 3 | 1253 | 99.1% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1264 | 79 | 116 | 92.7 | 5.6 |
| akurasi≥1 | 1253 | 79 | 116 | 92.8 | 5.6 |
