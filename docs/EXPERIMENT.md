# Desain Eksperimen & Pengumpulan Data

Dokumen ini menjelaskan cara mengevaluasi sistem secara empiris agar hasilnya
dapat dilaporkan dan **direproduksi** dalam paper. Mencakup pertanyaan
penelitian, variabel, definisi metrik, prosedur, cara pengumpulan data, dan
analisis.

---

## 1. Pertanyaan penelitian (contoh)

- **RQ1.** Seberapa andal pengiriman data detak jantung dari watch ke ponsel
  via BLE dengan pola *store-and-forward*? (→ *delivery ratio* / packet loss)
- **RQ2.** Berapa latensi dan throughput pengiriman satu batch, dan bagaimana
  pengaruh ukuran batch (interval 3 vs 5 menit) serta MTU?
- **RQ3.** Bagaimana ketahanan sistem terhadap gangguan koneksi (perangkat
  menjauh / Bluetooth sempat mati) — apakah ada data yang hilang?
- **RQ4.** Berapa konsumsi baterai/sumber daya selama sesi pemantauan kontinu?

> Sesuaikan RQ dengan fokus paper. Tidak semua wajib dipakai.

---

## 2. Variabel

| Jenis | Variabel | Contoh nilai |
|-------|----------|--------------|
| Bebas | Interval pengiriman | 3 menit, 5 menit |
| Bebas | Jarak watch–ponsel | 1 m, 5 m, 10 m, dengan/ tanpa penghalang |
| Bebas | Skenario gangguan | normal, putus sementara, Bluetooth mati lalu nyala |
| Terikat | Delivery ratio, latensi batch, throughput, frame loss | (diukur) |
| Kontrol | Perangkat, versi OS, MTU diminta (512), durasi sesi | tetap |

---

## 3. Definisi metrik

| Metrik | Definisi | Sumber |
|--------|----------|--------|
| **Delivery ratio** | `record diterima ponsel / record terkirim watch` | Perbandingan DB (lihat §6). |
| **Packet/record loss** | `1 − delivery ratio` | idem |
| **Latensi transfer batch (watch)** | Waktu dari frame pertama sampai frame terakhir (`OP_END`) tuntas terkirim | Log `HR-METRIC` watch, kolom `duration_ms`. |
| **Throughput** | `payload_bytes / duration` | Log `HR-METRIC` watch, kolom `throughput_Bps`. |
| **Waktu reassembly (ponsel)** | Waktu dari `OP_START` sampai `OP_END` diterima | Log `HR-METRIC` ponsel, kolom `reassembly_ms`. |
| **Waktu insert DB (ponsel)** | Durasi menyimpan satu batch ke SQLite | Log `HR-METRIC` ponsel, kolom `insert_ms`. |
| **Frame per batch** | Jumlah frame BLE (START + DATA… + END) | kolom `frames`. |
| **Konsumsi baterai** | Δ persentase baterai per durasi | `adb shell dumpsys batterystats` / Battery Historian. |

---

## 4. Format log metrik

Kedua aplikasi mencetak satu baris CSV per batch dengan penanda `HR-METRIC`.

**Watch** (tag Logcat `HR-METRIC`, level INFO):
```
tx_batch,records,bytes,frames,mtu,duration_ms,throughput_Bps
```
Contoh: `tx_batch,180,5400,14,512,96.4,56016`

**Ponsel** (lewat `debugPrint`, prefiks `HR-METRIC`):
```
HR-METRIC,rx_batch,records,bytes,frames,reassembly_ms,insert_ms
```
Contoh: `HR-METRIC,rx_batch,180,5400,14,110,7`

---

## 5. Prosedur

### 5.1 Persiapan
1. Pasang aplikasi watch ke smartwatch Wear OS fisik, aplikasi penerima ke ponsel fisik.
2. Catat spesifikasi: model & OS kedua perangkat, versi aplikasi (`1.0.0+1`), Flutter `3.41.4`.
3. Kosongkan database kedua sisi (tombol **Hapus** di UI) agar sesi bersih.
4. Sinkronkan jam kedua perangkat (mis. via NTP/otomatis) bila ingin membandingkan timestamp absolut.

