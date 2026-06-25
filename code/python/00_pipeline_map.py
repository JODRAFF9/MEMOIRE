# ============================================================
#  00_pipeline_map.py — Carte visuelle du pipeline d'analyse
#  Genere pipeline.png dans code/python/output/
# ============================================================

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyArrowPatch
from config import OUTPUT_DIR

fig, ax = plt.subplots(figsize=(18, 22))
ax.set_xlim(0, 18)
ax.set_ylim(0, 22)
ax.axis("off")

# ── Palette ──────────────────────────────────────────────────
C = {
    "data"   : ("#dbeafe", "#3b82f6"),   # bleu   — données
    "step"   : ("#dcfce7", "#16a34a"),   # vert   — etapes
    "out"    : ("#fef9c3", "#ca8a04"),   # jaune  — sorties
    "robust" : ("#fce7f3", "#db2777"),   # rose   — robustesse
    "title"  : ("#f1f5f9", "#334155"),   # gris   — titres
}

def box(ax, x, y, w, h, label, color, fontsize=9, bold=False):
    fc, ec = color
    rect = mpatches.FancyBboxPatch(
        (x - w/2, y - h/2), w, h,
        boxstyle="round,pad=0.1", linewidth=1.5,
        facecolor=fc, edgecolor=ec
    )
    ax.add_patch(rect)
    weight = "bold" if bold else "normal"
    ax.text(x, y, label, ha="center", va="center",
            fontsize=fontsize, fontweight=weight, color="#1e293b",
            wrap=True, multialignment="center")

def arrow(ax, x1, y1, x2, y2, color="#64748b"):
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle="-|>", color=color,
                                lw=1.4, mutation_scale=12))

def hline(ax, y, x1, x2, color="#94a3b8"):
    ax.plot([x1, x2], [y, y], color=color, lw=1, ls="--")

# ── Titre ────────────────────────────────────────────────────
ax.text(9, 21.4,
        "Pipeline d'analyse — Impact des transferts de migrants\n"
        "sur la pauvreté multidimensionnelle des enfants au Sénégal",
        ha="center", va="center", fontsize=13, fontweight="bold", color="#1e293b")

# ── BLOC 0 : Données brutes ──────────────────────────────────
box(ax,  4.5, 20.2, 3.8, 0.7, "EHCVM I (2018-2019)\nehcvm_individu · menage · welfare · S13A", C["data"], 8)
box(ax, 13.5, 20.2, 3.8, 0.7, "EHCVM II (2021-2022)\nehcvm_individu · menage · welfare · S13", C["data"], 8)

arrow(ax,  4.5, 19.85,  4.5, 19.35)
arrow(ax, 13.5, 19.85, 13.5, 19.35)

# ── BLOC 1 : Visitation ──────────────────────────────────────
box(ax, 9, 19.0, 16, 0.6, "01_visitation — Exploration & audit qualité des bases", C["step"], 9, bold=True)

arrow(ax, 9, 18.7, 9, 18.2)

# ── BLOC 2 : Variable de traitement ─────────────────────────
box(ax, 9, 17.9, 16, 0.55,
    "02_traitement — Variable de traitement D_i", C["step"], 9, bold=True)

box(ax, 4.5, 17.1, 5.5, 0.65,
    "s13aq14 / s13q19 ≥ 4\n(pays étranger : France, Espagne…)", C["out"], 8)
box(ax, 13.5, 17.1, 5.5, 0.65,
    "s13aq14 / s13q19 ≤ 3\n(intérieur Sénégal ou même localité)", C["title"], 8)

ax.text(3.5, 17.1, "D = 1", ha="center", va="center",
        fontsize=9, fontweight="bold", color="#16a34a")
ax.text(15.8, 17.1, "D = 0", ha="center", va="center",
        fontsize=9, fontweight="bold", color="#dc2626")

arrow(ax, 9, 18.62, 4.5, 17.43)
arrow(ax, 9, 18.62, 13.5, 17.43)

# ── BLOC 3 : Déprivation ────────────────────────────────────
arrow(ax, 9, 17.58, 9, 16.75)
box(ax, 9, 16.45, 16, 0.55,
    "03_deprivation — Indicateurs de pauvreté (enfants 0-17 ans)", C["step"], 9, bold=True)

# AF
box(ax, 4, 15.55, 7, 1.1,
    "Alkire-Foster\n6 indicateurs (éducation, santé, nutrition,\neau, assainissement, habitat)\n"
    "score_dep = Σ wⱼ·dⱼ   ·   pauvre_AF = 1 si score ≥ 1/3\n"
    "M0 = H × A", C["out"], 7.5)

# MODA
box(ax, 14, 15.55, 7.5, 1.1,
    "MODA UNICEF\n0-4 ans : santé · nutrition · eau · assaini. · habitat\n"
    "5-14 ans : éduc. · santé · eau · assaini. · habitat\n"
    "15-17 ans : éduc. · travail · eau · assaini. · habitat\n"
    "pauvre_MODA = 1 si nb_dep ≥ 2", C["out"], 7.5)

