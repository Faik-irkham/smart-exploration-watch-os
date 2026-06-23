# Laporan Progres Penelitian

**Nama:** Faik Irkham
**Tanggal:** 23 Juni 2026
**Topik:** Pemantauan detak jantung dari smartwatch ke smartphone melalui Bluetooth Low Energy (BLE)

---

Pada periode ini saya melanjutkan pengembangan dua aplikasi yang menjadi inti
penelitian, yaitu aplikasi di **smartwatch** yang membaca detak jantung dan
aplikasi di **smartphone** yang menerima datanya melalui Bluetooth. Fokus saya
kali ini adalah menjalankan dan menguji kedua aplikasi tersebut secara langsung
pada perangkat sungguhan, sekaligus melihat sejauh mana sistem dapat diandalkan.

## Yang sudah berjalan

Secara umum sistem sudah dapat bekerja. Smartwatch berhasil membaca detak
jantung, menyimpannya, lalu mengirimkannya ke smartphone melalui Bluetooth, dan
smartphone dapat menerima serta menyimpan data tersebut. Pengujian saya lakukan
pada perangkat fisik (Samsung Galaxy Watch dan Xiaomi Redmi Note 10 Pro), karena
Bluetooth memang tidak bisa diuji menggunakan emulator.

Dalam satu sesi pengujian, smartwatch dapat merekam secara terus-menerus selama
sekitar 36 menit dan menghasilkan 2.167 pembacaan detak jantung. Saya juga
menambahkan pencatatan metrik otomatis (jumlah data, waktu pengiriman, dan
kecepatan) supaya hasilnya bisa diukur secara objektif, serta fitur untuk
mengekspor data ke file CSV agar mudah dianalisis nanti. Dari data yang
**berhasil** diterima smartphone, isinya cocok sepenuhnya dengan catatan di
smartwatch, jadi data yang sampai memang akurat.

*(Tangkapan layar aplikasi smartwatch dan smartphone akan saya lampirkan.)*

## Kendala yang ditemukan

Saat menguji sesi yang lebih panjang, saya menemukan bahwa **tidak semua data
sampai ke smartphone**. Smartwatch merekam 2.167 pembacaan, tetapi smartphone
hanya menerima 1.264 (sekitar 58%), sehingga ada 903 data yang hilang. Setelah
saya telusuri, ternyata smartphone berhenti menerima data di sekitar menit ke-21,
padahal smartwatch tetap merekam sampai menit ke-36.

Saya menduga ada dua penyebab. Pertama, aplikasi penerima di smartphone
kemungkinan dihentikan oleh sistem ketika berpindah ke latar belakang atau saat
layar mati (HP Xiaomi cukup agresif menutup aplikasi yang berjalan di belakang).
Kedua, smartwatch menganggap data sudah terkirim begitu Bluetooth masih
terhubung, tanpa memastikan data benar-benar diterima smartphone; jadi ketika
penerima diam-diam berhenti, data tetap dianggap terkirim dan akhirnya hilang.

Sebagai catatan, pada pengujian singkat sebelumnya pengiriman sempat berhasil
100%. Masalah ini baru muncul pada sesi yang panjang, sehingga menurut saya
penting untuk diperbaiki lebih dulu sebelum masuk ke pengukuran yang sebenarnya.

## Rencana selanjutnya

Langkah terdekat saya adalah memperbaiki keandalan pengiriman pada sesi panjang,
yaitu memastikan aplikasi penerima tetap berjalan di latar belakang dan menambah
mekanisme konfirmasi penerimaan supaya data yang belum sampai akan dikirim ulang
(tidak langsung dianggap selesai). Setelah pengiriman stabil dan mendekati 100%,
saya akan melanjutkan ke pengukuran formal dengan berbagai kondisi (interval
pengiriman, jarak, dan gangguan koneksi), lalu menyusun tabel dan grafik hasilnya
sebagai bahan penulisan artikel.
