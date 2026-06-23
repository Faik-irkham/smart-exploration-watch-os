# Desain Eksperimen & Pengumpulan Data

Dokumen ini menjelaskan cara mengevaluasi sistem secara empiris agar hasilnya
dapat dilaporkan dan **direproduksi** dalam paper. Mencakup pertanyaan
penelitian, variabel, definisi metrik, prosedur, cara pengumpulan data, dan
analisis.

> Status sistem terkini: pengiriman batch BLE + *store-and-forward* dengan
> **konfirmasi penerimaan (ACK)** dan penerima **idempoten** (anti-duplikat),
> serta eksekusi **latar belakang/layar mati** lewat *foreground service*.
> Belum mencakup auto-jalan saat aplikasi ditutup/­reboot.

---

## 1. Pertanyaan penelitian (contoh)

- **RQ1.** Seberapa andal pengiriman data detak jantung dari watch ke ponsel
  via BLE dengan pola *store-and-forward* + ACK? (→ *delivery ratio* / loss)
- **RQ2.** Berapa latensi dan throughput pengiriman satu batch, dan bagaimana
  pengaruh ukuran batch (interval 3 vs 5 menit) serta MTU?
- **RQ3.** Bagaimana ketahanan terhadap gangguan koneksi (perangkat menjauh /
  Bluetooth sempat mati) — apakah data tertunda akhirnya terkirim tanpa hilang
  dan tanpa duplikat?
- **RQ4.** Berapa konsumsi baterai/sumber daya selama sesi pemantauan kontinu?

> Sesuaikan RQ dengan fokus paper. Tidak semua wajib dipakai.

---

## 2. Variabel

| Jenis | Variabel | Contoh nilai |
|-------|----------|--------------|
| Bebas | Interval pengiriman | 3 menit, 5 menit |
| Bebas | Jarak watch–ponsel | 1 m, 5 m, 10 m, dengan/ tanpa penghalang |
| Bebas | Skenario gangguan | normal, putus sementara, Bluetooth mati lalu nyala, background/layar mati |
| Terikat | Delivery ratio, duplikat, latensi batch, throughput | (diukur) |
| Kontrol | Perangkat, versi OS, MTU diminta (512), durasi sesi, **jenis build (release)** | tetap |

---

## 3. Definisi metrik

| Metrik | Definisi | Sumber |
|--------|----------|--------|
| **Delivery ratio** | `record cocok di ponsel / record direkam watch` (cocok via `time`) | CSV ekspor (lihat §6) / `tools/analyze.py`. |
| **Record loss** | `1 − delivery ratio` | idem |
| **Duplikat** | jumlah `time` ganda di ponsel (harus 0 berkat indeks unik) | `tools/analyze.py`. |
| **Distribusi akurasi** | sebaran nilai `accuracy` sensor (-1..3, konstanta `SensorManager`) sebagai indikator kualitas data | CSV ekspor / `tools/analyze.py`. |
| **Latensi transfer batch (watch)** | Waktu dari frame pertama sampai frame terakhir (`OP_END`) tuntas terkirim | Log `HR-METRIC` watch, kolom `duration_ms`. |
| **Throughput** | `payload_bytes / duration` | Log `HR-METRIC` watch, kolom `throughput_Bps`. |
| **Waktu reassembly (ponsel)** | Waktu dari `OP_START` sampai `OP_END` diterima | Log `HR-METRIC` ponsel, kolom `reassembly_ms`. |
| **Waktu insert DB (ponsel)** | Durasi menyimpan satu batch ke SQLite | Log `HR-METRIC` ponsel, kolom `insert_ms`. |
| **Konsumsi baterai** | Δ persentase baterai per durasi | `adb shell dumpsys batterystats` / Battery Historian. |

---

## 4. Format log metrik

Kedua aplikasi mencetak satu baris CSV per batch dengan penanda `HR-METRIC`.

**Watch** (tag Logcat `HR-METRIC`, level INFO):
```
tx_batch,records,bytes,frames,mtu,duration_ms,throughput_Bps
```
Contoh: `tx_batch,228,10717,24,512,323.1,33168`

**Ponsel** (lewat `debugPrint`, prefiks `HR-METRIC`):
```
HR-METRIC,rx_batch,records,bytes,frames,reassembly_ms,insert_ms
```
Contoh: `HR-METRIC,rx_batch,228,10717,24,250,56`

> Catatan: log `debugPrint` ponsel hanya muncul pada build **debug**. Untuk
> build **release**, gunakan metrik watch (Logcat tetap muncul) atau andalkan
> CSV ekspor untuk delivery ratio.

---

## 5. Prosedur

### 5.1 Persiapan
1. **Gunakan build RELEASE** untuk pengukuran (build *debug* Flutter jauh lebih
   lambat sehingga membiaskan latensi/throughput). Contoh:
   `flutter run --release -d <SERIAL>` atau pasang APK release.
2. Pasang aplikasi watch ke smartwatch Wear OS fisik, aplikasi penerima ke ponsel
   fisik. Contoh perangkat uji: Samsung Galaxy Watch (SM-R860), Xiaomi Redmi
   Note 10 Pro (Android 13).
3. Catat spesifikasi: model & OS kedua perangkat, versi aplikasi, Flutter `3.41.4`.
4. Kosongkan database kedua sisi (tombol **Hapus** di UI) agar sesi bersih.
5. Pada ponsel OEM agresif (mis. MIUI), **nonaktifkan optimasi baterai** untuk
   aplikasi penerima agar tidak dihentikan saat di latar belakang.
6. Beri izin **notifikasi** saat diminta (untuk *foreground service*).

