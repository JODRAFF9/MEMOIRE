/* ============================================================
   panel_suivi.do — Identification des ménages suivis (panel)
   ------------------------------------------------------------
   Script AUTONOME (independant de tout.do). Il :
     1. charge, pour chaque vague, la base individus et la base
        menage, et les fusionne au niveau menage (grappe + menage) ;
     2. identifie les menages suivis entre 2018-2019 et 2021-2022
        a partir de la variable PanelHH de l'EHCVM II.

   Lancement depuis la racine du projet :
     do "code/stata/panel_suivi.do"

   Cle menage : grappe + menage (identifiant commun aux deux vagues).
   ============================================================ */

clear all
set more off

/* ── Chemins des bases ─────────────────────────────────────── */
global BASE_2018 "Base/2018-2019/SEN_2018_EHCVM_v02_M_Stata"
global BASE_2021 "Base/2021-2022/SEN_2021_EHCVM-2_v01_M_STATA14"
global TEMP      "code/stata/temp"
capture mkdir "$TEMP"

/* ============================================================
   1. Base individus + menage fusionnee, par vague
   ------------------------------------------------------------
   ehcvm_menage n'a pas grappe/menage mais un identifiant hhid :
     2018 : hhid = grappe*1000 + menage
     2021 : hhid = grappe*100  + menage
   ============================================================ */

program drop _all
program define charger_vague
    args annee base
    di _newline(2) "=== Vague `annee' ==="

    /* -- Base individus -- */
    use "`base'/ehcvm_individu_sen`annee'.dta", clear
    di "  Individus : " _N " observations"

    /* -- Fusion avec la base menage (niveau menage) -- */
    if `annee' == 2018 gen long hhid = grappe*1000 + menage
    else               gen long hhid = grappe*100  + menage

    merge m:1 hhid using "`base'/ehcvm_menage_sen`annee'.dta", ///
        nogenerate keep(master match)
    di "  Individus + menage fusionnes : " _N " observations"

    /* -- Sauvegarde de la base individuelle fusionnee -- */
    gen int vague = `annee'
    save "$TEMP/indiv_menage_`annee'.dta", replace

    /* -- Table des menages (une ligne par menage) -- */
    bysort grappe menage: keep if _n == 1
    keep grappe menage vague
    di "  Menages distincts : " _N
    save "$TEMP/menages_`annee'.dta", replace
end

charger_vague 2018 "$BASE_2018"
charger_vague 2021 "$BASE_2021"

/* ============================================================
   2. Identification des menages suivis (panel)
   ------------------------------------------------------------
   PanelHH (module s00 de l'EHCVM II) :
     1 = menage panel, suivi depuis 2018
     0 = nouveau menage (remplacement)
   Un menage est "suivi" s'il est marque PanelHH=1 en 2021 ET
   present dans les deux vagues sur (grappe, menage).
   ============================================================ */

di _newline(2) "=== Identification du panel ==="

/* PanelHH depuis le module menage de 2021 */
use "$BASE_2021/s00_me_sen2021.dta", clear
keep grappe menage PanelHH
label define lpanel 0 "Nouveau menage" 1 "Menage panel (suivi)", replace
label values PanelHH lpanel
di "Repartition PanelHH (EHCVM II) :"
tab PanelHH, missing

tempfile panelhh
save `panelhh'

/* Croisement avec la presence effective dans les deux vagues */
use "$TEMP/menages_2021.dta", clear
merge 1:1 grappe menage using "$TEMP/menages_2018.dta", ///
    keepusing(vague) generate(_present)
/* _present : 1 = 2021 seul, 2 = 2018 seul, 3 = present aux deux vagues */

merge 1:1 grappe menage using `panelhh', keepusing(PanelHH) nogenerate

gen byte suivi = (PanelHH == 1 & _present == 3)
label var suivi "Menage effectivement suivi (panel vrai)"

di _newline "Menages suivis vs non suivis :"
tab suivi, missing

di _newline "Detail (PanelHH x presence dans les deux vagues) :"
tab PanelHH _present, missing

/* -- Sauvegarde de la liste des menages suivis -- */
keep grappe menage PanelHH suivi
save "$TEMP/menages_suivi.dta", replace

quietly count if suivi == 1
di _newline ">>> " r(N) " menages suivis identifies."
di ">>> Liste sauvegardee : $TEMP/menages_suivi.dta"
di ">>> panel_suivi.do termine."
