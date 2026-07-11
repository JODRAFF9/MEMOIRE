/* ============================================================
   test_psm_sans_dd.do — TEST : PSM seul (sans double difference)
   ============================================================

   Script de TEST, hors pipeline principal (tout.do garde le PSM-DD
   comme design principal, cf. section methodo sur la causalite
   inverse). Objectif : comparer l'ATT PSM-DD (design retenu) a un
   simple appariement transversal sans double difference, pour isoler
   la contribution de la composante "difference" (tendance temporelle
   commune) dans l'estimateur.

   PSM seul = comparaison des moyennes appariees a une seule date
   (t=1, EHCVM II), entre traites stables et temoins apparies,
   ponderee par le poids d'appariement k-NN. Contrairement au PSM-DD,
   cet estimateur ne retranche pas la difference de niveau initiale
   (t=0) : il suppose que l'appariement a lui seul suffit a rendre
   traites et temoins comparables, sans corriger d'eventuelles
   differences residuelles non observees a t=0.

   Necessite d'avoir deja execute tout.do (utilise son fichier
   temporaire : $TEMP/panel_apparie.dta).
   ============================================================ */

clear all
set more off

global TEMP "code/stata/temp"

di _newline "=== PSM seul (transversal, sans DD) vs PSM-DD (reference) ==="

use "$TEMP/panel_apparie.dta", clear

/* ============================================================
   1. PSM-DD (reference, tout.do)
   ============================================================ */

di _newline "--- PSM-DD (reference) ---"
regress pauvre_MODA i.t##i.D [aw=weight_knn], vce(cluster grappe)
lincom 1.t#1.D
di "  ATT PSM-DD = " %8.4f r(estimate) "  SE=" %8.4f r(se) "  p=" %6.4f r(p)

/* ============================================================
   2. PSM seul a t=0 (EHCVM I) : difference de niveau initiale
   entre traites et temoins apparies, avant tout transfert observe
   sur la periode d'etude
   ============================================================ */

di _newline "--- PSM seul, t=0 (EHCVM I, niveau initial) ---"
regress pauvre_MODA D [aw=weight_knn] if t == 0, vce(cluster grappe)
di "  ATT PSM (t=0) = " %8.4f _b[D] "  SE=" %8.4f _se[D] ///
   "  p=" %6.4f (2*ttail(e(df_r), abs(_b[D]/_se[D])))

/* ============================================================
   3. PSM seul a t=1 (EHCVM II) : estimateur transversal, sans
   correction de la difference initiale (equivalent a un PSM
   "simple" tel qu'utilise hors design DD)
   ============================================================ */

di _newline "--- PSM seul, t=1 (EHCVM II, sans DD) ---"
regress pauvre_MODA D [aw=weight_knn] if t == 1, vce(cluster grappe)
di "  ATT PSM (t=1) = " %8.4f _b[D] "  SE=" %8.4f _se[D] ///
   "  p=" %6.4f (2*ttail(e(df_r), abs(_b[D]/_se[D])))

di _newline "Rappel : ATT_PSM-DD = ATT_PSM(t=1) - ATT_PSM(t=0), par construction."

di _newline ">>> test_psm_sans_dd.do termine."
