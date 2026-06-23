# Laporan Progres Penelitian

**Nama:** Faik Irkham
**Tanggal:** 23 Juni 2026
**Topik:** Sistem pemantauan detak jantung dari smartwatch ke smartphone melalui Bluetooth Low Energy (BLE)

---

## 1. Tujuan penelitian (ringkas)

Membangun dua aplikasi yang saling terhubung: aplikasi pada **smartwatch** membaca
detak jantung lalu mengirimkannya ke aplikasi pada **smartphone** melalui Bluetooth
(BLE), dengan jaminan **data tidak hilang** walau koneksi sempat terputus. Sistem
ini menjadi objek pengukuran untuk artikel ilmiah.

## 2. Yang dikerjakan periode ini

1. Menyelesaikan komunikasi data dua arah antara smartwatch dan smartphone, dan
   mengujinya langsung pada **perangkat fisik** (bukan emulator, karena Bluetooth
   tidak dapat diuji di emulator).
2. Menambahkan **pencatatan metrik otomatis** (jumlah data, waktu kirim, kecepatan,
   keberhasilan) agar hasil dapat diukur dan dilaporkan secara objektif.
3. Membuat sistem tetap bekerja **saat aplikasi berjalan di latar belakang atau
   layar mati**, supaya perekaman tidak terputus saat dipakai sehari-hari.
4. Menambahkan fitur **ekspor data** (format CSV dan basis data) agar data hasil
   percobaan mudah diambil dan dianalisis.
5. Merapikan struktur kode agar lebih terorganisir dan mudah dikembangkan.

## 3. Hasil utama & bukti

Pengujian fungsional berhasil: satu paket data berisi **228 pembacaan detak jantung**
terkirim dari smartwatch dan **diterima seluruhnya** oleh smartphone.

| Indikator | Hasil |
|-----------|-------|
| Data terkirim | 228 pembacaan |
| Data diterima | 228 pembacaan |
| **Keberhasilan pengiriman (delivery ratio)** | **100% (tidak ada data hilang)** |
| Waktu pengiriman satu paket | ± 0,3 detik |
| Ukuran data | ± 10,7 KB |

**Artinya:** mekanisme inti penelitian sudah berfungsi dan terbukti andal pada
kondisi normal. Kesesuaian data dicek berdasarkan **waktu pencatatan** tiap
pembacaan, sehingga perhitungan keberhasilan tidak terpengaruh perbedaan jam
antar perangkat.

## 4. Kendala

- Pengujian wajib memakai dua perangkat fisik (Bluetooth tidak bisa diemulasikan).
- Pada smartphone tertentu (mis. Xiaomi/MIUI), sistem operasi cenderung menutup
  aplikasi latar belakang; perlu pengaturan agar tidak dihentikan saat percobaan.

## 5. Rencana berikutnya

1. Pengukuran formal dengan **variasi kondisi**: interval pengiriman (3 vs 5 menit),
   jarak antar-perangkat, dan skenario koneksi terputus.
2. **Pengulangan** tiap kondisi beberapa kali untuk memperoleh rata-rata dan
   simpangan baku.
3. Analisis: keberhasilan pengiriman, waktu/kecepatan transfer, dan konsumsi daya.
4. Menyusun **tabel dan grafik hasil** sebagai bahan naskah artikel.

## 6. Status

Tahap pengembangan sistem dan uji fungsional **selesai**. Tahap berikutnya adalah
**pengumpulan data percobaan** untuk analisis dan penulisan artikel.
