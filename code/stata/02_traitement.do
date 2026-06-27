/* ============================================================
   02_traitement.do — Variable de traitement + identifiant panel

   D = 1 si le menage a recu un transfert de l'etranger
   panel_id = identifiant unique grappe-menage pour le panel vrai

   NB : s13aq14 (2018) et s13q19 (2021) indiquent le pays de
        l'expediteur ; >= CODE_ETRANGER_MIN => transfert etranger
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/* ── Sous-programme : construire D pour une annee ─────────── */

program define construire_traitement
    /*
       args : annee  var_lieu  fichier_detail  fichier_liste
              annee      = 2018 ou 2021
              var_lieu   = nom de la variable lieu expediteur
              fichier_detail = s13a_2 (2018) ou s13_2 (2021)
              fichier_liste  = s13a_1 (2018) ou s13_1 (2021)
    */
    args annee var_lieu fich_det fich_list

    /* Resoudre le chemin de base selon l'annee (evite l'ambiguite $BASE_`annee') */
    if `annee' == 2018 local base "$BASE_2018"
    else               local base "$BASE_2021"

    /* Identifier les menages avec au moins un transfert etranger */
    use "`base'/`fich_det'_me_sen`annee'.dta", clear
    keep if `var_lieu' >= $CODE_ETRANGER_MIN & !missing(`var_lieu')
    bysort grappe menage: keep if _n == 1
    gen transfert_migrant = 1
    keep grappe menage transfert_migrant
    tempfile etrangers
    save `etrangers'

    /* Fusionner sur la liste exhaustive des menages */
    use "`base'/`fich_list'_me_sen`annee'.dta", clear
    merge m:1 grappe menage using `etrangers', ///
        keepusing(transfert_migrant) nogenerate
    replace transfert_migrant = 0 if missing(transfert_migrant)
    rename transfert_migrant D
    bysort grappe menage: keep if _n == 1
    label var D "Traitement : transfert de migrant recu (1=oui)"
    keep grappe menage D
    save "$TEMP/traitement_`annee'.dta", replace

    quietly summarize D
    di "  `annee' : " %5.1f r(mean)*100 "%  (" %4.0f r(sum) "/" %5.0f r(N) " menages)"
end

/* ── Construction pour chaque vague ──────────────────────── */

di _newline ">>> Prevalence des transferts de migrants :"
construire_traitement 2018 s13aq14 s13a_2 s13a_1
construire_traitement 2021 s13q19  s13_2  s13_1

/* ── Identifiant panel (PanelHH) ─────────────────────────── */
/*
   On recupere PanelHH depuis s00_me_sen2021 et on le joint
   au fichier traitement_2021 pour distinguer :
     - panel vrai  (PanelHH=1, grappe+menage communs aux 2 vagues)
     - remplacement (PanelHH=0, ménage nouveau en 2021)
*/

use "$BASE_2021/s00_me_sen2021.dta", clear
keep grappe menage PanelHH
label var PanelHH "Type de menage (1=Panel, 0=Nouveau)"
save "$TEMP/panel_id.dta", replace

/* Verifier cohérence : les memes (grappe,menage) en 2018 */
use "$TEMP/traitement_2018.dta", clear
merge 1:1 grappe menage using "$TEMP/panel_id.dta", ///
    keepusing(PanelHH) nogenerate
quietly count if PanelHH == 1
di _newline "Menages panel retrouves dans traitement_2018 : " r(N)
save "$TEMP/traitement_2018.dta", replace

di _newline ">>> Statut de traitement par type de menage (vague 2021) :"
use "$TEMP/traitement_2021.dta", clear
merge 1:1 grappe menage using "$TEMP/panel_id.dta", ///
    keepusing(PanelHH) nogenerate
tabstat D, by(PanelHH) stat(mean sum n) format(%6.3f)
save "$TEMP/traitement_2021.dta", replace
