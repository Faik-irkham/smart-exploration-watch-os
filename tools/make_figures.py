# -*- coding: utf-8 -*-
"""Diagram konseptual untuk paper — gaya monokrom jurnal (lihat
generate_figure1_2phase.py). Disusun agar mudah dibaca: nomor langkah pada
arsitektur, bracket fase pada sequence, inset struktur frame, dan bracket
dua-skala-waktu pada flowchart.

Output ke figures/ (PNG 300 dpi + PDF):
  fig_architecture, fig_sequence, fig_framing, fig_storeforward

Pakai:  python3 tools/make_figures.py [OUT_DIR]
"""
import os
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Polygon, Circle

BLACK = "#000000"
WHITE = "#FFFFFF"
OUT = sys.argv[1] if len(sys.argv) > 1 else "figures"


def terminator(ax, x, y, w, h, label, fs=11):
    ax.add_patch(FancyBboxPatch((x - w / 2, y - h / 2), w, h,
        boxstyle=f"round,pad=0.01,rounding_size={h/2}",
        linewidth=1.5, edgecolor=BLACK, facecolor=WHITE, zorder=5))
    ax.text(x, y, label, fontsize=fs, fontweight="bold",
            ha="center", va="center", color=BLACK, zorder=6)


def box(ax, x, y, w, h, title, fs=10.0):
    ax.add_patch(FancyBboxPatch((x - w / 2, y - h / 2), w, h,
        boxstyle="round,pad=0.01,rounding_size=0.03",
        linewidth=1.4, edgecolor=BLACK, facecolor=WHITE, zorder=2))
    ax.text(x, y, title, fontsize=fs, fontweight="bold",
            ha="center", va="center", color=BLACK, zorder=4)


def diamond(ax, x, y, w, h, title, fs=8.8):
    pts = [(x, y + h / 2), (x + w / 2, y), (x, y - h / 2), (x - w / 2, y)]
    ax.add_patch(Polygon(pts, closed=True, linewidth=1.4,
                         edgecolor=BLACK, facecolor=WHITE, zorder=2))
    ax.text(x, y, title, fontsize=fs, fontweight="bold",
            ha="center", va="center", color=BLACK, zorder=4)


def arrow(ax, x1, y1, x2, y2, lw=1.5, dashed=False):
    style = (0, (5, 3)) if dashed else "solid"
    ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>",
        mutation_scale=15, linewidth=lw, color=BLACK, zorder=4,
        linestyle=style, shrinkA=0, shrinkB=0))


def line(ax, pts, lw=1.4, dashed=False):
    style = (0, (5, 3)) if dashed else "solid"
    ax.plot([p[0] for p in pts], [p[1] for p in pts], linewidth=lw,
            color=BLACK, linestyle=style, zorder=4,
            solid_capstyle="round", solid_joinstyle="round")


def small(ax, x, y, text, ha="center", fs=8.6):
    ax.text(x, y, text, fontsize=fs, fontweight="bold",
            ha=ha, va="center", color=BLACK, zorder=6)


def tag(ax, x, y, text, fs=8.0):
    ax.text(x, y, text, fontsize=fs, style="italic", ha="center", va="center",
            color=BLACK, zorder=6,
            bbox=dict(boxstyle="round,pad=0.30", facecolor=WHITE,
                      edgecolor=BLACK, linewidth=0.8))


def num(ax, x, y, n, r=0.32):
    ax.add_patch(Circle((x, y), r, facecolor=BLACK, edgecolor=BLACK, zorder=7))
    ax.text(x, y, str(n), ha="center", va="center", color=WHITE,
            fontsize=9, fontweight="bold", zorder=8)


def bracket(ax, x, y_top, y_bot, label, side="left", fs=10):
    dx = 0.20 if side == "left" else -0.20
    line(ax, [(x, y_bot), (x, y_top)])
    line(ax, [(x, y_top), (x + dx, y_top)])
    line(ax, [(x, y_bot), (x + dx, y_bot)])
    lx = x - 0.28 if side == "left" else x + 0.28
    ax.text(lx, (y_top + y_bot) / 2, label, rotation=90, ha="center",
            va="center", fontsize=fs, fontweight="bold", color=BLACK)


def new_ax(xlim, ylim, scale=0.62, landscape=False):
    figsize = (11.7, 7.2) if landscape else (xlim * scale, ylim * scale)
    fig, ax = plt.subplots(figsize=figsize, dpi=300)
    ax.set_xlim(0, xlim); ax.set_ylim(0, ylim)
    ax.set_aspect("auto" if landscape else "equal"); ax.axis("off")
    fig.patch.set_facecolor(WHITE)
    return fig, ax


def legend_flow(ax, x, y, dashed_label):
    arrow(ax, x, y, x + 0.9, y)
    ax.text(x + 1.05, y, "flow (solid)", fontsize=9, ha="left", va="center")
    arrow(ax, x + 4.4, y, x + 5.3, y, dashed=True)
    ax.text(x + 5.45, y, dashed_label, fontsize=9, ha="left", va="center")


def save(fig, name):
    os.makedirs(OUT, exist_ok=True)
    fig.savefig(os.path.join(OUT, name + ".png"), dpi=300, bbox_inches="tight",
                facecolor=WHITE)
    fig.savefig(os.path.join(OUT, name + ".pdf"), bbox_inches="tight",
                facecolor=WHITE)
    plt.close(fig)
    print("[OK] saved:", name)


# ---------- 1. arsitektur (dua kolom, alur-U bernomor 1..10) ----------
def fig_architecture():
    fig, ax = new_ax(13, 16.5, landscape=True)
    xW, xP = 3.6, 9.4
    w, h = 3.2, 1.5
    R = [13.4, 11.1, 8.8, 6.5, 4.2]   # baris (atas -> bawah)

    # judul tiap kolom + kotak pengelompok tipis
    ax.add_patch(FancyBboxPatch((xW - w / 2 - 0.4, R[4] - h / 2 - 0.4),
        w + 0.8, R[0] - R[4] + h + 0.8, boxstyle="round,pad=0.02,rounding_size=0.1",
        fill=False, edgecolor=BLACK, linewidth=1.0, linestyle=(0, (4, 3)), zorder=1))
    ax.add_patch(FancyBboxPatch((xP - w / 2 - 0.4, R[4] - h / 2 - 0.4),
        w + 0.8, R[0] - R[4] + h + 0.8, boxstyle="round,pad=0.02,rounding_size=0.1",
        fill=False, edgecolor=BLACK, linewidth=1.0, linestyle=(0, (4, 3)), zorder=1))
    ax.text(xW, R[0] + h / 2 + 1.05, "SMARTWATCH (Wear OS)\nPeripheral / GATT Server",
            fontsize=11, fontweight="bold", ha="center", va="center")
    ax.text(xP, R[0] + h / 2 + 1.05, "SMARTPHONE (Android)\nCentral / GATT Client",
            fontsize=11, fontweight="bold", ha="center", va="center")

    # WATCH: mengalir ke bawah (1..5)
    watch = ["HR Sensor\n(TYPE_HEART_RATE)", "Native\n(EventChannel)",
             "Flutter UI\n+ BLoC", "SQLite\n(synced flag)", "BLE Advertiser\n+ GATT"]
    for i, t in enumerate(watch):
        box(ax, xW, R[i], w, h, t, fs=8.7)
        num(ax, xW - w / 2 + 0.05, R[i] + h / 2 - 0.05, i + 1)
        if i:
            arrow(ax, xW, R[i - 1] - h / 2, xW, R[i] + h / 2)

    # PHONE: mengalir ke atas (6 di bawah .. 10 di atas)
    phone = ["BLE Central\n(flutter_blue_plus)", "Reassembly\n(START/DATA/END)",
             "SQLite\n(deduplicated)", "BLoC + UI", "Export\nCSV / .db"]
    for i, t in enumerate(phone):
        ry = R[4 - i]
        box(ax, xP, ry, w, h, t, fs=8.7)
        num(ax, xP - w / 2 + 0.05, ry + h / 2 - 0.05, i + 6)
        if i:
            arrow(ax, xP, R[4 - i + 1] + h / 2, xP, ry - h / 2)

    # jembatan BLE di baris bawah (horizontal, pendek & rapi)
    yb = R[4]
    arrow(ax, xW + w / 2, yb + 0.32, xP - w / 2, yb + 0.32)            # NOTIFY ->
    arrow(ax, xP - w / 2, yb - 0.32, xW + w / 2, yb - 0.32, dashed=True)  # <- ACK
    ax.text((xW + xP) / 2, yb + 0.72, "Batch (NOTIFY)", ha="center",
            va="center", fontsize=9, fontweight="bold")
    ax.text((xW + xP) / 2, yb - 0.72, "ACK (WRITE)", ha="center",
            va="center", fontsize=9, fontweight="bold")

    small(ax, 6.5, 2.3,
          "Data flow (U-shaped):  Watch 1 -> 5  ->  BLE  ->  Phone 6 -> 10", fs=9)
    legend_flow(ax, 1.9, 1.4, "ACK (dashed)")
    save(fig, "fig_architecture")


