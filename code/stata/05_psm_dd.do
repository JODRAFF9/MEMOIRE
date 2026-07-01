/* ============================================================
   05_psm_dd.do — Estimation PSM-DD sur panel vrai

   Strategie :
     1. Probit au NIVEAU MENAGE sur t=0 -> score de propension
        (toutes les covariables du score sont des caracteristiques
        menage : l'appariement au niveau menage est l'approche
        correcte ; il evite les ex-aequo massifs qu'induirait un
        appariement au niveau enfant avec des scores identiques
        au sein d'un meme menage)
     2. Verification equilibre (SMD)
     3. Appariement PSM (k-NN, kernel, caliper) au niveau menage
     4. DD brute (sans appariement)
     5. PSM-DD sur panel vrai (Heckman et al. 1997/1998)
     6. Heterogeneite (milieu, sexe, age)
     7. Robustesse (seuil k, methodes d'appariement)

   Traitement : statut STABLE (transferts etrangers recus aux
   deux vagues vs jamais recus ; switchers exclus en 04_panel).

   Aucune ponderation par poids d'enquete (hhweight) : estimations
   sur effectifs bruts, erreurs-types clusterisees par grappe.
   Le seul poids utilise est le poids d'appariement PSM.
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
   1. Score de propension (probit MENAGE sur t=0, panel vrai)
   ============================================================ */

use "$TEMP/panel_vrai.dta", clear
keep if t == 0 & !missing(D) & !missing(log_pcexp) & !missing(hhsize)
bysort grappe menage: keep if _n == 1   /* un menage = une observation */

di _newline "=== Probit menage — score de propension (EHCVM I, panel vrai) ==="
di "Menages : " _N

probit D c.hhsize c.log_pcexp i.milieu i.region ///
         c.hgender c.hage i.heduc i.hmstat, vce(cluster grappe) nolog

di "Pseudo-R2 McFadden : " %6.3f 1 - e(ll)/e(ll_0)

predict pscore, pr
label var pscore "Score de propension (menage)"

/* Graphique de densite (support commun) */
twoway ///
    (kdensity pscore if D == 0, lcolor(ltblue) lwidth(medthick)) ///
    (kdensity pscore if D == 1, lcolor(navy) lwidth(medthick)), ///
    legend(order(1 "Jamais traites" 2 "Traites stables")) ///
    xtitle("Score de propension") ytitle("Densité") ///
    title("Support commun — panel vrai (niveau ménage)") ///
    saving("$OUTPUT/overlap_panel.gph", replace)
graph export "$OUTPUT/overlap_panel.pdf", replace

save "$TEMP/pscore_t0.dta", replace

/* ============================================================
   2. Appariement PSM au niveau menage

   Trois algorithmes pour robustesse :
     a. k plus proches voisins (k=K_VOISINS, avec remise)
     b. Kernel Epanechnikov (h=0.06)
     c. Caliper (epsilon=CALIPER, sans remise)
   ============================================================ */

/* -- 2a. k-NN ------------------------------------------------ */
di _newline "=== Appariement k-NN (k=$K_VOISINS, avec remise) ==="
psmatch2 D, pscore(pscore) neighbor($K_VOISINS) common

di _newline "Balance avant/apres (SMD) :"
pstest hhsize log_pcexp i.milieu i.region hgender hage i.heduc i.hmstat, both

rename _weight weight_knn
keep grappe menage D pscore weight_knn _support
save "$TEMP/pscore_knn.dta", replace

/* -- 2b. Kernel Epanechnikov --------------------------------- */
di _newline "=== Appariement Kernel (Epanechnikov, h=0.06) ==="
use "$TEMP/pscore_t0.dta", clear
psmatch2 D, pscore(pscore) kernel kerneltype(epan) bwidth(0.06) common
rename _weight weight_kernel
keep grappe menage weight_kernel
save "$TEMP/poids_kernel.dta", replace

/* -- 2c. Caliper -------------------------------------------- */
di _newline "=== Appariement Caliper (eps=$CALIPER, sans remise) ==="
use "$TEMP/pscore_t0.dta", clear
psmatch2 D, pscore(pscore) caliper($CALIPER) noreplacement common
rename _weight weight_caliper
keep grappe menage weight_caliper
save "$TEMP/poids_caliper.dta", replace

/* ============================================================
   3. Statistiques descriptives sur le panel
   ============================================================ */

use "$TEMP/panel_vrai.dta", clear
di _newline "=== Stats descriptives (panel vrai, D stable) ==="
tabstat pauvre_AF pauvre_MODA nb_dep score_dep pcexp, ///
    by(D) stat(mean n) format(%6.3f)

/* ============================================================
   4. Double Difference brute (sans appariement, reference)
   ============================================================ */

