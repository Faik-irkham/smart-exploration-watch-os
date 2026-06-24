# -*- coding: utf-8 -*-
"""
Figure 1 - Research flow in the same monochrome journal style as
figure1_research_flow.png, but explicitly split into a TRAINING PHASE and a
TESTING PHASE (as requested).

Output: figures/fig01_research_flow_2phase.png  (+ .pdf)
"""
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Polygon

BLACK = "#000000"
WHITE = "#FFFFFF"


def terminator(ax, x, y, w, h, label):
    ax.add_patch(FancyBboxPatch((x - w / 2, y - h / 2), w, h,
        boxstyle=f"round,pad=0.01,rounding_size={h/2}",
        linewidth=1.5, edgecolor=BLACK, facecolor=WHITE, zorder=5))
    ax.text(x, y, label, fontsize=12, fontweight="bold",
            ha="center", va="center", color=BLACK, zorder=6)


def box(ax, x, y, w, h, title, fs=10.0):
    ax.add_patch(FancyBboxPatch((x - w / 2, y - h / 2), w, h,
        boxstyle="round,pad=0.01,rounding_size=0.03",
        linewidth=1.4, edgecolor=BLACK, facecolor=WHITE, zorder=2))
    ax.text(x, y, title, fontsize=fs, fontweight="bold",
            ha="center", va="center", color=BLACK, zorder=4)


