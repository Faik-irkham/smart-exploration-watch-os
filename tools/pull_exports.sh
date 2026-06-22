#!/usr/bin/env bash
#
# Tarik file EKSPOR terbaru dari folder Downloads kedua device (build RELEASE,
# tanpa root). Pakai setelah menekan "Export CSV"/"Export .db" di tiap app.
#
# Pakai:
#   bash tools/pull_exports.sh <SERIAL_WATCH> <SERIAL_PHONE> [OUT_DIR]
# Contoh:
#   bash tools/pull_exports.sh 192.168.1.23:43455 192.168.1.15:41907 ~/hr_data
set -u

WATCH="${1:-192.168.1.23:43455}"
PHONE="${2:-192.168.1.15:41907}"
OUT_DIR="${3:-$HOME/hr_data}"
mkdir -p "$OUT_DIR"

# pull_latest <serial> <glob> <local_out>
pull_latest() {
  local serial="$1" glob="$2" out="$3"
  local remote
  remote=$(adb -s "$serial" shell "ls -1t $glob" 2>/dev/null | tr -d '\r' | head -1)
  if [ -z "$remote" ] || echo "$remote" | grep -q "No such file"; then
    echo "  (tidak ada file $glob di $serial)"
    return 1
  fi
  adb -s "$serial" pull "$remote" "$out" >/dev/null 2>&1 \
    && echo "  ✓ $(basename "$remote") → $out"
}

echo "→ Watch ($WATCH)"
pull_latest "$WATCH" "/sdcard/Download/watch_hr_*.db"  "$OUT_DIR/watch.db"
pull_latest "$WATCH" "/sdcard/Download/watch_hr_*.csv" "$OUT_DIR/watch.csv"
echo "→ Phone ($PHONE)"
pull_latest "$PHONE" "/sdcard/Download/phone_hr_*.db"  "$OUT_DIR/phone.db"
pull_latest "$PHONE" "/sdcard/Download/phone_hr_*.csv" "$OUT_DIR/phone.csv"

echo
echo "=== Hasil ($OUT_DIR) ==="
if [ -s "$OUT_DIR/watch.db" ] && [ -s "$OUT_DIR/phone.db" ]; then
  w_total=$(sqlite3 "$OUT_DIR/watch.db" 'SELECT COUNT(*) FROM readings;')
  w_synced=$(sqlite3 "$OUT_DIR/watch.db" 'SELECT COUNT(*) FROM readings WHERE synced=1;')
  p_total=$(sqlite3 "$OUT_DIR/phone.db" 'SELECT COUNT(*) FROM readings;')
  missing=$(sqlite3 "$OUT_DIR/watch.db" "ATTACH '$OUT_DIR/phone.db' AS p; \
    SELECT COUNT(*) FROM readings w \
    WHERE NOT EXISTS (SELECT 1 FROM p.readings ph WHERE ph.time = w.time);")
  echo "watch total   : $w_total"
  echo "watch synced  : $w_synced"
  echo "phone total   : $p_total"
  echo "hilang (watch tak ada di phone): $missing"
  if [ "${w_total:-0}" -gt 0 ]; then
    awk -v t="$w_total" -v m="$missing" \
      'BEGIN { printf "delivery ratio: %.2f%% (%d/%d)\n", (t-m)*100.0/t, t-m, t }'
  fi
else
  echo "DB watch/phone belum lengkap — pastikan sudah tekan Export .db di kedua app."
fi
