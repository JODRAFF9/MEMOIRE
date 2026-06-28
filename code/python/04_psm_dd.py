# ============================================================
#  04_psm_dd.py — Estimation PSM-DD (Heckman et al. 1997/1998)
#  ATT sur pauvre_AF et pauvre_MODA — panel vrai (PanelHH=1)
# ============================================================

import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy import stats
from config import BASE_2018, BASE_2021, ID, SEED, OUTPUT_DIR, N_BOOT, CALIPER, K_VOISINS
from utils import lire_stata, taux

np.random.seed(SEED)

# ── 1. Charger le panel vrai ──────────────────────────────────

panel = pd.read_parquet(OUTPUT_DIR / "panel_ind_vrai.parquet")
panel_complet = pd.read_parquet(OUTPUT_DIR / "panel_ind_complet.parquet")

# Covariables welfare
wel_2018_df, _ = lire_stata(BASE_2018, "ehcvm_welfare_sen2018.dta")
wel_2021_df, _ = lire_stata(BASE_2021, "ehcvm_welfare_sen2021.dta")

VARS_WEL = ID + ["pcexp", "hhsize", "region", "milieu",
                 "hgender", "hage", "heduc", "hmstat"]


def prep_welfare(wel):
    cols = [c for c in VARS_WEL if c in wel.columns]
    df = wel[cols].copy()
    df["hhid"] = df["grappe"].astype(int) * 1000 + df["menage"].astype(int)
    return df


def enrichir_welfare(base, wel):
    cols_a_ajouter = [c for c in VARS_WEL + ["hhid"]
                      if c in wel.columns and c not in base.columns and c != "hhid"]
    return base.merge(wel[["hhid"] + cols_a_ajouter], on="hhid", how="left")


wel_18 = prep_welfare(wel_2018_df)
wel_21 = prep_welfare(wel_2021_df)

panel = pd.concat([
    enrichir_welfare(panel[panel["annee"] == 2018].copy(), wel_18),
    enrichir_welfare(panel[panel["annee"] == 2021].copy(), wel_21),
], ignore_index=True)
panel["log_pcexp"] = np.log(panel["pcexp"].clip(lower=1))

panel_complet = pd.concat([
    enrichir_welfare(panel_complet[panel_complet["annee"] == 2018].copy(), wel_18),
    enrichir_welfare(panel_complet[panel_complet["annee"] == 2021].copy(), wel_21),
], ignore_index=True)
panel_complet["log_pcexp"] = np.log(panel_complet["pcexp"].clip(lower=1))

# ── Filtre never-treated ──────────────────────────────────────
# Groupe témoin = D=0 en 2018 ET en 2021 (jamais traité)
# Groupe traité = D=1 en 2018 (statut stable à la période de base)
def filtrer_never_treated(df):
    d_pivot = df.pivot_table(index="hhid", columns="annee", values="D", aggfunc="max")
    if 2018 in d_pivot.columns and 2021 in d_pivot.columns:
        # Traités : D=1 en 2018 ET D=0 en 2021
        traites     = d_pivot[(d_pivot[2018] == 1) & (d_pivot[2021] == 0)].index
        # Témoins : D=0 en 2018 ET D=0 en 2021
        never       = d_pivot[(d_pivot[2018] == 0) & (d_pivot[2021] == 0)].index
        ids_valides = traites.union(never)
    else:
        ids_valides = d_pivot.index
    return df[df["hhid"].isin(ids_valides)].copy()

panel          = filtrer_never_treated(panel)
panel_complet  = filtrer_never_treated(panel_complet)

# D doit être statique (valeur 2018) pour que l'interaction t×D soit valide
def fixer_d_base(df):
    d_base = (df[df["annee"] == 2018][["hhid", "D"]]
              .drop_duplicates("hhid")
              .rename(columns={"D": "D_base"}))
    df = df.drop(columns=["D"]).merge(d_base, on="hhid", how="left")
    df = df.rename(columns={"D_base": "D"})
    return df

panel         = fixer_d_base(panel)
panel_complet = fixer_d_base(panel_complet)

print(f"Panel vrai : {len(panel):,} obs | traites : {panel['D'].sum():,}")

# ── 2. Statistiques descriptives ──────────────────────────────

print("\nStats descriptives par statut de traitement :")
print(panel.groupby(["annee", "D"])[
    ["pauvre_AF", "pauvre_MODA", "score_dep", "pcexp"]
].mean().round(3))

# ── 3. PSM : probit sur t=0 (base 2018) ──────────────────────

base_t0 = panel[panel["annee"] == 2018].dropna(
    subset=["D", "hhsize", "log_pcexp"]
).copy()

