/// Format waktu ringkas `dd/MM HH:mm:ss` untuk tampilan riwayat.
String formatDateTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}
