#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Genere les quatre graphiques de taux de privation par indicateur, par
tranche d'age (ensemble 0-17, 0-4, 5-14, 15-17 ans) et par vague, a
l'image de la figure ANSD/UNICEF : barres horizontales, deux series
(EHCVM I / II), regroupees par dimension avec le nom de la dimension
place dans une colonne a gauche, centree verticalement sur son groupe
d'indicateurs.

Cette mise en page (libelles de dimension centres a gauche) n'est pas
realisable proprement avec `graph hbar` de Stata : le double
over(indicateur)#over(dimension) echoue sur un croisement non
rectangulaire (chaque indicateur n'appartient qu'a une dimension).
La generation est donc confiee a ce script, execute apres tout.do.

Estimations PONDEREES par les poids de sondage (hhweight), comme le
reste des statistiques descriptives du chapitre 3.

Usage :  python code/python/gen_fig_privind.py
"""
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.transforms as mtrans
from matplotlib.ticker import MultipleLocator
from matplotlib.patches import Patch

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEMP = os.path.join(ROOT, "code", "stata", "temp")
OUTDIRS = [os.path.join(ROOT, "latex", "figures"),
           os.path.join(ROOT, "Presentation", "figures"),
           os.path.join(ROOT, "code", "stata", "output", "figures")]

GREY, ORANGE = "#8c8c8c", "#e07b39"

# variable, libelle, dimension, applicabilite (all / g12=0-14 / g2=5-14 / g3=15-17)
META = [
    ("m_toilet",     "Type de toilettes",          "Assainissement", "all"),
    ("m_partag_toi", "Partage des toilettes",       "Assainissement", "all"),
    ("m_eau_source", "Source d'eau non améliorée",  "Eau",            "all"),
    ("m_eau_temps",  "Temps d'accès à l'eau",       "Eau",            "all"),
    ("m_ordures",    "Gestion des ordures",         "Logement",       "all"),
    ("m_surpeup",    "Surpeuplement",               "Logement",       "all"),
    ("m_securite",   "Insécurité alimentaire",      "Nutrition",      "all"),
    ("m_combust",    "Combustible solide",          "Santé",          "all"),
    ("m_acte_nais",  "Absence d'acte de naissance", "Protection",     "g12"),
    ("m_trav_enf",   "Travail des enfants",         "Protection",     "g2"),
    ("m_parents",    "Séparation parentale",        "Protection",     "all"),
    ("m_scol",       "Non-scolarisation",           "Éducation",      "g2"),
    ("m_alfab",      "Illettrisme",                 "Éducation",      "g3"),
    ("m_neet",       "NEET",                        "Éducation",      "g3"),
]
DIM_ORDER = ["Assainissement", "Eau", "Logement", "Nutrition",
             "Santé", "Protection", "Éducation"]
FIGS = [("all", "0 à 17 ans", "all"), ("1", "0-4 ans", "0_4"),
        ("2", "5-14 ans", "5_14"), ("3", "15-17 ans", "15_17")]
GRPMAP = {"1": "0-4 ans", "2": "5-14 ans", "3": "15-17 ans"}


def applicable(a, G):
    return (a == "all"
            or (a == "g12" and G in ("all", "1", "2"))
            or (a == "g2" and G in ("all", "2"))
            or (a == "g3" and G in ("all", "3")))


def subset(df, a, G):
    if G != "all":
        return df[df["grp"] == GRPMAP[G]]
    if a == "all":
        return df
    if a == "g12":
        return df[df["age"] <= 14]
    if a == "g2":
        return df[(df["age"] >= 5) & (df["age"] <= 14)]
    return df[df["age"] >= 15]


def wmean(df, v):
    m = df[[v, "hhweight"]].dropna()
    return np.nan if len(m) == 0 else 100 * np.average(m[v], weights=m["hhweight"])


def comma(x):
    return "" if x is None or np.isnan(x) else f"{x:.1f}".replace(".", ",")


def main():
    d = {}
    for y in (2018, 2021):
        df = pd.read_stata(os.path.join(TEMP, f"enfants_dep_{y}.dta"))
        df["grp"] = df["groupe_moda"].astype(str)
        d[y] = df

    for G, glabel, suf in FIGS:
        rows = []  # (label, dim, v18, v21)
        for dim in DIM_ORDER:
            inds = [(name, v, a) for v, name, dm, a in META
                    if dm == dim and applicable(a, G)]
            for name, v, a in inds:
                rows.append((name, dim,
                             wmean(subset(d[2018], a, G), v),
                             wmean(subset(d[2021], a, G), v)))
        labels = [r[0] for r in rows]
        dims = [r[1] for r in rows]
        v18 = [r[2] for r in rows]
        v21 = [r[3] for r in rows]
        n = len(rows)
        yy = np.arange(n)          # bottom-to-top ; index 0 en bas
        h = 0.38

        fig, ax = plt.subplots(figsize=(10.2, 0.46 * n + 1.4))
        fig.subplots_adjust(left=0.40, right=0.97, top=0.97, bottom=0.13)
        ax.barh(yy + h / 2, v18, height=h, color=GREY,
                label="EHCVM I (2018-19)", zorder=3)
        ax.barh(yy - h / 2, v21, height=h, color=ORANGE,
                label="EHCVM II (2021-22)", zorder=3)
        for y, x in zip(yy + h / 2, v18):
            if not np.isnan(x):
                ax.text(x + 1, y, comma(x), va="center", fontsize=7.5)
        for y, x in zip(yy - h / 2, v21):
            if not np.isnan(x):
                ax.text(x + 1, y, comma(x), va="center", fontsize=7.5)

        ax.set_yticks(yy)
        ax.set_yticklabels(labels, fontsize=8.5)
        ax.set_ylim(-0.6, n - 0.4)
        ax.set_xlim(0, 100)
        ax.xaxis.set_major_locator(MultipleLocator(10))
        ax.set_xlabel("Taux de privation (%)", fontsize=9)
        # Pas de titre integre : la figure est titree par le \caption LaTeX.
        ax.grid(axis="x", color="#dddddd", lw=0.6, zorder=0)
        ax.set_axisbelow(True)
        for sp in ("top", "right", "left"):
            ax.spines[sp].set_visible(False)
        ax.tick_params(length=0)

        # Libelles de dimension dans une colonne a gauche, centres
        # verticalement sur leur groupe d'indicateurs + separateurs.
        blend = mtrans.blended_transform_factory(ax.transAxes, ax.transData)
        groups = {}
        for i, dm in enumerate(dims):
            groups.setdefault(dm, []).append(i)
        order = list(dict.fromkeys(dims))
        for k, dm in enumerate(order):
            idx = groups[dm]
            ax.text(-0.36, np.mean(idx), dm.upper(), transform=blend,
                    ha="left", va="center", fontsize=8.5,
                    color="#555555", weight="bold")
            if k > 0:
                yb = min(idx) - 0.5
                ax.plot([-0.38, 1.0], [yb, yb], transform=blend,
                        color="#cccccc", lw=0.7, clip_on=False, zorder=1)
        for yb in (-0.5, n - 0.5):
            ax.plot([-0.38, 1.0], [yb, yb], transform=blend,
                    color="#cccccc", lw=0.7, clip_on=False, zorder=1)
        ax.plot([-0.005, -0.005], [-0.5, n - 0.5], transform=blend,
                color="#cccccc", lw=0.7, clip_on=False)

        ax.legend(handles=[Patch(color=GREY, label="EHCVM I (2018-19)"),
                           Patch(color=ORANGE, label="EHCVM II (2021-22)")],
                  loc="lower right", fontsize=8.5, frameon=False)

        for out in OUTDIRS:
            os.makedirs(out, exist_ok=True)
            fig.savefig(os.path.join(out, f"fig_privind_{suf}.pdf"),
                        bbox_inches="tight")
        plt.close(fig)
        print(f">>> fig_privind_{suf}.pdf ({n} indicateurs)")


if __name__ == "__main__":
    main()
