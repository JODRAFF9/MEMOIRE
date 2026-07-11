/* ============================================================
   test_psm_entrants.do — TEST : PSM applique au design "entrants"
   ============================================================

   Script de TEST, hors pipeline principal. tout.do fournit deja une
   comparaison DD brute (sans appariement) entre entrants et jamais
   beneficiaires (section 8, robustesse). Objectif ici : appliquer le
   PSM a ce meme design pour voir si l'appariement change la
   conclusion (ATT_DD_entrants brut = 0,0007, non significatif,
   p=0,976).

   Echantillon : menages SANS transfert en 2018 (D_2018=0) uniquement.
   Parmi eux, deux groupes :
     - entrants   : D_2021=1 (deviennent beneficiaires en 2021)
     - jamais benef. : D_2021=0 (restent sans transfert aux 2 vagues)
   Appariement (probit + k-NN) sur les caracteristiques de 2018,
   AVANT que le statut de traitement ne change - donc sur des
   variables non affectees par le traitement (pas de "bad control").

   Necessite d'avoir deja execute tout.do (utilise ses fichiers
   temporaires : $TEMP/vague_2018.dta, vague_2021.dta,
   $TEMP/ids_panel.dta, $TEMP/traitement_stable.dta).
   ============================================================ */

clear all
set more off

global TEMP "code/stata/temp"

capture which psmatch2
if _rc {
    di "Installation de psmatch2 depuis SSC..."
    ssc install psmatch2, replace
}

/* ============================================================
   1. Reconstruire l'echantillon "entrants" (identique a tout.do,
   section robustesse "entrants")
   ============================================================ */

use "$TEMP/ids_panel.dta", clear
tempfile menages_panel
save `menages_panel'

use "$TEMP/vague_2018.dta", clear
merge m:1 grappe menage using `menages_panel', keep(match) nogenerate
merge m:1 grappe menage using "$TEMP/traitement_stable.dta", ///
    keepusing(D_2018 D_2021) keep(match) nogenerate
tempfile ent_t0
save `ent_t0'

use "$TEMP/vague_2021.dta", clear
merge m:1 grappe menage using `menages_panel', keep(match) nogenerate
merge m:1 grappe menage using "$TEMP/traitement_stable.dta", ///
    keepusing(D_2018 D_2021) keep(match) nogenerate
tempfile ent_t1
save `ent_t1'

use `ent_t0', clear
append using `ent_t1'
keep if D_2018 == 0
gen byte D_entrant = D_2021
label var D_entrant "1=entrant (beneficiaire seulement en 2021), 0=jamais beneficiaire"

quietly count if D_entrant == 1 & t == 0
local n_ent = r(N)
quietly count if D_entrant == 0 & t == 0
local n_jam = r(N)
di _newline "=== Echantillon entrants (D_2018=0) ==="
di "  Entrants (D=0 en 2018 -> D=1 en 2021) : `n_ent' menages"
di "  Jamais beneficiaires (aux 2 vagues)   : `n_jam' menages"

save "$TEMP/panel_entrants.dta", replace

/* ============================================================
   2. DD brute (reference, deja dans tout.do)
   ============================================================ */

di _newline "--- DD brute, entrants vs jamais beneficiaires (reference) ---"
regress pauvre_MODA i.t##i.D_entrant, vce(cluster grappe)
lincom 1.t#1.D_entrant
di "  ATT_DD_entrants (brut) = " %8.4f r(estimate) ///
   "  SE=" %8.4f r(se) "  p=" %6.4f r(p)

/* ============================================================
   3. Score de propension a t=0 (menage), sur les entrants et
   jamais beneficiaires uniquement
   ============================================================ */

di _newline "=== Score de propension (menage), echantillon entrants, EHCVM I ==="

use "$TEMP/panel_entrants.dta", clear
keep if t == 0 & !missing(D_entrant) & !missing(log_pcexp) & !missing(hhsize)
bysort grappe menage: keep if _n == 1

di "Menages : " _N

probit D_entrant c.hhsize c.log_pcexp i.milieu i.region ///
       c.hgender c.hage i.heduc i.hmstat, vce(cluster grappe) nolog

predict pscore_ent, pr
label var pscore_ent "Score de propension (menage, design entrants)"

di _newline "=== Appariement k-NN (k=4, avec remise), design entrants ==="
psmatch2 D_entrant, pscore(pscore_ent) neighbor(4) common

di _newline "Balance avant/apres (SMD) :"
pstest hhsize log_pcexp i.milieu i.region hgender hage i.heduc i.hmstat, both

rename _weight weight_knn_ent
keep grappe menage D_entrant pscore_ent weight_knn_ent _support
tempfile pscore_ent_knn
save `pscore_ent_knn'

/* ============================================================
   4. PSM-DD sur le design entrants
   ============================================================ */

use "$TEMP/panel_entrants.dta", clear
merge m:1 grappe menage using `pscore_ent_knn', ///
    keepusing(weight_knn_ent) keep(master match) nogenerate
keep if !missing(weight_knn_ent) & weight_knn_ent > 0

di _newline "Panel apparie (entrants, k-NN) : " _N " obs enfants"

di _newline "--- PSM-DD, design entrants ---"
regress pauvre_MODA i.t##i.D_entrant [aw=weight_knn_ent], vce(cluster grappe)
lincom 1.t#1.D_entrant
di "  ATT PSM-DD (entrants) = " %8.4f r(estimate) ///
   "  SE=" %8.4f r(se) "  p=" %6.4f r(p)

di _newline "--- PSM seul, t=0 (niveau initial, design entrants) ---"
regress pauvre_MODA D_entrant [aw=weight_knn_ent] if t == 0, vce(cluster grappe)
di "  ATT PSM (t=0) = " %8.4f _b[D_entrant] "  SE=" %8.4f _se[D_entrant] ///
   "  p=" %6.4f (2*ttail(e(df_r), abs(_b[D_entrant]/_se[D_entrant])))

di _newline "--- PSM seul, t=1 (EHCVM II, design entrants) ---"
regress pauvre_MODA D_entrant [aw=weight_knn_ent] if t == 1, vce(cluster grappe)
di "  ATT PSM (t=1) = " %8.4f _b[D_entrant] "  SE=" %8.4f _se[D_entrant] ///
   "  p=" %6.4f (2*ttail(e(df_r), abs(_b[D_entrant]/_se[D_entrant])))

di _newline ">>> test_psm_entrants.do termine."
