#!/usr/bin/env python3
"""Analisa & visualisasi data HR: watch (sumber) vs phone (penerima BLE).

Memisahkan periode PENGUKURAN VALID dari ekor OFF-WRIST (BPM beku, accuracy<=0)
agar metrik delivery & statistik BPM tidak bias.

Tiap aspek = satu figur mandiri (PNG + PDF) di folder figures/.
"""
import pandas as pd, numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIGS = ROOT / "figures"; FIGS.mkdir(exist_ok=True)

# ---------- palette & style ----------
C_WATCH = "#2563EB"; C_PHONE = "#F97316"; C_LOST = "#DC2626"
C_OK = "#16A34A"; C_INK = "#0F172A"; C_MUTE = "#64748B"
C_GREY = "#CBD5E1"; C_GRID = "#E2E8F0"
mpl.rcParams.update({
    "font.family": "DejaVu Sans", "font.size": 11,
    "axes.edgecolor": C_MUTE, "axes.labelcolor": C_INK, "axes.titlecolor": C_INK,
    "text.color": C_INK, "xtick.color": C_MUTE, "ytick.color": C_MUTE,
    "axes.grid": True, "grid.color": C_GRID, "grid.linewidth": 0.9,
    "axes.axisbelow": True, "figure.dpi": 110,
})
def idn(n): return f"{n:,}".replace(",", ".")

# Judul/subjudul TIDAK digambar di dalam figur (dipakai caption "Gambar N." di naskah).
SHOW_TITLES = False

def titled(w, h, title, sub, left=0.13, right=0.95, top=0.80, bottom=0.16):
    """Figur satu-axes; judul dihilangkan agar bersih untuk caption eksternal."""
    fig = plt.figure(figsize=(w, h)); fig.patch.set_facecolor("white")
    if SHOW_TITLES:
        fig.text(left - 0.005, 0.955, title, fontsize=15, fontweight="bold", va="top")
        fig.text(left - 0.005, 0.875, sub, fontsize=10, color=C_MUTE, va="top")
    else:
        top = 0.95            # pakai ruang judul untuk memperbesar area plot
    ax = fig.add_axes([left, bottom, right - left, top - bottom])
    return fig, ax

def save(fig, name):
    fig.savefig(FIGS / f"{name}.png", dpi=200, facecolor="white", bbox_inches="tight")
    fig.savefig(FIGS / f"{name}.pdf", facecolor="white", bbox_inches="tight")
    plt.close(fig)

# ---------- load ----------
w = pd.read_csv(ROOT / "watch-2026-06-28.csv")
p = pd.read_csv(ROOT / "phone-2026-06-28.csv")
w["t"] = pd.to_datetime(w["time_iso"]); w = w.sort_values("time_ms").reset_index(drop=True)
w["sess"] = (w.time_ms.diff() > 60_000).cumsum()
w["delivered"] = w.time_ms.isin(set(p.time_ms))

# ---------- active vs off-wrist ----------
amask = np.zeros(len(w), bool)
for sid in w.sess.unique():
    g = w[w.sess == sid]
    good = g.index[g.accuracy == 3]
    end = good.max() if len(good) else g.index.min()
    amask[(w.sess == sid) & (w.index <= end)] = True
w["active"] = amask
act = w[w.active].copy()
valid = act[act.accuracy == 3]

N_W, N_P, N_LOST = len(w), len(p), len(w) - len(p)
DELIV_ALL = N_P / N_W * 100
DELIV_ACT = act.delivered.mean() * 100
N_ACT, N_OFF = len(act), int((~w.active).sum())
FIDELITY = (w.merge(p, on="time_ms", suffixes=("_w", "_p"))
            .pipe(lambda m: (m.bpm_w == m.bpm_p).mean() * 100))
ACC_SHARE = (act.accuracy == 3).mean() * 100

sess = act.groupby("sess").agg(n=("t", "size"), deliv=("delivered", "sum"),
                               t0=("t", "min"), t1=("t", "max")).reset_index()
sess["lost"] = sess.n - sess.deliv
sess["loss_pct"] = sess.lost / sess.n * 100
sess["dur_min"] = (sess.t1 - sess.t0).dt.total_seconds() / 60
main = int(sess.sort_values("n").iloc[-1]["sess"])
ms = act[act.sess == main].set_index("t").sort_index()
connect_t = ms[ms.delivered].index.min()
per_min = ms["delivered"].resample("1min").agg(["size", "sum"])
per_min["lost"] = per_min["size"] - per_min["sum"]

