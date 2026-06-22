# basic_sensor_heart_rate_interval

Aplikasi Wear OS untuk membaca detak jantung (heart rate) lewat sensor tubuh,
dengan **interval pembacaan yang dapat dipilih: 1 menit, 3 menit, atau 5 menit**.

Merupakan pengembangan dari proyek `basic_sensor_heart_rate` — bedanya, sensor
tidak menyala terus-menerus. Pada mode interval, sensor hanya diaktifkan sebentar
setiap N menit untuk mengambil satu pembacaan valid lalu dimatikan lagi agar
hemat baterai.

## Cara kerja

- **Dart (`lib/main.dart`)** — UI memilih interval, meminta izin `BODY_SENSORS`,
  lalu menjalankan `Timer.periodic` sesuai interval. Setiap siklus mendengarkan
  `EventChannel('heart_rate/stream')` hingga mendapat satu pembacaan valid
  (bpm > 0 dan akurasi minimal "rendah"), menyimpannya ke riwayat, lalu
  membatalkan stream. Ada hitung mundur ke pembacaan berikutnya.
- **Kotlin (`MainActivity.kt`)** — `HeartRateStreamHandler` mendaftarkan listener
  `Sensor.TYPE_HEART_RATE` saat Dart mulai mendengarkan dan melepasnya saat
  dibatalkan.

## Izin & konfigurasi

- `android.permission.BODY_SENSORS` (diminta saat runtime via `permission_handler`).
- Ditandai sebagai aplikasi Wear OS standalone di `AndroidManifest.xml`.

## Menjalankan

```bash
flutter pub get
flutter run   # pada perangkat / emulator Wear OS
```
