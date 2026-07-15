# Spesifikasi Protokol BLE — Watch ➜ Smartphone

Dokumen ini mendefinisikan protokol komunikasi *Bluetooth Low Energy* (BLE)
antara aplikasi **watch** (`basic_sensor_heart_rate_interval_sqflite_ble`) dan
aplikasi **smartphone** (`heart_rate_phone_receiver`). Tujuannya agar
eksperimen dapat direproduksi dan agar implementasi kedua sisi tetap sinkron.

## 1. Peran perangkat

| Perangkat | Peran BLE | Tugas |
|-----------|-----------|-------|
| Watch (Wear OS) | **Peripheral / GATT server** | Membaca sensor `TYPE_HEART_RATE`, menyimpan ke SQLite, mengiklankan service, mengirim batch data sebagai notifikasi. |
| Smartphone (Android) | **Central / GATT client** | Memindai (scan) service, connect, subscribe ke karakteristik, merangkai batch, menyimpan ke SQLite. |

Watch bersifat *standalone* (`com.google.android.wearable.standalone = true`):
tidak butuh aplikasi pendamping di ponsel untuk berfungsi; data dikirim murni
lewat BLE.

## 2. Identitas GATT

| Elemen | UUID | Properti |
|--------|------|----------|
| Record Service | `0000a100-0000-1000-8000-00805f9b34fb` | Primary service |
| Record Characteristic | `0000a101-0000-1000-8000-00805f9b34fb` | `NOTIFY` |
| CCCD (Client Characteristic Configuration) | `00002902-0000-1000-8000-00805f9b34fb` | `READ` + `WRITE` |

> Konstanta ini wajib identik di kedua sisi:
> - Watch: `HeartRateBleServer.RECORD_SERVICE_UUID` / `RECORD_CHAR_UUID` / `CCCD_UUID` (`MainActivity.kt`).
> - Phone: `BleReceiver.recordServiceUuid` / `recordCharUuid` (`ble_receiver.dart`).

## 3. Advertising

- Mode: `ADVERTISE_MODE_LOW_LATENCY`, `connectable = true`, `timeout = 0` (tanpa batas, dihentikan manual).
- Tx power: `ADVERTISE_TX_POWER_MEDIUM`.
- **Paket utama** berisi *service UUID* (`0000a100…`) agar phone bisa memfilter saat scan (`withServices`).
- **Scan response** berisi nama perangkat (`setIncludeDeviceName`) — dipisah agar paket utama tidak melebihi batas 31 byte.

Phone memfilter scan berdasarkan service UUID, mengambil hasil **pertama** yang
cocok, menghentikan scan, lalu connect.

## 4. Koneksi & MTU

1. Phone `connect()` (timeout 15 s).
2. Phone meminta `requestMtu(512)`. Jika ditolak perangkat, tetap lanjut dengan MTU default (23).
3. Watch menyimpan MTU hasil negosiasi (`onMtuChanged`) untuk menentukan ukuran chunk.
4. Phone `discoverServices()`, mencari Record Characteristic, lalu `setNotifyValue(true)`.
5. Menulis CCCD memicu `onDescriptorWriteRequest` di watch; perangkat ditambahkan ke daftar `subscribers`. Mulai titik ini batch boleh dikirim.

## 5. Format payload (level aplikasi)

Satu **batch** adalah JSON **array** berisi nol/lebih record:

```json
[
  { "bpm": 78.0, "accuracy": 3, "time": 1750662000000 },
  { "bpm": 80.0, "accuracy": 3, "time": 1750662001000 }
]
```

| Field | Tipe | Keterangan |
|-------|------|------------|
| `bpm` | number | Detak jantung (beats per minute). |
| `accuracy` | integer | Akurasi sensor: `0` tidak dapat dipercaya, `1` rendah, `2` sedang, `3` tinggi. |
| `time` | integer | Epoch **milliseconds** waktu pembacaan. Dipakai sebagai timestamp identik di kedua database. |

## 6. Framing (level transport) — wajib karena MTU terbatas