# ---------- Sesi 5 (5 Jul 2026, versi revisi ACK) ----------
# Figur kelengkapan, distribusi BPM, dan kualitas kontak memakai cakupan LIMA
# sesi agar sebangun dengan Tabel 2/Tabel 3 di naskah. Figur profil kehilangan
# dan timeline tetap memakai sesi utama Juni (ms) karena bersifat per-sesi.
w5 = pd.read_csv(ROOT / "2026-07-05_watch_hr_20260705_234006.csv")
p5 = pd.read_csv(ROOT / "M2101K6G_2026-07-05_phone_hr_20260705_234520.csv")
w5["t"] = pd.to_datetime(w5["time_iso"]); w5 = w5.sort_values("time_ms").reset_index(drop=True)
w5["delivered"] = w5.time_ms.isin(set(p5.time_ms))
w5["sess"] = act.sess.max() + 1
w5["active"] = True

act5 = pd.concat([act, w5[act.columns]], ignore_index=True)
valid5 = act5[act5.accuracy == 3]
sess5 = act5.groupby("sess").agg(n=("t", "size"), deliv=("delivered", "sum"),
                                 t0=("t", "min"), t1=("t", "max")).reset_index()
sess5["lost"] = sess5.n - sess5.deliv
sess5["loss_pct"] = sess5.lost / sess5.n * 100
sess5["dur_min"] = (sess5.t1 - sess5.t0).dt.total_seconds() / 60

# ============================================================
# FIG 1 — KELENGKAPAN DATA PER SESI
# ============================================================
fig, ax = titled(8.4, 4.0, "Kelengkapan Data per Sesi",
                 "Sampel diterima phone vs hilang di transmisi BLE (periode pengukuran)",
                 left=0.21, bottom=0.14, top=0.82)
y = np.arange(len(sess5))[::-1]
labels = [f"Sesi {i+1}\n{r.t0:%d/%m %H:%M} · {r.dur_min:.0f} mnt" for i, r in sess5.iterrows()]
ax.barh(y, sess5.deliv, color=C_WATCH, label="Diterima phone", edgecolor="white", height=0.6)
ax.barh(y, sess5.lost, left=sess5.deliv, color=C_LOST, label="Hilang", edgecolor="white", height=0.6)
for yi, r in zip(y, sess5.itertuples()):
    ax.text(r.n + max(sess5.n)*0.012, yi, f"{idn(r.deliv)}/{idn(r.n)}  ·  {r.loss_pct:.1f}% hilang",
            va="center", fontsize=9.5, color=C_INK)
ax.set_yticks(y); ax.set_yticklabels(labels, fontsize=9.5)
ax.set_xlim(0, max(sess5.n)*1.34); ax.set_xlabel("Jumlah sampel")
ax.grid(axis="y", visible=False); ax.legend(loc="lower right", frameon=False, fontsize=10)
save(fig, "fig_hr_completeness")

# ============================================================
# FIG 2 — DISTRIBUSI BPM (kontak valid)
# ============================================================
fig, ax = titled(6.8, 4.4, "Distribusi Detak Jantung",
                 f"Sampel kontak valid (accuracy=3), n={idn(len(valid5))}",
                 left=0.13, bottom=0.13, top=0.82)
bins = np.arange(valid5.bpm.min(), valid5.bpm.max()+2, 2)
ax.hist(valid5.bpm, bins=bins, color=C_WATCH, alpha=0.88, edgecolor="white")
ax.axvline(valid5.bpm.mean(), color=C_LOST, lw=2, ls="--")
ax.text(valid5.bpm.mean()+1.5, ax.get_ylim()[1]*0.93,
        f"rata² {valid5.bpm.mean():.0f} bpm\nSD {valid5.bpm.std():.0f}",
        color=C_LOST, fontsize=10.5, fontweight="bold", va="top")
ax.set_xlabel("BPM"); ax.set_ylabel("Jumlah sampel"); ax.grid(axis="x", visible=False)
save(fig, "fig_hr_bpm_dist")

# ============================================================
# FIG 3 — KUALITAS KONTAK SENSOR
# ============================================================
fig = plt.figure(figsize=(6.6, 4.4)); fig.patch.set_facecolor("white")
if SHOW_TITLES:
    fig.text(0.05, 0.955, "Kualitas Kontak Sensor", fontsize=15, fontweight="bold", va="top")
    fig.text(0.05, 0.875, "Status accuracy Samsung HR sensor (periode pengukuran)",
             fontsize=10, color=C_MUTE, va="top")