# ---------- 2. sequence (bracket fase + nomor langkah) ----------
def fig_sequence():
    fig, ax = new_ax(15.5, 18, landscape=True)
    L, R = 6.2, 12.2
    GX = 3.8                          # gutter nomor langkah
    box(ax, L, 16.8, 3.4, 0.9, "Watch (Peripheral)", fs=10)
    box(ax, R, 16.8, 3.4, 0.9, "Phone (Central)", fs=10)
    line(ax, [(L, 1.8), (L, 16.35)]); line(ax, [(R, 1.8), (R, 16.35)])
    small(ax, GX, 16.0, "Step", fs=8.5)

    step = [0]

    def number(y):
        step[0] += 1
        num(ax, GX, y, step[0])

    def msg(y, a, b, text, dashed=False):
        arrow(ax, a, y, b, y, dashed=dashed)
        small(ax, (a + b) / 2, y + 0.34, text)
        number(y)

    def note(y, x, text):
        tag(ax, x, y, text)
        number(y)

    Y = dict(adv=15.4, scan=14.0, mtu=12.6, sub=11.2, start=9.8,
             data=8.4, end=7.0, store=5.6, ack=4.2, mark=2.8)

    note(Y["adv"], L, "advertising (svc 0000a100)")
    msg(Y["scan"], R, L, "scan + connect")
    msg(Y["mtu"], R, L, "requestMtu(512)")
    msg(Y["sub"], R, L, "subscribe (enable notify / CCCD)")
    msg(Y["start"], L, R, "NOTIFY: START (0x01)")
    msg(Y["data"], L, R, "NOTIFY: DATA (0x02) x n")
    msg(Y["end"], L, R, "NOTIFY: END (0x03)")
    note(Y["store"], R, "store batch to SQLite")
    msg(Y["ack"], R, L, "WRITE: ACK (record count)", dashed=True)
    note(Y["mark"], L, "markSynced = 1")

    bracket(ax, 2.6, Y["scan"] + 0.55, Y["sub"] - 0.55, "Connection\nsetup")
    bracket(ax, 2.6, Y["start"] + 0.55, Y["end"] - 0.55, "Batch\ntransfer")
    bracket(ax, 2.6, Y["store"] + 0.55, Y["mark"] - 0.55, "Persist\n& ACK")

    legend_flow(ax, 3.6, 0.7, "ACK (dashed)")
    save(fig, "fig_sequence")


# ---------- 3. framing (chain + inset struktur 1 frame) ----------
def fig_framing():
    fig, ax = new_ax(21, 8)
    yc = 5.6
    box(ax, 2.6, yc, 4.0, 1.7, "JSON array\n[ {bpm, accuracy,\ntime}, ... ]", fs=9)
    arrow(ax, 4.6, yc, 5.7, yc)
    small(ax, 5.15, yc + 0.45, "split")

    items = [("START\n0x01", "term"), ("DATA 0x02\n+ chunk 1", "box"),
             ("DATA 0x02\n+ chunk 2", "box"), ("...", "box"),
             ("DATA 0x02\n+ chunk n", "box"), ("END\n0x03", "term")]
    x = 6.7
    prev = None
    for t, kind in items:
        bw = 1.0 if t == "..." else 2.0
        if kind == "term":
            terminator(ax, x, yc, bw, 1.4, t, fs=8.5)
        else:
            box(ax, x, yc, bw, 1.4, t, fs=8.3)
        if prev is not None:
            arrow(ax, prev, yc, x - bw / 2, yc)
        prev = x + bw / 2
        x += bw + 0.7

    # inset: struktur satu DATA frame
    small(ax, 4.4, 2.7, "Structure of one DATA frame:", ha="left", fs=9)
    box(ax, 5.0, 1.9, 2.0, 0.9, "0x02", fs=9)
    box(ax, 9.0, 1.9, 6.0, 0.9, "JSON payload bytes", fs=9)
    small(ax, 5.0, 1.1, "opcode (1 byte)", fs=8)
    small(ax, 9.0, 1.1, "chunk = up to MTU - 4 bytes", fs=8)

    small(ax, 15.5, 1.9, "one frame = one BLE\nnotification (flow-controlled)", fs=8.5)
    save(fig, "fig_framing")


# ---------- 4. store-and-forward (bracket dua skala waktu) ----------
def fig_storeforward():
    fig, ax = new_ax(13, 21, landscape=True)
    XC, W, H = 6.6, 6.0, 1.3
    XL = 1.9                       # lajur loop kiri
    XBR = 10.6                     # bracket kanan

    y_a = 19.4; y_b = 17.0; y_c = 14.6; y_d = 12.2
    y_e = 9.3; y_f = 6.0; y_g = y_e

    terminator(ax, XC, y_a, 5.2, 1.0, "Read sensor (every 1 s)", fs=10)
    box(ax, XC, y_b, W, H, "Store to SQLite (synced = 0)")
    box(ax, XC, y_c, W, H, "Fetch records (synced = 0)")
    box(ax, XC, y_d, W, H, "Send batch over BLE")
    diamond(ax, XC, y_e, 5.2, 2.6, "ACK received?\n(timeout 30 s)")
    terminator(ax, XC, y_f, 5.2, 1.0, "markSynced = 1 (done)", fs=10)
    box(ax, XL, y_g, 3.0, 1.7, "Keep\nsynced = 0\n(retransmit)", fs=9)

    arrow(ax, XC, y_a - 0.5, XC, y_b + H / 2)
    arrow(ax, XC, y_b - H / 2, XC, y_c + H / 2)
    arrow(ax, XC, y_c - H / 2, XC, y_d + H / 2)
    arrow(ax, XC, y_d - H / 2, XC, y_e + 2.6 / 2)
    arrow(ax, XC, y_e - 2.6 / 2, XC, y_f + 0.5)
    small(ax, XC + 0.35, (y_e - 2.6 / 2 + y_f + 0.5) / 2, "Yes", ha="left")
    arrow(ax, XC - 5.2 / 2, y_e, XL + 1.5, y_e)
    small(ax, (XC - 5.2 / 2 + XL + 1.5) / 2, y_e + 0.35, "No")
    line(ax, [(XL, y_g + 0.85), (XL, y_c)], dashed=True)
    arrow(ax, XL, y_c, XC - W / 2, y_c, dashed=True)
    small(ax, XL + 0.2, (y_g + 0.85 + y_c) / 2, "next\ninterval", ha="left")

    # bracket dua skala waktu (kanan)
    bracket(ax, XBR, y_a + 0.5, y_b - H / 2, "continuous\n(every 1 s)", side="right", fs=9)
    bracket(ax, XBR, y_c + H / 2, y_f - 0.5, "per interval\n(3/5 min)", side="right", fs=9)

    legend_flow(ax, 1.4, 1.2, "retransmit (dashed)")
    save(fig, "fig_storeforward")


