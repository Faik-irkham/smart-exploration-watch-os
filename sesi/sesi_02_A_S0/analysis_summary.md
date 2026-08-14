# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 21.0 menit |
| Direkam watch | 1257 |
| Ditandai terkirim (synced) | 1253 |
| Diterima phone | 1253 |
| Cocok | 1253 |
| Hilang | 4 |
| — di antaranya *false-sent* (synced=1) | 0 |
| — di antaranya *pending* (synced=0) | 4 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **99.68%** |
| CI 95% (Wilson) | 99.18% – 99.88% |

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1257 | 1253 | 99.68% | 99.18–99.88% |
| Hanya pembacaan segar (fresh=1) | 1252 | 1248 | 99.68% | 99.18–99.88% |
| Eksklusi accuracy ≤ 0 | 1257 | 1253 | 99.68% | 99.18–99.88% |
| Hanya accuracy = 3 | 1257 | 1253 | 99.68% | 99.18–99.88% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| 3 | 1257 | 100.0% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1257 | 82 | 97 | 88.4 | 2.1 |
| akurasi≥1 | 1257 | 82 | 97 | 88.4 | 2.1 |