def diamond(ax, x, y, w, h, title):
    pts = [(x, y + h / 2), (x + w / 2, y), (x, y - h / 2), (x - w / 2, y)]
    ax.add_patch(Polygon(pts, closed=True, linewidth=1.4,
                         edgecolor=BLACK, facecolor=WHITE, zorder=2))
    ax.text(x, y, title, fontsize=8.8, fontweight="bold",
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


def small(ax, x, y, text, ha="center"):
    ax.text(x, y, text, fontsize=8.6, fontweight="bold",
            ha=ha, va="center", color=BLACK, zorder=6)


def tag(ax, x, y, text):
    ax.text(x, y, text, fontsize=8.0, style="italic", ha="center", va="center",
            color=BLACK, zorder=6,
            bbox=dict(boxstyle="round,pad=0.28", facecolor=WHITE,
                      edgecolor=BLACK, linewidth=0.8))


def phase_bracket(ax, x, y_top, y_bot, label):
    line(ax, [(x, y_bot), (x, y_top)])
    line(ax, [(x, y_top), (x + 0.18, y_top)])
    line(ax, [(x, y_bot), (x + 0.18, y_bot)])
    ax.text(x - 0.22, (y_top + y_bot) / 2, label, rotation=90, ha="center",
            va="center", fontsize=12, fontweight="bold", color=BLACK)


def build(out_png):
    XC = 6.4
    W, H = 8.8, 0.95
    DEC_W, DEC_H = 3.2, 1.45
    XLOOP = 11.6
    XHOLD = 12.7

    y = 25.0
    def place(h, gap):
        nonlocal y
        cy = y - h / 2
        y = cy - h / 2 - gap
        return cy

    y_start = place(0.72, 0.80)
    y_data  = place(H, 0.80)
    y_prep  = place(H, 0.80)
    y_feat  = place(H, 0.80)
    y_split = place(H, 1.10)
    y_hpo   = place(1.15, 0.80)
    y_dec   = place(DEC_H, 0.80)
    y_best  = place(H, 0.80)
    y_cv    = place(1.15, 0.80)
    y_stat  = place(H, 0.80)
    y_sel   = place(H, 1.20)
    y_retr  = place(1.15, 0.80)
    y_eval  = place(1.15, 0.80)
    y_feim  = place(H, 0.80)
    y_res   = place(H, 0.80)
    y_end   = place(0.72, 0.0)

    fig, ax = plt.subplots(figsize=(10.0, 17.5), dpi=300)
    ax.set_xlim(0, 14.0)
    ax.set_ylim(y_end - 1.4, y_start + 0.7)
    ax.set_aspect("equal")
    ax.axis("off")
    fig.patch.set_facecolor(WHITE)

    # ---- shared intake ----
    terminator(ax, XC, y_start, 2.3, 0.72, "START")
    box(ax, XC, y_data, W, H, "Dataset  (24,084 records  x  12 attributes)")
    box(ax, XC, y_prep, W, H,
        "Preprocessing\n(drop 13 duplicates -> 24,071; encode target; boolean -> integer)", fs=9.2)
    box(ax, XC, y_feat, W, H,
        "Feature Engineering  (+6 engineered features -> 17 predictors)", fs=9.4)
    box(ax, XC, y_split, W, H, "Stratified 80 : 20 Split  (random_state = 42)")

    # ---- training phase ----
    box(ax, XC, y_hpo, W, 1.15,
        "Seven Configurations: Baseline (default)  +  6 HPO Methods\n"
        "Hyperparameter Optimization  .  Inner 5-Fold CV", fs=9.2)
    diamond(ax, XC, y_dec, DEC_W, DEC_H, "Trial budget\nreached?")
    box(ax, XC, y_best, W, H, "Best Hyperparameter Configuration  (theta*)")
    box(ax, XC, y_cv, W, 1.15,
        "10-Fold Stratified Cross-Validation\n"
        "Accuracy . Precision . Recall . F1 . MCC . AUC", fs=9.2)
    box(ax, XC, y_stat, W, H, "Statistical Validation  (Friedman -> Nemenyi CD)")
    box(ax, XC, y_sel, W, H, "Select Best HPO Method")

    # ---- testing phase ----
    box(ax, XC, y_retr, W, 1.15,
        "Retrain Best Model on the\nFull Training Set  (19,256 samples)", fs=9.6)
    box(ax, XC, y_eval, W, 1.15,
        "Holdout Test Evaluation  (4,815 samples)\n"
        "Accuracy . Precision . Recall . F1 . MCC . AUC", fs=9.2)
    box(ax, XC, y_feim, W, H, "Feature Importance Analysis  (best model)")
    box(ax, XC, y_res, W, H, "Results & Interpretation")
    terminator(ax, XC, y_end, 2.3, 0.72, "END")

    # ---- vertical arrows ----
    arrow(ax, XC, y_start - 0.36, XC, y_data + H / 2)
    arrow(ax, XC, y_data - H / 2, XC, y_prep + H / 2)
    arrow(ax, XC, y_prep - H / 2, XC, y_feat + H / 2)
    arrow(ax, XC, y_feat - H / 2, XC, y_split + H / 2)
    arrow(ax, XC, y_split - H / 2, XC, y_hpo + 1.15 / 2)
    small(ax, XC + 1.5, (y_split - H / 2 + y_hpo + 1.15 / 2) / 2, "X_train . 19,256", ha="left")
    arrow(ax, XC, y_hpo - 1.15 / 2, XC, y_dec + DEC_H / 2)

    # decision: No -> loop back to HPO (right lane)
    line(ax, [(XC + DEC_W / 2, y_dec), (XLOOP, y_dec), (XLOOP, y_hpo)])
    arrow(ax, XLOOP, y_hpo, XC + W / 2, y_hpo)
    small(ax, (XC + DEC_W / 2 + XLOOP) / 2, y_dec + 0.26, "No")
    # decision: Yes -> down
    arrow(ax, XC, y_dec - DEC_H / 2, XC, y_best + H / 2)
    small(ax, XC + 0.30, (y_dec - DEC_H / 2 + y_best + H / 2) / 2, "Yes", ha="left")

    arrow(ax, XC, y_best - H / 2, XC, y_cv + 1.15 / 2)
    arrow(ax, XC, y_cv - 1.15 / 2, XC, y_stat + H / 2)
    arrow(ax, XC, y_stat - H / 2, XC, y_sel + H / 2)
    arrow(ax, XC, y_sel - H / 2, XC, y_retr + 1.15 / 2)
    arrow(ax, XC, y_retr - 1.15 / 2, XC, y_eval + 1.15 / 2)
    arrow(ax, XC, y_eval - 1.15 / 2, XC, y_feim + H / 2)
    arrow(ax, XC, y_feim - H / 2, XC, y_res + H / 2)
    arrow(ax, XC, y_res - H / 2, XC, y_end + 0.36)

    # ---- dashed holdout hand-off: Split -> Holdout Test Evaluation ----
    line(ax, [(XC + W / 2, y_split), (XHOLD, y_split), (XHOLD, y_eval)], dashed=True)
    arrow(ax, XHOLD, y_eval, XC + W / 2, y_eval, dashed=True)
    tag(ax, XHOLD, (y_split + y_eval) / 2, "X_test\nreserved\n(holdout\n4,815)")

    # ---- phase brackets on the left ----
    phase_bracket(ax, 1.05, y_hpo + 1.15 / 2, y_sel - H / 2, "TRAINING PHASE")
    phase_bracket(ax, 1.05, y_retr + 1.15 / 2, y_feim - H / 2, "TESTING PHASE")

    # ---- legend ----
    leg_y = y_end - 0.95
    arrow(ax, XC - 4.4, leg_y, XC - 3.6, leg_y)
    ax.text(XC - 3.45, leg_y, "sequential flow", fontsize=9,
            ha="left", va="center", color=BLACK)
    arrow(ax, XC + 0.9, leg_y, XC + 1.7, leg_y, dashed=True)
    ax.text(XC + 1.85, leg_y, "reserved data hand-off (holdout)",
            fontsize=9, ha="left", va="center", color=BLACK)

    plt.subplots_adjust(left=0.01, right=0.99, top=0.99, bottom=0.01)
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    plt.savefig(out_png, dpi=300, bbox_inches="tight", facecolor=WHITE)
    plt.savefig(os.path.splitext(out_png)[0] + ".pdf", bbox_inches="tight", facecolor=WHITE)
    plt.close(fig)
    print("[OK] saved:", out_png)


if __name__ == "__main__":
    build(os.path.join("figures", "fig01_research_flow_2phase.png"))
