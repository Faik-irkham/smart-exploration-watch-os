# Smart Exploration — Heart Rate over BLE (Watch ➜ Smartphone)

Sistem dua-aplikasi untuk merekam detak jantung pada *smartwatch* (Wear OS) dan
mengirimkannya ke *smartphone* (Android) melalui **Bluetooth Low Energy (BLE)**,
dengan penyimpanan lokal SQLite dan pola *store-and-forward*.

Repositori ini merupakan artefak pendukung penelitian (target publikasi jurnal
terindeks SINTA 2). Dokumentasi disusun agar eksperimen dapat **direproduksi**.

## Arsitektur

```
┌──────────────────────────┐         BLE GATT (NOTIFY)        ┌──────────────────────────┐
│   WATCH (Wear OS)         │   service 0000a100…             │   SMARTPHONE (Android)    │
│   Peripheral / GATT server│ ───────────────────────────────▶│   Central / GATT client   │
│                           │   batch JSON ber-frame           │                           │
│  • Sensor TYPE_HEART_RATE │                                  │  • flutter_blue_plus      │
│  • SQLite (synced flag)   │                                  │  • SQLite (riwayat)       │
│  • Advertiser + GATT      │                                  │  • UI real-time           │
└──────────────────────────┘                                  └──────────────────────────┘
   basic_sensor_heart_rate_                                       heart_rate_phone_receiver
   interval_sqflite_ble
```

## Komponen

| Folder | Peran | Bahasa | README |
|--------|-------|--------|--------|
| [`basic_sensor_heart_rate_interval_sqflite_ble/`](basic_sensor_heart_rate_interval_sqflite_ble/) | Watch — pembaca sensor + BLE peripheral | Flutter + Kotlin (native GATT) | [README](basic_sensor_heart_rate_interval_sqflite_ble/README.md) |
| [`heart_rate_phone_receiver/`](heart_rate_phone_receiver/) | Smartphone — penerima BLE central | Flutter (`flutter_blue_plus`) | [README](heart_rate_phone_receiver/README.md) |

## Alur kerja singkat

1. **Watch**: pilih interval (3/5 menit) → izinkan sensor & Bluetooth → mulai.
2. Sensor dibaca terus-menerus; **satu pembacaan valid disimpan tiap detik** ke SQLite (`synced = 0`).
3. Tiap interval, semua record `synced = 0` dikirim sebagai **satu batch** JSON ke ponsel; yang berhasil terkirim ditandai `synced = 1`.
4. **Smartphone**: scan → connect → subscribe → merangkai batch → simpan ke SQLite → tampilkan.

## Dokumentasi

- **[docs/BLE_PROTOCOL.md](docs/BLE_PROTOCOL.md)** — spesifikasi protokol BLE (UUID, framing, opcode, MTU, store-and-forward). Wajib dibaca untuk menjaga kedua sisi tetap sinkron.
- **[docs/EXPERIMENT.md](docs/EXPERIMENT.md)** — desain eksperimen, metrik, dan prosedur verifikasi data untuk paper.

## Lingkungan pengembangan (diuji)

| Komponen | Versi |
|----------|-------|
| Flutter | 3.41.4 (stable) |
| Dart SDK | ^3.11.1 |
| Target | Android (Wear OS untuk watch), Android 12+ direkomendasikan |

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
- ⚠️ Verifikasi end-to-end (BLE di udara) memerlukan perangkat fisik — lihat [docs/EXPERIMENT.md](docs/EXPERIMENT.md).
