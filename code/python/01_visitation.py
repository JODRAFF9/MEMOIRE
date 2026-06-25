# ============================================================
#  01_visitation.py — Exploration des deux bases EHCVM
# ============================================================

from config import BASE_2018, BASE_2021
from utils import lire_stata, visiter

# ── EHCVM I (2018-2019) ──────────────────────────────────────

ind_2018,   m = lire_stata(BASE_2018, "ehcvm_individu_sen2018.dta")  ; visiter(ind_2018, m, "Individus 2018-2019")
men_2018,   m = lire_stata(BASE_2018, "ehcvm_menage_sen2018.dta")    ; visiter(men_2018, m, "Menages 2018-2019")
wel_2018,   m = lire_stata(BASE_2018, "ehcvm_welfare_sen2018.dta")   ; visiter(wel_2018, m, "Welfare 2018-2019")
s13a1_2018, m = lire_stata(BASE_2018, "s13a_1_me_sen2018.dta")       ; visiter(s13a1_2018, m, "Transferts S13A-1 (2018-2019)")
s13a2_2018, m = lire_stata(BASE_2018, "s13a_2_me_sen2018.dta")       ; visiter(s13a2_2018, m, "Transferts S13A-2 (2018-2019)")

# ── EHCVM II (2021-2022) ─────────────────────────────────────

ind_2021,   m = lire_stata(BASE_2021, "ehcvm_individu_sen2021.dta")  ; visiter(ind_2021, m, "Individus 2021-2022")
men_2021,   m = lire_stata(BASE_2021, "ehcvm_menage_sen2021.dta")    ; visiter(men_2021, m, "Menages 2021-2022")
wel_2021,   m = lire_stata(BASE_2021, "ehcvm_welfare_sen2021.dta")   ; visiter(wel_2021, m, "Welfare 2021-2022")
s13a1_2021, m = lire_stata(BASE_2021, "s13_1_me_sen2021.dta")       ; visiter(s13a1_2021, m, "Transferts S13A-1 (2021-2022)")
s13a2_2021, m = lire_stata(BASE_2021, "s13_2_me_sen2021.dta")       ; visiter(s13a2_2021, m, "Transferts S13A-2 (2021-2022)")

# Modalites s13aq14
print("\nModalites s13aq14 (2018) :")
print(s13a2_2018["s13aq14"].value_counts(dropna=False))
print("\nModalites s13aq14 (2021) :")
print(s13a2_2021["s13aq14"].value_counts(dropna=False))