### 5.2 Satu run
1. Di **ponsel**: tekan *Hubungkan watch* (scan → connect → subscribe).
2. Di **watch**: pilih interval → *Izinkan & Mulai*.
3. Biarkan berjalan **N** interval (mis. ≥ 5 interval agar ada cukup batch).
4. Untuk skenario gangguan: jauhkan perangkat / matikan Bluetooth ponsel selama 1 interval, lalu dekatkan/ nyalakan kembali dan amati apakah data tertunda terkirim pada interval berikutnya.
5. Akhiri sesi (tombol **Berhenti** / *Putuskan*).

### 5.3 Replikasi
- Ulangi tiap kondisi minimal **3–5 kali** untuk mendapat rata-rata ± standar deviasi.
- Gunakan durasi sesi yang sama antar kondisi agar adil.

---

## 6. Pengumpulan data

### 6.1 Log metrik (real-time)

Watch (USB/Wi-Fi debugging):
```bash
adb -s <SERIAL_WATCH> logcat -s HR-METRIC:I > watch_metrics.csv
```

Ponsel:
```bash
adb -s <SERIAL_PHONE> logcat | grep HR-METRIC > phone_metrics.csv
# atau: flutter logs | grep HR-METRIC
```

### 6.2 Database SQLite (ground truth)

Aplikasi *debug* dapat diakses dengan `run-as`:
```bash
# Watch — sumber kebenaran (perhatikan kolom synced)
adb -s <SERIAL_WATCH> exec-out run-as com.flutfy.basic_sensor_heart_rate_interval_sqflite_ble \
  cat databases/heart_rate.db > watch.db

# Ponsel — data yang diterima
adb -s <SERIAL_PHONE> exec-out run-as com.flutfy.heart_rate_phone_receiver \
  cat databases/heart_rate.db > phone.db
```

Hitung jumlah & bandingkan:
```bash
sqlite3 watch.db  "SELECT COUNT(*) FROM readings;"            # total di watch
sqlite3 watch.db  "SELECT COUNT(*) FROM readings WHERE synced=1;"  # yang ditandai terkirim
sqlite3 phone.db  "SELECT COUNT(*) FROM readings;"            # yang diterima ponsel
```

Cocokkan record berdasarkan `time` (epoch ms identik di kedua sisi):
```sql
-- Jalankan setelah ATTACH kedua db; contoh konsep:
-- record watch yang tidak ada di ponsel (hilang):
SELECT COUNT(*) FROM watch.readings w
WHERE NOT EXISTS (SELECT 1 FROM phone.readings p WHERE p.time = w.time);
```

> **Delivery ratio** = `record cocok di ponsel / record di watch`. Karena
> `time` (epoch ms) dibuat di watch dan dikirim apa adanya, pencocokan
> berbasis `time` valid tanpa perlu sinkronisasi jam.

---

## 7. Analisis

- **Reliabilitas (RQ1/RQ3):** delivery ratio rata-rata per kondisi; tampilkan apakah store-and-forward berhasil mengirim ulang data yang tertunda (loss → 0 setelah rekoneksi).
- **Kinerja (RQ2):** rata-rata ± SD untuk `duration_ms`, `throughput_Bps`, `reassembly_ms`; uji pengaruh interval (3 vs 5 mnt) dan MTU.
- **Visualisasi:** boxplot latensi per kondisi; bar chart delivery ratio; garis throughput vs ukuran batch.
- **Statistik (opsional):** uji t / Mann–Whitney untuk membandingkan dua interval; ANOVA untuk >2 jarak.

---

## 8. Ancaman terhadap validitas

| Ancaman | Mitigasi |
|---------|----------|
| Variasi lingkungan RF (interferensi 2.4 GHz) | Uji di lokasi & waktu serupa; catat kondisi; replikasi. |
| Heterogenitas perangkat | Laporkan model & OS; jangan generalisasi lintas perangkat tanpa uji. |
| Throttling sensor saat layar mati / hemat daya | Nonaktifkan mode hemat daya; catat status layar. |
| Jumlah sampel kecil | Tambah replikasi; laporkan SD/interval kepercayaan. |
| Drift jam antar perangkat | Pencocokan berbasis `time` dari watch (bukan jam ponsel) menghindari isu ini untuk delivery ratio. |

---

## 9. Checklist pelaporan (untuk paper)

- [ ] Spesifikasi perangkat keras & versi perangkat lunak.
- [ ] Parameter: interval, jarak, durasi, jumlah replikasi.
- [ ] Tabel hasil: delivery ratio, latensi, throughput (mean ± SD).
- [ ] Grafik pendukung.
- [ ] Pernyataan ketersediaan kode (repositori) untuk reproduksibilitas.
