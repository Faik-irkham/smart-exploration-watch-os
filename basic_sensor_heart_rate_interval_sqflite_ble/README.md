# Watch — Heart Rate Sensor + BLE Peripheral

Aplikasi **Wear OS** yang membaca sensor detak jantung, menyimpannya ke SQLite,
dan mengirimkannya ke smartphone lewat **BLE** (watch berperan sebagai
*peripheral / GATT server*). Record baru ditandai terkirim setelah ponsel
mengirim **konfirmasi (ACK)**. Bagian dari sistem dua-aplikasi — lihat
[README induk](../README.md).

## Fitur

- Membaca sensor Android `TYPE_HEART_RATE` secara kontinu.
- Menyimpan **satu pembacaan per detik** ke SQLite, dengan penanda `fresh` bila
  nilainya berasal dari pembacaan sensor baru (bukan nilai terakhir yang diulang).
- *Store-and-forward*: kolom `synced` memastikan data tidak hilang saat ponsel terputus.
- Mengirim batch tiap **3 atau 5 menit** (dapat dipilih), dan **langsung** saat
  ponsel tersambung kembali.
- Tiap batch diberi `batch_id` unik; record ditandai `synced = 1` hanya bila ACK
  dengan `batch_id` yang sama berstatus `ok`. Tanpa ACK dalam 30 detik, record
  dikirim ulang pada flush berikutnya.
- Foreground service agar tetap berjalan di background / layar mati.
- Ekspor CSV dan file `.db` ke folder Downloads (tombol *CSV* / *DB*).
- Indikator status koneksi (idle / advertising / connected / error) dan jumlah record belum terkirim.

## Struktur kode

| Berkas | Tanggung jawab |
|--------|----------------|
| [lib/main.dart](lib/main.dart) | Entry point & tema aplikasi. |
| [lib/heart_rate_page.dart](lib/heart_rate_page.dart) | UI saja: menyediakan `MonitoringCubit` dan menampilkan state-nya. |
| [lib/monitoring/monitoring_cubit.dart](lib/monitoring/monitoring_cubit.dart) | Seluruh logika: izin, sensor, timer simpan (1 dtk) & kirim (interval), flush + ACK, ekspor, log metrik. |
| [lib/monitoring/monitoring_state.dart](lib/monitoring/monitoring_state.dart) | State imutable layar pemantauan. |
| [lib/ble_peripheral.dart](lib/ble_peripheral.dart) | Jembatan Dart ⇄ native; `batch_id`, penantian ACK, flag `AWAIT_ACK`. |
| [lib/heart_rate_database.dart](lib/heart_rate_database.dart) | SQLite + store-and-forward (`insertReading`, `getUnsynced`, `markSynced`), `device_id`, ekspor CSV/DB. |
| [lib/models/heart_rate_reading.dart](lib/models/heart_rate_reading.dart) | Model satu pembacaan. |
| [lib/widgets/](lib/widgets/) | `BleStatusIndicator`, `HistoryView`, `IntervalSelector`. |
| [android/.../MainActivity.kt](android/app/src/main/kotlin/com/flutfy/basic_sensor_heart_rate_interval_sqflite_ble/MainActivity.kt) | Registrasi kanal Flutter ⇄ native, kontrol service, simpan ke Downloads (MediaStore). |
| [android/.../HeartRateStreamHandler.kt](android/app/src/main/kotlin/com/flutfy/basic_sensor_heart_rate_interval_sqflite_ble/HeartRateStreamHandler.kt) | Listener sensor `TYPE_HEART_RATE` → EventChannel. |
| [android/.../HeartRateBleServer.kt](android/app/src/main/kotlin/com/flutfy/basic_sensor_heart_rate_interval_sqflite_ble/HeartRateBleServer.kt) | GATT server + advertiser, framing batch (START/DATA/END + CRC32), flow-control, penerimaan ACK. |
| [android/.../MonitoringService.kt](android/app/src/main/kotlin/com/flutfy/basic_sensor_heart_rate_interval_sqflite_ble/MonitoringService.kt) | Foreground service (`health` + `connectedDevice`) + `PARTIAL_WAKE_LOCK`. |

## Identitas GATT

