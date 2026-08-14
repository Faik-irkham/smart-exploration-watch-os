# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 18.1 menit |
| Direkam watch | 1087 |
| Ditandai terkirim (synced) | 1078 |
| Diterima phone | 1078 |
| Cocok | 1078 |
| Hilang | 9 |
| — di antaranya *false-sent* (synced=1) | 0 |
| — di antaranya *pending* (synced=0) | 9 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **99.17%** |
| CI 95% (Wilson) | 98.43% – 99.56% |

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1087 | 1078 | 99.17% | 98.43–99.56% |
| Hanya pembacaan segar (fresh=1) | 1078 | 1069 | 99.17% | 98.42–99.56% |
| Eksklusi accuracy ≤ 0 | 1083 | 1074 | 99.17% | 98.43–99.56% |
| Hanya accuracy = 3 | 1083 | 1074 | 99.17% | 98.43–99.56% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| -1 | 4 | 0.4% |
| 3 | 1083 | 99.6% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1087 | 78 | 99 | 91.2 | 3.2 |
| akurasi≥1 | 1083 | 78 | 99 | 91.2 | 3.2 |
