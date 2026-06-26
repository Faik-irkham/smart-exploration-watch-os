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


def new_ax(xlim, ylim, scale=0.62):
    fig, ax = plt.subplots(figsize=(xlim * scale, ylim * scale), dpi=300)
    ax.set_xlim(0, xlim); ax.set_ylim(0, ylim)
    ax.set_aspect("equal"); ax.axis("off")
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
    fig, ax = new_ax(13, 16.5)
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
    fig, ax = new_ax(15.5, 18)
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
    fig, ax = new_ax(13, 21)
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
    fig, ax = new_ax(16.5, 17)

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
    fig, ax = new_ax(15.5, 27.5)
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
    small(ax, GX, 21.1, "Step", fs=8.4)

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
    lnote(9.3, "sendBatch -> frame queue\n[ START | DATA x n | END ]")
    msg(8.0, L, R, "notifyCharacteristicChanged(frame)", fs=7.7)
    rnote(7.2, "onValueReceived ->\nreassemble (_rxBuffer)")
    lnote(6.4, "onNotificationSent ->\nsend next frame")
    rnote(5.2, "on END: decode JSON array ->\ninsertReadings (INSERT OR IGNORE)")
    # -- Acknowledge (write-back) --
    msg(4.2, R, L, "write ACK char = record count", dashed=True)
    lnote(3.2, "onCharacteristicWriteRequest:\nmarkSynced = 1")
    msg(2.2, L, R, "sendResponse(SUCCESS)", dashed=True)

    # ===== UML 'loop' fragment di sekitar transfer per-frame =====
    lx0, lx1, ly0, ly1 = 4.9, 13.6, 5.85, 8.5
    ax.add_patch(Polygon([(lx0, ly0), (lx1, ly0), (lx1, ly1), (lx0, ly1)],
        closed=True, fill=False, edgecolor=BLACK, linewidth=1.0, zorder=1))
    ax.add_patch(Polygon([(lx0, ly1), (lx0 + 2.0, ly1), (lx0 + 2.0, ly1 - 0.34),
        (lx0 + 1.7, ly1 - 0.54), (lx0, ly1 - 0.54)], closed=True, fill=True,
        facecolor=WHITE, edgecolor=BLACK, linewidth=1.0, zorder=6))
    ax.text(lx0 + 0.95, ly1 - 0.27, "loop [per frame]", fontsize=7.3,
            fontweight="bold", ha="center", va="center", zorder=7)

    # ===== bracket fase (kiri) =====
    bracket(ax, 2.2, 21.25, 19.25, "Setup\n(server)", fs=8.5)
    bracket(ax, 2.2, 18.95, 13.05, "Connect &\ndiscover", fs=8.5)
    bracket(ax, 2.2, 12.85, 9.95, "Subscribe\n(CCCD)", fs=8.5)
    bracket(ax, 2.2, 9.75, 4.75, "Notify\n(flow control)", fs=8.5)
    bracket(ax, 2.2, 4.65, 1.75, "ACK", fs=8.5)

    # ===== catatan kaki & legenda =====
    small(ax, 7.7, 1.0,
          "128-bit UUIDs (16-bit aliases A100/A101/A102 on the Bluetooth base "
          "UUID).  One notification = one frame (opcode 1 B + chunk <= MTU-4).",
          fs=7.4)
    legend_flow(ax, 1.0, 0.3, "ACK / response (dashed)")
    save(fig, "fig_gatt")


if __name__ == "__main__":
    print("Membuat diagram (gaya monokrom) ke %s/ ..." % OUT)
    fig_architecture(); fig_sequence(); fig_framing(); fig_storeforward()
    fig_watch_arch(); fig_gatt()
    print("Selesai.")
