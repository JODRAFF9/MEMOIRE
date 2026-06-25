# ============================================================
#  04_psm_dd.py — Estimation PSM-DD (Heckman et al. 1997/1998)
#  ATT sur pauvre_AF et pauvre_MODA
# ============================================================

import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
import matplotlib.pyplot as plt
from config import BASE_2018, BASE_2021, ID, SEED, OUTPUT_DIR
from utils import lire_stata, taux

wel_2018, _ = lire_stata(BASE_2018, "ehcvm_welfare_sen2018.dta")
wel_2021, _ = lire_stata(BASE_2021, "ehcvm_welfare_sen2021.dta")

traitement_2018 = pd.read_parquet(OUTPUT_DIR / "traitement_2018.parquet")
traitement_2021 = pd.read_parquet(OUTPUT_DIR / "traitement_2021.parquet")
enfants_2018    = pd.read_parquet(OUTPUT_DIR / "enfants_dep_2018.parquet")
enfants_2021    = pd.read_parquet(OUTPUT_DIR / "enfants_dep_2021.parquet")


def construire_base(enfants, traitement, welfare, annee, t):
    return (
        enfants
        .merge(traitement[ID + ["D"]], on=ID, how="left")
        .merge(welfare[ID + ["pcexp","hhsize"]], on=ID, how="left")
        .assign(annee=annee, t=t, log_pcexp=lambda x: np.log(x["pcexp"] + 1))
    )


base_2018 = construire_base(enfants_2018, traitement_2018, wel_2018, 2018, 0)
base_2021 = construire_base(enfants_2021, traitement_2021, wel_2021, 2021, 1)
panel = pd.concat([base_2018, base_2021], ignore_index=True)

print(f"Base analytique : {len(panel):,} obs")

# Stats descriptives par statut traitement
print(panel.groupby(["annee","D"])[["pauvre_AF","pauvre_MODA","score_dep","pcexp"]].mean().round(3))

# ── PSM : probit (periode de base t=0) ───────────────────────

base_t0 = base_2018.dropna(subset=["D","hhsize","log_pcexp"])

probit = smf.probit("D ~ hhsize + log_pcexp", data=base_t0).fit()
print(probit.summary())

base_t0 = base_t0.copy()
base_t0["pscore"] = probit.predict()

# Overlap
fig, ax = plt.subplots()
for d, label, color in [(0,"Non-traites","steelblue"), (1,"Traites","tomato")]:
    base_t0[base_t0["D"]==d]["pscore"].plot.kde(ax=ax, label=label, color=color)
ax.set(title="Distribution du score de propension", xlabel="pscore")
ax.legend()
fig.savefig(OUTPUT_DIR / "overlap.pdf")

# ── Double Difference ─────────────────────────────────────────

for outcome in ["pauvre_AF", "pauvre_MODA"]:
    mod = smf.ols(f"{outcome} ~ t * D", data=panel).fit(
        cov_type="cluster", cov_kwds={"groups": panel["grappe"]}
    )
    att_dd = mod.params.get("t:D", float("nan"))
    pval   = mod.pvalues.get("t:D", float("nan"))
    print(f"\nDD — {outcome} : ATT = {att_dd:.4f}  (p = {pval:.3f})")

# ── PSM-DD ────────────────────────────────────────────────────
# (a implementer apres appariement et pseudo-panel grappe-level)

# ── Robustesse : bootstrap ────────────────────────────────────
# (a implementer avec la librairie arch ou bootstrapped)
