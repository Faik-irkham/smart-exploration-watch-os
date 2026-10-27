# Smartphone — Heart Rate BLE Receiver

Aplikasi **Android** yang menerima data detak jantung dari smartwatch lewat
**BLE** (ponsel berperan sebagai *central / GATT client*), merangkai dan
memverifikasi batch, menyimpannya ke SQLite, **mengirim ACK** ke watch, dan
menampilkannya secara real-time. Bagian dari sistem dua-aplikasi — lihat
[README induk](../README.md).

## Fitur

- Scan service watch (`0000a100…`), connect, dan request MTU 512.
- Subscribe karakteristik record (`0000a101…`), **merangkai batch ber-frame**
  (opcode START/DATA/END).
- Verifikasi batch: urutan `seq`, jumlah frame, panjang payload, dan CRC32.
- Parse payload `{device, records}` → simpan satu batch dalam satu transaksi
  SQLite; duplikat ditolak indeks unik `(device_id, record_id)`. Payload lama
  berbentuk JSON array tetap diterima.
- Menulis **ACK / NACK** ke karakteristik `0000a102…` agar watch tahu batch
  mana yang benar-benar tersimpan.
- Foreground service agar tetap berjalan di background / layar mati.
- Ekspor CSV dan file `.db` ke folder Downloads (menu *Export CSV* / *Export .db*).
- Tampilkan BPM terbaru, status koneksi, dan riwayat tersimpan.

## Struktur kode

| Berkas | Tanggung jawab |
|--------|----------------|
| [lib/main.dart](lib/main.dart) | Entry point & tema aplikasi. |
| [lib/receiver/receiver_page.dart](lib/receiver/receiver_page.dart) | UI saja: menyediakan `ReceiverCubit` dan menampilkan state-nya. |
| [lib/receiver/receiver_cubit.dart](lib/receiver/receiver_cubit.dart) | Menjembatani `BleReceiver` + database ke state UI; ekspor CSV/DB. |
| [lib/receiver/receiver_state.dart](lib/receiver/receiver_state.dart) | State imutable layar penerima. |
| [lib/ble_receiver.dart](lib/ble_receiver.dart) | Logika BLE central: izin, scan, connect, subscribe, reassembly & verifikasi batch, ACK, log metrik. |
| [lib/heart_rate_database.dart](lib/heart_rate_database.dart) | SQLite (`insertReadings` batch, `getReadings`, ekspor CSV/DB). |
| [lib/models/heart_rate_reading.dart](lib/models/heart_rate_reading.dart) | Model satu pembacaan (termasuk `deviceId`, `recordId`). |
| [lib/utils/crc32.dart](lib/utils/crc32.dart) | CRC-32 IEEE 802.3 (sama dengan `java.util.zip.CRC32` di watch). |
| [lib/utils/date_format.dart](lib/utils/date_format.dart) | Format waktu riwayat. |
| [lib/widgets/](lib/widgets/) | `StatusCard`, `LatestCard`, `HistoryList`. |
| [android/.../MainActivity.kt](android/app/src/main/kotlin/com/flutfy/heart_rate_phone_receiver/MainActivity.kt) | MethodChannel `hr_receiver/service`: `startService` / `stopService` / `saveToDownloads`. |
| [android/.../MonitoringService.kt](android/app/src/main/kotlin/com/flutfy/heart_rate_phone_receiver/MonitoringService.kt) | Foreground service (`connectedDevice`) + `PARTIAL_WAKE_LOCK`. |

Seluruh logika BLE memakai paket Dart `flutter_blue_plus`. Kode native hanya
dipakai untuk foreground service dan penyimpanan ke Downloads (MediaStore).

## Izin (AndroidManifest)

