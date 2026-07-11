/* ============================================================
   test_sans_nutrition.do — TEST : N-MODA sans la dimension nutrition
   ============================================================

   Script de TEST, hors pipeline principal (tout.do garde les 7
   dimensions, choix methodologique du memoire justifie par le canal
   nutritionnel teste dans la revue de litterature). Objectif :
   comparer l'incidence N-MODA et l'ATT PSM-DD avec et sans la
   dimension nutrition, pour juger de sa contribution a l'ecart
   observe avec l'ANSD (annexe E).

   Necessite d'avoir deja execute tout.do (utilise ses fichiers
   temporaires : $TEMP/vague_2018.dta, vague_2021.dta,
   panel_vrai.dta, panel_apparie.dta).
   ============================================================ */

clear all
set more off

global TEMP "code/stata/temp"
global K_MODA 4

/* ============================================================
   1. Incidence N-MODA (H, A, M0) : 7 dimensions vs 6 (sans nutrition)
   ============================================================ */

di _newline "=== 1. Incidence N-MODA, 7 dimensions vs 6 (sans nutrition) ==="

foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear

    gen byte nb_dep6 = dim_assai + dim_eau + dim_logem + ///
        dim_sante + dim_protect + dim_educ if !missing(dim_assai, dim_eau, ///
        dim_logem, dim_sante, dim_protect, dim_educ)
    gen byte pauvre_MODA6 = (nb_dep6 >= $K_MODA) if !missing(nb_dep6)

    di _newline "--- `annee' ---"

    quietly summarize pauvre_MODA
    local h7 = r(mean)*100
    quietly summarize nb_dep if pauvre_MODA == 1
    local a7 = r(mean)/7*100
    di "  7 dimensions (memoire) : H=" %6.2f `h7' "%   A=" %6.2f `a7' ///
       "%   M0=" %6.4f (`h7'/100)*(`a7'/100)

    quietly summarize pauvre_MODA6
    local h6 = r(mean)*100
    quietly summarize nb_dep6 if pauvre_MODA6 == 1
    local a6 = r(mean)/6*100
    di "  6 dimensions (sans nutrition) : H=" %6.2f `h6' "%   A=" %6.2f `a6' ///
       "%   M0=" %6.4f (`h6'/100)*(`a6'/100)

    di "  Ecart H (7-6 dims) : " %6.2f (`h7'-`h6') " points"
}

/* ============================================================
   2. PSM-DD : ATT avec 7 dimensions (reference) vs 6 (sans nutrition)
   ============================================================ */

di _newline "=== 2. PSM-DD — ATT, 7 dimensions vs 6 (sans nutrition) ==="

use "$TEMP/panel_apparie.dta", clear

gen byte nb_dep6 = dim_assai + dim_eau + dim_logem + ///
    dim_sante + dim_protect + dim_educ if !missing(dim_assai, dim_eau, ///
    dim_logem, dim_sante, dim_protect, dim_educ)
gen byte pauvre_MODA6 = (nb_dep6 >= $K_MODA) if !missing(nb_dep6)

di _newline "--- 7 dimensions (memoire, reference) ---"
regress pauvre_MODA i.t##i.D [aw=weight_knn], vce(cluster grappe)
lincom 1.t#1.D
di "  ATT (7 dim) = " %8.4f r(estimate) "  SE=" %8.4f r(se) "  p=" %6.4f r(p)

di _newline "--- 6 dimensions (sans nutrition) ---"
regress pauvre_MODA6 i.t##i.D [aw=weight_knn], vce(cluster grappe)
lincom 1.t#1.D
di "  ATT (6 dim) = " %8.4f r(estimate) "  SE=" %8.4f r(se) "  p=" %6.4f r(p)

/* ============================================================
   3. Incidence N-MODA (6 dim, sans nutrition) : pondere par hhweight,
   pour comparaison directe avec l'ANSD (qui est pondere)
   ============================================================ */

di _newline "=== 3. Incidence N-MODA a 6 dimensions (sans nutrition), pondere (hhweight) ==="

foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear

    gen byte nb_dep6 = dim_assai + dim_eau + dim_logem + ///
        dim_sante + dim_protect + dim_educ if !missing(dim_assai, dim_eau, ///
        dim_logem, dim_sante, dim_protect, dim_educ)
    gen byte pauvre_MODA6 = (nb_dep6 >= $K_MODA) if !missing(nb_dep6)

    di _newline "--- `annee' ---"
    quietly summarize pauvre_MODA6
    di "  H (6 dim) non pondere : " %6.2f r(mean)*100 "%"
    quietly summarize pauvre_MODA6 [aweight=hhweight]
    di "  H (6 dim) pondere     : " %6.2f r(mean)*100 "%"

    egen strate = group(region milieu)
    svyset grappe [pweight=hhweight], strata(strate)
    svy: mean pauvre_MODA6
}

/* ============================================================
   4. PSM-DD (6 dim, sans nutrition) : pondere (poids d'appariement x
   poids d'enquete)
   ============================================================ */

di _newline "=== 4. PSM-DD — ATT (6 dim, sans nutrition), pondere ==="

use "$TEMP/panel_apparie.dta", clear

gen byte nb_dep6 = dim_assai + dim_eau + dim_logem + ///
    dim_sante + dim_protect + dim_educ if !missing(dim_assai, dim_eau, ///
    dim_logem, dim_sante, dim_protect, dim_educ)
gen byte pauvre_MODA6 = (nb_dep6 >= $K_MODA) if !missing(nb_dep6)
gen double weight_combine = weight_knn * hhweight

regress pauvre_MODA6 i.t##i.D [pw=weight_combine], vce(cluster grappe)
lincom 1.t#1.D
di "  ATT (6 dim, pondere) = " %8.4f r(estimate) "  SE=" %8.4f r(se) "  p=" %6.4f r(p)

di _newline ">>> test_sans_nutrition.do termine."
