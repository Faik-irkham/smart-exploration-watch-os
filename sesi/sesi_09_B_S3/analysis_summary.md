# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 20.3 menit |
| Direkam watch | 1216 |
| Ditandai terkirim (synced) | 1074 |
| Diterima phone | 1074 |
| Cocok | 1074 |
| Hilang | 142 |
| — di antaranya *false-sent* (synced=1) | 0 |
| — di antaranya *pending* (synced=0) | 142 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **88.32%** |
| CI 95% (Wilson) | 86.40% – 90.01% |

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1216 | 1074 | 88.32% | 86.40–90.01% |
| Hanya pembacaan segar (fresh=1) | 1208 | 1066 | 88.25% | 86.31–89.94% |
| Eksklusi accuracy ≤ 0 | 1215 | 1073 | 88.31% | 86.38–90.00% |
| Hanya accuracy = 3 | 1215 | 1073 | 88.31% | 86.38–90.00% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| 0 | 1 | 0.1% |
| 3 | 1215 | 99.9% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1216 | 85 | 112 | 98.6 | 5.8 |
| akurasi≥1 | 1215 | 85 | 112 | 98.6 | 5.8 |
