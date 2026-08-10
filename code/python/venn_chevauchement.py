# -*- coding: utf-8 -*-
"""Diagrammes de Venn du chevauchement tridimensionnel logement x
nutrition x assainissement a la periode de base (EHCVM I) : ensemble des
enfants suivis, puis beneficiaires stables et non-beneficiaires.

Se lance depuis la racine du depot, apres un run complet de tout.do :
    python code/python/venn_chevauchement.py
Sorties : latex/figures/fig_venn_{ensemble,beneficiaires,nonbeneficiaires}.pdf
(copies dans Presentation/figures et code/stata/output/figures)."""

import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib_venn import venn3

COLS = ["t", "D", "dim_logem", "dim_nutri", "dim_assai"]
df = pd.read_stata("code/stata/temp/panel_enfants_psm.dta",
                   convert_categoricals=False, columns=COLS)
base = df[df.t == 0].dropna(subset=["dim_logem", "dim_nutri", "dim_assai"])

def venn(nom_fichier, d):
    n = len(d)
    L, N, A = d.dim_logem == 1, d.dim_nutri == 1, d.dim_assai == 1

    def pct(mask):
        return round(100 * mask.sum() / n, 1)

    subsets = (pct(L & ~N & ~A), pct(~L & N & ~A), pct(L & N & ~A),
               pct(~L & ~N & A), pct(L & ~N & A), pct(~L & N & A),
               pct(L & N & A))
    fig, ax = plt.subplots(figsize=(7, 6))
    v = venn3(subsets=subsets,
              set_labels=(f"Logement ({pct(L)} %)".replace(".", ","),
                          f"Nutrition ({pct(N)} %)".replace(".", ","),
                          f"Assainissement ({pct(A)} %)".replace(".", ",")),
              set_colors=("#999999", "#e07b39", "#4c72b0"), alpha=0.6, ax=ax)
    for idx in ("100", "010", "001", "110", "101", "011", "111"):
        lbl = v.get_label_by_id(idx)
        if lbl:
            lbl.set_text(lbl.get_text().replace(".", ",") + " %")
            lbl.set_fontsize(9)
    ax.set_title(f"Non-privés des trois : {pct(~L & ~N & ~A)} %"
                 .replace(".", ","), fontsize=10, loc="left")
    fig.tight_layout()
    for basedir in ("latex/figures", "Presentation/figures",
                    "code/stata/output/figures"):
        fig.savefig(f"{basedir}/{nom_fichier}")
    plt.close(fig)
    print(nom_fichier, "ecrit.")

venn("fig_venn_ensemble.pdf", base)
venn("fig_venn_beneficiaires.pdf", base[base.D == 1])
venn("fig_venn_nonbeneficiaires.pdf", base[base.D == 0])
