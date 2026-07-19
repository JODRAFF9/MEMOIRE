#!/usr/bin/env python3
"""
Carte choroplethe de l'incidence N-MODA par region (EHCVM I et II).

Produit output/figures/fig_carte_nmoda.pdf a partir :
  - des fichiers panel temp/vague_2018.dta et vague_2021.dta (variable
    pauvre_MODA, produits par tout.do) ;
  - du fond de carte des regions Vecteurs_Senegal/Limite_Region.shp.

A lancer APRES tout.do (qui genere les fichiers vague_*.dta), depuis la
racine du depot :  python3 code/python/carte_nmoda.py

Dependances : pandas, pyshp (import shapefile), matplotlib, numpy.
"""
import warnings
from pathlib import Path

warnings.filterwarnings("ignore")
import numpy as np
import pandas as pd
import shapefile
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon as MplPoly
from matplotlib.cm import ScalarMappable
from matplotlib.colors import Normalize

ROOT = Path(__file__).resolve().parents[2]
TEMP = ROOT / "code" / "stata" / "temp"
SHP = ROOT / "Vecteurs_Sénégal" / "Limite_Région.shp"
OUT = ROOT / "code" / "stata" / "output" / "figures" / "fig_carte_nmoda.pdf"

# code region EHCVM -> nom du shapefile (NOMREG, en majuscules)
CODE2NOM = {1: "DAKAR", 2: "ZIGUINCHOR", 3: "DIOURBEL", 4: "SAINT LOUIS",
            5: "TAMBACOUNDA", 6: "KAOLACK", 7: "THIES", 8: "LOUGA",
            9: "FATICK", 10: "KOLDA", 11: "MATAM", 12: "KAFFRINE",
            13: "KEDOUGOU", 14: "SEDHIOU"}

# 1. Incidence N-MODA par region, memes valeurs que tout.do
nom2h = {}
for an in (2018, 2021):
    d = pd.read_stata(TEMP / f"vague_{an}.dta", convert_categoricals=False)
    h = (d.groupby("region").pauvre_MODA.mean() * 100).to_dict()
    nom2h[an] = {CODE2NOM[c]: v for c, v in h.items()}
    print(f"National H {an} = {d.pauvre_MODA.mean() * 100:.1f}%")

# 2. Fond de carte
sf = shapefile.Reader(str(SHP), encoding="latin1")
idx = [f[0] for f in sf.fields[1:]].index("NOMREG")

vmin = min(min(nom2h[a].values()) for a in (2018, 2021))
vmax = max(max(nom2h[a].values()) for a in (2018, 2021))
norm = Normalize(vmin=vmin, vmax=vmax)
cmap = plt.cm.YlOrRd

fig, axes = plt.subplots(1, 2, figsize=(11, 5.6))
titres = {2018: "EHCVM I (2018-2019)", 2021: "EHCVM II (2021-2022)"}

for ax, an in zip(axes, (2018, 2021)):
    for sr in sf.shapeRecords():
        nom = sr.record[idx]
        val = nom2h[an].get(nom, np.nan)
        col = cmap(norm(val)) if not np.isnan(val) else "#dddddd"
        pts = sr.shape.points
        parts = list(sr.shape.parts) + [len(pts)]
        for i in range(len(parts) - 1):
            seg = pts[parts[i]:parts[i + 1]]
            ax.add_patch(MplPoly(seg, closed=True, facecolor=col,
                                 edgecolor="white", linewidth=0.5))
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        if not np.isnan(val):
            ax.text(np.mean(xs), np.mean(ys), f"{val:.1f}".replace(".", ","),
                    ha="center", va="center", fontsize=6.5, color="black",
                    weight="bold")
    ax.set_title(titres[an], fontsize=11)
    ax.set_aspect("equal")
    ax.axis("off")
    ax.autoscale_view()

sm = ScalarMappable(cmap=cmap, norm=norm)
sm.set_array([])
cbar = fig.colorbar(sm, ax=axes, orientation="horizontal",
                    fraction=0.045, pad=0.04, aspect=40)
cbar.set_label("Incidence N-MODA H (%)", fontsize=10)
fig.suptitle("Pauvreté multidimensionnelle des enfants par région",
             fontsize=13, y=0.98)
for out in (OUT, ROOT / "latex" / "figures" / "fig_carte_nmoda.pdf"):
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, bbox_inches="tight")
    print(f">>> {out.relative_to(ROOT)} sauvegardé")