# Encodage dummies pour region, milieu, heduc, hmstat
cols_dummies = [c for c in ["region", "milieu", "heduc", "hmstat"]
                if c in base_t0.columns]
base_t0 = pd.get_dummies(base_t0, columns=cols_dummies, drop_first=True)
dummy_cols = [c for c in base_t0.columns
              if any(c.startswith(p + "_") for p in cols_dummies)]

formule = ("D ~ hhsize + log_pcexp + hgender + hage + "
           + " + ".join(dummy_cols)) if dummy_cols else \
          "D ~ hhsize + log_pcexp + hgender + hage"

probit = smf.probit(formule, data=base_t0).fit(disp=False)
print(f"\nPseudo-R2 McFadden : {1 - probit.llf/probit.llnull:.3f}")

base_t0 = base_t0.copy()
base_t0["pscore"] = probit.predict()

# Graphique support commun
fig, ax = plt.subplots(figsize=(8, 5))
for d, label, color in [(0, "Non-traites", "steelblue"), (1, "Traites", "tomato")]:
    base_t0[base_t0["D"] == d]["pscore"].plot.kde(
        ax=ax, label=label, color=color, linewidth=2)
ax.set(title="Distribution du score de propension — panel vrai",
       xlabel="Score de propension", ylabel="Densité")
ax.legend()
fig.tight_layout()
fig.savefig(OUTPUT_DIR / "overlap_panel.pdf")
print("Graphique sauvegardé : overlap_panel.pdf")

# ── 4. Appariement k-NN (k=K_VOISINS, caliper=CALIPER) ───────

from sklearn.neighbors import NearestNeighbors


def apparier_knn(base_t0, k=K_VOISINS, caliper=CALIPER):
    traites = base_t0[base_t0["D"] == 1][["hhid", "pscore"]].reset_index(drop=True)
    temoins = base_t0[base_t0["D"] == 0][["hhid", "pscore"]].reset_index(drop=True)

    nn = NearestNeighbors(n_neighbors=k, algorithm="ball_tree")
    nn.fit(temoins[["pscore"]])
    distances, indices = nn.kneighbors(traites[["pscore"]])

    paires = []
    for i, (dists, idxs) in enumerate(zip(distances, indices)):
        for d, j in zip(dists, idxs):
            if d <= caliper:
                paires.append({
                    "hhid_traite": traites.loc[i, "hhid"],
                    "hhid_temoin": temoins.loc[j, "hhid"],
                    "dist": d,
                })
    return pd.DataFrame(paires)


paires = apparier_knn(base_t0)
ids_traites = paires["hhid_traite"].unique()
ids_temoins = paires["hhid_temoin"].unique()
ids_apparies = np.union1d(ids_traites, ids_temoins)

print(f"\nAppariement k-NN (k={K_VOISINS}, caliper={CALIPER}) :")
print(f"  Traites retenus : {len(ids_traites)}")
print(f"  Temoins uniques : {len(ids_temoins)}")

# SMD avant/apres appariement
cov_cols = ["hhsize", "log_pcexp", "hgender", "hage"]


def smd(x1, x0):
    return (x1.mean() - x0.mean()) / np.sqrt((x1.var() + x0.var()) / 2)


print("\nBalance des covariables (SMD) :")
for col in cov_cols:
    if col in base_t0.columns:
        avant = smd(base_t0[base_t0["D"] == 1][col],
                    base_t0[base_t0["D"] == 0][col])
        apres_data = panel[
            panel["hhid"].isin(ids_apparies) & (panel["annee"] == 2018)
        ].copy()
        if "log_pcexp" not in apres_data.columns:
            apres_data = enrichir_welfare(apres_data, wel_18)
            apres_data["log_pcexp"] = np.log(apres_data["pcexp"].clip(lower=1))
        if col in apres_data.columns:
            apres = smd(apres_data[apres_data["D"] == 1][col],
                        apres_data[apres_data["D"] == 0][col])
            print(f"  {col:20s} : avant={avant:+.3f}  apres={apres:+.3f}")

# ── 5. Double Difference brute (sans appariement, panel vrai) ─

print("\n=== Double Difference brute — panel vrai (sans appariement) ===")
for outcome in ["pauvre_AF", "pauvre_MODA"]:
    mod = smf.ols(f"{outcome} ~ t * D", data=panel).fit(
        cov_type="cluster", cov_kwds={"groups": panel["grappe"]}
    )
    att = mod.params.get("t:D", float("nan"))
    pval = mod.pvalues.get("t:D", float("nan"))
    print(f"  DD {outcome} : ATT = {att:.4f}  (p = {pval:.3f})")