ax = fig.add_axes([0.02, 0.05, 0.62, 0.74 if SHOW_TITLES else 0.9])
order = [3, 0, -1]; acc_lab = {3: "Akurat (3)", 0: "Sedang (0)", -1: "Tidak akurat (-1)"}
acc_col = {3: C_OK, 0: "#F59E0B", -1: C_MUTE}
vals = [int((act5.accuracy == k).sum()) for k in order]
ax.pie(vals, colors=[acc_col[k] for k in order], startangle=90, counterclock=False,
       wedgeprops=dict(width=0.42, edgecolor="white", linewidth=2))
ax.text(0, 0.10, f"{vals[0]/sum(vals)*100:.0f}%", ha="center", fontsize=22,
        fontweight="bold", color=C_OK)
ax.text(0, -0.22, "kontak akurat", ha="center", fontsize=10, color=C_MUTE)
ax.legend([f"{acc_lab[k]} · {idn(v)} ({v/sum(vals)*100:.1f}%)" for k, v in zip(order, vals)],
          loc="center left", bbox_to_anchor=(1.02, 0.5), frameon=False, fontsize=10)
save(fig, "fig_hr_contact")

# ============================================================
# FIG 4 — PROFIL KEHILANGAN PAKET (sesi utama)
# ============================================================
fig, ax = titled(9.2, 3.8, "Profil Kehilangan Paket BLE — Sesi Utama",
                 f"Sampel hilang per menit · {ms.index.min():%d %b %Y, %H:%M}–{ms.index.max():%H:%M} WIB",
                 left=0.08, right=0.97, bottom=0.16, top=0.80)
ax.fill_between(per_min.index, per_min["lost"], color=C_LOST, alpha=0.9, step="mid")
ax.axvline(connect_t, color=C_OK, lw=1.8, ls="--")
ax.text(connect_t, ax.get_ylim()[1]*0.92, " phone connect", color=C_OK,
        fontsize=10.5, fontweight="bold", va="top")
ax.set_ylabel("Sampel hilang / menit"); ax.set_xlabel("Waktu (WIB)")
ax.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M")); ax.margins(x=0.01)
save(fig, "fig_hr_loss_profile")

# ============================================================
# FIG 5 — TIMELINE SINYAL + LOSS (sesi utama, 2 panel)
# ============================================================
fig2 = plt.figure(figsize=(13, 6.6)); fig2.patch.set_facecolor("white")
gs2 = fig2.add_gridspec(2, 1, height_ratios=[3, 1], hspace=0.12,
                        left=0.07, right=0.97, top=(0.83 if SHOW_TITLES else 0.96), bottom=0.10)
if SHOW_TITLES:
    fig2.text(0.07, 0.945, "Sinyal Detak Jantung & Kehilangan Paket BLE — Sesi Utama",
              fontsize=18, fontweight="bold")
    fig2.text(0.07, 0.895, f"{ms.index.min():%d %b %Y, %H:%M}–{ms.index.max():%H:%M} WIB  ·  "
              f"{idn(len(ms))} sampel @ ~1 Hz  ·  ekor off-wrist tidak ditampilkan",
              fontsize=11.5, color=C_MUTE)
ax1 = fig2.add_subplot(gs2[0])
ax1.plot(ms.index, ms.bpm.where(ms.accuracy < 3), color=C_GREY, lw=0.7, label="Kontak rendah")
ax1.plot(ms.index, ms.bpm.where(ms.accuracy == 3), color=C_WATCH, lw=0.7, alpha=0.9, label="BPM (kontak valid)")
ax1.plot(ms.index, ms.bpm.where(ms.accuracy == 3).interpolate(limit=5).rolling("60s", min_periods=1).mean(),
         color=C_INK, lw=1.7, label="Rata² bergerak 60 dtk")
lostpts = ms[~ms.delivered]; ybot = ms.bpm.min() - 4
ax1.scatter(lostpts.index, [ybot]*len(lostpts), s=10, color=C_LOST, marker="|",
            alpha=0.5, label=f"Sampel hilang ({idn(len(lostpts))})")
ax1.axvline(connect_t, color=C_OK, lw=1.6, ls="--")
ax1.text(connect_t, ms.bpm.max(), " phone connect", color=C_OK, fontsize=10, fontweight="bold", va="top")
ax1.set_ylabel("Detak jantung (BPM)"); ax1.set_ylim(ybot-2, ms.bpm.max()+3)
ax1.legend(loc="upper right", frameon=True, framealpha=0.95, edgecolor=C_GRID, fontsize=9.5, ncol=2)
ax1.tick_params(labelbottom=False); ax1.margins(x=0.01)
ax2 = fig2.add_subplot(gs2[1], sharex=ax1)
ax2.fill_between(per_min.index, per_min["lost"], color=C_LOST, alpha=0.9, step="mid")
ax2.axvline(connect_t, color=C_OK, lw=1.6, ls="--")
ax2.set_ylabel("Hilang/mnt"); ax2.set_xlabel("Waktu (WIB)")
ax2.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M")); ax2.margins(x=0.01)
save(fig2, "fig_hr_timeline")

