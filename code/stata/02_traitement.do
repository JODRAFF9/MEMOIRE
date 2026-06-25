/* ============================================================
   02_traitement.do — Variable de traitement
   D = 1 si menage a recu un transfert de l'etranger
   ============================================================ */

do "code/stata/config.do"

/* ── 2018-2019 ─────────────────────────────────────────────── */

use "$BASE_2018/s13a_2_me_sen2018.dta", clear
keep if s13aq14 == $CODE_ETRANGER
bysort grappe menage: keep if _n == 1
gen transfert_migrant = 1
save "$TEMP/etrangers_2018.dta", replace

use "$BASE_2018/s13a_1_me_sen2018.dta", clear
merge m:1 grappe menage using "$TEMP/etrangers_2018.dta", ///
    keepusing(transfert_migrant) nogenerate
replace transfert_migrant = 0 if missing(transfert_migrant)
rename transfert_migrant D
label var D "Traitement : transfert de migrant recu (1=oui)"
save "$TEMP/traitement_2018.dta", replace

/* ── 2021-2022 ─────────────────────────────────────────────── */
/* NB: 2021 renomme s13aq14 -> s13q19 (lieu de l'expediteur)  */

use "$BASE_2021/s13_2_me_sen2021.dta", clear
keep if s13q19 == $CODE_ETRANGER
bysort grappe menage: keep if _n == 1
gen transfert_migrant = 1
save "$TEMP/etrangers_2021.dta", replace

use "$BASE_2021/s13_1_me_sen2021.dta", clear
merge m:1 grappe menage using "$TEMP/etrangers_2021.dta", ///
    keepusing(transfert_migrant) nogenerate
replace transfert_migrant = 0 if missing(transfert_migrant)
rename transfert_migrant D
label var D "Traitement : transfert de migrant recu (1=oui)"
save "$TEMP/traitement_2021.dta", replace

/* Prevalence */
di _newline ">>> Prevalence des transferts de migrants :"
use "$TEMP/traitement_2018.dta", clear
quietly summarize D
di "  2018-2019 : " %5.1f r(mean)*100 "%  (" r(sum) "/" r(N) ")"

use "$TEMP/traitement_2021.dta", clear
quietly summarize D
di "  2021-2022 : " %5.1f r(mean)*100 "%  (" r(sum) "/" r(N) ")"
