# ============================================================
#  05_panel.py — Construction du panel vrai (PanelHH=1)
# ============================================================

import pandas as pd
import pyreadstat
from config import BASE_2021, OUTPUT_DIR, ID
from utils import lire_stata, construire_panel_vrai

# Charger PanelHH depuis s00_me_sen2021.dta
s00_2021_df, _ = lire_stata(BASE_2021, "s00_me_sen2021.dta")
s00_2021_df["hhid"] = (s00_2021_df["grappe"].astype(int) * 1000
                        + s00_2021_df["menage"].astype(int))
panel_id = s00_2021_df[["hhid", "PanelHH"]].drop_duplicates()

# Charger les bases fusionnées
base_men_2018 = pd.read_parquet(OUTPUT_DIR / "base_menage_2018.parquet")
base_men_2021 = pd.read_parquet(OUTPUT_DIR / "base_menage_2021.parquet")
base_ind_2018 = pd.read_parquet(OUTPUT_DIR / "base_individu_2018.parquet")
base_ind_2021 = pd.read_parquet(OUTPUT_DIR / "base_individu_2021.parquet")

# Joindre PanelHH aux bases 2021
base_men_2021 = base_men_2021.merge(panel_id, on="hhid", how="left")
base_men_2021["PanelHH"] = base_men_2021["PanelHH"].fillna(0).astype(int)
base_ind_2021 = base_ind_2021.merge(panel_id, on="hhid", how="left")
base_ind_2021["PanelHH"] = base_ind_2021["PanelHH"].fillna(0).astype(int)

# Statistique de suivi
n_panel = (base_men_2021["PanelHH"] == 1).sum()
n_total = len(base_men_2021)
print(f"Ménages panel (PanelHH=1) : {n_panel} sur {n_total} ({100*n_panel/n_total:.1f}%)")

# Identifiants ménages suivis
ids_panel = (base_men_2021[base_men_2021["PanelHH"] == 1][["hhid"]]
             .drop_duplicates())

# Panel vrai ménages
panel_men_vrai = pd.concat([
    base_men_2018.merge(ids_panel, on="hhid"),
    base_men_2021.merge(ids_panel, on="hhid"),
], ignore_index=True)

# Panel vrai enfants
panel_ind_vrai = pd.concat([
    base_ind_2018.merge(ids_panel, on="hhid"),
    base_ind_2021.merge(ids_panel, on="hhid"),
], ignore_index=True)

# Panel complet (toutes vagues, tous ménages)
panel_men_complet = pd.concat([base_men_2018, base_men_2021], ignore_index=True)
panel_ind_complet = pd.concat([base_ind_2018, base_ind_2021], ignore_index=True)

# Sauvegardes
panel_men_vrai.to_parquet(OUTPUT_DIR / "panel_men_vrai.parquet")
panel_ind_vrai.to_parquet(OUTPUT_DIR / "panel_ind_vrai.parquet")
panel_men_complet.to_parquet(OUTPUT_DIR / "panel_men_complet.parquet")
panel_ind_complet.to_parquet(OUTPUT_DIR / "panel_ind_complet.parquet")

print(f"Panel vrai ménages    : {len(panel_men_vrai):,} obs")
print(f"Panel vrai enfants    : {len(panel_ind_vrai):,} obs")
print(f"Panel complet ménages : {len(panel_men_complet):,} obs")
print(f"Panel complet enfants : {len(panel_ind_complet):,} obs")