| Item | UUID | Properti |
|------|------|----------|
| Service | `0000a100-0000-1000-8000-00805f9b34fb` | — |
| Record characteristic | `0000a101-0000-1000-8000-00805f9b34fb` | `NOTIFY` (+ CCCD `0x2902`) |
| ACK characteristic | `0000a102-0000-1000-8000-00805f9b34fb` | `WRITE` (ditulis ponsel) |

Payload batch: `{"device": <device_id>, "records": [{"rid", "bpm", "accuracy", "time"}, …]}`,
dipecah menjadi frame `START (0x01 | batch_id | jumlah frame | panjang)`,
`DATA (0x02 | seq | potongan JSON)`, dan `END (0x03 | crc32)`. Ukuran potongan
mengikuti MTU hasil negosiasi ponsel.

## Izin (AndroidManifest)

| Izin | Alasan |
|------|--------|
| `BODY_SENSORS` | Membaca sensor detak jantung. |
| `BLUETOOTH_ADVERTISE` (API 31+) | Mengiklankan service BLE. |
| `BLUETOOTH_CONNECT` (API 31+) | Melayani GATT server. |
| `BLUETOOTH` / `BLUETOOTH_ADMIN` (≤ API 30) | Bluetooth pada Android lama. |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_HEALTH`, `FOREGROUND_SERVICE_CONNECTED_DEVICE` | Foreground service pemantauan. |
| `WAKE_LOCK` | Menjaga CPU aktif saat layar mati. |
| `POST_NOTIFICATIONS` (API 33+) | Notifikasi permanen foreground service. |

`uses-feature`: `android.hardware.type.watch`, `android.hardware.bluetooth_le` (required).
Aplikasi ditandai *standalone* (`com.google.android.wearable.standalone`).

## Kanal Flutter ⇄ Native

| Kanal | Tipe | Fungsi |
|-------|------|--------|
| `heart_rate/stream` | EventChannel | Streaming pembacaan sensor. |
| `heart_rate/ble` | MethodChannel | `startAdvertising` / `stopAdvertising` / `sendBatch` / `isConnected` / `startService` / `stopService` / `saveToDownloads`. |
| `heart_rate/ble/status` | EventChannel | Status koneksi BLE. |
| `heart_rate/ble/ack` | EventChannel | ACK dari ponsel (JSON `{batch_id, expected, stored, status}`). |

## Skema database (`heart_rate.db`, versi 4)

Tabel `readings`:

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | INTEGER PK AUTOINCREMENT | rowid; dikirim sebagai `rid` dan menjadi `record_id` di ponsel. |
| `bpm` | REAL | Detak jantung. |
| `accuracy` | INTEGER | Akurasi sensor (0–3). |
| `time` | INTEGER | Epoch ms. |
| `synced` | INTEGER (default 0) | 0 = belum dikonfirmasi ponsel, 1 = sudah. |
| `fresh` | INTEGER, boleh NULL | 1 = pembacaan sensor baru, 0 = nilai terakhir diulang, NULL = record dari versi sebelum kolom ini ada. |

Tabel `meta` (`key`, `value`) menyimpan `device_id` — 16 byte acak (hex) yang
dibuat sekali dan dikirim di setiap batch.

## Dua versi pembanding (`AWAIT_ACK`)

```bash
# Versi B (default): tandai terkirim setelah ACK yang cocok diterima
flutter build apk --release

# Versi A (awal): tandai terkirim begitu panggilan kirim lokal berhasil
flutter build apk --release --dart-define=AWAIT_ACK=false
```

Pada versi A, status flush di log tercatat sebagai `sent_unconfirmed`.

## Log metrik

Baris berawalan `HR-METRIC` di logcat (`adb logcat | grep HR-METRIC`):

| Event | Kolom |
|-------|-------|
| `session_start` | `await_ack`, `interval_min` |
| `flush` | `batch_id, attempt, pending, stored, duplicates, status, ack_latency_ms, backlog_after, recovery_ms` |
| `tx_batch` (native) | `batch_id, records, bytes, frames, mtu, duration_ms, throughput_Bps` |

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

- Akhir sesi, isi tabel `readings` adalah *ground truth* data watch. Ekspor CSV
  (kolom `id, device_id, bpm, accuracy, time_ms, time_iso, synced, fresh`) lalu
  cocokkan dengan ekspor ponsel lewat `device_id` + `id` ↔ `record_id`.
- Record ber-`synced = 1` yang tidak ada di ponsel adalah **kehilangan senyap**.
  Data sesi eksperimen ada di [`../sesi/`](../sesi/).
