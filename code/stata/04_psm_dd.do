/* ============================================================
   04_psm_dd.do — Estimation PSM-DD (Heckman et al. 1997/1998)
   ATT sur pauvre_AF et pauvre_MODA
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/* ============================================================
   1. Construction de la base analytique (pseudo-panel)
   ============================================================ */

foreach annee in 2018 2021 {
    if `annee' == 2018 { local base "$BASE_2018" ; local t_val 0 }
    else               { local base "$BASE_2021" ; local t_val 1 }

    use "$TEMP/enfants_dep_`annee'.dta", clear

    /* Traitement */
    merge m:1 grappe menage using "$TEMP/traitement_`annee'.dta", ///
        keepusing(D) nogenerate keep(master match)

    /* Welfare : covariables PSM */
    merge m:1 grappe menage using "`base'/ehcvm_welfare_sen`annee'.dta", ///
        keepusing(pcexp hhsize region milieu hgender hage heduc hmstat) ///
        nogenerate keep(master match)

    gen t         = `t_val'
    gen log_pcexp = log(pcexp + 1)

    /* Facteurs (numeriques pour Stata) */
    foreach v in milieu region heduc hmstat {
        capture confirm variable `v'
        if _rc == 0 {
            capture destring `v', replace
        }
    }
    gen hgender_n = hgender
    gen hage_n    = hage
    gen hhsize_n  = hhsize

    save "$TEMP/base_`annee'.dta", replace
}

use "$TEMP/base_2018.dta", clear
append using "$TEMP/base_2021.dta"
save "$TEMP/pseudo_panel.dta", replace

di _newline "Base analytique : " _N " obs"
di "  Traites (D=1) : " _N - r(N) " (verif ci-dessous)"
tabstat D, by(t) stat(sum mean n) format(%6.3f)

/* ============================================================
   2. Statistiques descriptives par statut de traitement
   ============================================================ */

di _newline "=== Stats descriptives par annee et statut ==="
tabstat pauvre_AF pauvre_MODA nb_dep score_dep pcexp, ///
    by(D) stat(mean n) format(%6.3f)

/* ============================================================
   3. PSM : probit sur covariables (periode de base t = 0)
   Specification : hhsize + log_pcexp + milieu + region +
                   hgender + hage + heduc + hmstat
   ============================================================ */

use "$TEMP/pseudo_panel.dta", clear
keep if t == 0 & !missing(D) & !missing(log_pcexp) & !missing(hhsize_n)

di _newline "=== Modele probit (score de propension) ==="
probit D c.hhsize_n c.log_pcexp i.milieu i.region ///
         c.hgender_n c.hage_n i.heduc i.hmstat, ///
         robust nolog

/* Pseudo-R2 de McFadden */
di "Pseudo-R2 McFadden : " %6.3f 1 - e(ll)/e(ll_0)

predict pscore, pr
label var pscore "Score de propension"

/* Overlap — densite du score par statut */
twoway ///
    (kdensity pscore if D == 0, lcolor(blue) lwidth(medthick)) ///
    (kdensity pscore if D == 1, lcolor(red)  lwidth(medthick)), ///
    legend(order(1 "Non-traites" 2 "Traites")) ///
    xtitle("Score de propension") ytitle("Densité") ///
    title("Support commun — score de propension") ///
    saving("$OUTPUT/overlap.gph", replace)
graph export "$OUTPUT/overlap.pdf", replace

save "$TEMP/base_pscore.dta", replace

/* ============================================================
   4. Appariement PSM (package psmatch2 requis)
      ssc install psmatch2
   ============================================================ */

/* 4a. k plus proches voisins (k = 4, sans remplacement) */
di _newline "=== Appariement k-NN (k=4, sans remplacement) ==="
psmatch2 D, pscore(pscore) neighbor(4) noreplacement common

/* Balance apres appariement */
di _newline "Balance avant/apres (SMD) :"
pstest hhsize_n log_pcexp i.milieu i.region ///
       hgender_n hage_n i.heduc i.hmstat, both

/* Sauvegarder les poids et identifiants */
rename _weight weight_knn
save "$TEMP/base_pscore.dta", replace

/* 4b. Kernel (Epanechnikov) — full matching */
di _newline "=== Appariement Kernel (Epanechnikov) ==="
psmatch2 D, pscore(pscore) kernel kerneltype(epan) bwidth(0.06) common

/* 4c. Caliper (epsilon = 0.05) */
di _newline "=== Appariement Caliper (eps = 0.05) ==="
psmatch2 D, pscore(pscore) caliper(0.05) noreplacement common

/* ============================================================
   5. Double Difference (DD simple, sans appariement)
      Y_it = alpha + beta*t + gamma*D + delta*(t x D) + eps
      delta = ATT_DD
   ============================================================ */

use "$TEMP/pseudo_panel.dta", clear

di _newline "=== Double Difference (sans appariement) ==="
foreach outcome in pauvre_AF pauvre_MODA {
    di _newline "--- DD `outcome' ---"
    reg `outcome' i.t##i.D, vce(cluster grappe)
    lincom 1.t#1.D
    di "  ATT_DD = " %8.4f r(estimate) "  SE = " %8.4f r(se) ///
       "  p = " %6.4f r(p)
}

/* ============================================================
   6. PSM-DD (Heckman et al. 1997/1998)
      Sur la base appariee (poids kNN)
      Y_it = alpha + beta*t + gamma*D + delta*(t x D) + eps
      estime avec poids PSM
   ============================================================ */

/* Reconstituer le pseudo-panel sur les individus apparies */
use "$TEMP/base_pscore.dta", clear
keep grappe menage weight_knn
drop if missing(weight_knn)
duplicates drop grappe menage, force
tempfile matched_ids
save `matched_ids'

/* Joindre les poids aux deux periodes */
use "$TEMP/pseudo_panel.dta", clear
merge m:1 grappe menage using `matched_ids', ///
    keepusing(weight_knn) nogenerate
gen double weight_final = hhweight * weight_knn
label var weight_final "Poids combine sondage x PSM"
keep if !missing(weight_knn)

di _newline "Panel apparie : " _N " obs"

di _newline "=== PSM-DD (Heckman 1997/1998) ==="
foreach outcome in pauvre_AF pauvre_MODA {
    di _newline "--- PSM-DD `outcome' ---"
    reg `outcome' i.t##i.D [pw = weight_final], vce(cluster grappe)
    lincom 1.t#1.D
    di "  ATT_PSM-DD = " %8.4f r(estimate) "  SE = " %8.4f r(se) ///
       "  p = " %6.4f r(p)
}

/* ============================================================
   7. Heterogeneite par milieu
   ============================================================ */

di _newline "=== Heterogeneite par milieu ==="
foreach mil in 1 2 {
    if `mil' == 1 local lab_mil "Urbain"
    else          local lab_mil "Rural"

    foreach outcome in pauvre_AF pauvre_MODA {
        qui count if milieu == `mil' & !missing(weight_knn)
        if r(N) > 30 {
            di _newline "--- `lab_mil' — `outcome' ---"
            reg `outcome' i.t##i.D [pw = weight_final] ///
                if milieu == `mil', vce(cluster grappe)
            lincom 1.t#1.D
        }
    }
}

/* ============================================================
   8. Robustesse : bootstrap (N_BOOT replications)
   ============================================================ */

di _newline "=== Bootstrap PSM-DD ($N_BOOT replications) ==="
foreach outcome in pauvre_AF pauvre_MODA {
    di _newline "--- Bootstrap `outcome' ---"
    bootstrap att = _b[1.t#1.D], ///
        reps($N_BOOT) seed($SEED) nodots: ///
        reg `outcome' i.t##i.D [pw = weight_final], ///
        vce(cluster grappe)
    estat bootstrap, percentile all
}

/* ============================================================
   9. Bornes de Rosenbaum (package rbounds requis)
      ssc install rbounds
   ============================================================ */
/*
di _newline "=== Bornes de Rosenbaum (gamma = 1 a 2) ==="
use "$TEMP/base_pscore.dta", clear
keep if D == 1 | _nn != .
rbounds pauvre_AF, gamma(1(0.1)2)
rbounds pauvre_MODA, gamma(1(0.1)2)
*/
