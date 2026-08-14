# Data Sesi Eksperimen Terkendali

Data mentah dua belas sesi yang dilaporkan pada subbagian *Controlled Evaluation
of the Acknowledgement Decision*. Direkam 12–14 Agustus 2026 pada satu pasang
perangkat: smartwatch Samsung Galaxy Watch4 (SM-R860, Wear OS) dan smartphone
Xiaomi Redmi Note 10 (M2101K6G, Android).

## Rancangan

Tiga skenario × dua ulangan × dua versi perangkat lunak. Tiap sesi 20 menit pada
interval pengiriman 3 menit.

| Skenario | Gangguan pada menit 7–12 |
|----------|--------------------------|
| S0 | tidak ada (kontrol) |
| S3 | watch dibawa keluar jangkauan, ponsel ditinggal di tempat |
| S4 | aplikasi penerima dipaksa tutup, Bluetooth tetap menyala |

Nama folder berpola `sesi_<nomor>_<versi>_<skenario>`. Versi **A** adalah versi
awal yang menandai record terkirim begitu panggilan kirim lokal berhasil; versi
**B** menunggu konfirmasi dari ponsel lebih dulu. Keduanya dibedakan satu build
flag, `AWAIT_ACK`, di
[ble_peripheral.dart](../basic_sensor_heart_rate_interval_sqflite_ble/lib/ble_peripheral.dart).

Folder berawalan `_batal_` adalah sesi yang dibatalkan; alasannya ada pada nama
folder. Sesi-sesi itu tidak masuk analisis mana pun, dan disertakan agar seluruh
perekaman yang pernah dilakukan terlihat.

## Isi tiap folder

| Berkas | Isi |
|--------|-----|
| `watch.csv` | seluruh record di basis data watch |
| `phone.csv` | seluruh record yang tersimpan di ponsel |
| `watch.log` | logcat watch selama sesi |
| `phone.log` | logcat ponsel selama sesi |
| `catatan.txt` | catatan operasional: jam mulai, jam gangguan, persentase baterai |
| `analysis_summary.md` | ringkasan per sesi |
| `*.png` | grafik per sesi |

Kolom `watch.csv`: `id`, `device_id`, `bpm`, `accuracy`, `time_ms`, `time_iso`,
`synced`, `fresh`. Kolom `phone.csv`: `id`, `device_id`, `record_id`, `bpm`,
`accuracy`, `time_ms`, `time_iso`.

Pencocokan watch ↔ phone memakai pasangan (`device_id`, `record_id`), bukan
timestamp. `synced = 1` berarti watch menganggap record sudah terkirim; record
yang bertanda demikian tetapi tidak ada di `phone.csv` adalah **kehilangan
senyap**, yaitu besaran yang diukur eksperimen ini.

## Cara memverifikasi angka di naskah

```
python3 tools/agregat.py
```

Menghasilkan tabel per sesi, ringkasan per versi dan skenario, serta uji
berpasangan. Skrip `tools/` tidak disertakan di repositori ini.

## Catatan tentang datanya

**Alamat MAC disamarkan.** Log watch mencatat alamat MAC Bluetooth ponsel pada
tiap peristiwa sambungan. Alamat itu diganti `PERANGKAT-01` karena tidak
diperlukan untuk memverifikasi angka mana pun — analisis memakai `device_id`
yang sudah berupa hash. Urutan peristiwanya tetap utuh.

**Penanda versi di awal sesi tidak selalu tersimpan.** Aplikasi menuliskan
`HR-METRIC,session_start,await_ack=…` setiap kali pemantauan dimulai, tetapi
perekaman logcat sering baru dijalankan setelah aplikasi berjalan, sehingga baris
itu hanya tersisa di `sesi_01` dan `sesi_07`. Versi tiap sesi tetap dapat
diverifikasi dari lognya sendiri lewat kolom status pada baris `HR-METRIC,flush`:
hanya build yang tidak menunggu konfirmasi yang bisa melaporkan `sent_unconfirmed`.
Status itu muncul di keenam sesi A dan tidak satu pun di sesi B.

**`sesi_01` direkam dari binari sebelum flag diganti nama.** Lognya menyebut
`ack_validation=true`, nama flag lama. Perekamannya (12 Agustus 22:06) mendahului
commit `b0ebfe3` yang mengganti `ACK_VALIDATION` menjadi `AWAIT_ACK`. Pada build
lama, `ack_validation=true` menghasilkan perilaku yang identik dengan
`AWAIT_ACK=true`: kedua baris yang diubah commit itu bercabang ke hasil yang sama
saat flag bernilai benar, dan cabang `!awaitAck` yang ditambahkan tidak pernah
dieksekusi. Karena itu `sesi_01` sah sebagai sesi versi B. Sebelas sesi lainnya
direkam dari binari setelah commit tersebut.

**Ketiga sesi `_batal_`** dibatalkan karena riwayat ponsel telanjur dihapus di
tengah sesi (satu sesi) dan karena flag pembanding lama tidak benar-benar
mereproduksi versi awal (dua sesi).

## Data detak jantung

Pembacaan detak jantung di sini adalah data penulis sendiri, yang mengenakan
smartwatch selama perekaman, dan dipublikasikan atas keputusannya sendiri. Data
ini berfungsi sebagai muatan uji untuk mengukur keandalan pengiriman, bukan
pengamatan klinis, dan tidak boleh dipakai untuk tujuan medis apa pun. Tidak ada
subjek lain yang terlibat.
