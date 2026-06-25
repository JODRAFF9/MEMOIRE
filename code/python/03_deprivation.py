# ============================================================
#  03_deprivation.py — Indicateurs de pauvrete multidimensionnelle
#  Approche 1 : Alkire-Foster (M0 = H x A, k = 1/3)
#  Approche 2 : MODA UNICEF (par groupe d'age)
# ============================================================

import numpy as np
import pandas as pd
from config import BASE_2018, BASE_2021, K_SEUIL, OUTPUT_DIR
from utils import lire_stata, taux, indices_af

ind_2018, _ = lire_stata(BASE_2018, "ehcvm_individu_sen2018.dta")
ind_2021, _ = lire_stata(BASE_2021, "ehcvm_individu_sen2021.dta")


def extraire_enfants(ind, annee, col_age="age"):
    df = ind[ind[col_age] <= 17].copy()
    df["annee"] = annee
    df["age"]   = df[col_age]
    df["groupe_moda"] = pd.cut(df["age"], bins=[-1, 4, 14, 17],
                               labels=["0-4 ans", "5-14 ans", "15-17 ans"])
    return df


def construire_af(df):
    dep = df.copy()
    dep["d1_educ"]  = 0   # non-scolarise / retard scolaire     - a construire
    dep["d2_sante"] = 0   # pas de suivi medical                - a construire
    dep["d3_nutri"] = 0   # malnutrition anthropometrique       - a construire
    dep["d4_eau"]   = 0   # source d'eau non amelioree          - a construire
    dep["d5_assai"] = 0   # assainissement non ameliore         - a construire
    dep["d6_habit"] = 0   # habitat precaire                    - a construire
    cols = ["d1_educ","d2_sante","d3_nutri","d4_eau","d5_assai","d6_habit"]
    dep["score_dep"] = dep[cols].mean(axis=1)
    dep["pauvre_AF"] = (dep["score_dep"] >= K_SEUIL).astype(int)
    return dep


def construire_moda(df):
    dep = df.copy()
    dep["m_sante"] = 0
    dep["m_nutri"] = 0
    dep["m_educ"]  = 0
    dep["m_eau"]   = 0
    dep["m_assai"] = 0
    dep["m_habit"] = 0
    dep["m_trav"]  = 0   # travail des enfants (15-17 ans)

    dep["nb_dep"] = np.nan
    mask_04   = dep["groupe_moda"] == "0-4 ans"
    mask_514  = dep["groupe_moda"] == "5-14 ans"
    mask_1517 = dep["groupe_moda"] == "15-17 ans"

    dep.loc[mask_04,   "nb_dep"] = dep.loc[mask_04,   ["m_sante","m_nutri","m_eau","m_assai","m_habit"]].sum(axis=1)
    dep.loc[mask_514,  "nb_dep"] = dep.loc[mask_514,  ["m_educ","m_sante","m_eau","m_assai","m_habit"]].sum(axis=1)
    dep.loc[mask_1517, "nb_dep"] = dep.loc[mask_1517, ["m_educ","m_trav","m_eau","m_assai","m_habit"]].sum(axis=1)

    dep["pauvre_MODA"] = (dep["nb_dep"] >= 2).astype(int)
    return dep


for annee, ind in [(2018, ind_2018), (2021, ind_2021)]:
    enfants = extraire_enfants(ind, annee)
    enfants = construire_af(enfants)
    enfants = construire_moda(enfants)

    # Indices Alkire-Foster
    idx = indices_af(enfants["score_dep"])
    print(f"\nAlkire-Foster {annee} : H={idx['H']:.3f}  A={idx['A']:.3f}  M0={idx['M0']:.3f}")

    # Prevalence MODA par groupe
    print(f"MODA {annee} — prevalence par groupe :")
    print(enfants.groupby("groupe_moda", observed=True)["pauvre_MODA"]
                 .agg(n="count", pct=lambda x: round(taux(x)*100,1)))

    enfants.to_parquet(OUTPUT_DIR / f"enfants_dep_{annee}.parquet")
