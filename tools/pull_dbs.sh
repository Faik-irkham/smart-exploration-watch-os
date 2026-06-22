#!/usr/bin/env bash
#
# Tarik database SQLite dari watch & ponsel (build DEBUG), lalu cetak jumlah
# record dan delivery ratio (cocok berdasarkan kolom 'time').
#
# Pakai:
#   bash tools/pull_dbs.sh <SERIAL_WATCH> <SERIAL_PHONE> [OUT_DIR]
# Contoh:
#   bash tools/pull_dbs.sh 192.168.1.23:43455 192.168.1.15:41907 ~/hr_data
#
# Catatan: hanya bekerja pada build DEBUG (run-as). Build release akan ditolak
# dengan "package not debuggable".
set -u

WATCH="${1:-192.168.1.23:43455}"
PHONE="${2:-192.168.1.15:41907}"
OUT_DIR="${3:-$HOME/hr_data}"

WPKG="com.flutfy.basic_sensor_heart_rate_interval_sqflite_ble"
PPKG="com.flutfy.heart_rate_phone_receiver"

mkdir -p "$OUT_DIR"

# pull <serial> <package> <prefix>  → prefix.db (+ -wal/-shm bila ada)
pull() {
  local serial="$1" pkg="$2" prefix="$3"
  echo "→ menarik dari $serial ($pkg)"
  adb -s "$serial" exec-out run-as "$pkg" cat databases/heart_rate.db \
      > "$OUT_DIR/$prefix.db" 2>/dev/null
  # Validasi: file harus berawalan header SQLite. Build RELEASE membuat run-as
  # menolak dan menulis pesan error ke file (bukan database).
  if ! head -c 16 "$OUT_DIR/$prefix.db" 2>/dev/null | grep -q "SQLite format 3"; then
    echo "  GAGAL: app build RELEASE (run-as ditolak) atau db belum ada."
    echo "         Pasang DEBUG dulu:  flutter run -d $serial"
    rm -f "$OUT_DIR/$prefix.db"
    return 1
  fi
  adb -s "$serial" exec-out run-as "$pkg" cat databases/heart_rate.db-wal \
      > "$OUT_DIR/$prefix.db-wal" 2>/dev/null || rm -f "$OUT_DIR/$prefix.db-wal"
  adb -s "$serial" exec-out run-as "$pkg" cat databases/heart_rate.db-shm \
      > "$OUT_DIR/$prefix.db-shm" 2>/dev/null || rm -f "$OUT_DIR/$prefix.db-shm"
  # Gabungkan WAL ke file db utama agar konsisten.
  sqlite3 "$OUT_DIR/$prefix.db" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1
  return 0
}

pull "$WATCH" "$WPKG" watch || exit 1
pull "$PHONE" "$PPKG" phone || exit 1

cd "$OUT_DIR"
echo
echo "=== Hasil ($OUT_DIR) ==="
w_total=$(sqlite3 watch.db 'SELECT COUNT(*) FROM readings;')
w_synced=$(sqlite3 watch.db 'SELECT COUNT(*) FROM readings WHERE synced=1;')
p_total=$(sqlite3 phone.db 'SELECT COUNT(*) FROM readings;')
missing=$(sqlite3 watch.db "ATTACH 'phone.db' AS p; \
  SELECT COUNT(*) FROM readings w \
  WHERE NOT EXISTS (SELECT 1 FROM p.readings ph WHERE ph.time = w.time);")

echo "watch total   : $w_total"
echo "watch synced  : $w_synced"
echo "phone total   : $p_total"
echo "hilang (watch tak ada di phone): $missing"
if [ "$w_total" -gt 0 ]; then
  awk -v t="$w_total" -v m="$missing" \
    'BEGIN { printf "delivery ratio: %.2f%% (%d/%d)\n", (t-m)*100.0/t, t-m, t }'
fi
