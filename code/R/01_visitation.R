# ============================================================
#  01_visitation.R — Exploration des deux bases EHCVM
# ============================================================

source("code/R/config.R")
source("code/R/utils.R")

# ── EHCVM I (2018-2019) ──────────────────────────────────────

ind_2018   <- lire_stata(BASE_2018, "ehcvm_individu_sen2018.dta")
men_2018   <- lire_stata(BASE_2018, "ehcvm_menage_sen2018.dta")
wel_2018   <- lire_stata(BASE_2018, "ehcvm_welfare_sen2018.dta")
s13a1_2018 <- lire_stata(BASE_2018, "s13a_1_me_sen2018.dta")
s13a2_2018 <- lire_stata(BASE_2018, "s13a_2_me_sen2018.dta")

visiter(ind_2018,   "Individus 2018-2019")
visiter(men_2018,   "Menages 2018-2019")
visiter(wel_2018,   "Welfare 2018-2019")
visiter(s13a1_2018, "Transferts recus S13A-1 (2018-2019)")
visiter(s13a2_2018, "Transferts recus S13A-2 (2018-2019)")

# ── EHCVM II (2021-2022) ─────────────────────────────────────

ind_2021   <- lire_stata(BASE_2021, "ehcvm_individu_sen2021.dta")
men_2021   <- lire_stata(BASE_2021, "ehcvm_menage_sen2021.dta")
wel_2021   <- lire_stata(BASE_2021, "ehcvm_welfare_sen2021.dta")
s13a1_2021 <- lire_stata(BASE_2021, "s13a_1_me_sen2021.dta")
s13a2_2021 <- lire_stata(BASE_2021, "s13a_2_me_sen2021.dta")

visiter(ind_2021,   "Individus 2021-2022")
visiter(men_2021,   "Menages 2021-2022")
visiter(wel_2021,   "Welfare 2021-2022")
visiter(s13a1_2021, "Transferts recus S13A-1 (2021-2022)")
visiter(s13a2_2021, "Transferts recus S13A-2 (2021-2022)")

# Modalites s13aq14 (lieu de residence de l'expediteur)
cat("\n>>> Modalites s13aq14 — 2018:\n")
print(table(s13a2_2018$s13aq14, useNA = "ifany"))
cat("\n>>> Modalites s13aq14 — 2021:\n")
print(table(s13a2_2021$s13aq14, useNA = "ifany"))