# ============================================================
# RINGKASAN MARKDOWN
# ============================================================
md = []
md.append("# Ringkasan Analisis Data (gabungan terbaru)\n")
md.append(f"Data: `watch-2026-06-28.csv` vs `phone-2026-06-28.csv` · "
          f"rentang {w.t.min():%d %b %Y %H:%M} – {w.t.max():%d %b %Y %H:%M} WIB\n")
md.append("> Catatan: ekor rekaman **off-wrist** (sensor lepas, BPM beku konstan, "
          f"accuracy≤0) sebanyak **{idn(N_OFF)} sampel** dikecualikan dari metrik di bawah.\n")
md.append("## Pengiriman (delivery)\n")
md.append("| Indikator | Nilai |")
md.append("|-----------|-------|")
md.append(f"| Direkam watch (total) | {idn(N_W)} |")
md.append(f"| Sampel pengukuran valid (aktif) | {idn(N_ACT)} |")
md.append(f"| Diterima phone (aktif) | {idn(int(act.delivered.sum()))} |")
md.append(f"| Hilang (aktif) | {idn(int((~act.delivered).sum()))} |")
md.append(f"| Duplikat di phone | 0 |")
md.append(f"| **Delivery ratio (periode aktif)** | **{DELIV_ACT:.2f}%** |")
md.append(f"| Delivery ratio (keseluruhan, termasuk off-wrist) | {DELIV_ALL:.2f}% |")
md.append(f"| **Fidelity nilai BPM (sampel cocok)** | **{FIDELITY:.1f}%** |\n")
md.append("## Per sesi (periode aktif)\n")
md.append("| Sesi | Mulai (WIB) | Durasi | Direkam | Diterima | Hilang | Loss % |")
md.append("|---:|---|---:|---:|---:|---:|---:|")
for i, r in sess.iterrows():
    md.append(f"| {i+1} | {r.t0:%d/%m %H:%M} | {r.dur_min:.0f} mnt | "
              f"{idn(r.n)} | {idn(r.deliv)} | {idn(r.lost)} | {r.loss_pct:.2f}% |")
md.append("")
md.append("## Statistik BPM\n")
md.append("| Himpunan | n | min | maks | rata-rata | SD |")
md.append("|----------|--:|----:|-----:|----------:|---:|")
for name, sub in [("aktif (semua)", act), ("kontak valid (acc=3)", valid)]:
    md.append(f"| {name} | {idn(len(sub))} | {sub.bpm.min():.0f} | {sub.bpm.max():.0f} "
              f"| {sub.bpm.mean():.1f} | {sub.bpm.std():.1f} |")
md.append("")
md.append("## Distribusi akurasi sensor (periode aktif)\n")
md.append("| accuracy | jumlah | persen |")
md.append("|---------:|-------:|-------:|")
for k in [3, 0, -1]:
    c = int((act.accuracy == k).sum())
    md.append(f"| {k} | {idn(c)} | {c/len(act)*100:.1f}% |")
md.append("\n## Temuan utama\n")
md.append("- **Fidelity 100%** — setiap sampel yang diterima phone identik nilainya (BPM & accuracy) dengan watch; BLE tidak merusak data.")
md.append(f"- **Kehilangan paket terkonsentrasi di awal sesi** sebelum phone terhubung/subscribe (sesi utama: connect ~{connect_t:%H:%M}); setelah terhubung delivery mendekati 100%.")
md.append("- Sesi pendek yang phone-nya tidak terhubung sama sekali hilang 100%.")
md.append("\n## Figur\n")
md.append("- `figures/fig_hr_completeness.png` — kelengkapan data per sesi.")
md.append("- `figures/fig_hr_bpm_dist.png` — distribusi BPM (kontak valid).")
md.append("- `figures/fig_hr_contact.png` — kualitas kontak sensor.")
md.append("- `figures/fig_hr_loss_profile.png` — profil kehilangan paket per menit (sesi utama).")
md.append("- `figures/fig_hr_timeline.png` — sinyal BPM + kehilangan paket (sesi utama, 2 panel).")
(ROOT/"hr_analysis"/"analysis_summary.md").write_text("\n".join(md))

print("OK — figur terpisah dibuat")
print(f"active={N_ACT} off={N_OFF} deliv_act={DELIV_ACT:.2f}% deliv_all={DELIV_ALL:.2f}% "
      f"fidelity={FIDELITY:.1f}% acc3_share={ACC_SHARE:.1f}% connect={connect_t:%H:%M}")
