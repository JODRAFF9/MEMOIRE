# ============================================================
#  utils.py — Fonctions utilitaires
# ============================================================

import numpy as np
import pandas as pd
import pyreadstat
from config import BASE_2018, BASE_2021, ID, K_SEUIL


def lire_stata(base, fichier):
    return pyreadstat.read_dta(base / fichier)


def visiter(df, meta, nom):
    labels = meta.column_names_to_labels or {}
    print(f"\n{'='*60}\n  {nom}\n{'='*60}")
    print(f"  Dimensions : {df.shape[0]:,} x {df.shape[1]}")
    info = pd.DataFrame({
        "Variable" : df.columns,
        "Label"    : [labels.get(c, "") for c in df.columns],
        "Type"     : df.dtypes.values,
        "NaN %"    : (df.isnull().mean().values * 100).round(1),
    })
    print(info.to_string(index=False))


def taux(serie):
    return serie.mean(skipna=True)


def indices_af(score, k=K_SEUIL):
    pauvre = (score >= k).astype(int)
    H  = taux(pauvre)
    A  = taux(score[pauvre == 1])
    M0 = H * A
    return {"H": H, "A": A, "M0": M0, "pauvre": pauvre}
