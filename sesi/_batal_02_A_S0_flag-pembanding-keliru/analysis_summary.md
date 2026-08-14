# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 21.0 menit |
| Direkam watch | 1260 |
| Ditandai terkirim (synced) | 1256 |
| Diterima phone | 1256 |
| Cocok | 1256 |
| Hilang | 4 |
| — di antaranya *false-sent* (synced=1) | 0 |
| — di antaranya *pending* (synced=0) | 4 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **99.68%** |
| CI 95% (Wilson) | 99.19% – 99.88% |

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1260 | 1256 | 99.68% | 99.19–99.88% |
| Hanya pembacaan segar (fresh=1) | 1255 | 1251 | 99.68% | 99.18–99.88% |
| Eksklusi accuracy ≤ 0 | 1260 | 1256 | 99.68% | 99.19–99.88% |
| Hanya accuracy = 3 | 1260 | 1256 | 99.68% | 99.19–99.88% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| 3 | 1260 | 100.0% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1260 | 78 | 99 | 86.1 | 3.4 |
| akurasi≥1 | 1260 | 78 | 99 | 86.1 | 3.4 |
