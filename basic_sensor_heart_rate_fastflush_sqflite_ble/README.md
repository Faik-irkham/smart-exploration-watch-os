# Varian FAST-FLUSH (eksperimen irama kirim 15/30 detik)

Salinan dari `basic_sensor_heart_rate_interval_sqflite_ble` dengan SATU perbedaan:
batch dikirim tiap **15 atau 30 detik** (dapat dipilih di UI), bukan 3/5 menit.
Mekanisme lain identik (store-and-forward, ACK, idempoten, foreground service).
applicationId dibedakan (`...fastflush_ble`) sehingga bisa terpasang berdampingan
dengan aplikasi asli. Proyek asli TIDAK diubah.

## Accelerometer

Varian ini juga membaca `TYPE_ACCELEROMETER` sekitar 25 Hz. Sampel X/Y/Z tidak
disimpan mentah; setiap satu detik aplikasi menghitung rata-rata magnitude,
standar deviasi magnitude (indikator gerakan), dan jumlah sampel. Ringkasan itu
disimpan bersama record HR dan dikirim dalam batch BLE yang sama. Interval
pengukuran/penyimpanan tetap satu detik, sedangkan flush tetap 15/30 detik.

# Watch — Heart Rate Sensor + BLE Peripheral

Aplikasi **Wear OS** yang membaca sensor detak jantung, menyimpannya ke SQLite,
dan mengirimkannya ke smartphone lewat **BLE** (watch berperan sebagai
*peripheral / GATT server*). Bagian dari sistem dua-aplikasi — lihat
[README induk](../README.md) dan [spesifikasi protokol](../docs/BLE_PROTOCOL.md).

## Fitur

- Membaca sensor Android `TYPE_HEART_RATE` secara kontinu.
- Menyimpan **satu pembacaan valid per detik** ke SQLite.
- *Store-and-forward*: kolom `synced` memastikan data tidak hilang saat ponsel terputus.
- Mengirim batch tiap **3 atau 5 menit** (dapat dipilih) sebagai notifikasi BLE ber-frame.
- Indikator status koneksi (idle / advertising / connected / error) dan jumlah record belum terkirim.

## Struktur kode

| Berkas | Tanggung jawab |
|--------|----------------|
| [lib/main.dart](lib/main.dart) | Entry point & tema aplikasi. |
| [lib/heart_rate_page.dart](lib/heart_rate_page.dart) | UI, izin, timer pembacaan (1 dtk) & pengiriman (interval). |
| [lib/ble_peripheral.dart](lib/ble_peripheral.dart) | Jembatan Dart ⇄ native (MethodChannel/EventChannel). |
| [lib/heart_rate_database.dart](lib/heart_rate_database.dart) | SQLite + store-and-forward (`insert`, `getUnsynced`, `markSynced`). |
| [android/.../MainActivity.kt](android/app/src/main/kotlin/com/flutfy/basic_sensor_heart_rate_interval_sqflite_ble/MainActivity.kt) | Sensor listener + GATT server + advertiser + framing batch. |

## Izin (AndroidManifest)

| Izin | Alasan |
|------|--------|
| `BODY_SENSORS` | Membaca sensor detak jantung. |
| `BLUETOOTH_ADVERTISE` (API 31+) | Mengiklankan service BLE. |
| `BLUETOOTH_CONNECT` (API 31+) | Melayani GATT server. |
| `BLUETOOTH` / `BLUETOOTH_ADMIN` (≤ API 30) | Bluetooth pada Android lama. |

`uses-feature`: `android.hardware.type.watch`, `android.hardware.bluetooth_le` (required).

## Kanal Flutter ⇄ Native

| Kanal | Tipe | Fungsi |
|-------|------|--------|
| `heart_rate/stream` | EventChannel | Streaming pembacaan sensor. |
| `heart_rate/ble` | MethodChannel | `startAdvertising` / `stopAdvertising` / `sendBatch` / `isConnected`. |
| `heart_rate/ble/status` | EventChannel | Status koneksi BLE. |

## Skema database (`heart_rate.db`, tabel `readings`, versi 2)

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | INTEGER PK AUTOINCREMENT | rowid. |
| `bpm` | REAL | Detak jantung. |
| `accuracy` | INTEGER | Akurasi sensor (0–3). |
| `time` | INTEGER | Epoch ms. |
| `synced` | INTEGER (default 0) | 0 = belum terkirim, 1 = terkirim. |

## Menjalankan

```bash
flutter pub get
flutter run     # pilih perangkat smartwatch Wear OS
```

> Sensor detak jantung dan BLE advertising **tidak tersedia di emulator**.
> Gunakan smartwatch fisik. Pastikan mode hemat daya nonaktif agar sensor
> tidak dibatasi sistem.

## Berjalan di background / layar mati

Saat *Izinkan & Mulai* ditekan, aplikasi menjalankan **foreground service**
(`MonitoringService`) dengan notifikasi permanen + `PARTIAL_WAKE_LOCK`. Ini
menjaga proses tetap hidup sehingga pembacaan sensor, penyimpanan SQLite, dan
pengiriman batch BLE **tetap berjalan saat app di-background atau layar watch
mati**. Service dihentikan saat menekan *Berhenti*.

> Cakupan: background + layar mati. Jika aplikasi **ditutup paksa** (di-swipe
> dari recent) atau perangkat reboot, pemantauan berhenti — ini batasan yang
> disengaja (lihat juga keterbatasan OEM/Wear OS). Butuh `POST_NOTIFICATIONS`
> (Android 13+) agar notifikasi service tampil.

## Catatan untuk eksperimen

- Akhir sesi, isi tabel `readings` adalah *ground truth* data watch — gunakan untuk membandingkan dengan database penerima (lihat [docs/EXPERIMENT.md](../docs/EXPERIMENT.md)).
