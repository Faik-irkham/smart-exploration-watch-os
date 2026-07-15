# Smartphone — Heart Rate BLE Receiver

Aplikasi **Android** yang menerima data detak jantung dari smartwatch lewat
**BLE** (ponsel berperan sebagai *central / GATT client*), merangkai batch,
menyimpannya ke SQLite, dan menampilkannya secara real-time. Bagian dari sistem
dua-aplikasi — lihat [README induk](../README.md) dan
[spesifikasi protokol](../docs/BLE_PROTOCOL.md).

## Fitur

- Scan service watch (`0000a100…`), connect, dan request MTU 512.
- Subscribe karakteristik record, **merangkai batch ber-frame** (opcode START/DATA/END).
- Parse JSON array → simpan satu batch dalam satu transaksi SQLite.
- Simpan ringkasan accelerometer opsional dari varian fast-flush; payload HR
  lama tanpa field accelerometer tetap didukung.
- Tampilkan BPM terbaru, status koneksi, dan riwayat tersimpan.

## Struktur kode

| Berkas | Tanggung jawab |
|--------|----------------|
| [lib/main.dart](lib/main.dart) | UI penerima (status, BPM terbaru, daftar riwayat). |
| [lib/ble_receiver.dart](lib/ble_receiver.dart) | Logika BLE central: scan, connect, subscribe, reassembly batch. |
| [lib/heart_rate_database.dart](lib/heart_rate_database.dart) | SQLite (`insertReadings` batch, `getReadings`). |

Seluruh logika BLE memakai paket Dart `flutter_blue_plus` — tidak ada kode
native khusus (`MainActivity.kt` hanya `FlutterActivity` default).

## Izin (AndroidManifest)

| Izin | Alasan |
|------|--------|
| `BLUETOOTH_SCAN` (`neverForLocation`, API 31+) | Memindai perangkat BLE. |
| `BLUETOOTH_CONNECT` (API 31+) | Connect & komunikasi GATT. |
| `BLUETOOTH` / `BLUETOOTH_ADMIN` (≤ API 30) | Bluetooth pada Android lama. |
| `ACCESS_FINE_LOCATION` (≤ API 30) | Wajib untuk BLE scan sebelum Android 12. |

`uses-feature`: `android.hardware.bluetooth_le` (required).

## Reassembly (ringkas)

Setiap notifikasi dibaca berdasarkan opcode byte pertama:

| Opcode | Aksi penerima |
|--------|---------------|
| `0x01` START | Kosongkan buffer. |
| `0x02` DATA | Append `value.sublist(1)` ke buffer. |
| `0x03` END | Decode buffer → JSON array → simpan & pancarkan tiap record. |

Detail lengkap: [docs/BLE_PROTOCOL.md](../docs/BLE_PROTOCOL.md) §6.

## Skema database (`heart_rate.db`, tabel `readings`, versi 1)

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | INTEGER PK AUTOINCREMENT | rowid. |
| `bpm` | REAL | Detak jantung. |
| `accuracy` | INTEGER | Akurasi sensor (0–3). |
| `time` | INTEGER | Epoch ms (identik dengan timestamp di watch). |

> Tidak ada kolom `synced` di sini — penerima hanya menyimpan apa yang diterima.
> Timestamp `time` dipakai untuk mencocokkan record dengan database watch.

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

- Tabel `readings` di sini dibandingkan dengan database watch untuk menghitung *delivery ratio* / packet loss (lihat [docs/EXPERIMENT.md](../docs/EXPERIMENT.md)).