di _newline "=== Double Difference brute (sans appariement) ==="
foreach outcome in pauvre_AF pauvre_MODA {
    di _newline "--- DD `outcome' ---"
    regress `outcome' i.t##i.D, vce(cluster grappe)
    lincom 1.t#1.D
    di "  ATT_DD  = " %8.4f r(estimate) ///
       "  SE = " %8.4f r(se) "  p = " %6.4f r(p)
}

/* ============================================================
   5. PSM-DD sur panel vrai
      Specification : Y_it = a + b*t + c*D + d*(t#D) + e
      d = ATT estime, poids d'appariement k-NN (niveau menage)
   ============================================================ */

use "$TEMP/panel_vrai.dta", clear
merge m:1 grappe menage using "$TEMP/pscore_knn.dta", ///
    keepusing(weight_knn) keep(master match) nogenerate
keep if !missing(weight_knn) & weight_knn > 0

di _newline "Panel apparie (k-NN, niveau menage) : " _N " obs enfants"
tabstat D, by(t) stat(mean sum n) format(%6.3f)

di _newline "=== PSM-DD — ATT principal (Heckman 1997/1998) ==="
foreach outcome in pauvre_AF pauvre_MODA {
    di _newline "--- PSM-DD `outcome' ---"
    regress `outcome' i.t##i.D [aw=weight_knn], vce(cluster grappe)
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
        quietly count if milieu == `mil'
        if r(N) > 30 {
            di _newline "--- `lab_mil' — `outcome' ---"
            regress `outcome' i.t##i.D [aw=weight_knn] if milieu == `mil', ///
                vce(cluster grappe)
            lincom 1.t#1.D
            di "  ATT = " %8.4f r(estimate) "  p = " %6.4f r(p)
        }
    }
}

/* Test d'egalite urbain vs rural */
di _newline "Test d'egalite (urbain vs rural) :"
gen byte urban = (milieu == 1)
foreach outcome in pauvre_AF pauvre_MODA {
    regress `outcome' i.t##i.D##i.urban [aw=weight_knn], vce(cluster grappe)
    lincom 1.t#1.D#1.urban
    di "  Diff ATT (urbain - rural) : " %8.4f r(estimate) "  p = " %6.4f r(p)
}
drop urban

/* -- 6b. Par sexe de l'enfant ------------------------------- */
di _newline "=== Heterogeneite par sexe ==="
capture confirm variable sexe
if _rc == 0 {
    foreach outcome in pauvre_AF pauvre_MODA {
        foreach s in 1 2 {
            if `s' == 1 local lab_s "Garcons"
            else        local lab_s "Filles"
            quietly count if sexe == `s'
            if r(N) > 30 {
                di "--- `lab_s' — `outcome' ---"
                regress `outcome' i.t##i.D [aw=weight_knn] if sexe == `s', ///
                    vce(cluster grappe)
                lincom 1.t#1.D
                di "  ATT = " %8.4f r(estimate) "  p = " %6.4f r(p)
            }
        }
    }
}

/* -- 6c. Par groupe d'age ----------------------------------- */
di _newline "=== Heterogeneite par groupe d'age ==="
foreach g in 1 2 3 {
    foreach outcome in pauvre_AF pauvre_MODA {
        quietly count if groupe_moda == `g'
        if r(N) > 30 {
            di "--- Groupe `g' — `outcome' ---"
            regress `outcome' i.t##i.D [aw=weight_knn] if groupe_moda == `g', ///
                vce(cluster grappe)
            lincom 1.t#1.D
            di "  ATT = " %8.4f r(estimate) "  p = " %6.4f r(p)
        }
    }
}

/* ============================================================
   7. Robustesse
   ============================================================ */

/* -- 7a. Sensibilite au seuil k (Alkire-Foster) ------------- */
di _newline "=== Sensibilite au seuil k (Alkire-Foster) ==="
foreach k_test in 0.1667 0.3333 0.5 {
    gen byte pauvre_ktest = (score_dep >= `k_test') if !missing(score_dep)
    regress pauvre_ktest i.t##i.D [aw=weight_knn], vce(cluster grappe)
    lincom 1.t#1.D
    di "  k=" %5.4f `k_test' " : ATT=" %8.4f r(estimate) "  p=" %6.4f r(p)
    drop pauvre_ktest
}

/* -- 7b. Robustesse aux trois methodes d'appariement -------- */
di _newline "=== Comparaison des trois methodes d'appariement ==="
foreach poids_var in weight_kernel weight_caliper {
    merge m:1 grappe menage using "$TEMP/poids_`=substr("`poids_var'",8,.)'.dta", ///
        keepusing(`poids_var') keep(master match) nogenerate
}
foreach poids_var in weight_knn weight_kernel weight_caliper {
    foreach outcome in pauvre_AF pauvre_MODA {
        quietly count if !missing(`poids_var') & `poids_var' > 0
        if r(N) > 0 {
            regress `outcome' i.t##i.D [aw=`poids_var'] ///
                if `poids_var' > 0, vce(cluster grappe)
            lincom 1.t#1.D
            di "  `poids_var' — `outcome' : ATT=" %8.4f r(estimate) ///
               "  p=" %6.4f r(p)
        }
    }
}

di _newline ">>> 05_psm_dd.do termine."
