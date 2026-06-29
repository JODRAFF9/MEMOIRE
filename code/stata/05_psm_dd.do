/* ============================================================
   05_psm_dd.do — Estimation PSM-DD sur panel vrai

   Strategie :
     1. Probit sur t=0 (2018) -> score de propension
     2. Verification equilibre (SMD)
     3. Appariement PSM (k-NN, kernel, caliper)
     4. DD brute (sans appariement)
     5. PSM-DD sur panel vrai (Heckman et al. 1997/1998)
     6. Heterogeneite (milieu, sexe, age, montant)
     7. Robustesse bootstrap + bornes de Rosenbaum
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/* Verifier/installer psmatch2 si absent */
capture which psmatch2
if _rc {
    di "Installation de psmatch2 depuis SSC..."
    ssc install psmatch2, replace
}

/* ============================================================
   1. Score de propension (probit sur t=0, panel vrai)
   ============================================================ */

use "$TEMP/panel_vrai.dta", clear
keep if t == 0 & !missing(D) & !missing(log_pcexp) & !missing(hhsize)

di _newline "=== Probit — score de propension (EHCVM I, panel vrai) ==="
di "Observations : " _N

/* Déclaration du plan de sondage (strates = région x milieu) */
svyset_ehcvm hhweight

svy: probit D c.hhsize c.log_pcexp i.milieu i.region ///
         c.hgender c.hage i.heduc i.hmstat, nolog

/* Pseudo-R2 McFadden : svy: probit ne stocke pas e(ll)/e(ll_0)
   On réestimé sans svy pour calculer le pseudo-R2 uniquement */
quietly probit D c.hhsize c.log_pcexp i.milieu i.region ///
         c.hgender c.hage i.heduc i.hmstat [pw = hhweight], robust nolog
di "Pseudo-R2 McFadden : " %6.3f 1 - e(ll)/e(ll_0)

predict pscore, pr
label var pscore "Score de propension"

/* Graphique de densite (support commun) */
twoway ///
    (kdensity pscore if D == 0, lcolor("168 199 232") lwidth(medthick)) ///
    (kdensity pscore if D == 1, lcolor("31 78 121") lwidth(medthick)), ///
    legend(order(1 "Non-traites" 2 "Traites")) ///
    xtitle("Score de propension") ytitle("Densité") ///
    title("Support commun — panel vrai") ///
    saving("$OUTPUT/overlap_panel.gph", replace)
graph export "$OUTPUT/overlap_panel.pdf", replace

save "$TEMP/pscore_t0.dta", replace

/* ============================================================
   2. Appariement PSM (sur periode de base uniquement)

   Trois algorithmes pour robustesse :
     a. k plus proches voisins (k=K_VOISINS, sans remplacement)
     b. Kernel gaussien
     c. Caliper (epsilon=CALIPER)
   ============================================================ */

/* -- 2a. k-NN ------------------------------------------------ */
di _newline "=== Appariement k-NN (k=$K_VOISINS, sans remplacement) ==="
psmatch2 D, pscore(pscore) neighbor($K_VOISINS) common

di _newline "Balance avant/apres (SMD) :"
pstest hhsize log_pcexp i.milieu i.region hgender hage i.heduc i.hmstat, both

rename _weight weight_knn
save "$TEMP/pscore_knn.dta", replace

/* -- 2b. Kernel gaussien ------------------------------------- */
di _newline "=== Appariement Kernel (Epanechnikov, h=0.06) ==="
use "$TEMP/pscore_t0.dta", clear
psmatch2 D, pscore(pscore) kernel kerneltype(epan) bwidth(0.06) common
rename _weight weight_kernel
keep grappe menage weight_kernel
duplicates drop grappe menage, force
save "$TEMP/poids_kernel.dta", replace

/* -- 2c. Caliper -------------------------------------------- */
di _newline "=== Appariement Caliper (eps=$CALIPER) ==="
use "$TEMP/pscore_t0.dta", clear
psmatch2 D, pscore(pscore) caliper($CALIPER) noreplacement common
rename _weight weight_caliper
keep grappe menage weight_caliper
duplicates drop grappe menage, force
save "$TEMP/poids_caliper.dta", replace

