#!/usr/bin/env python3
"""Analisis hasil ekspor CSV (watch & phone) untuk laporan/paper.

Menghitung delivery ratio (cocok via kolom time_ms), distribusi akurasi,
statistik BPM, dan durasi sesi. Mencetak ringkasan teks + tabel Markdown, dan
(jika matplotlib tersedia) membuat grafik PNG.

Pakai:
    python3 tools/analyze.py watch.csv phone.csv [OUT_DIR]

Tidak butuh dependensi selain pustaka standar. Untuk grafik:  pip install matplotlib
"""
import csv
import statistics
import sys
from pathlib import Path


def read_csv(path):
    rows = []
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            rows.append(r)
    return rows


def to_float(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def to_int(x):
    try:
        return int(float(x))
    except (TypeError, ValueError):
        return None


def bpm_stats(rows, valid_only=False):
    vals = []
    for r in rows:
        acc = to_int(r.get("accuracy"))
        if valid_only and acc is not None and acc < 1:
            continue  # buang -1 (tanpa kontak) & 0 (tak dipercaya)
        b = to_float(r.get("bpm"))
        if b is not None and b > 0:
            vals.append(b)
    if not vals:
        return None
    return {
        "n": len(vals),
        "min": min(vals),
        "max": max(vals),
        "mean": statistics.fmean(vals),
        "sd": statistics.pstdev(vals) if len(vals) > 1 else 0.0,
    }


def accuracy_dist(rows):
    dist = {}
    for r in rows:
        acc = r.get("accuracy")
        dist[acc] = dist.get(acc, 0) + 1
    return dist


def duration_str(rows):
    ts = sorted(t for t in (to_int(r.get("time_ms")) for r in rows) if t)
    if not ts:
        return "-", None, None
    sec = (ts[-1] - ts[0]) / 1000.0
    return f"{sec/60:.1f} menit", ts[0], ts[-1]


def main():
    if len(sys.argv) < 3:
        print("Pakai: python3 tools/analyze.py watch.csv phone.csv [OUT_DIR]")
        sys.exit(1)
    watch_path, phone_path = sys.argv[1], sys.argv[2]
    out_dir = Path(sys.argv[3]) if len(sys.argv) > 3 else Path(".")
    out_dir.mkdir(parents=True, exist_ok=True)

    watch = read_csv(watch_path)
    phone = read_csv(phone_path)

    w_times = [to_int(r.get("time_ms")) for r in watch if to_int(r.get("time_ms"))]
    p_times = [to_int(r.get("time_ms")) for r in phone if to_int(r.get("time_ms"))]
    p_set = set(p_times)

    w_total = len(watch)
    p_total = len(phone)
    w_synced = sum(1 for r in watch if to_int(r.get("synced")) == 1)
    matched = sum(1 for t in w_times if t in p_set)
    missing = w_total - matched
    dup_phone = len(p_times) - len(p_set)
    delivery = (matched / w_total * 100) if w_total else 0.0

    w_dur, _, _ = duration_str(watch)
    p_dur, _, _ = duration_str(phone)

    lines = []
    lines.append("# Ringkasan Analisis Data\n")
    lines.append("## Pengiriman (delivery)\n")
    lines.append("| Indikator | Nilai |")
    lines.append("|-----------|-------|")
    lines.append(f"| Durasi sesi (watch) | {w_dur} |")
    lines.append(f"| Direkam watch | {w_total} |")
    lines.append(f"| Ditandai terkirim (synced) | {w_synced} |")
    lines.append(f"| Diterima phone | {p_total} |")
    lines.append(f"| Cocok (via time) | {matched} |")
    lines.append(f"| Hilang | {missing} |")
    lines.append(f"| Duplikat di phone | {dup_phone} |")
    lines.append(f"| **Delivery ratio** | **{delivery:.2f}%** |")
    lines.append("")

    lines.append("## Distribusi akurasi sensor (watch)\n")
    lines.append("| accuracy | jumlah | persen |")
    lines.append("|---------:|-------:|-------:|")
    for k in sorted(accuracy_dist(watch), key=lambda x: to_int(x) if to_int(x) is not None else 99):
        c = accuracy_dist(watch)[k]
        lines.append(f"| {k} | {c} | {c/w_total*100:.1f}% |")
    lines.append("")

    s_all = bpm_stats(watch)
    s_valid = bpm_stats(watch, valid_only=True)
    lines.append("## Statistik BPM (watch)\n")
    lines.append("| Himpunan | n | min | maks | rata-rata | SD |")
    lines.append("|----------|--:|----:|-----:|----------:|---:|")
    if s_all:
        lines.append(f"| semua | {s_all['n']} | {s_all['min']:.0f} | {s_all['max']:.0f} | {s_all['mean']:.1f} | {s_all['sd']:.1f} |")
    if s_valid:
        lines.append(f"| akurasi≥1 | {s_valid['n']} | {s_valid['min']:.0f} | {s_valid['max']:.0f} | {s_valid['mean']:.1f} | {s_valid['sd']:.1f} |")
    lines.append("")

    report = "\n".join(lines)
    print(report)
    md_path = out_dir / "analysis_summary.md"
    md_path.write_text(report)
    print(f"\n(Ringkasan ditulis ke {md_path})")

    # --- Grafik (opsional) ---
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("(matplotlib tidak terpasang — lewati grafik. `pip install matplotlib` untuk mengaktifkan.)")
        return

    # 1) BPM watch sepanjang waktu (akurasi≥1)
    pts = []
    for r in watch:
        t = to_int(r.get("time_ms"))
        b = to_float(r.get("bpm"))
        a = to_int(r.get("accuracy"))
        if t and b and (a is None or a >= 1):
            pts.append((t, b))
    pts.sort()
    if pts:
        t0 = pts[0][0]
        xs = [(t - t0) / 60000.0 for t, _ in pts]
        ys = [b for _, b in pts]
        plt.figure(figsize=(8, 3))
        plt.plot(xs, ys, linewidth=0.8)
        plt.xlabel("Menit"); plt.ylabel("BPM"); plt.title("Detak jantung sepanjang sesi (watch)")
        plt.tight_layout(); plt.savefig(out_dir / "bpm_timeline.png", dpi=150); plt.close()

    # 2) Delivery: cocok vs hilang
    plt.figure(figsize=(4, 4))
    plt.bar(["Cocok", "Hilang"], [matched, missing], color=["#2e7d32", "#c62828"])
    plt.title(f"Delivery ratio {delivery:.1f}%"); plt.ylabel("Jumlah record")
    plt.tight_layout(); plt.savefig(out_dir / "delivery.png", dpi=150); plt.close()

    print(f"(Grafik PNG ditulis ke {out_dir}/bpm_timeline.png & delivery.png)")


if __name__ == "__main__":
    main()
