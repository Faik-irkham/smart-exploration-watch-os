# Laporan Progres Penelitian

**Nama:** Faik Irkham
**Tanggal:** 23 Juni 2026
**Topik:** Sistem pemantauan detak jantung dari smartwatch ke smartphone melalui Bluetooth Low Energy (BLE)

---

## 1. Tujuan (ringkas)

Membangun dua aplikasi: aplikasi di **smartwatch** membaca detak jantung lalu
mengirimkannya ke aplikasi di **smartphone** melalui Bluetooth (BLE), dengan
upaya agar **data tidak hilang** walau koneksi sempat terputus.

## 2. Perangkat uji

| Peran | Perangkat | OS |
|-------|-----------|-----|
| Pengirim | Samsung Galaxy Watch (SM-R860) | Wear OS |
| Penerima | Xiaomi Redmi Note 10 Pro | Android 13 |

Pengujian dilakukan pada **perangkat fisik** (Bluetooth tidak bisa diuji di emulator).

---

## 3. Yang sudah BERHASIL ✅

1. **Koneksi & pengiriman data dua arah** antara smartwatch dan smartphone
   berjalan (scan → connect → kirim data).
2. **Perekaman jangka panjang**: dalam satu sesi, smartwatch merekam **2.167
   pembacaan** detak jantung selama **± 36 menit** tanpa henti.
3. **Penyimpanan lokal** di kedua perangkat (basis data) berfungsi.
4. **Pencatatan metrik otomatis** (jumlah data, waktu kirim, kecepatan) sudah
   aktif sehingga hasil dapat diukur secara objektif.
5. **Fitur ekspor data** ke format CSV dan basis data berhasil — data percobaan
   dapat diambil dari kedua perangkat untuk dianalisis.
6. **Kesesuaian data terbukti pada data yang berhasil diterima**: seluruh 1.264
   pembacaan yang sampai di smartphone **identik** dengan catatan di smartwatch
   (dicocokkan berdasarkan waktu pencatatan).

*(Lampiran tangkapan layar: aplikasi smartwatch saat merekam, aplikasi
smartphone saat menerima — akan dilampirkan.)*

## 4. Yang BELUM BERHASIL / perlu diperbaiki ⚠️

Pada sesi uji yang lebih lama, ditemukan **kehilangan data**:

| Indikator | Hasil |
|-----------|-------|
| Direkam smartwatch | 2.167 pembacaan (06:38–07:15, ± 36 menit) |
| Diterima smartphone | 1.264 pembacaan (berhenti 07:00, ± 21 menit) |
| **Data hilang** | **903 pembacaan** |
| **Keberhasilan pengiriman (delivery ratio)** | **58,33%** |

**Temuan:** penerima (smartphone) **berhenti menerima di tengah sesi** (sekitar
menit ke-21), sedangkan smartwatch tetap merekam sampai menit ke-36. Akibatnya
data setelah menit ke-21 tidak tersimpan di smartphone.

**Dugaan penyebab (akan diverifikasi):**
1. Aplikasi penerima kemungkinan terhenti/dihentikan sistem saat berpindah ke
   latar belakang atau layar mati (Android Xiaomi cenderung agresif menutup
   aplikasi latar belakang).
2. Smartwatch menandai data sebagai "terkirim" begitu Bluetooth masih terhubung,
   **tanpa konfirmasi** bahwa data benar-benar diterima smartphone. Jika
   penerima diam-diam berhenti, data tetap dianggap terkirim sehingga hilang.

> Catatan: pada uji singkat sebelumnya (satu paket kecil) keberhasilan mencapai
> 100%. Masalah ini baru muncul pada sesi panjang, sehingga penting untuk
> diperbaiki sebelum pengukuran formal.

## 5. Rencana perbaikan & langkah berikutnya

1. **Memastikan aplikasi penerima tetap berjalan** di latar belakang/layar mati
   (mekanisme *foreground service* sudah ditambahkan dan akan diuji ulang).
2. **Menambahkan konfirmasi penerimaan**: smartwatch hanya menandai data
   "terkirim" setelah smartphone memastikan data sudah tersimpan, agar data yang
   belum sampai dikirim ulang (mencegah kehilangan).
3. Mengulang pengujian sesi panjang untuk memastikan delivery ratio mendekati
   100%.
4. Setelah stabil: pengukuran formal dengan variasi (interval, jarak, gangguan
   koneksi) dan pengulangan, lalu menyusun tabel & grafik untuk naskah artikel.

## 6. Status keseluruhan

Pengembangan sistem dan **uji fungsional dasar selesai**. Saat ini fokus pada
**perbaikan keandalan pengiriman jangka panjang** sebelum masuk ke tahap
pengumpulan data untuk analisis.
