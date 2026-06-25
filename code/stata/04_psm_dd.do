/* ============================================================
   04_psm_dd.do — Estimation PSM-DD (Heckman et al. 1997/1998)
   ATT sur pauvre_AF et pauvre_MODA
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/* ── Fusion base analytique ───────────────────────────────── */

foreach annee in 2018 2021 {
    if `annee' == 2018 { local base "$BASE_2018" ; local t 0 }
    else               { local base "$BASE_2021" ; local t 1 }

    use "$TEMP/enfants_dep_`annee'.dta", clear
    merge m:1 grappe menage using "$TEMP/traitement_`annee'.dta",  ///
        keepusing(D) nogenerate
    merge m:1 grappe menage using "`base'/ehcvm_welfare_sen`annee'.dta", ///
        keepusing(pcexp hhsize) nogenerate
    gen t    = `t'
    gen log_pcexp = log(pcexp + 1)
    save "$TEMP/base_`annee'.dta", replace
}

use "$TEMP/base_2018.dta", clear
append using "$TEMP/base_2021.dta"
save "$TEMP/pseudo_panel.dta", replace

di "Base analytique : " _N " obs"

/* ── Stats descriptives ───────────────────────────────────── */

tabstat pauvre_AF pauvre_MODA score_dep nb_dep pcexp, ///
    by(D) stat(mean sd n) format(%6.3f)

/* ── PSM : probit sur covariables (periode de base t=0) ─────── */

use "$TEMP/pseudo_panel.dta", clear
keep if t == 0 & !missing(D)

/* Covariables a adapter selon variables disponibles */
probit D hhsize log_pcexp, robust

predict pscore, pr
label var pscore "Score de propension"

/* Overlap */
twoway ///
    (kdensity pscore if D == 0, lcolor(blue)) ///
    (kdensity pscore if D == 1, lcolor(red)), ///
    legend(order(1 "Non-traites" 2 "Traites")) ///
    title("Distribution du score de propension") ///
    saving("$OUTPUT/overlap.gph", replace)

save "$TEMP/base_pscore.dta", replace

/* ── Appariement PSM (psmatch2 requis) ───────────────────── */

/* k plus proches voisins (k=4) */
psmatch2 D pauvre_AF, pscore(pscore) neighbor(4) noreplacement common
pstest hhsize log_pcexp, both

/* Kernel */
psmatch2 D pauvre_AF, pscore(pscore) kernel kerneltype(epan) bwidth(0.06) common

/* Caliper (0.25 sigma) */
psmatch2 D pauvre_AF, pscore(pscore) caliper(0.25) noreplacement common

/* ── Double Difference ────────────────────────────────────── */

use "$TEMP/pseudo_panel.dta", clear

foreach outcome in pauvre_AF pauvre_MODA {
    di _newline "=== DD — `outcome' ==="
    reg `outcome' i.t##i.D [pw = hhsize], vce(cluster grappe)
    lincom 1.t#1.D
}

/* ── PSM-DD (Heckman et al. 1997/1998) ──────────────────── */
/* ATT_PSM-DD = somme_i w_i [DeltaY_i - somme_j w_ij DeltaY_j] */
/* (a implementer apres construction du pseudo-panel grappe-level) */

/* ── Robustesse : bootstrap (1000 replications) ──────────── */
/*
bootstrap r(att): psmatch2 D pauvre_AF, pscore(pscore) neighbor(4) noreplacement common
*/

/* Bornes de Rosenbaum */
/*
rbounds pauvre_AF, gamma(1(0.1)2)
*/