# ---------- 5. arsitektur internal WATCH (Flutter <-> Native) ----------
def fig_watch_arch():
    fig, ax = new_ax(16.5, 17, landscape=True)

    # region Flutter (atas) & Native (bawah)
    ax.add_patch(FancyBboxPatch((0.6, 10.0), 12.6, 6.3,
        boxstyle="round,pad=0.02,rounding_size=0.1", fill=False,
        edgecolor=BLACK, linewidth=1.0, linestyle=(0, (4, 3)), zorder=1))
    ax.add_patch(FancyBboxPatch((0.6, 0.7), 12.6, 6.7,
        boxstyle="round,pad=0.02,rounding_size=0.1", fill=False,
        edgecolor=BLACK, linewidth=1.0, linestyle=(0, (4, 3)), zorder=1))
    ax.text(1.0, 15.9, "FLUTTER (Dart)", fontsize=11, fontweight="bold", ha="left")
    ax.text(1.0, 7.0, "NATIVE (Kotlin / Android)", fontsize=11, fontweight="bold",
            ha="left")

    # --- Flutter layer ---
    box(ax, 3.3, 14.6, 4.8, 1.2, "HeartRatePage\n+ widgets (UI)", fs=9)
    box(ax, 3.3, 12.4, 5.2, 1.9,
        "MonitoringCubit (BLoC)\n1 s sampling . interval flush\n"
        "store-and-forward + ACK wait", fs=8.3)
    box(ax, 3.3, 10.6, 4.8, 1.1, "BlePeripheral\n(platform bridge)", fs=9)
    box(ax, 9.9, 12.3, 5.4, 1.5, "SQLite (heart_rate.db)\nsynced flag . sqflite", fs=9)
    arrow(ax, 3.3, 14.0, 3.3, 13.35)       # UI <- Cubit
    arrow(ax, 3.3, 11.45, 3.3, 11.15)      # Cubit -> BlePeripheral
    arrow(ax, 5.9, 12.35, 7.2, 12.35)      # Cubit -> SQLite
    small(ax, 6.55, 12.62, "store / fetch", fs=8)

    # --- boundary (di celah antara dua region) ---
    line(ax, [(0.6, 8.9), (13.2, 8.9)], lw=1.6)
    ax.text(6.9, 9.25, "Platform-channel boundary", fontsize=9,
            fontweight="bold", ha="center", va="center")
    arrow(ax, 4.3, 9.85, 4.3, 7.55)        # commands turun
    small(ax, 4.05, 8.5, "MethodChannel\nheart_rate/ble\n(commands)", fs=7.2, ha="right")
    arrow(ax, 9.8, 7.55, 9.8, 9.85)        # events naik
    small(ax, 10.05, 8.5, "EventChannel\n/stream . /status . /ack\n(events)",
          fs=7.2, ha="left")

    # --- Native layer ---
    box(ax, 2.9, 6.0, 4.4, 1.2, "HeartRateStreamHandler\n(sensor listener)", fs=8.4)
    box(ax, 10.4, 6.0, 5.0, 1.2, "MonitoringService\n(foreground service + wakelock)", fs=8.2)
    box(ax, 7.2, 3.7, 9.2, 1.7,
        "HeartRateBleServer\nGATT server . Advertiser . frame queue +\nflow-control . ACK char",
        fs=8.2)
    box(ax, 2.0, 1.5, 3.2, 1.0, "HR Sensor\n(TYPE_HEART_RATE)", fs=8.2)
    arrow(ax, 1.8, 2.0, 1.8, 5.4)          # sensor -> StreamHandler (lajur kiri)
    small(ax, 1.55, 3.7, "readings", fs=7.4, ha="right")

    # --- BLE keluar ke Phone ---
    terminator(ax, 15.0, 3.7, 2.2, 1.1, "Phone\n(Central)", fs=8.4)
    arrow(ax, 11.8, 4.0, 13.9, 4.0)                 # NOTIFY ->
    arrow(ax, 13.9, 3.4, 11.8, 3.4, dashed=True)    # <- ACK
    small(ax, 12.85, 4.3, "NOTIFY", fs=7.4)
    small(ax, 12.85, 3.1, "ACK", fs=7.4)

    legend_flow(ax, 1.0, 0.1, "ACK / events (dashed)")
    save(fig, "fig_watch_arch")


