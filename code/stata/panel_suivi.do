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

/* ============================================================
   3. Base complete : enfants suivis + caracteristiques menage
   ------------------------------------------------------------
   Enfants de 0 a 17 ans des menages suivis (panel vrai), enrichis
   des caracteristiques du menage (taille, depense par tete, milieu,
   region, sexe/age/education du chef). Base prete pour les
   statistiques descriptives.
   ============================================================ */

di _newline(2) "=== Construction de la base complete (enfants suivis) ==="

foreach annee in 2018 2021 {
    local base = cond(`annee' == 2018, "$BASE_2018", "$BASE_2021")

    use "$TEMP/indiv_menage_`annee'.dta", clear

    /* Enfants de 0 a 17 ans */
    keep if inrange(age, 0, 17)

    /* Caracteristiques du menage depuis la base welfare (evite les
       conflits en supprimant d'eventuels doublons deja presents) */
    capture drop hhsize pcexp region milieu hgender hage heduc hmstat
    merge m:1 grappe menage using "`base'/ehcvm_welfare_sen`annee'.dta", ///
        keepusing(hhsize pcexp region milieu hgender hage heduc hmstat) ///
        nogenerate keep(master match)

    /* Restriction aux menages suivis (panel vrai) */
    merge m:1 grappe menage using "$TEMP/menages_suivi.dta", ///
        keepusing(suivi) nogenerate keep(master match)
    keep if suivi == 1

    gen int vague_obs = `annee'
    tempfile enf_`annee'
    save `enf_`annee''
    di "  `annee' : " _N " enfants suivis"
}

use `enf_2018', clear
append using `enf_2021'

/* Variables derivees utiles aux statistiques descriptives */
gen byte urbain = (milieu == 1)  if !missing(milieu)
gen byte chef_f = (hgender == 2) if !missing(hgender)
label var urbain "Menage urbain"
label var chef_f "Chef de menage feminin"
label var vague_obs "Vague d'observation"

save "$TEMP/base_enfants_suivis.dta", replace
di ">>> Base complete sauvegardee : $TEMP/base_enfants_suivis.dta (" _N " enfants-vagues)"

/* ============================================================
   4. Statistiques descriptives
   ============================================================ */

di _newline "=== Statistiques descriptives (enfants suivis) ==="

foreach annee in 2018 2021 {
    di _newline "-- Vague `annee' --"
    tabstat hhsize pcexp hage urbain chef_f if vague_obs == `annee', ///
        stat(mean sd n) format(%9.2f) columns(statistics)
}

di _newline "Repartition des enfants par milieu et vague :"
tab milieu vague_obs
di _newline "Repartition des enfants par sexe et vague :"
tab sexe vague_obs

di _newline ">>> panel_suivi.do termine."
