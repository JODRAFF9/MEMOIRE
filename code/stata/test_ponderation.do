/* ============================================================
   test_ponderation.do — TEST : effet de la ponderation d'enquete
   ============================================================

   Script de TEST, hors pipeline principal (tout.do reste sur
   effectifs bruts, choix methodologique du memoire). Objectif :
   comparer les resultats non pondere / pondere par hhweight, pour
   voir l'ampleur du changement induit par la ponderation.

   Necessite d'avoir deja execute tout.do (utilise ses fichiers
   temporaires : $TEMP/vague_2018.dta, vague_2021.dta,
   panel_apparie.dta).
   ============================================================ */

clear all
set more off

global TEMP "code/stata/temp"

/* ============================================================
   1. Incidence N-MODA (H) : non pondere vs pondere
   ============================================================ */

di _newline "=== 1. Incidence N-MODA (H), non pondere vs pondere (hhweight) ==="

foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear

    di _newline "--- `annee' ---"
    quietly summarize pauvre_MODA
    di "  H non pondere : " %6.3f r(mean)*100 "%  (n=" r(N) ")"

    quietly summarize pauvre_MODA [aweight=hhweight]
    di "  H pondere     : " %6.3f r(mean)*100 "%  (somme poids=" %12.0f r(sum_w) ")"
}

/* ============================================================
   2. Prevalence par dimension : non pondere vs pondere
   ============================================================ */

di _newline "=== 2. Prevalence par dimension, non pondere vs pondere (EHCVM I) ==="

use "$TEMP/vague_2018.dta", clear
foreach dim in assai eau logem nutri sante protect educ {
    quietly summarize dim_`dim'
    local np = r(mean)*100
    quietly summarize dim_`dim' [aweight=hhweight]
    local p  = r(mean)*100
    di "  `dim' : non pondere=" %5.1f `np' "%   pondere=" %5.1f `p' "%"
}

/* ============================================================
   3. PSM-DD : ATT non pondere vs pondere (poids combine)
   ============================================================ */

di _newline "=== 3. PSM-DD — ATT, non pondere vs pondere ==="

use "$TEMP/panel_apparie.dta", clear

di _newline "--- Non pondere (reference, tout.do) ---"
regress pauvre_MODA i.t##i.D [aw=weight_knn], vce(cluster grappe)
lincom 1.t#1.D
di "  ATT non pondere = " %8.4f r(estimate) "  SE=" %8.4f r(se) "  p=" %6.4f r(p)

di _newline "--- Pondere (poids d'appariement x poids d'enquete) ---"
gen double weight_combine = weight_knn * hhweight
regress pauvre_MODA i.t##i.D [pw=weight_combine], vce(cluster grappe)
lincom 1.t#1.D
di "  ATT pondere     = " %8.4f r(estimate) "  SE=" %8.4f r(se) "  p=" %6.4f r(p)

di _newline "--- Pondere (poids d'enquete seul, sans poids d'appariement) ---"
regress pauvre_MODA i.t##i.D [pw=hhweight], vce(cluster grappe)
lincom 1.t#1.D
di "  ATT poids enquete seul = " %8.4f r(estimate) "  SE=" %8.4f r(se) "  p=" %6.4f r(p)

/* ============================================================
   4. Design d'enquete complet (svyset) : grappe + strate (region x
   milieu) + hhweight. Comparaison des ecarts-types "design-based"
   (svy:) a ceux obtenus par simple poids applique a summarize/regress
   (aweight/pweight, sans tenir compte de la stratification).

   Documentation EHCVM (basicinformationdocument_sen.pdf) : plan de
   sondage a 2 degres (598 grappes tirees au 1er degre, 12 menages par
   grappe au 2e), stratifie par region x milieu. Aucune variable de
   strate dediee dans les donnees : reconstruite ici par region x milieu.
   ============================================================ */

di _newline "=== 4. Design d'enquete complet (svyset : grappe, strate region x milieu, hhweight) ==="

foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear

    egen strate = group(region milieu)
    svyset grappe [pweight=hhweight], strata(strate)

    di _newline "--- `annee' : H, svy: mean (design-based) ---"
    svy: mean pauvre_MODA

    di _newline "--- `annee' : prevalence par dimension, svy: mean ---"
    svy: mean dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect dim_educ
}

di _newline ">>> test_ponderation.do termine."
