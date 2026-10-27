# Smart Exploration — Heart Rate over BLE (Watch ➜ Smartphone)

Sistem dua-aplikasi untuk merekam detak jantung pada *smartwatch* (Wear OS) dan
mengirimkannya ke *smartphone* (Android) melalui **Bluetooth Low Energy (BLE)**,
dengan penyimpanan lokal SQLite, pola *store-and-forward*, dan **konfirmasi
penerimaan (ACK) per batch**.

Repositori ini merupakan artefak pendukung penelitian (target publikasi jurnal
terindeks SINTA 2). Dokumentasi disusun agar eksperimen dapat **direproduksi**.

## Arsitektur

```
┌───────────────────────────┐                                  ┌───────────────────────────┐
│   WATCH (Wear OS)         │   service 0000a100…              │   SMARTPHONE (Android)    │
│   Peripheral / GATT server│                                  │   Central / GATT client   │
│                           │  record 0000a101… (NOTIFY)       │                           │
│  • Sensor TYPE_HEART_RATE │ ───────────────────────────────▶ │  • flutter_blue_plus      │
│  • SQLite (synced flag)   │  START │ DATA… │ END(CRC32)      │  • Verifikasi CRC32       │
│  • Advertiser + GATT      │                                  │  • SQLite, unik per       │
│  • Foreground service     │  ack 0000a102… (WRITE)           │    (device_id, record_id) │
│                           │ ◀─────────────────────────────── │  • Foreground service     │
│                           │  {batch_id, expected,            │  • UI real-time           │
│                           │   stored, status}                │                           │
└───────────────────────────┘                                  └───────────────────────────┘
   basic_sensor_heart_rate_                                       heart_rate_phone_receiver
   interval_sqflite_ble
```

Payload tiap batch berupa JSON
`{"device": <device_id>, "records": [{"rid", "bpm", "accuracy", "time"}, …]}`
yang dipecah menjadi frame sesuai MTU:

| Frame | Isi |
|-------|-----|
| `0x01` START | `batch_id` (4) · jumlah frame (2) · panjang payload (4) |
| `0x02` DATA | `seq` (2) · potongan JSON |
| `0x03` END | CRC32 payload (4) |

## Komponen

| Folder | Peran | Bahasa | README |
|--------|-------|--------|--------|
| [`basic_sensor_heart_rate_interval_sqflite_ble/`](basic_sensor_heart_rate_interval_sqflite_ble/) | Watch — pembaca sensor + BLE peripheral | Flutter (`flutter_bloc`) + Kotlin (native GATT) | [README](basic_sensor_heart_rate_interval_sqflite_ble/README.md) |
| [`heart_rate_phone_receiver/`](heart_rate_phone_receiver/) | Smartphone — penerima BLE central | Flutter (`flutter_blue_plus`, `flutter_bloc`) | [README](heart_rate_phone_receiver/README.md) |
| [`sesi/`](sesi/) | Data mentah eksperimen terkendali (CSV, log, ringkasan per sesi) | — | [README](sesi/README.md) |

## Alur kerja singkat

1. **Watch**: pilih interval (3/5 menit) → izinkan sensor, Bluetooth & notifikasi → mulai.
   Foreground service menjaga pemantauan tetap berjalan saat app di-background atau layar mati.
2. Sensor dibaca terus-menerus; **satu pembacaan disimpan tiap detik** ke SQLite
   (`synced = 0`, plus penanda `fresh` bila nilainya berasal dari pembacaan sensor baru).
3. Tiap interval — dan **segera setelah ponsel tersambung kembali** — semua record
   `synced = 0` dikirim sebagai **satu batch** dengan `batch_id` unik.
4. **Smartphone**: scan → connect (MTU 512) → subscribe → merangkai frame →
   verifikasi jumlah frame, panjang & CRC32 → simpan dalam satu transaksi
   (duplikat ditolak indeks unik `(device_id, record_id)`) → tulis **ACK**.
5. **Watch** menandai record `synced = 1` **hanya** bila menerima ACK dengan
   `batch_id` yang sama dan `status == "ok"`. Bila ACK tidak datang dalam 30 detik
   atau berisi status gagal, record tetap `synced = 0` dan dikirim ulang pada flush berikutnya.

## Dua versi pembanding (build flag `AWAIT_ACK`)

Eksperimen membandingkan dua versi watch yang dibangun dari kode yang sama dan
hanya dibedakan oleh satu flag di
[ble_peripheral.dart](basic_sensor_heart_rate_interval_sqflite_ble/lib/ble_peripheral.dart):

```bash
cd basic_sensor_heart_rate_interval_sqflite_ble

# Versi B (default): tandai terkirim setelah ACK yang cocok diterima
flutter build apk --release

# Versi A (awal): tandai terkirim begitu panggilan kirim lokal berhasil,
# tanpa menunggu konfirmasi ponsel
flutter build apk --release --dart-define=AWAIT_ACK=false
```

Versi yang berjalan tercatat di log pada awal tiap sesi
(`HR-METRIC,session_start,await_ack=…`).

## Data & metrik

- Kedua aplikasi dapat **mengekspor CSV dan file `.db`** ke folder Downloads
  (lewat MediaStore). CSV watch dan ponsel dicocokkan lewat `device_id` + `id`/`record_id`.
- Metrik per batch dicetak ke logcat dengan awalan `HR-METRIC` (mis. `flush`:
  `batch_id`, percobaan, jumlah pending, tersimpan, duplikat, status, latensi ACK,
  sisa backlog, waktu pemulihan).

## Lingkungan pengembangan (diuji)

| Komponen | Versi |
|----------|-------|
| Flutter | 3.47.8 (stable) |
| Dart SDK | ^3.11.1 |
| Target | Android (Wear OS untuk watch), Android 12+ direkomendasikan |
| Perangkat eksperimen | Samsung Galaxy Watch4 (SM-R860) + Xiaomi Redmi Note 10 (M2101K6G) |

> BLE **tidak dapat diemulasikan**. Pengujian fungsional & pengumpulan data
> harus dilakukan pada **dua perangkat fisik** (smartwatch + smartphone).

## Build & jalankan

```bash
# Watch (pasang ke smartwatch Wear OS)
cd basic_sensor_heart_rate_interval_sqflite_ble
flutter pub get
flutter run            # pilih perangkat watch

# Smartphone
cd ../heart_rate_phone_receiver
flutter pub get
flutter run            # pilih perangkat ponsel
```

## Status verifikasi

- ✅ Analisis statis: `flutter analyze` bersih di kedua project.
- ✅ Verifikasi end-to-end pada perangkat fisik: dua belas sesi eksperimen
  terkendali (12–14 Agustus 2026), lihat [`sesi/`](sesi/).