Satu notifikasi BLE tidak cukup memuat batch besar, jadi payload JSON dipecah
menjadi beberapa **frame**. Byte pertama tiap frame adalah **opcode**:

| Opcode | Nilai | Isi frame | Arti |
|--------|-------|-----------|------|
| `OP_START` | `0x01` | (kosong) | Awal batch baru — penerima mengosongkan buffer. |
| `OP_DATA` | `0x02` | `0x02` + potongan byte JSON (UTF-8) | Satu chunk payload. |
| `OP_END` | `0x03` | (kosong) | Akhir batch — penerima merangkai & memproses buffer. |

Ukuran chunk data dihitung dari MTU:

```
chunkSize = max(negotiatedMtu - 3 (header ATT) - 1 (opcode), 18)
```

### Urutan pengiriman satu batch

```
START(0x01)
DATA(0x02 | chunk#1)
DATA(0x02 | chunk#2)
...
END(0x03)
```

### Flow control

Watch mengirim satu frame, lalu menunggu callback `onNotificationSent` sebelum
mengirim frame berikutnya (antrean `sendQueue`). Ini mencegah frame hilang
akibat buffer BLE penuh. Jika perangkat terputus di tengah pengiriman, antrean
dibersihkan dan MTU di-reset ke 23.

## 7. Store-and-forward (desain jaminan kelengkapan)

- Setiap record di watch disimpan ke SQLite dengan kolom `synced = 0`.
- Tiap interval (mis. 3 atau 5 menit), watch mengambil semua record `synced = 0`, mengirimnya sebagai satu batch.
- Record ditandai `synced = 1` **hanya** bila native melaporkan batch diterima (ada subscriber terhubung).
- Jika phone sedang terputus, record seharusnya tetap `synced = 0` dan dikirim
  ulang pada interval berikutnya (desain — lihat keterbatasan di bawah).

> **Keterbatasan yang diketahui (temuan empiris 23–28 Jun 2026):** pada
> praktiknya penandaan `synced = 1` masih dapat terjadi ketika tautan sedang
> terputus, sehingga backlog tidak selalu dikirim ulang setelah tautan pulih.
> Pada periode pengukuran valid, 2.755 dari 2.760 record yang hilang (99,8%)
> berstatus `synced = 1` — termasuk seluruh record satu sesi yang phone-nya
> tidak pernah terhubung. Perbaikan yang direncanakan: tunda `synced = 1`
> sampai ACK benar-benar diterima + pemicu backfill saat rekoneksi. Rincian:
> catatan 4 Juli 2026 dan naskah §3.5.

> Catatan reproduksibilitas: idealnya jumlah record `bpm/time` di SQLite watch
> dan di SQLite phone identik setelah sesi selesai dan semua batch terkirim.
> Lihat [docs/EXPERIMENT.md](EXPERIMENT.md) untuk prosedur verifikasi.

## 8. Penanganan kesalahan

| Kondisi | Perilaku |
|---------|----------|
| Belum ada subscriber saat `sendBatch` | Watch mengembalikan `false`; record tetap `synced = 0`. |
| Bluetooth mati di watch | `emit("error", "Bluetooth tidak aktif")`. |
| Izin BLE belum diberikan | `emit("error", …)`; tidak crash. |
| Frame dengan opcode tak dikenal di phone | Di-log dan diabaikan. |
| JSON gagal di-parse di phone | Di-log (`[RX] gagal parse batch`), batch dibuang. |

## 9. Ringkasan kanal Flutter ⇄ Native (watch)

| Kanal | Tipe | Arah | Fungsi |
|-------|------|------|--------|
| `heart_rate/stream` | EventChannel | Native ➜ Dart | Streaming pembacaan sensor (`bpm`, `accuracy`). |
| `heart_rate/ble` | MethodChannel | Dart ➜ Native | `startAdvertising`, `stopAdvertising`, `sendBatch`, `isConnected`. |
| `heart_rate/ble/status` | EventChannel | Native ➜ Dart | Status BLE (`idle`/`advertising`/`connected`/`error`). |

Di sisi phone, seluruh logika BLE memakai paket Dart `flutter_blue_plus`
(tidak ada kode native khusus).