arrow(ax, 9, 16.17, 4, 16.1)
arrow(ax, 9, 16.17, 14, 16.1)

# ── BLOC 4 : PSM-DD ─────────────────────────────────────────
arrow(ax, 4, 15.0, 4, 14.3)
arrow(ax, 14, 15.0, 14, 14.3)
arrow(ax, 4.5, 16.78, 9, 14.35)   # D -> PSM-DD
ax.plot([9, 9], [14.3, 14.05], color="#64748b", lw=1.4)

box(ax, 9, 13.75, 16, 0.55,
    "04_psm_dd — Estimation PSM-DD (Heckman et al. 1997/1998)", C["step"], 9, bold=True)

# PSM
box(ax, 4, 12.85, 7, 0.95,
    "PSM — Score de propension\nProbit : D ~ X\np̂(X) = Φ(Xβ)\nVérification overlap", C["out"], 7.5)

# Appariement
box(ax, 14, 12.85, 7.5, 0.95,
    "Appariement\nk plus proches voisins (k=4)\nKernel (Epanechnikov)\nCaliper (0.25σ)", C["out"], 7.5)

arrow(ax, 9, 13.47, 4, 13.33)
arrow(ax, 9, 13.47, 14, 13.33)

# DD
arrow(ax, 4, 12.37, 9, 11.85)
arrow(ax, 14, 12.37, 9, 11.85)

box(ax, 9, 11.55, 13, 0.55,
    "Double Différence : Y_it = α + β·t + γ·D + δ·(t×D) + ε", C["out"], 8.5)

arrow(ax, 9, 11.27, 9, 10.75)

box(ax, 9, 10.45, 13, 0.55,
    "PSM-DD : ATT = E[ΔY_traités] − Σ wᵢⱼ E[ΔY_appariés]", C["out"], 8.5, bold=True)

# ── BLOC 5 : Résultats ───────────────────────────────────────
arrow(ax, 9, 10.17, 9, 9.55)

box(ax, 4.5, 9.25, 6.5, 0.55,
    "ATT — pauvre_AF\nImpact sur M0 Alkire-Foster", C["out"], 8, bold=True)
box(ax, 13.5, 9.25, 6.5, 0.55,
    "ATT — pauvre_MODA\nImpact sur déprivations MODA", C["out"], 8, bold=True)

arrow(ax, 9, 10.17, 4.5, 9.53)
arrow(ax, 9, 10.17, 13.5, 9.53)

# ── BLOC 6 : Robustesse ──────────────────────────────────────
arrow(ax, 4.5, 8.97, 4.5, 8.35)
arrow(ax, 13.5, 8.97, 13.5, 8.35)
ax.plot([4.5, 13.5], [8.35, 8.35], color="#64748b", lw=1.4)
ax.plot([9, 9], [8.35, 8.1], color="#64748b", lw=1.4)
arrow(ax, 9, 8.1, 9, 7.85)

box(ax, 9, 7.55, 16, 0.55,
    "Robustesse & sensibilité", C["robust"], 9, bold=True)

box(ax,  3.5, 6.75, 4.5, 0.65,
    "Bootstrap\n1 000 réplications", C["robust"], 7.5)
box(ax,  9,   6.75, 5,   0.65,
    "Bornes de Rosenbaum\nsensibilité aux biais cachés", C["robust"], 7.5)
box(ax, 14.5, 6.75, 5.5, 0.65,
    "Hétérogénéité\nmilieu · région · sexe chef", C["robust"], 7.5)

arrow(ax, 9, 7.27, 3.5,  7.08)
arrow(ax, 9, 7.27, 9,    7.08)
arrow(ax, 9, 7.27, 14.5, 7.08)

# ── Légende ──────────────────────────────────────────────────
legend_items = [
    mpatches.Patch(facecolor=C["data"][0],   edgecolor=C["data"][1],   label="Données brutes"),
    mpatches.Patch(facecolor=C["step"][0],   edgecolor=C["step"][1],   label="Étape du pipeline"),
    mpatches.Patch(facecolor=C["out"][0],    edgecolor=C["out"][1],    label="Sortie / résultat"),
    mpatches.Patch(facecolor=C["robust"][0], edgecolor=C["robust"][1], label="Robustesse"),
]
ax.legend(handles=legend_items, loc="lower center", bbox_to_anchor=(0.5, 0.01),
          ncol=4, fontsize=8, frameon=True)

plt.tight_layout()
out = OUTPUT_DIR / "pipeline.png"
plt.savefig(out, dpi=150, bbox_inches="tight", facecolor="white")
print(f"Pipeline sauvegarde : {out}")
plt.show()