# ---------- 6. GATT: tabel atribut + jalur komunikasi lengkap ----------
def fig_gatt():
    """Diagram komprehensif jalur komunikasi GATT: tabel atribut yang di-host
    watch (server) di bagian atas, lalu seluruh siklus antara watch (peripheral/
    server) dan ponsel (central/client) — setup, connect & discover, subscribe
    (CCCD), transfer notifikasi berbingkai dengan flow-control, dan ACK
    write-back. Tiap langkah memakai nama callback/API asli dari kode
    (Android BluetoothGattServer + flutter_blue_plus)."""
    fig, ax = new_ax(15.5, 27.5, landscape=True)
    L, R = 6.6, 12.2                 # lifeline server (watch) & client (phone)
    GX = 3.4                         # gutter nomor langkah

    # ===== judul =====
    ax.text(8.0, 27.0,
            "GATT Communication Path —  Watch (Peripheral / Server)  <->  "
            "Phone (Central / Client)",
            fontsize=11, fontweight="bold", ha="center", va="center")

    # ===== inset: tabel atribut GATT (di-host watch) =====
    ax.add_patch(FancyBboxPatch((2.4, 23.0), 9.6, 3.3,
        boxstyle="round,pad=0.02,rounding_size=0.1", fill=False,
        edgecolor=BLACK, linewidth=1.0, linestyle=(0, (4, 3)), zorder=1))
    ax.text(7.2, 26.0, "GATT attribute table (hosted by the Watch / Server)",
            fontsize=9, fontweight="bold", ha="center", va="center")
    box(ax, 4.4, 24.6, 3.0, 1.0, "Service 0000a100\n(PRIMARY)", fs=7.6)
    box(ax, 9.0, 25.25, 4.4, 0.95,
        "Char 0000a101 — NOTIFY\n(+ CCCD 0x2902 · R/W)", fs=7.4)
    box(ax, 9.0, 23.85, 4.4, 0.85, "Char 0000a102 — WRITE", fs=7.4)
    # rail pohon: service -> {RECORD, ACK}
    line(ax, [(5.9, 24.6), (6.3, 24.6)])
    line(ax, [(6.3, 23.85), (6.3, 25.25)])
    line(ax, [(6.3, 25.25), (6.8, 25.25)])
    line(ax, [(6.3, 23.85), (6.8, 23.85)])

    # ===== header & lifelines =====
    box(ax, L, 22.2, 3.8, 1.1, "Watch — Peripheral\nGATT Server", fs=9)
    box(ax, R, 22.2, 3.8, 1.1, "Phone — Central\nGATT Client", fs=9)
    line(ax, [(L, 1.6), (L, 21.6)])
    line(ax, [(R, 1.6), (R, 21.6)])
    small(ax, GX, 21.45, "Step", fs=8.4)

    step = [0]

    def number(y):
        step[0] += 1
        num(ax, GX, y, step[0])

    def msg(y, a, b, text, dashed=False, fs=8.0):
        arrow(ax, a, y, b, y, dashed=dashed)
        small(ax, (a + b) / 2, y + 0.32, text, fs=fs)
        number(y)

    def lnote(y, text, fs=7.5):
        tag(ax, L, y, text, fs=fs)
        number(y)

    def rnote(y, text, fs=7.5):
        tag(ax, R, y, text, fs=fs)
        number(y)

    # ===== siklus komunikasi (atas -> bawah) =====
    # -- Setup (hanya server) --
    lnote(20.8, "openGattServer()\n+ addService(A100)")
    lnote(19.7, "startAdvertising\nADV=A100 · scanRsp=name")
    # -- Connect & discover (client memulai) --
    msg(18.5, R, L, "startScan(withServices:[A100]) -> connect()")
    lnote(17.5, "onConnectionStateChange:\nCONNECTED")
    msg(16.4, R, L, "requestMtu(512)")
    lnote(15.5, "onMtuChanged: 23 -> up to 512")
    msg(14.4, R, L, "discoverServices()")
    rnote(13.5, "finds A101 / A102 / CCCD")
    # -- Subscribe (CCCD) --
    msg(12.4, R, L, "setNotifyValue(true) -> write CCCD = 0x01 0x00", fs=7.6)
    lnote(11.4, "onDescriptorWriteRequest:\nsubscribers.add(device)")
    msg(10.4, L, R, "sendResponse(SUCCESS)", dashed=True)
    # -- Notify (transfer batch, flow-controlled) --
    lnote(9.5, "sendBatch -> frame queue\n[ START | DATA x n | END ]")
    msg(7.9, L, R, "notifyCharacteristicChanged(frame)", fs=7.7)
    rnote(7.0, "onValueReceived ->\nreassemble (_rxBuffer)")
    lnote(6.1, "onNotificationSent ->\nsend next frame")
    rnote(5.0, "on END: decode JSON array ->\ninsertReadings (INSERT OR IGNORE)")
    # -- Acknowledge (write-back) --
    msg(4.0, R, L, "write ACK char = record count", dashed=True)
    lnote(3.0, "onCharacteristicWriteRequest:\nmarkSynced = 1")
    msg(2.0, L, R, "sendResponse(SUCCESS)", dashed=True)

    # ===== UML 'loop' fragment di sekitar transfer per-frame =====
    # Bingkai sengaja dibuat tinggi: tab di atas pesan pertama agar tidak
    # bertumpuk dengan label "notifyCharacteristicChanged(frame)".
    lx0, lx1, ly0, ly1 = 4.9, 13.6, 5.55, 9.0
    ax.add_patch(Polygon([(lx0, ly0), (lx1, ly0), (lx1, ly1), (lx0, ly1)],
        closed=True, fill=False, edgecolor=BLACK, linewidth=1.0, zorder=1))
    ax.add_patch(Polygon([(lx0, ly1), (lx0 + 2.3, ly1), (lx0 + 2.3, ly1 - 0.28),
        (lx0 + 2.0, ly1 - 0.44), (lx0, ly1 - 0.44)], closed=True, fill=True,
        facecolor=WHITE, edgecolor=BLACK, linewidth=1.0, zorder=6))
    ax.text(lx0 + 1.15, ly1 - 0.22, "loop [per frame]", fontsize=7.2,
            fontweight="bold", ha="center", va="center", zorder=7)

    # ===== bracket fase (kiri) =====
    bracket(ax, 2.2, 21.25, 19.25, "Setup\n(server)", fs=8.5)
    bracket(ax, 2.2, 18.95, 13.05, "Connect &\ndiscover", fs=8.5)
    bracket(ax, 2.2, 12.85, 9.95, "Subscribe\n(CCCD)", fs=8.5)
    bracket(ax, 2.2, 9.9, 4.6, "Notify\n(flow control)", fs=8.5)
    bracket(ax, 2.2, 4.4, 1.6, "ACK", fs=8.5)

    # ===== catatan kaki & legenda =====
    small(ax, 7.7, 1.0,
          "128-bit UUIDs (16-bit aliases A100/A101/A102 on the Bluetooth base "
          "UUID).  One notification = one frame (opcode 1 B + chunk <= MTU-4).",
          fs=7.4)
    legend_flow(ax, 1.0, 0.3, "ACK / response (dashed)")
    save(fig, "fig_gatt")


# ---------- 7. negosiasi MTU (terima / tolak) ----------
def fig_mtu():
    """Flowchart negosiasi MTU: ponsel mengusulkan 512, watch membalas dengan
    yang ia dukung, dipakai yang terkecil; bila gagal memakai default 23.
    Hasilnya menentukan ukuran chunk (MTU - 4)."""
    fig, ax = new_ax(14, 13)
    XC = 7.0

    terminator(ax, XC, 11.6, 5.4, 1.0, "Phone requests MTU 512", fs=10)
    arrow(ax, XC, 11.1, XC, 10.3)
    box(ax, XC, 9.6, 5.8, 1.3,
        "Watch replies with its\nsupported MTU (negotiation)", fs=9.3)
    arrow(ax, XC, 8.95, XC, 8.2)
    diamond(ax, XC, 7.0, 4.0, 2.3, "Negotiation\nsuccessful?", fs=9.3)

    # cabang Ya -> ambil yang terkecil
    arrow(ax, XC, 5.85, XC, 5.15)
    small(ax, XC + 0.3, 5.5, "Yes", ha="left")
    box(ax, XC, 4.3, 6.8, 1.6,
        "MTU = smaller of the requested\nand supported values\n"
        "(example: min(512, 247) = 247)", fs=8.8)

    # cabang Tidak -> default 23
    arrow(ax, XC - 2.0, 7.0, 3.95, 7.0)
    small(ax, 4.9, 7.32, "No")
    box(ax, 2.5, 7.0, 2.9, 1.3, "MTU = 23\n(default)", fs=9.3)

    # konvergensi -> terminator
    terminator(ax, XC, 1.9, 6.8, 1.0,
               "Use final MTU  ->  chunk = MTU - 4 bytes", fs=9.3)
    arrow(ax, XC, 3.5, XC, 2.4)
    line(ax, [(2.5, 6.35), (2.5, 1.9)])
    arrow(ax, 2.5, 1.9, 3.6, 1.9)

    small(ax, XC, 0.5,
          "The value 247 is illustrative; the actual value depends on device "
          "capabilities.", fs=8)
    save(fig, "fig_mtu")