/* ============================================================
   3. Statistiques descriptives sur le panel apparie
   ============================================================ */

use "$TEMP/panel_vrai.dta", clear
di _newline "=== Stats descriptives (panel vrai) ==="
tabstat pauvre_AF pauvre_MODA nb_dep score_dep pcexp ///
    [aw=hhweight], by(D) stat(mean n) format(%6.3f)

/* ============================================================
   4. Double Difference brute (sans appariement, reference)
   ============================================================ */

di _newline "=== Double Difference brute (sans appariement) ==="
svyset_ehcvm hhweight
foreach outcome in pauvre_AF pauvre_MODA {
    di _newline "--- DD `outcome' ---"
    svy: reg `outcome' i.t##i.D
    lincom 1.t#1.D
    di "  ATT_DD  = " %8.4f r(estimate) ///
       "  SE = " %8.4f r(se) "  p = " %6.4f r(p)
}

/* ============================================================
   5. PSM-DD sur panel vrai
      Specification : Y_it = a + b*t + c*D + d*(t#D) + e
      d = ATT estime, poids PSM k-NN
   ============================================================ */

/* Joindre poids k-NN aux deux periodes */
use "$TEMP/pscore_knn.dta", clear
keep grappe menage weight_knn
drop if missing(weight_knn)
duplicates drop grappe menage, force
tempfile poids_knn
save `poids_knn'

use "$TEMP/panel_vrai.dta", clear
merge m:1 grappe menage using `poids_knn', keepusing(weight_knn) nogenerate
keep if !missing(weight_knn)

/* Poids final = poids sondage * poids PSM */
gen double weight_final = hhweight * weight_knn
label var weight_final "Poids combine sondage x PSM"

di _newline "Panel apparie (k-NN) : " _N " obs"
tabstat D, by(t) stat(mean sum n) format(%6.3f)

di _newline "=== PSM-DD — ATT principal (Heckman 1997/1998) ==="
/* Poids combiné sondage x PSM : déclaré dans svyset */
svyset_ehcvm weight_final
foreach outcome in pauvre_AF pauvre_MODA {
    di _newline "--- PSM-DD `outcome' ---"
    svy: reg `outcome' i.t##i.D
    lincom 1.t#1.D
    di "  ATT_PSM-DD = " %8.4f r(estimate) ///
       "  SE = " %8.4f r(se) "  p = " %6.4f r(p)
}

save "$TEMP/panel_apparie.dta", replace

/* ============================================================
   6. Heterogeneite
   ============================================================ */

/* -- 6a. Par milieu de residence ---------------------------- */
di _newline "=== Heterogeneite par milieu ==="
foreach mil in 1 2 {
    if `mil' == 1 local lab_mil "Urbain"
    else          local lab_mil "Rural"

    foreach outcome in pauvre_AF pauvre_MODA {
        quietly count if milieu == `mil' & !missing(weight_knn)
        if r(N) > 30 {
            di _newline "--- `lab_mil' — `outcome' ---"
            svyset_ehcvm weight_final
            svy, subpop(if milieu == `mil'): reg `outcome' i.t##i.D
            lincom 1.t#1.D
            di "  ATT = " %8.4f r(estimate) "  p = " %6.4f r(p)
        }
    }
}

/* Test d'egalite milieu urbain vs rural */
di _newline "Test d'egalite Chow (urbain vs rural) :"
gen byte urban = (milieu == 1)
svyset_ehcvm weight_final
foreach outcome in pauvre_AF pauvre_MODA {
    svy: reg `outcome' i.t##i.D##i.urban
    lincom 1.t#1.D#1.urban - 1.t#1.D#0.urban
    di "  Diff ATT (urbain - rural) : " %8.4f r(estimate) "  p = " %6.4f r(p)
}
drop urban

/* -- 6b. Par sexe de l'enfant ------------------------------- */
di _newline "=== Heterogeneite par sexe ==="
capture confirm variable sexe
if _rc == 0 {
    svyset_ehcvm weight_final
    foreach outcome in pauvre_AF pauvre_MODA {
        foreach s in 1 2 {
            if `s' == 1 local lab_s "Garcons"
            else        local lab_s "Filles"
            quietly count if sexe == `s' & !missing(weight_knn)
            if r(N) > 30 {
                di "--- `lab_s' — `outcome' ---"
                svy, subpop(if sexe == `s'): reg `outcome' i.t##i.D
                lincom 1.t#1.D
                di "  ATT = " %8.4f r(estimate) "  p = " %6.4f r(p)
            }
        }
    }
}
else {
    di "Variable sexe non disponible dans la base courante."
}

