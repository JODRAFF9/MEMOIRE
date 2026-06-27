/* ============================================================
   01_visitation.do — Exploration des deux bases EHCVM
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/* ── EHCVM I (2018-2019) ──────────────────────────────────── */

visiter "$BASE_2018/ehcvm_individu_sen2018.dta"  "Individus 2018-2019"
visiter "$BASE_2018/ehcvm_menage_sen2018.dta"    "Menages 2018-2019"
visiter "$BASE_2018/ehcvm_welfare_sen2018.dta"   "Welfare 2018-2019"
visiter "$BASE_2018/s13a_1_me_sen2018.dta"       "Transferts S13A-1 (2018-2019)"
visiter "$BASE_2018/s13a_2_me_sen2018.dta"       "Transferts S13A-2 (2018-2019)"

/* ── EHCVM II (2021-2022) ─────────────────────────────────── */

visiter "$BASE_2021/ehcvm_individu_sen2021.dta"  "Individus 2021-2022"
visiter "$BASE_2021/ehcvm_menage_sen2021.dta"    "Menages 2021-2022"
visiter "$BASE_2021/ehcvm_welfare_sen2021.dta"   "Welfare 2021-2022"
visiter "$BASE_2021/s13_1_me_sen2021.dta"        "Transferts S13-1 (2021-2022)"
visiter "$BASE_2021/s13_2_me_sen2021.dta"        "Transferts S13-2 (2021-2022)"

/* ── Structure panel : variable PanelHH (s00_me_sen2021) ─── */

di _newline "===== Structure panel EHCVM II ====="
use "$BASE_2021/s00_me_sen2021.dta", clear
di "Total menages enquetes (2021) : " _N
tab PanelHH, missing
di "  --> PanelHH=1 : meme menage suivi depuis 2018"
di "  --> PanelHH=0 : nouveau menage (remplacement)"

/* Verification croisement grappe+menage entre les deux vagues */
preserve
    keep grappe menage PanelHH
    tempfile id_2021
    save `id_2021'
restore

use "$BASE_2018/s00_me_sen2018.dta", clear
merge 1:1 grappe menage using `id_2021', keepusing(PanelHH)
di _newline "Menages 2018 retrouves en 2021 (_merge==3) : " ///
   r(N) " (verif : doit etre proche de 6127)"
tab _merge

/* Modalites variables de transferts */
use "$BASE_2018/s13a_2_me_sen2018.dta", clear
di _newline "Modalites s13aq14 (lieu expediteur, 2018) :"
tabulate s13aq14, missing

use "$BASE_2021/s13_2_me_sen2021.dta", clear
di _newline "Modalites s13q19 (lieu expediteur, 2021) :"
tabulate s13q19, missing