# ---------- 8. asal-usul timestamp (native -> Dart -> SQLite) ----------
def fig_timestamp():
    """Dari mana kolom `time` di database berasal. Native hanya mengirim
    {bpm, accuracy} lewat EventChannel; timestamp TIDAK ikut dari sensor.
    Waktu dibuat di sisi Dart saat record disimpan (DateTime.now() di dalam
    _onTick yang berjalan tiap 1 s), lalu disimpan sebagai epoch milliseconds.
    Bracket kanan menegaskan dua zona: aliran sensor (belum ber-waktu) vs
    penyimpanan per 1 s (waktu = saat simpan)."""
    fig, ax = new_ax(15, 21, landscape=True)
    XC = 6.6
    GX = 1.7                          # gutter nomor langkah

    y_sensor = 19.4
    y_native = 17.3
    y_bound = 15.9
    y_dart = 13.9
    y_timer = 11.4
    y_make = 8.6
    y_map = 5.9
    y_sql = 3.7

    step = [0]

    def number(y):
        step[0] += 1
        num(ax, GX, y, step[0])

    small(ax, GX, 20.2, "Step", fs=8.5)

    # 1. sensor (native)
    terminator(ax, XC, y_sensor, 6.2, 1.0,
               "HR Sensor (TYPE_HEART_RATE)\nonSensorChanged()", fs=8.8)
    number(y_sensor)

    # 2. native emit -> hanya bpm + accuracy (TANPA waktu)
    box(ax, XC, y_native, 6.4, 1.5,
        "Native -> EventChannel\nsuccess({ bpm, accuracy })", fs=9)
    number(y_native)
    tag(ax, 12.1, y_native, "no timestamp\nyet", fs=7.6)
    arrow(ax, XC, y_sensor - 0.5, XC, y_native + 0.75)

    # boundary platform-channel
    line(ax, [(1.2, y_bound), (13.8, y_bound)], lw=1.6)
    small(ax, XC, y_bound + 0.33, "Platform-channel boundary (EventChannel)",
          fs=8.4)
    arrow(ax, XC, y_native - 0.75, XC, y_bound + 0.02)

    # 3. Dart listener -> simpan ke state (masih tanpa waktu)
    box(ax, XC, y_dart, 6.4, 1.9,
        "Dart stream listener\nstores in state:\nlatestBpm, latestAccuracy", fs=8.8)
    number(y_dart)
    tag(ax, 12.1, y_dart, "still no\ntimestamp", fs=7.6)
    arrow(ax, XC, y_bound - 0.02, XC, y_dart + 0.95)

    # 4. timer 1 s -> _onTick
    box(ax, XC, y_timer, 6.8, 1.5,
        "Timer.periodic(1 s) -> _onTick()\nif (latestBpm > 0)", fs=8.8)
    number(y_timer)
    arrow(ax, XC, y_dart - 0.95, XC, y_timer + 0.75)

    # 5. HeartRateReading(... time: DateTime.now())  <-- TITIK KUNCI
    hw, hh = 7.2, 2.5
    ax.add_patch(FancyBboxPatch(
        (XC - hw / 2 - 0.18, y_make - hh / 2 - 0.18), hw + 0.36, hh + 0.36,
        boxstyle="round,pad=0.02,rounding_size=0.06", fill=False,
        edgecolor=BLACK, linewidth=1.1, linestyle=(0, (4, 3)), zorder=3))
    box(ax, XC, y_make, hw, hh,
        "HeartRateReading(\n  bpm, accuracy,\n  time: DateTime.now()  <==\n)\n"
        "[ TIMESTAMP CREATED HERE ]", fs=8.4)
    number(y_make)
    arrow(ax, XC, y_timer - 0.75, XC, y_make + hh / 2 + 0.18)

    # 6. toMap -> epoch milliseconds
    box(ax, XC, y_map, 6.6, 1.5,
        "toMap(): time ->\ntime.millisecondsSinceEpoch", fs=8.8)
    number(y_map)
    arrow(ax, XC, y_make - hh / 2 - 0.18, XC, y_map + 0.75)

    # 7. SQLite
    terminator(ax, XC, y_sql, 6.8, 1.3,
               "SQLite readings\n(bpm, accuracy, time, synced)", fs=8.8)
    number(y_sql)
    arrow(ax, XC, y_map - 0.75, XC, y_sql + 0.65)

    # bracket dua zona (kanan)
    bracket(ax, 10.9, y_sensor + 0.5, y_dart - 0.95,
            "Sensor stream\n(not timestamped)", side="right", fs=8.2)
    bracket(ax, 10.9, y_timer + 0.75, y_sql - 0.65,
            "Store every 1 s\n(time = storage time)", side="right", fs=8.2)

    # catatan kaki
    small(ax, 7.5, 1.6,
          "Native sends only bpm & accuracy; Dart creates the timestamp when "
          "the record is stored (DateTime.now()), not at the sensor.", fs=7.8)
    small(ax, 7.5, 1.0,
          "The 1 s timer samples the latest value: if the sensor emits no new "
          "value, one bpm may be stored repeatedly with different timestamps.",
          fs=7.8)
    save(fig, "fig_timestamp")


# ---------- 9. ukuran data & pengaruh MTU (record -> batch -> frame) ----------
def fig_batch_mtu():
    """Ukuran data yang dikirim dan peran MTU. Baris atas: 1 record JSON
    (±47 byte) dikali 228 menjadi 1 batch (10.717 byte). Batch dipotong per
    chunk = MTU-4, lalu dua lajur membandingkan hasil pemotongan pada MTU 512
    (24 frame, terukur ±0,32 s) vs MTU 23 (567 frame). Catatan bawah menegaskan
    isi yang sampai sama lengkap — MTU hanya mengubah jumlah frame/kecepatan."""
    fig, ax = new_ax(17, 12)

    # --- baris atas: record -> batch ---
    yt = 10.6
    box(ax, 3.2, yt, 4.0, 1.5, "1 record (JSON)\n±47 byte", fs=9.5)
    small(ax, 3.2, yt - 1.15, '{"bpm":76.0,"accuracy":3,"time":...}', fs=7.6)
    arrow(ax, 5.3, yt, 8.0, yt)
    small(ax, 6.65, yt + 0.35, "x 228 record", fs=8.6)
    box(ax, 10.6, yt, 5.0, 1.5, "1 batch (collection)\n228 records = 10,717 bytes", fs=9.5)

    # --- turun: dipotong per chunk = MTU - 4 ---
    arrow(ax, 10.6, yt - 0.75, 10.6, 8.55)
    tag(ax, 10.6, 8.05, "split into frames\nchunk = MTU - 4 bytes", fs=8.2)
    # rel siku di kiri agar cabang tidak memotong kotak frame
    line(ax, [(10.6, 7.55), (10.6, 7.38), (0.75, 7.38), (0.75, 4.35)])
    arrow(ax, 0.75, 6.65, 1.3, 6.65, lw=1.2)   # ke lajur MTU 512
    arrow(ax, 0.75, 4.35, 1.3, 4.35, lw=1.2)   # ke lajur MTU 23

    def strip(y, label, frames, bw, bh, note, fs_box):
        small(ax, 2.45, y, label, fs=8.8)
        x = 3.9
        for t in frames:
            if t == "...":
                small(ax, x + 0.35, y, "...", fs=10); x += 1.0; continue
            if t in ("START", "END"):
                terminator(ax, x + bw / 2, y, bw, bh, t, fs=fs_box)
            else:
                box(ax, x + bw / 2, y, bw, bh, t, fs=fs_box)
            x += bw + 0.22
        small(ax, x + 0.25, y, note, ha="left", fs=8.8)

    # --- lajur MTU 512: potongan besar, frame sedikit ---
    strip(6.65, "MTU 512\n(chunk 508 B)",
          ["START", "DATA 1", "DATA 2", "...", "DATA 22", "END"],
          1.75, 1.05, "= 24 frames\nmeasured +-0.32 s", 7.8)
    # --- lajur MTU 23: potongan kecil, frame banyak ---
    strip(4.35, "MTU 23\n(chunk 19 B)",
          ["START", "D1", "D2", "D3", "D4", "D5", "D6", "...", "D565", "END"],
          0.95, 0.85, "= 567 frames\n(~24x more)", 6.8)

    # --- catatan bawah ---
    tag(ax, 8.5, 2.3,
        "The received content is equally complete (228 full records).\n"
        "MTU changes only frame count and speed, not completeness.",
        fs=9.0)
    save(fig, "fig_batch_mtu")


def fig_hr_contact():
    """Sensor-contact distribution with identical solid chart/legend colors."""
    values = [21087, 15, 2113]
    colors = ["#16A34A", "#D97706", "#64748B"]
    labels = [
        "Accurate (3) · 21,087 (90.8%)",
        "Medium (0) · 15 (0.1%)",
        "Inaccurate (-1) · 2,113 (9.1%)",
    ]

    fig, ax = plt.subplots(figsize=(9.0, 5.4), dpi=300)
    fig.patch.set_facecolor(WHITE)
    ax.set_facecolor(WHITE)
    wedges, _ = ax.pie(
        values,
        colors=colors,
        startangle=90,
        counterclock=False,
        # The medium category is only 0.1%; a very thin separator keeps its
        # true-size amber wedge visible instead of covering it with white.
        wedgeprops=dict(width=0.40, edgecolor=WHITE, linewidth=0.15),
    )
    ax.text(0, 0.15, "91%", ha="center", va="center",
            fontsize=26, fontweight="bold", color=colors[0])
    ax.text(0, -0.20, "accurate contact", ha="center", va="center",
            fontsize=12, color=colors[2])
    ax.legend(
        wedges,
        labels,
        loc="center left",
        bbox_to_anchor=(1.02, 0.5),
        frameon=False,
        fontsize=11,
        handlelength=1.6,
        handletextpad=0.8,
    )
    ax.set_aspect("equal")
    fig.subplots_adjust(left=0.04, right=0.78, top=0.96, bottom=0.04)
    os.makedirs(OUT, exist_ok=True)
    fig.savefig(os.path.join(OUT, "fig_hr_contact.png"), dpi=300,
                facecolor=WHITE, bbox_inches="tight")
    plt.close(fig)
    print("[OK] saved: fig_hr_contact")


