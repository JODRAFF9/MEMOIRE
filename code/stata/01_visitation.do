/* ============================================================
   01_visitation.do — Exploration des deux bases EHCVM
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/* ── EHCVM I (2018-2019) ─────────────────────────────────── */

visiter "$BASE_2018/ehcvm_individu_sen2018.dta"  "Individus 2018-2019"
visiter "$BASE_2018/ehcvm_menage_sen2018.dta"    "Menages 2018-2019"
visiter "$BASE_2018/ehcvm_welfare_sen2018.dta"   "Welfare 2018-2019"
visiter "$BASE_2018/s13a_1_me_sen2018.dta"       "Transferts S13A-1 (2018-2019)"
visiter "$BASE_2018/s13a_2_me_sen2018.dta"       "Transferts S13A-2 (2018-2019)"

/* ── EHCVM II (2021-2022) ────────────────────────────────── */

visiter "$BASE_2021/ehcvm_individu_sen2021.dta"  "Individus 2021-2022"
visiter "$BASE_2021/ehcvm_menage_sen2021.dta"    "Menages 2021-2022"
visiter "$BASE_2021/ehcvm_welfare_sen2021.dta"   "Welfare 2021-2022"
visiter "$BASE_2021/s13_1_me_sen2021.dta"       "Transferts S13A-1 (2021-2022)"
visiter "$BASE_2021/s13_2_me_sen2021.dta"       "Transferts S13A-2 (2021-2022)"

/* Modalites s13aq14 */
use "$BASE_2018/s13a_2_me_sen2018.dta", clear
di "Modalites s13aq14 (2018) :"
tabulate s13aq14, missing

use "$BASE_2021/s13_2_me_sen2021.dta", clear
di "Modalites s13aq14 (2021) :"
tabulate s13aq14, missing
