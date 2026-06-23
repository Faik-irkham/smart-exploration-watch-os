# Laporan Progres Penelitian

**Nama:** Faik Irkham
**Tanggal:** 23 Juni 2026
**Topik:** Pemantauan detak jantung dari smartwatch ke smartphone melalui Bluetooth Low Energy (BLE)

---

Pada periode ini saya melanjutkan pengembangan dua aplikasi yang menjadi inti
penelitian, yaitu aplikasi di **smartwatch** yang membaca detak jantung dan
aplikasi di **smartphone** yang menerima datanya melalui Bluetooth. Fokus saya
kali ini adalah menjalankan dan menguji kedua aplikasi secara langsung pada
perangkat sungguhan, sekaligus mengukur seberapa andal sistemnya.

## Yang sudah berjalan

Secara keseluruhan sistem sudah dapat bekerja dengan baik. Smartwatch berhasil
membaca detak jantung, menyimpannya, lalu mengirimkannya ke smartphone melalui
Bluetooth, dan smartphone dapat menerima serta menyimpan data tersebut.
Pengujian saya lakukan pada perangkat fisik (Samsung Galaxy Watch dan Xiaomi
Redmi Note 10 Pro), karena Bluetooth memang tidak bisa diuji menggunakan
emulator.

Saya juga menambahkan pencatatan metrik otomatis (jumlah data, waktu pengiriman,
dan kecepatan) supaya hasilnya bisa diukur secara objektif, serta fitur untuk
mengekspor data ke file CSV agar mudah dianalisis.

*(Tangkapan layar aplikasi smartwatch dan smartphone akan saya lampirkan.)*

## Hasil pengujian

Saya menguji sistem dalam satu sesi panjang selama sekitar 36 menit. Hasilnya
cukup memuaskan:

- Smartwatch merekam **2.167** pembacaan detak jantung.
- Sebanyak **2.164** pembacaan berhasil dikirim dan diterima smartphone, dan
  isinya **cocok sepenuhnya** dengan catatan di smartwatch (dicocokkan
  berdasarkan waktu pencatatan).
- **Tingkat keberhasilan pengiriman mencapai sekitar 99,9%**, atau praktis 100%
  dari seluruh data yang sempat dikirim.

Tiga pembacaan terakhir memang belum sampai di smartphone, tetapi itu bukan
karena hilang — data tersebut masih berstatus "belum terkirim" dan akan dikirim
pada giliran berikutnya. Ini justru menunjukkan mekanisme penyimpanan-sementara
(*store-and-forward*) berfungsi sebagaimana mestinya: data yang belum sempat
terkirim tetap aman dan tidak langsung dianggap selesai.

## Catatan

Pada percobaan awal sempat terlihat seolah banyak data tidak sampai, namun
ternyata itu karena saya menarik file datanya sebelum sesi benar-benar selesai.
Setelah diambil ulang dari data yang final, hasilnya sesuai harapan.

## Rencana selanjutnya

Karena pengiriman dasar sudah terbukti andal, langkah berikutnya adalah
melakukan pengukuran yang lebih lengkap dengan berbagai kondisi (interval
pengiriman, jarak antar-perangkat, dan skenario koneksi terputus), serta menguji
sistem saat aplikasi berjalan di latar belakang/layar mati dalam waktu lama.
Hasil pengukuran tersebut kemudian saya susun menjadi tabel dan grafik sebagai
bahan penulisan artikel.