# ---------- Native landscape layouts ----------
# These functions intentionally redefine the earlier portrait implementations.
# The content is reflowed into rows/columns designed for a landscape canvas;
# no coordinate stretching is used.
def landscape_ax(xlim=24, ylim=13):
    fig, ax = plt.subplots(figsize=(12, 6.5), dpi=300)
    ax.set_xlim(0, xlim); ax.set_ylim(0, ylim)
    ax.set_aspect("equal"); ax.axis("off")
    fig.patch.set_facecolor(WHITE)
    return fig, ax


def fig_architecture():
    fig, ax = landscape_ax()
    xs = [2.6, 6.9, 11.2, 15.5, 19.8]
    w, h = 3.35, 1.65
    watch = ["HR Sensor\n(TYPE_HEART_RATE)", "Native\n(EventChannel)",
             "Flutter UI\n+ BLoC", "SQLite\n(synced flag)",
             "BLE Advertiser\n+ GATT"]
    phone = ["BLE Central\n(flutter_blue_plus)", "Reassembly\n(START/DATA/END)",
             "SQLite\n(deduplicated)", "BLoC + UI", "Export\nCSV / .db"]

    ax.text(11.2, 12.25, "END-TO-END SMARTWATCH DATA ARCHITECTURE",
            fontsize=13, fontweight="bold", ha="center")
    for y, title in [(9.25, "SMARTWATCH (Wear OS) — Peripheral / GATT Server"),
                     (4.45, "SMARTPHONE (Android) — Central / GATT Client")]:
        ax.add_patch(FancyBboxPatch((0.45, y - 1.35), 21.5, 2.95,
            boxstyle="round,pad=0.02,rounding_size=0.1", fill=False,
            edgecolor=BLACK, linewidth=1.0, linestyle=(0, (4, 3))))
        ax.text(0.75, y + 1.25, title, fontsize=10, fontweight="bold",
                ha="left", va="center")

    for i, (x, text) in enumerate(zip(xs, watch)):
        box(ax, x, 9.15, w, h, text, fs=8.2)
        num(ax, x - w / 2 + 0.12, 9.15 + h / 2 - 0.12, i + 1, r=0.28)
        if i:
            arrow(ax, xs[i - 1] + w / 2, 9.15, x - w / 2, 9.15)

    # Phone data continues from right to left, yielding a clean serpentine path.
    for j, (x, text) in enumerate(zip(reversed(xs), phone)):
        box(ax, x, 4.35, w, h, text, fs=8.2)
        num(ax, x - w / 2 + 0.12, 4.35 + h / 2 - 0.12, j + 6, r=0.28)
        if j:
            arrow(ax, list(reversed(xs))[j - 1] - w / 2, 4.35,
                  x + w / 2, 4.35)

    arrow(ax, xs[-1], 8.32, xs[-1], 5.18)
    small(ax, xs[-1] + 0.45, 6.95, "Batch (NOTIFY)", ha="left", fs=8.2)
    arrow(ax, xs[-1] - 0.55, 5.18, xs[-1] - 0.55, 8.32, dashed=True)
    small(ax, xs[-1] - 0.95, 6.2, "ACK (WRITE)", ha="right", fs=8.2)
    legend_flow(ax, 5.2, 1.25, "ACK (dashed)")
    save(fig, "fig_architecture")


def fig_sequence():
    fig, ax = landscape_ax()
    ax.text(12, 12.2, "BATCH TRANSFER SEQUENCE", fontsize=13,
            fontweight="bold", ha="center")
    y_watch, y_phone = 8.65, 4.25
    box(ax, 1.9, y_watch, 3.0, 1.0, "Watch\n(Peripheral)", fs=8.5)
    box(ax, 1.9, y_phone, 3.0, 1.0, "Phone\n(Central)", fs=8.5)
    line(ax, [(3.7, y_watch), (23, y_watch)])
    line(ax, [(3.7, y_phone), (23, y_phone)])

    phases = [
        ("CONNECTION SETUP", 4.3, 9.0, [
            ("note", "advertise\nA100"), ("up", "scan + connect"),
            ("up", "request MTU"), ("up", "subscribe / CCCD")]),
        ("BATCH TRANSFER", 9.4, 17.0, [
            ("down", "START"), ("down", "DATA × n"), ("down", "END"),
            ("note2", "store SQLite")]),
        ("PERSIST & ACK", 17.4, 22.8, [
            ("updash", "ACK count"), ("note", "mark synced")])
    ]
    step = 1
    for title, x0, x1, events in phases:
        ax.add_patch(FancyBboxPatch((x0, 2.55), x1 - x0, 7.85,
            boxstyle="round,pad=0.02,rounding_size=0.08", fill=False,
            edgecolor="#555555", linewidth=0.9, linestyle=(0, (4, 3))))
        ax.text((x0 + x1) / 2, 10.72, title, fontsize=8.5,
                fontweight="bold", ha="center")
        exs = [x0 + (i + 1) * (x1 - x0) / (len(events) + 1)
               for i in range(len(events))]
        for event_i, (x, (kind, label)) in enumerate(zip(exs, events)):
            num(ax, x, 11.35, step, r=0.25); step += 1
            if kind == "down":
                arrow(ax, x, y_watch - 0.12, x, y_phone + 0.12)
                ax.text(x + 0.28, 6.45, label, rotation=90, fontsize=7.0,
                        fontweight="bold", ha="center", va="center")
            elif kind in ("up", "updash"):
                arrow(ax, x, y_phone + 0.12, x, y_watch - 0.12,
                      dashed=kind == "updash")
                ax.text(x + 0.28, 6.45, label, rotation=90, fontsize=7.0,
                        fontweight="bold", ha="center", va="center")
            elif kind == "note":
                tag(ax, x, y_watch - 1.05, label, fs=7.0)
            else:
                tag(ax, x, y_phone + 1.05, label, fs=7.0)
    legend_flow(ax, 7.0, 1.15, "ACK (dashed)")
    save(fig, "fig_sequence")


def fig_storeforward():
    fig, ax = landscape_ax()
    ax.text(12, 12.2, "STORE-AND-FORWARD WORKFLOW", fontsize=13,
            fontweight="bold", ha="center")
    y = 7.15
    nodes = [
        (2.0, "Read sensor\n(every 1 s)", "term", 3.1),
        (5.8, "Store SQLite\nsynced = 0", "box", 3.0),
        (9.6, "Fetch unsynced\nrecords", "box", 3.0),
        (13.4, "Send BLE\nbatch", "box", 3.0),
        (17.3, "ACK\nreceived?", "diamond", 3.0),
        (21.5, "markSynced = 1\n(done)", "term", 3.2)]
    for x, label, kind, width in nodes:
        if kind == "term": terminator(ax, x, y, width, 1.25, label, fs=8.2)
        elif kind == "diamond": diamond(ax, x, y, width, 2.1, label, fs=8.2)
        else: box(ax, x, y, width, 1.5, label, fs=8.2)
    for a, b in zip(nodes[:-1], nodes[1:]):
        arrow(ax, a[0] + a[3] / 2, y, b[0] - b[3] / 2, y)
    small(ax, 19.25, y + 0.42, "Yes", fs=8)
    box(ax, 17.3, 3.25, 3.7, 1.45, "Keep synced = 0\n(retransmit)", fs=8.2)
    arrow(ax, 17.3, 6.1, 17.3, 3.98)
    small(ax, 17.65, 5.05, "No", ha="left", fs=8)
    line(ax, [(15.45, 3.25), (9.6, 3.25), (9.6, 6.4)], dashed=True)
    arrow(ax, 9.6, 6.4, 9.6, 6.42, dashed=True)
    small(ax, 12.5, 3.62, "next interval", fs=7.8)
    ax.text(3.9, 9.25, "CONTINUOUS · 1 s", fontsize=8.5,
            fontweight="bold", ha="center")
    line(ax, [(0.8, 8.8), (7.1, 8.8)])
    ax.text(15.3, 9.25, "PER INTERVAL · 3/5 min", fontsize=8.5,
            fontweight="bold", ha="center")
    line(ax, [(7.9, 8.8), (22.7, 8.8)])
    legend_flow(ax, 6.2, 1.15, "retransmit (dashed)")
    save(fig, "fig_storeforward")