/* -- 6c. Par groupe d'age ----------------------------------- */
di _newline "=== Heterogeneite par groupe d'age ==="
svyset_ehcvm weight_final
foreach g in 1 2 3 {
    foreach outcome in pauvre_AF pauvre_MODA {
        quietly count if groupe_moda == `g' & !missing(weight_knn)
        if r(N) > 30 {
            di "--- Groupe `g' — `outcome' ---"
            svy, subpop(if groupe_moda == `g'): reg `outcome' i.t##i.D
            lincom 1.t#1.D
            di "  ATT = " %8.4f r(estimate) "  p = " %6.4f r(p)
        }
    }
}

/* ============================================================
   7. Robustesse
   ============================================================ */

/* -- 7a. Bootstrap (N_BOOT replications) -------------------- */
di _newline "=== Bootstrap PSM-DD ($N_BOOT replications) ==="
foreach outcome in pauvre_AF pauvre_MODA {
    di _newline "--- Bootstrap `outcome' ---"
    att_psmdd `outcome' weight_final $N_BOOT
}

/* -- 7b. Sensibilite au seuil k (Alkire-Foster) ------------- */
di _newline "=== Sensibilite au seuil k (Alkire-Foster) ==="
svyset_ehcvm weight_final
foreach k_test in 0.1667 0.3333 0.5 {
    gen byte pauvre_ktest = (score_dep >= `k_test') if !missing(score_dep)
    svy: reg pauvre_ktest i.t##i.D
    lincom 1.t#1.D
    di "  k=" %5.4f `k_test' " : ATT=" %8.4f r(estimate) "  p=" %6.4f r(p)
    drop pauvre_ktest
}

/* -- 7c. Robustesse aux trois methodes d'appariement -------- */
di _newline "=== Comparaison des trois methodes d'appariement ==="
foreach poids_var in weight_knn weight_kernel weight_caliper {
    /* Joindre le jeu de poids si necessaire */
    if "`poids_var'" == "weight_kernel" {
        merge m:1 grappe menage using "$TEMP/poids_kernel.dta", ///
            keepusing(weight_kernel) nogenerate
        capture drop wf_kernel
        gen double wf_kernel = hhweight * weight_kernel
    }
    if "`poids_var'" == "weight_caliper" {
        merge m:1 grappe menage using "$TEMP/poids_caliper.dta", ///
            keepusing(weight_caliper) nogenerate
        capture drop wf_caliper
        gen double wf_caliper = hhweight * weight_caliper
    }

    /* Poids combine sondage x PSM */
    local wf = cond("`poids_var'" == "weight_knn",    "weight_final", ///
                cond("`poids_var'" == "weight_kernel", "wf_kernel",   ///
                                                       "wf_caliper"))

    foreach outcome in pauvre_AF pauvre_MODA {
        quietly count if !missing(`poids_var')
        if r(N) > 0 {
            svyset_ehcvm `wf'
            svy: reg `outcome' i.t##i.D
            lincom 1.t#1.D
            di "  `poids_var' — `outcome' : ATT=" %8.4f r(estimate) ///
               "  p=" %6.4f r(p)
        }
    }
}

/* -- 7d. Bornes de Rosenbaum (ssc install rbounds) ---------- */
/*
di _newline "=== Bornes de Rosenbaum (gamma = 1 a 2) ==="
use "$TEMP/pscore_knn.dta", clear
keep if D == 1 | _nn != .
rbounds pauvre_AF,   gamma(1(0.1)2)
rbounds pauvre_MODA, gamma(1(0.1)2)
*/

di _newline ">>> 05_psm_dd.do termine."
