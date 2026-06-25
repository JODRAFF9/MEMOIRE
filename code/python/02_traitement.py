# ============================================================
#  02_traitement.py — Variable de traitement
#  D = 1 si menage a recu un transfert de l'etranger
# ============================================================

import pandas as pd
from config import BASE_2018, BASE_2021, ID, CODE_ETRANGER, OUTPUT_DIR
from utils import lire_stata, taux

s13a1_2018, _ = lire_stata(BASE_2018, "s13a_1_me_sen2018.dta")
s13a2_2018, _ = lire_stata(BASE_2018, "s13a_2_me_sen2018.dta")
s13a1_2021, _ = lire_stata(BASE_2021, "s13_1_me_sen2021.dta")
s13a2_2021, _ = lire_stata(BASE_2021, "s13_2_me_sen2021.dta")


def construire_traitement(s13a1, s13a2, code_etr=CODE_ETRANGER):
    etrangers = (
        s13a2[s13a2["s13aq14"] == code_etr][ID]
        .drop_duplicates()
        .assign(transfert_migrant=1)
    )
    return (
        s13a1[ID + ["s13aq04"]]
        .merge(etrangers, on=ID, how="left")
        .assign(D=lambda x: x["transfert_migrant"].fillna(0).astype(int))
    )


traitement_2018 = construire_traitement(s13a1_2018, s13a2_2018)
traitement_2021 = construire_traitement(s13a1_2021, s13a2_2021)

print("\nPrevalence des transferts de migrants :")
for annee, df in [("2018-2019", traitement_2018), ("2021-2022", traitement_2021)]:
    print(f"  {annee} : {taux(df['D'])*100:.1f}%  ({df['D'].sum()} / {len(df)})")

traitement_2018.to_parquet(OUTPUT_DIR / "traitement_2018.parquet")
traitement_2021.to_parquet(OUTPUT_DIR / "traitement_2021.parquet")