def fig_timestamp():
    fig, ax = landscape_ax()
    ax.text(12, 12.2, "TIMESTAMP ORIGIN AND STORAGE PATH", fontsize=13,
            fontweight="bold", ha="center")
    xs = [1.9, 5.1, 8.4, 11.7, 15.0, 18.4, 21.8]
    labels = [
        "HR Sensor\nonSensorChanged\ncallback",
        "Native\nEventChannel\n{bpm, accuracy}",
        "Dart listener\nlatest values",
        "Timer.periodic\n(1 s) → _onTick()",
        "HeartRateReading\nDateTime.now()",
        "toMap()\nepoch ms",
        "SQLite\nbpm · accuracy\ntime · synced"]
    widths = [2.8, 3.0, 2.8, 3.0, 3.0, 3.0, 2.9]
    y = 6.8
    for i, (x, label, width) in enumerate(zip(xs, labels, widths)):
        if i in (0, 6):
            terminator(ax, x, y, width, 1.75, label,
                       fs=6.1 if i == 0 else 6.8)
        else:
            box(ax, x, y, width, 1.8, label, fs=6.8)
        num(ax, x, 8.3, i + 1, r=0.26)
        if i:
            arrow(ax, xs[i - 1] + widths[i - 1] / 2, y,
                  x - width / 2, y)
    ax.add_patch(FancyBboxPatch((0.35, 4.95), 9.55, 4.25,
        boxstyle="round,pad=0.02,rounding_size=0.08", fill=False,
        edgecolor="#555555", linewidth=0.9, linestyle=(0, (4, 3))))
    ax.add_patch(FancyBboxPatch((10.15, 4.95), 13.45, 4.25,
        boxstyle="round,pad=0.02,rounding_size=0.08", fill=False,
        edgecolor="#555555", linewidth=0.9, linestyle=(0, (4, 3))))
    ax.text(5.1, 9.55, "SENSOR STREAM · NOT TIMESTAMPED", fontsize=8.3,
            fontweight="bold", ha="center")
    ax.text(16.9, 9.55, "1 s STORAGE PATH · TIMESTAMP CREATED IN DART",
            fontsize=8.3, fontweight="bold", ha="center")
    tag(ax, 5.1, 4.0, "Native sends only bpm and accuracy", fs=7.6)
    tag(ax, 15.0, 4.0, "TIMESTAMP CREATED HERE", fs=7.8)
    small(ax, 12, 1.8,
          "DateTime.now() records storage time, not the original sensor event time.",
          fs=8.2)
    save(fig, "fig_timestamp")


def fig_watch_arch():
    fig, ax = landscape_ax()
    ax.text(12, 12.2, "SMARTWATCH INTERNAL ARCHITECTURE", fontsize=13,
            fontweight="bold", ha="center")
    # Three native landscape columns: Flutter, bridge/native, external phone.
    regions = [(0.5, 8.0, "FLUTTER (Dart)"),
               (8.35, 20.2, "NATIVE (Kotlin / Android)")]
    for x0, x1, title in regions:
        ax.add_patch(FancyBboxPatch((x0, 2.25), x1 - x0, 8.6,
            boxstyle="round,pad=0.02,rounding_size=0.1", fill=False,
            edgecolor=BLACK, linewidth=1.0, linestyle=(0, (4, 3))))
        ax.text(x0 + 0.35, 10.45, title, fontsize=9.5,
                fontweight="bold", ha="left")
    box(ax, 2.2, 8.65, 3.0, 1.3, "HeartRatePage\nUI", fs=8)
    box(ax, 5.7, 8.65, 3.2, 1.55, "MonitoringCubit\nBLoC", fs=8)
    box(ax, 2.2, 5.15, 3.2, 1.35, "BlePeripheral\nplatform bridge", fs=8)
    box(ax, 5.7, 5.15, 3.2, 1.35, "SQLite\nheart_rate.db", fs=8)
    arrow(ax, 3.7, 8.65, 4.1, 8.65)
    line(ax, [(5.0, 7.88), (5.0, 7.35), (2.2, 7.35)])
    arrow(ax, 2.2, 7.35, 2.2, 5.83)
    arrow(ax, 5.7, 7.88, 5.7, 5.83)

    box(ax, 10.2, 8.65, 3.0, 1.45, "StreamHandler\nsensor listener", fs=8)
    box(ax, 14.6, 8.65, 3.5, 1.45, "MonitoringService\nforeground + wakelock", fs=8)
    box(ax, 15.0, 5.15, 4.5, 1.55,
        "HeartRateBleServer\nGATT · advertiser · frame queue", fs=8)
    terminator(ax, 10.2, 3.25, 2.8, 1.15, "HR Sensor", fs=8)
    # Sensor and stream handler share a clean vertical lane.
    arrow(ax, 10.2, 3.83, 10.2, 7.92)
    # Stream handler reaches the BLE server through an orthogonal rail.
    line(ax, [(11.7, 8.65), (12.1, 8.65), (12.1, 6.15)])
    arrow(ax, 12.1, 6.15, 12.75, 5.65)
    # Foreground service has its own direct lane.
    arrow(ax, 14.6, 7.92, 14.6, 5.93)
    # Platform-channel traffic uses dedicated rails above and below the boxes.
    line(ax, [(3.8, 5.55), (3.8, 6.35), (9.75, 6.35),
              (9.75, 6.75), (10.65, 6.75), (10.65, 6.35),
              (12.15, 6.35)])
    arrow(ax, 12.15, 6.35, 12.75, 5.65)
    tag(ax, 6.65, 6.72, "MethodChannel commands", fs=6.4)
    line(ax, [(12.75, 4.65), (12.35, 2.55), (8.0, 2.55),
              (8.0, 4.0), (3.8, 4.0)], dashed=True)
    arrow(ax, 3.8, 3.95, 3.8, 4.75, dashed=True)
    tag(ax, 6.65, 3.55, "EventChannel status / ACK", fs=6.4)
    terminator(ax, 22.2, 5.15, 2.7, 1.25, "Phone\nCentral", fs=8)
    arrow(ax, 17.25, 5.4, 20.85, 5.4)
    arrow(ax, 20.85, 4.85, 17.25, 4.85, dashed=True)
    small(ax, 19.0, 5.75, "NOTIFY", fs=7.4)
    small(ax, 19.0, 4.5, "ACK", fs=7.4)
    legend_flow(ax, 7.0, 1.15, "ACK / events (dashed)")
    save(fig, "fig_watch_arch")