# ── 6. PSM-DD (Heckman 1997/1998) ────────────────────────────

panel_apparie = panel[panel["hhid"].isin(ids_apparies)].copy()
print(f"\nPanel apparie : {len(panel_apparie):,} obs")

print("\n=== PSM-DD — ATT principal (panel vrai) ===")
for outcome in ["pauvre_AF", "pauvre_MODA"]:
    mod = smf.ols(f"{outcome} ~ t * D", data=panel_apparie).fit(
        cov_type="cluster", cov_kwds={"groups": panel_apparie["grappe"]}
    )
    att = mod.params.get("t:D", float("nan"))
    se = mod.bse.get("t:D", float("nan"))
    pval = mod.pvalues.get("t:D", float("nan"))
    ic95_lo = att - 1.96 * se
    ic95_hi = att + 1.96 * se
    print(f"  PSM-DD {outcome} : ATT={att:.4f}  SE={se:.4f}  "
          f"IC95=[{ic95_lo:.4f},{ic95_hi:.4f}]  p={pval:.3f}")

# ── 7. Hétérogénéité par milieu (urbain vs rural) ─────────────

print("\n=== Hétérogénéité par milieu (urbain vs rural) ===")

# Test d'égalité via interaction
if "milieu" in panel_apparie.columns:
    for outcome in ["pauvre_AF", "pauvre_MODA"]:
        mod_int = smf.ols(f"{outcome} ~ t * D * C(milieu)", data=panel_apparie).fit(
            cov_type="cluster", cov_kwds={"groups": panel_apparie["grappe"]}
        )
        print(f"\n  Interaction milieu — {outcome} :")
        coefs_interaction = [(k, v) for k, v in mod_int.params.items()
                             if "milieu" in k and ("t:" in k or ":t" in k)]
        for k, v in coefs_interaction:
            pv = mod_int.pvalues[k]
            print(f"    {k} : coef={v:.4f}  p={pv:.3f}")

for mil, label in [(1, "Urbain"), (2, "Rural")]:
    if "milieu" not in panel_apparie.columns:
        break
    sub = panel_apparie[panel_apparie["milieu"] == mil]
    if len(sub) > 30:
        for outcome in ["pauvre_AF", "pauvre_MODA"]:
            mod = smf.ols(f"{outcome} ~ t * D", data=sub).fit(
                cov_type="cluster", cov_kwds={"groups": sub["grappe"]}
            )
            att = mod.params.get("t:D", float("nan"))
            pval = mod.pvalues.get("t:D", float("nan"))
            print(f"  {label} — {outcome} : ATT={att:.4f}  p={pval:.3f}")

# ── 8. Bootstrap PSM-DD ───────────────────────────────────────

def bootstrap_att(data, outcome, B=N_BOOT, seed=SEED):
    rng = np.random.default_rng(seed)
    att_boot = []
    for _ in range(B):
        idx = rng.integers(0, len(data), len(data))
        boot = data.iloc[idx]
        try:
            m = smf.ols(f"{outcome} ~ t * D", data=boot).fit(disp=False)
            att_boot.append(m.params.get("t:D", np.nan))
        except Exception:
            pass
    arr = np.array([x for x in att_boot if not np.isnan(x)])
    return {
        "mean": arr.mean(),
        "se": arr.std(),
        "ci95": np.percentile(arr, [2.5, 97.5]),
    }


print(f"\n=== Bootstrap PSM-DD ({N_BOOT} replications) — panel vrai ===")
for outcome in ["pauvre_AF", "pauvre_MODA"]:
    res = bootstrap_att(panel_apparie, outcome)
    print(f"  {outcome} : ATT={res['mean']:.4f}  SE={res['se']:.4f}  "
          f"IC95=[{res['ci95'][0]:.4f}, {res['ci95'][1]:.4f}]")

# ── 9. Robustesse : panel vrai vs panel complet ───────────────

print("\n=== Robustesse : panel vrai vs panel complet ===")
for outcome in ["pauvre_AF", "pauvre_MODA"]:
    mod_v = smf.ols(f"{outcome} ~ t * D", data=panel).fit(
        cov_type="cluster", cov_kwds={"groups": panel["grappe"]}
    )
    att_v = mod_v.params.get("t:D", float("nan"))

    mod_c = smf.ols(f"{outcome} ~ t * D", data=panel_complet).fit(
        cov_type="cluster", cov_kwds={"groups": panel_complet["grappe"]}
    )
    att_c = mod_c.params.get("t:D", float("nan"))

    print(f"  {outcome} : panel_vrai={att_v:.4f}  panel_complet={att_c:.4f}")
