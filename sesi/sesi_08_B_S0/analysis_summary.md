# Ringkasan Analisis Data

Pencocokan watch<->phone via **record_id**.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi (watch) | 20.9 menit |
| Direkam watch | 1256 |
| Ditandai terkirim (synced) | 1254 |
| Diterima phone | 1254 |
| Cocok | 1254 |
| Hilang | 2 |
| — di antaranya *false-sent* (synced=1) | 0 |
| — di antaranya *pending* (synced=0) | 2 |
| Duplikat di phone | 0 |
| **Delivery ratio** | **99.84%** |
| CI 95% (Wilson) | 99.42% – 99.96% |

## Analisis sensitivitas kriteria inklusi

| Kriteria | n | cocok | delivery | CI 95% |
|----------|--:|------:|---------:|--------|
| Semua record, tanpa eksklusi | 1256 | 1254 | 99.84% | 99.42–99.96% |
| Hanya pembacaan segar (fresh=1) | 1249 | 1247 | 99.84% | 99.42–99.96% |
| Eksklusi accuracy ≤ 0 | 1256 | 1254 | 99.84% | 99.42–99.96% |
| Hanya accuracy = 3 | 1256 | 1254 | 99.84% | 99.42–99.96% |

## Distribusi akurasi sensor (watch)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| 3 | 1256 | 100.0% |

## Statistik BPM (watch)

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| semua | 1256 | 79 | 110 | 91.4 | 4.7 |
| akurasi≥1 | 1256 | 79 | 110 | 91.4 | 4.7 |
