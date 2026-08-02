# Ringkasan Analisis Data (gabungan terbaru)

Data: `watch-2026-06-28.csv` vs `phone-2026-06-28.csv` · rentang 23 Jun 2026 06:38 – 28 Jun 2026 21:33 WIB

> Catatan: ekor rekaman **off-wrist** (sensor lepas, BPM beku konstan, accuracy≤0) sebanyak **22.231 sampel** dikecualikan dari metrik di bawah.

## Pengiriman (delivery)

| Indikator | Nilai |
|-----------|-------|
| Direkam watch (total) | 45.446 |
| Sampel pengukuran valid (aktif) | 23.215 |
| Diterima phone (aktif) | 20.455 |
| Hilang (aktif) | 2.760 |
| Duplikat di phone | 0 |
| **Delivery ratio (periode aktif)** | **88.11%** |
| Delivery ratio (keseluruhan, termasuk off-wrist) | 93.65% |
| **Fidelity nilai BPM (sampel cocok)** | **100.0%** |

## Per sesi (periode aktif)

| Sesi | Mulai (WIB) | Durasi | Direkam | Diterima | Hilang | Loss % |
|---:|---|---:|---:|---:|---:|---:|
| 1 | 23/06 06:38 | 36 mnt | 2.177 | 2.164 | 13 | 0.60% |
| 2 | 23/06 08:41 | 1 mnt | 53 | 0 | 53 | 100.00% |
| 3 | 23/06 14:15 | 345 mnt | 20.702 | 18.013 | 2.689 | 12.99% |
| 4 | 28/06 21:29 | 5 mnt | 283 | 278 | 5 | 1.77% |

## Statistik BPM

| Himpunan | n | min | maks | rata-rata | SD |
|----------|--:|----:|-----:|----------:|---:|
| aktif (semua) | 23.215 | 60 | 123 | 84.6 | 10.4 |
| kontak valid (acc=3) | 21.087 | 60 | 123 | 83.4 | 9.9 |

## Distribusi akurasi sensor (periode aktif)

| accuracy | jumlah | persen |
|---------:|-------:|-------:|
| 3 | 21.087 | 90.8% |
| 0 | 15 | 0.1% |
| -1 | 2.113 | 9.1% |

## Temuan utama

- **Fidelity 100%** — setiap sampel yang diterima phone identik nilainya (BPM & accuracy) dengan watch; BLE tidak merusak data.
- **Kehilangan paket terkonsentrasi di awal sesi** sebelum phone terhubung/subscribe (sesi utama: connect ~15:00); setelah terhubung delivery mendekati 100%.
- Sesi pendek yang phone-nya tidak terhubung sama sekali hilang 100%.

## Figur

- `figures/fig_hr_completeness.png` — kelengkapan data per sesi.
- `figures/fig_hr_bpm_dist.png` — distribusi BPM (kontak valid).
- `figures/fig_hr_contact.png` — kualitas kontak sensor.
- `figures/fig_hr_loss_profile.png` — profil kehilangan paket per menit (sesi utama).
- `figures/fig_hr_timeline.png` — sinyal BPM + kehilangan paket (sesi utama, 2 panel).