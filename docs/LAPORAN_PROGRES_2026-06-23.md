## KOMUNIKASI BLE SMARTWATCH KE SMARTPHONE — PEREKAMAN BERKALA & PENGIRIMAN BATCH (STORE-AND-FORWARD)

Catatan progres ini melanjutkan pengembangan sebelumnya pada komunikasi BLE
antara smartwatch dan smartphone. Pada tahap awal, sistem bekerja secara
*request–response*, yaitu smartphone meminta data dan smartwatch membalas dengan
*snapshot* pembacaan terakhir. Pada tahap ini, arsitektur dikembangkan agar
smartwatch tidak lagi hanya mengirim satu nilai terbaru saat diminta, melainkan
**merekam detak jantung secara berkelanjutan, menyimpannya ke basis data lokal,
lalu mengirimkan seluruh data tersebut secara berkala dalam bentuk paket (batch)**
ke smartphone. Pendekatan ini dipilih agar data yang terkumpul utuh dan tidak
hilang meskipun koneksi sempat terputus, sehingga lebih sesuai untuk kebutuhan
pemantauan jangka panjang.

### Arsitektur Sistem

Arsitektur dibagi menjadi beberapa bagian agar alurnya jelas. Pada sisi
smartwatch, sensor detak jantung dibaca oleh kode native dan diteruskan ke
lapisan Flutter melalui *EventChannel*. Setiap satu pembacaan yang valid disimpan
ke basis data **SQLite** di smartwatch dengan penanda status terkirim (*synced*).
Secara berkala (interval dapat dipilih, misalnya 3 atau 5 menit), seluruh data
yang **belum terkirim** dikumpulkan dan dikirimkan sekaligus ke smartphone
melalui BLE sebagai satu paket. Smartwatch berperan sebagai *peripheral / GATT
server* yang mengiklankan layanannya, sementara smartphone berperan sebagai
*central* yang memindai, terhubung, dan berlangganan (*subscribe*) untuk menerima
paket data.

Karena satu paket berisi banyak pembacaan dan ukurannya melebihi kapasitas satu
notifikasi BLE, paket dipecah menjadi beberapa potongan (*frame*) yang diberi
penanda urutan (awal–isi–akhir) lalu dirangkai kembali secara utuh di smartphone.
Setelah seluruh paket diterima dan disimpan ke basis data SQLite di smartphone,
data yang bersangkutan ditandai sebagai sudah terkirim di smartwatch. Mekanisme
ini disebut *store-and-forward*: data yang belum berhasil dikirim akan tetap
tersimpan dan dikirim ulang pada giliran berikutnya, sehingga tidak ada data yang
hilang akibat koneksi terputus sementara.

Selain itu, kedua aplikasi kini dilengkapi *foreground service* sehingga proses
perekaman dan pengiriman/penerimaan tetap berjalan walaupun aplikasi berada di
latar belakang atau layar dalam keadaan mati.

*[Gambar 1 — Diagram arsitektur sistem (Sensor → Native → Flutter → SQLite → BLE → Smartphone)]*

### Hasil Implementasi

*[Gambar 2 — Antarmuka smartwatch saat memantau detak jantung]*

Gambar di atas menunjukkan antarmuka smartwatch saat mode pemantauan aktif.
Layar menampilkan nilai detak jantung terkini dalam satuan BPM, hitung mundur
menuju pengiriman berikutnya, jumlah data yang belum terkirim, indikator status
koneksi ke ponsel, serta ringkasan riwayat pembacaan terakhir. Smartwatch
merekam satu pembacaan setiap detik dan menyimpannya secara lokal, sehingga data
tetap terkumpul meski belum dikirim.

*[Gambar 3 — Antarmuka smartphone saat menerima data]*

Gambar di atas menunjukkan antarmuka smartphone sebagai penerima. Halaman ini
menampilkan status koneksi ke smartwatch, nilai detak jantung terbaru yang
diterima beserta waktunya, dan daftar **riwayat tersimpan** lengkap dengan
jumlahnya. Setiap paket yang diterima langsung disimpan ke basis data lokal di
smartphone sehingga riwayat data dapat ditelusuri kembali kapan saja.

*[Gambar 4 — Fitur ekspor data ke folder Downloads]*

Untuk keperluan analisis, kedua aplikasi dilengkapi fitur ekspor yang menulis
seluruh isi basis data ke folder Downloads dalam format CSV maupun berkas basis
data. Dengan fitur ini, data hasil percobaan dapat diambil langsung dari
perangkat tanpa memerlukan akses khusus, lalu diolah untuk perhitungan dan
penyusunan grafik.

### Format Data

Setiap paket yang dikirim melalui BLE berisi sekumpulan pembacaan dalam format
JSON, di mana tiap pembacaan memuat nilai detak jantung (`bpm`), tingkat akurasi
sensor (`accuracy`), dan waktu perekaman dalam format *Unix epoch* (`time`).
Contoh isi paket:

```json
[
  { "bpm": 76.0, "accuracy": 3, "time": 1782171536608 },
  { "bpm": 77.0, "accuracy": 3, "time": 1782171537606 }
]
```

Atribut `time` berperan penting untuk menjaga urutan kronologis dan menjamin
keterlacakan data, sekaligus menjadi dasar pencocokan antara data di smartwatch
dan di smartphone. Hasil ekspor CSV memuat kolom `id, bpm, accuracy, time_ms,
time_iso` (ditambah `synced` pada sisi smartwatch), sehingga data siap dianalisis.

### Hasil Pengujian

Pengujian dilakukan langsung pada perangkat fisik (Samsung Galaxy Watch dan
Xiaomi Redmi Note 10 Pro), karena komunikasi Bluetooth tidak dapat diuji
menggunakan emulator. Sistem diuji dalam satu sesi berkelanjutan selama sekitar
36 menit dengan hasil sebagai berikut:

| Indikator | Nilai |
|-----------|-------|
| Durasi sesi | ± 36 menit |
| Data direkam smartwatch | 2.167 pembacaan |
| Data diterima smartphone | 2.164 pembacaan |
| Keberhasilan pengiriman (*delivery ratio*) | ± 99,9% |
| Data belum terkirim (menunggu giliran) | 3 pembacaan |

Seluruh data yang diterima smartphone terbukti **identik** dengan catatan di
smartwatch berdasarkan pencocokan waktu perekaman, sehingga data yang sampai
terjamin akurat. Tiga pembacaan yang belum sampai bukan karena hilang, melainkan
masih berstatus belum terkirim dan akan dikirim pada giliran berikutnya — hal ini
justru menunjukkan mekanisme *store-and-forward* berfungsi sebagaimana mestinya.

*[Gambar 5 — Cuplikan data hasil ekspor (CSV) dari smartwatch dan smartphone]*

### Kesimpulan dan Rencana Selanjutnya

Pada tahap ini, sistem telah mampu merekam detak jantung secara berkelanjutan,
mengirimkannya secara berkala dalam bentuk paket, dan menyimpannya di kedua sisi
dengan tingkat keberhasilan mendekati 100% pada kondisi normal. Mekanisme
*store-and-forward* dan eksekusi di latar belakang telah ditambahkan untuk
menjaga kelengkapan data.

Rencana selanjutnya adalah melakukan pengukuran formal dengan variasi kondisi
(interval pengiriman, jarak antar-perangkat, dan skenario koneksi terputus)
beserta pengulangan, kemudian menyusun tabel dan grafik hasil sebagai bahan
penulisan artikel.