| Izin | Alasan |
|------|--------|
| `BLUETOOTH_SCAN` (`neverForLocation`, API 31+) | Memindai perangkat BLE. |
| `BLUETOOTH_CONNECT` (API 31+) | Connect & komunikasi GATT. |
| `BLUETOOTH` / `BLUETOOTH_ADMIN` (≤ API 30) | Bluetooth pada Android lama. |
| `ACCESS_FINE_LOCATION` (≤ API 30) | Wajib untuk BLE scan sebelum Android 12. |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE` | Foreground service penerima. |
| `WAKE_LOCK` | Menjaga CPU aktif saat layar mati agar callback BLE tetap diproses. |
| `POST_NOTIFICATIONS` (API 33+) | Notifikasi permanen foreground service. |

`uses-feature`: `android.hardware.bluetooth_le` (required).

## Reassembly & ACK (ringkas)

Setiap notifikasi dibaca berdasarkan opcode byte pertama:

| Opcode | Isi frame | Aksi penerima |
|--------|-----------|---------------|
| `0x01` START | `batch_id` (4) · jumlah frame (2) · panjang payload (4) | Kosongkan buffer, catat `batch_id` & ukuran yang diharapkan. |
| `0x02` DATA | `seq` (2) · potongan JSON | Periksa `seq` berurutan, append potongan ke buffer. |
| `0x03` END | CRC32 (4) | Verifikasi → decode → simpan → tulis ACK. |

ACK ditulis ke karakteristik `0000a102…` sebagai JSON
`{"batch_id", "expected", "stored", "status"}`. `stored` adalah jumlah record
yang **baru** tersimpan (selisihnya dengan `expected` = duplikat). Nilai
`status` selain `ok` berfungsi sebagai NACK sehingga watch langsung mengirim ulang:

| Status | Penyebab |
|--------|----------|
| `ok` | Batch tersimpan. |
| `missing_frames` | `seq` melompat, jumlah frame tidak cocok, atau buffer kosong. |
| `length_mismatch` | Panjang buffer ≠ panjang payload di START. |
| `crc_mismatch` | CRC32 tidak cocok. |
| `parse_error` | Payload gagal di-decode/parse. |
| `no_start` | END diterima tanpa START. |

## Skema database (`heart_rate.db`, tabel `readings`, versi 4)

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | INTEGER PK AUTOINCREMENT | rowid lokal ponsel. |
| `device_id` | TEXT | Identitas watch (dari field `device` payload). |
| `record_id` | INTEGER | `id` record di database watch (field `rid`). |
| `bpm` | REAL | Detak jantung. |
| `accuracy` | INTEGER | Akurasi sensor (0–3). |
| `time` | INTEGER | Epoch ms (identik dengan timestamp di watch). |

Indeks: `UNIQUE (device_id, record_id)` sebagai anti-duplikat, dan indeks
non-unik pada `time`.

> Tidak ada kolom `synced` di sini — penerima hanya menyimpan apa yang diterima.
> Pencocokan dengan database watch memakai `(device_id, record_id)`, bukan timestamp.

## Log metrik

Setiap batch yang tersimpan mencetak baris `HR-METRIC,rx_batch,…` di logcat
dengan kolom `batch_id, records, stored, bytes, frames, reassembly_ms,
insert_ms, oldest_delay_ms, newest_delay_ms`.

## Menjalankan

```bash
flutter pub get
flutter run     # pilih perangkat ponsel; nyalakan Bluetooth
```

> BLE **tidak dapat diemulasikan**. Gunakan ponsel fisik dengan Bluetooth aktif.

## Berjalan di background / layar mati

Saat *Hubungkan watch* ditekan, aplikasi menjalankan **foreground service**
(`MonitoringService`) dengan notifikasi permanen + `PARTIAL_WAKE_LOCK`, sehingga
koneksi BLE dan penyimpanan data **tetap berjalan saat app di-background atau
layar mati**. Service dihentikan saat menekan *Putuskan*.

> Cakupan: background + layar mati. Jika app **ditutup paksa** (di-swipe dari
> recent) atau reboot, penerimaan berhenti. Pada perangkat OEM agresif
> (mis. MIUI/Xiaomi) sebaiknya nonaktifkan optimasi baterai untuk app ini agar
> tidak dibunuh sistem. Butuh `POST_NOTIFICATIONS` (Android 13+).

## Catatan untuk eksperimen

- Ekspor CSV (kolom `id, device_id, record_id, bpm, accuracy, time_ms, time_iso`)
  dibandingkan dengan ekspor watch untuk menghitung *delivery ratio* dan
  kehilangan senyap. Data sesi eksperimen ada di [`../sesi/`](../sesi/).