### 5.2 Satu run
1. Di **ponsel**: tekan *Hubungkan watch* (scan → connect → subscribe).
2. Di **watch**: pilih interval → *Izinkan & Mulai*.
3. Biarkan berjalan **N** interval (mis. ≥ 5 interval agar ada cukup batch).
4. Skenario gangguan: jauhkan perangkat / matikan Bluetooth ponsel selama 1
   interval, lalu dekatkan/nyalakan kembali; amati apakah data tertunda terkirim
   pada interval berikutnya (store-and-forward + ACK), **tanpa duplikat**.
5. Skenario background: kunci layar/pindahkan app ke latar belakang selama
   beberapa interval; pastikan perekaman & pengiriman tetap jalan.
6. Akhiri sesi (tombol **Berhenti** / *Putuskan*).

### 5.3 Replikasi
- Ulangi tiap kondisi minimal **3–5 kali** untuk mendapat rata-rata ± standar deviasi.
- Gunakan durasi sesi yang sama antar kondisi agar adil.

---

## 6. Pengumpulan data

### 6.1 Cara utama (build RELEASE) — ekspor ke Downloads
Pada build release, `run-as` tidak tersedia, jadi data diambil lewat **fitur
ekspor** di aplikasi (menulis ke folder Downloads via MediaStore):

1. Di tiap aplikasi tekan **Export CSV** dan/atau **Export .db** (watch & ponsel).
2. Tarik berkas terbaru + hitung delivery ratio otomatis:
   ```bash
   bash tools/pull_exports.sh <SERIAL_WATCH> <SERIAL_PHONE> <OUT_DIR>
   ```
   Skrip menarik `watch.csv/.db` & `phone.csv/.db` terbaru dari `/sdcard/Download`
   lalu mencetak jumlah record kedua sisi dan delivery ratio.

### 6.2 Cara alternatif (build DEBUG) — `run-as`
Hanya berlaku bila aplikasi dipasang sebagai **debug** (jangan dipakai untuk
pengukuran performa karena lebih lambat):
```bash
adb -s <SERIAL_WATCH> exec-out run-as com.flutfy.basic_sensor_heart_rate_interval_sqflite_ble \
  cat databases/heart_rate.db > watch.db
adb -s <SERIAL_PHONE> exec-out run-as com.flutfy.heart_rate_phone_receiver \
  cat databases/heart_rate.db > phone.db
```

### 6.3 Log metrik (latensi/throughput)
```bash
adb -s <SERIAL_WATCH> logcat -s HR-METRIC:I > watch_metrics.csv   # tx_batch
adb -s <SERIAL_PHONE> logcat | grep HR-METRIC > phone_metrics.csv  # rx_batch (debug)
```

### 6.4 Struktur CSV ekspor
`id, bpm, accuracy, time_ms, time_iso` (ditambah `synced` pada sisi watch).
Pencocokan watch↔ponsel memakai `time_ms`. Karena `time` dibuat di watch dan
dikirim apa adanya, perhitungan **tidak bergantung sinkronisasi jam**.

---

## 7. Analisis

Gunakan skrip bawaan untuk mengolah CSV ekspor menjadi ringkasan + grafik:
```bash
python3 tools/analyze.py watch.csv phone.csv <OUT_DIR>
```
Keluaran: delivery ratio, distribusi akurasi, statistik BPM (min/maks/rata-rata/SD),
durasi sesi, jumlah duplikat → ditulis ke `analysis_summary.md`, dan (bila
matplotlib terpasang) grafik `bpm_timeline.png` & `delivery.png`.

Untuk analisis lintas kondisi:
- **Reliabilitas (RQ1/RQ3):** delivery ratio rata-rata per kondisi; tunjukkan data tertunda akhirnya terkirim (loss → 0) setelah rekoneksi, dan duplikat = 0.
- **Kinerja (RQ2):** rata-rata ± SD untuk `duration_ms`, `throughput_Bps`, `reassembly_ms`; uji pengaruh interval (3 vs 5 mnt) dan MTU.
- **Visualisasi:** boxplot latensi per kondisi; bar chart delivery ratio; garis throughput vs ukuran batch.
- **Statistik (opsional):** uji t / Mann–Whitney untuk dua interval; ANOVA untuk >2 jarak.

---

## 8. Ancaman terhadap validitas

| Ancaman | Mitigasi |
|---------|----------|
| Build debug membiaskan latensi/throughput | Ukur memakai build **release**. |
| Variasi lingkungan RF (interferensi 2.4 GHz) | Uji di lokasi & waktu serupa; catat kondisi; replikasi. |
| Heterogenitas perangkat | Laporkan model & OS; jangan generalisasi lintas perangkat tanpa uji. |
| Throttling sensor saat layar mati | *Foreground service* + wake lock aktif; tetap catat status layar. |
| App dihentikan OEM saat background | Nonaktifkan optimasi baterai; catat sebagai keterbatasan (belum jalan saat app ditutup/reboot). |
| Jumlah sampel kecil | Tambah replikasi; laporkan SD/interval kepercayaan. |
| Drift jam antar perangkat | Pencocokan berbasis `time` dari watch menghindari isu ini. |

---

## 9. Checklist pelaporan (untuk paper)

- [ ] Spesifikasi perangkat keras & versi perangkat lunak (sebut build release).
- [ ] Parameter: interval, jarak, durasi, jumlah replikasi.
- [ ] Tabel hasil: delivery ratio, duplikat, latensi, throughput (mean ± SD).
- [ ] Distribusi akurasi sensor sebagai indikator kualitas data.
- [ ] Grafik pendukung.
- [ ] Pernyataan ketersediaan kode (repositori) untuk reproduksibilitas.
