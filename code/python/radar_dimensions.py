# -*- coding: utf-8 -*-
"""Radars des taux de privation par dimension MODA selon le statut de
beneficiaire, aux deux editions, pour l'ensemble puis chaque groupe d'age.

Quatre courbes par radar : non-beneficiaires et beneficiaires stables, a
chacune des deux editions. Les valeurs chiffrees figurent dans les
tableaux dimension x statut du chapitre de statistiques descriptives.

Se lance depuis la racine du depot apres un run complet de tout.do :
    python code/python/radar_dimensions.py
Sorties : latex/figures/fig_radar_{ensemble,0_4,5_14,15_17}.pdf (copies
dans Presentation/figures et code/stata/output/figures)."""

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

DIMS = ["dim_assai", "dim_eau", "dim_logem", "dim_nutri",
        "dim_sante", "dim_protect", "dim_educ"]
NOMS = ["Assainissement", "Eau", "Logement", "Nutrition",
        "Santé", "Protection", "Éducation"]

df = pd.read_stata("code/stata/temp/panel_enfants_psm.dta",
                   convert_categoricals=False,
                   columns=["t", "D", "groupe_base", "hhweight"] + DIMS)

def taux(sub):
    w = sub.hhweight
    return [100 * (sub[d] * w).sum() / w[sub[d].notna()].sum() for d in DIMS]

def radar(nom_fichier, sub):
    series = [
        (taux(sub[(sub.t == 0) & (sub.D == 0)]), "#999999", "-",
         "Non-bénéficiaires, EHCVM I"),
        (taux(sub[(sub.t == 1) & (sub.D == 0)]), "#999999", "--",
         "Non-bénéficiaires, EHCVM II"),
        (taux(sub[(sub.t == 0) & (sub.D == 1)]), "#e07b39", "-",
         "Bénéficiaires, EHCVM I"),
        (taux(sub[(sub.t == 1) & (sub.D == 1)]), "#e07b39", "--",
         "Bénéficiaires, EHCVM II"),
    ]
    ang = np.linspace(0, 2 * np.pi, len(DIMS), endpoint=False).tolist()
    fig, ax = plt.subplots(figsize=(8.6, 7.6),
                           subplot_kw={"projection": "polar"})
    for vals, coul, style, lab in series:
        v = vals + vals[:1]
        a = ang + ang[:1]
        ax.plot(a, v, color=coul, linestyle=style, linewidth=2, label=lab)
    ax.set_xticks(ang)
    ax.set_xticklabels([])
    ax.set_ylim(0, 100)
    ax.set_yticks([25, 50, 75, 100])
    ax.set_yticklabels(["25", "50", "75", "100"], fontsize=8, color="grey")
    # Valeurs aux sommets : editions I puis II, gris = non-beneficiaires,
    # orange = beneficiaires. Position en fraction d'axes pour empiler
    # proprement les deux lignes quel que soit l'angle.
    nb18, nb21 = series[0][0], series[1][0]
    b18,  b21  = series[2][0], series[3][0]
    for i, a_i in enumerate(ang):
        fx = 0.5 + 0.56 * np.cos(a_i)
        fy = 0.5 + 0.56 * np.sin(a_i)
        txt_nb = f"{nb18[i]:.1f} ; {nb21[i]:.1f}".replace(".", ",")
        txt_b  = f"{b18[i]:.1f} ; {b21[i]:.1f}".replace(".", ",")
        ax.text(fx, fy + 0.052, NOMS[i], transform=ax.transAxes,
                ha="center", va="center", fontsize=10, color="black")
        ax.text(fx, fy + 0.020, txt_nb, transform=ax.transAxes,
                ha="center", va="center", fontsize=7, color="#777777")
        ax.text(fx, fy - 0.010, txt_b, transform=ax.transAxes,
                ha="center", va="center", fontsize=7, color="#e07b39")
    ax.legend(loc="lower center", bbox_to_anchor=(0.5, -0.24),
              ncol=2, fontsize=9, frameon=False)
    fig.subplots_adjust(left=0.16, right=0.84, top=0.90, bottom=0.16)
    for base in ("latex/figures", "Presentation/figures",
                 "code/stata/output/figures"):
        fig.savefig(f"{base}/{nom_fichier}")
    plt.close(fig)
    print(nom_fichier, "ecrit.")

radar("fig_radar_ensemble.pdf", df)
radar("fig_radar_0_4.pdf",   df[df.groupe_base == 1])
radar("fig_radar_5_14.pdf",  df[df.groupe_base == 2])
radar("fig_radar_15_17.pdf", df[df.groupe_base == 3])