def fig_gatt():
    fig, ax = landscape_ax()
    ax.text(12, 12.35,
            "GATT COMMUNICATION PATH · WATCH SERVER ↔ PHONE CLIENT",
            fontsize=12.5, fontweight="bold", ha="center")
    # Attribute table occupies a compact top band.
    ax.add_patch(FancyBboxPatch((0.55, 9.65), 22.9, 1.95,
        boxstyle="round,pad=0.02,rounding_size=0.08", fill=False,
        edgecolor=BLACK, linewidth=0.9, linestyle=(0, (4, 3))))
    box(ax, 3.0, 10.55, 3.5, 0.9, "Service A100\nPRIMARY", fs=7.3)
    box(ax, 8.1, 10.55, 4.6, 0.9, "Characteristic A101 · NOTIFY\nCCCD 0x2902", fs=7.1)
    box(ax, 13.2, 10.55, 4.0, 0.9, "Characteristic A102\nWRITE ACK", fs=7.1)
    small(ax, 19.6, 10.55, "Hosted by Watch / GATT Server", fs=8)
    arrow(ax, 4.75, 10.55, 5.8, 10.55)
    arrow(ax, 10.4, 10.55, 11.2, 10.55)

    y_watch, y_phone = 7.25, 3.25
    box(ax, 1.65, y_watch, 2.7, 1.0, "WATCH\nGATT Server", fs=8)
    box(ax, 1.65, y_phone, 2.7, 1.0, "PHONE\nGATT Client", fs=8)
    line(ax, [(3.2, y_watch), (23.3, y_watch)])
    line(ax, [(3.2, y_phone), (23.3, y_phone)])

    phases = [
        ("SETUP", 3.5, 6.0, [("note", "open server"), ("note", "advertise")]),
        ("CONNECT & DISCOVER", 6.25, 11.7,
         [("up", "scan/connect"), ("up", "MTU 512"), ("up", "discover")]),
        ("SUBSCRIBE", 11.95, 15.2,
         [("up", "write CCCD"), ("downD", "SUCCESS")]),
        ("NOTIFY · FLOW CONTROL", 15.45, 20.1,
         [("down", "START"), ("down", "DATA × n"), ("down", "END")]),
        ("ACK", 20.35, 23.25,
         [("upD", "ACK count"), ("downD", "SUCCESS")])
    ]
    step = 1
    for title, x0, x1, events in phases:
        ax.add_patch(FancyBboxPatch((x0, 1.85), x1 - x0, 6.75,
            boxstyle="round,pad=0.02,rounding_size=0.06", fill=False,
            edgecolor="#666666", linewidth=0.8, linestyle=(0, (4, 3))))
        ax.text((x0 + x1) / 2, 8.82, title, fontsize=7.4,
                fontweight="bold", ha="center")
        exs = [x0 + (i + 1) * (x1 - x0) / (len(events) + 1)
               for i in range(len(events))]
        for event_i, (x, (kind, label)) in enumerate(zip(exs, events)):
            num(ax, x, 9.35, step, r=0.22); step += 1
            if kind == "note":
                tag(ax, x, y_watch - 0.85 - event_i * 0.85, label, fs=6.4)
                continue
            dashed = kind.endswith("D")
            if kind.startswith("up"):
                arrow(ax, x, y_phone + 0.1, x, y_watch - 0.1, dashed=dashed)
            else:
                arrow(ax, x, y_watch - 0.1, x, y_phone + 0.1, dashed=dashed)
            ax.text(x + 0.24, 5.25, label, rotation=90, fontsize=6.4,
                    fontweight="bold", ha="center", va="center")
    small(ax, 12, 1.15,
          "A100/A101/A102 are 16-bit aliases on the Bluetooth base UUID · "
          "one notification = one frame · payload chunk ≤ MTU − 4.",
          fs=7.4)
    save(fig, "fig_gatt")


# Final clean-room layout for the watch internals.  This deliberately keeps
# every connector on a dedicated rail so no arrow crosses a component.
def fig_watch_arch():
    fig, ax = landscape_ax()
    ax.text(12, 12.2, "SMARTWATCH INTERNAL ARCHITECTURE", fontsize=13,
            fontweight="bold", ha="center")

    # Two simple swimlanes make ownership and direction immediately clear.
    lanes = [(0.55, 6.65, 15.8, 4.15, "FLUTTER (Dart)"),
             (0.55, 1.65, 18.25, 4.15, "NATIVE (Kotlin / Android)")]
    for x, y, w, h, title in lanes:
        ax.add_patch(FancyBboxPatch(
            (x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.1",
            fill=False, edgecolor=BLACK, linewidth=1.0,
            linestyle=(0, (4, 3))))
        ax.text(x + 0.35, y + h - 0.45, title, fontsize=9.2,
                fontweight="bold", ha="left")

    # Flutter lane: one clean left-to-right processing pipeline.
    top_y = 8.35
    top_nodes = [
        (1.90, 2.65, "HeartRatePage\nUI"),
        (5.40, 2.80, "MonitoringCubit\nBLoC"),
        (10.40, 2.80, "SQLite\nheart_rate.db"),
        (14.70, 2.90, "BlePeripheral\nplatform bridge")]
    for x, w, label in top_nodes:
        box(ax, x, top_y, w, 1.3, label, fs=7.3)
    for (x1, w1, _), (x2, w2, _) in zip(top_nodes[:-1], top_nodes[1:]):
        arrow(ax, x1 + w1 / 2, top_y, x2 - w2 / 2, top_y)
    small(ax, 7.90, 8.72, "store / fetch", fs=6.1)

    # Native lane: sensor acquisition and BLE transport stay on one baseline.
    bot_y = 3.85
    bot_nodes = [
        (2.15, 2.65, "HR Sensor", "term"),
        (6.05, 3.0, "StreamHandler\nsensor listener", "box"),
        (10.05, 3.25, "MonitoringService\nforeground · wakelock", "box"),
        (14.15, 4.0,
         "HeartRateBleServer\nGATT server · advertiser\nframe queue", "box")]
    for x, w, label, kind in bot_nodes:
        if kind == "term":
            terminator(ax, x, bot_y, w, 1.15, label, fs=7.3)
        else:
            box(ax, x, bot_y, w, 1.5, label,
                fs=6.0 if x == 14.15 else 6.8)
    arrow(ax, 3.48, bot_y, 4.55, bot_y)
    arrow(ax, 7.55, bot_y, 8.43, bot_y)
    arrow(ax, 11.68, bot_y, 12.15, bot_y)

    # Short vertical platform-channel pair; no long rails or crossings.
    arrow(ax, 14.42, 7.70, 14.42, 4.53)
    arrow(ax, 14.96, 4.53, 14.96, 7.70, dashed=True)
    small(ax, 14.09, 6.10, "commands", ha="right", fs=6.3)
    small(ax, 15.29, 6.10, "events / ACK", ha="left", fs=6.3)

    # Sensor EventChannel enters the BLoC directly above it.
    arrow(ax, 5.40, 4.53, 5.40, 7.70, dashed=True)
    small(ax, 5.70, 6.10, "sensor events", ha="left", fs=6.3)

    # External phone is outside both ownership lanes.
    terminator(ax, 21.75, bot_y, 2.7, 1.25, "Phone\nCentral", fs=7.4)
    arrow(ax, 16.15, 4.08, 20.40, 4.08)
    arrow(ax, 20.40, 3.62, 16.15, 3.62, dashed=True)
    small(ax, 18.3, 4.42, "NOTIFY", fs=6.8)
    small(ax, 18.3, 3.28, "ACK", fs=6.8)

    legend_flow(ax, 7.0, 0.65, "events / ACK (dashed)")
    save(fig, "fig_watch_arch")


if __name__ == "__main__":
    print("Membuat diagram (gaya monokrom) ke %s/ ..." % OUT)
    fig_architecture(); fig_sequence(); fig_framing(); fig_storeforward()
    fig_watch_arch(); fig_gatt(); fig_mtu(); fig_timestamp(); fig_batch_mtu()
    print("Selesai.")
