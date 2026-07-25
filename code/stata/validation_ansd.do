/* ============================================================
   validation_ansd.do — Reproduction des taux de privation ANSD
   (colonne « MODA 2024 », Tableau 3) sur l'EHCVM 2018/19
   ------------------------------------------------------------
   Script AUTONOME et DESCRIPTIF (n'affecte pas la double
   difference du memoire). Il encode, indicateur par indicateur
   et pour les 7 dimensions N-MODA, les definitions retenues dans
   le memoire (alignees sur l'annexe methodologique ANSD/UNICEF),
   et calcule par groupe d'age (0-4 / 5-14 / 15-17) le taux de
   privation PONDERE (hhweight), afin de le comparer a la colonne
   MODA 2024 du rapport ANSD.

   Equivalent Stata de code/python/validation_indicateurs_ansd.py.
   Chaque bloc rappelle la cible ANSD et la valeur reproduite.

   Se lance de n'importe ou (bases lues via GitHub) :  do "validation_ansd.do"
   ============================================================ */

clear all
set more off
/* Bases lues directement depuis le depot GitHub (comme tout.do) : le script
   se lance de n'importe ou, sans fichiers locaux ni cd prealable. Pour lire
   des copies locales a la place, remplacer l'URL par le chemin du dossier. */
global B18 "https://raw.githubusercontent.com/JODRAFF9/MEMOIRE/main/Base/2018-2019/SEN_2018_EHCVM_v02_M_Stata"

/* ── Base enfants : age, education, activite, poids, taille menage ─── */
use "$B18/ehcvm_individu_sen2018.dta", clear
bysort grappe menage: gen int hhsize = _N        /* taille du menage (roster) */
keep grappe menage numind age scol activ7j alfab hhweight hhsize
gen byte gmoda = .
replace gmoda = 1 if age <= 4
replace gmoda = 2 if age >= 5  & age <= 14
replace gmoda = 3 if age >= 15 & age <= 17
label define gm 1 "0-4 ans" 2 "5-14 ans" 3 "15-17 ans"
label values gmoda gm
keep if inlist(gmoda,1,2,3)
tempfile base
save `base'

/* ============================================================
   1. MODULE HABITAT s11 (menage) : toilettes, eau, ordures,
      surpeuplement, combustible
   ============================================================ */
use "$B18/s11_me_sen2018.dta", clear

/* -- Type de toilettes non amelioré (s11q55 in 7..12).
      Cible ANSD 40,3 / 39,1 / 34,1 ; reproduit 40,3 / 39,1 / 34,1 (exact) -- */
gen byte m_toilet = inlist(s11q55, 7, 8, 9, 10, 11, 12) if !missing(s11q55)

/* -- Partage des toilettes (s11q56==1). Denominateur = menages dont la
      question du partage est renseignee.
      Cible 20,4 / 19,4 / 18,6 ; reproduit 20,4 / 19,4 / 18,6 (exact) -- */
gen byte m_partag = (s11q56 == 1) if !missing(s11q56)

/* -- Source d'eau non amelioree (codes 5,6,12,13,16,17), saison seche OU
      pluies, ET ne traite pas son eau (filtre s11q32 != 1 « oui » ; les
      « ne sait pas »/non-reponses comptes comme non-traitement).
      Denominateur PLEIN (type de source renseigne).
      Cible 12,0 / 10,7 / 8,5 ; reproduit 11,9 / 10,0 / 7,9 -- */
gen byte src_ss = inlist(s11q27a, 5, 6, 12, 13, 16, 17)
gen byte src_sp = inlist(s11q27b, 5, 6, 12, 13, 16, 17)
gen byte m_eau_source = ((src_ss==1 | src_sp==1) & (s11q32 != 1)) ///
    if !missing(s11q27a) | !missing(s11q27b)

/* -- Temps pour chercher l'eau >= 30 min (aller + attente a la source),
      l'une ou l'autre saison ; eau sur place (codes 1-2) = 0.
      Cible 17,7 / 16,4 / 13,9 ; reproduit 17,7 / 16,7 / 13,6 -- */
gen double t_ss = s11q29a + s11q29b_heure*60 + s11q29b_minute
gen double t_sp = s11q31a + s11q31b_heure*60 + s11q31b_minutes
gen byte m_eau_temps = (t_ss >= 30 & !missing(t_ss)) | (t_sp >= 30 & !missing(t_sp)) ///
    if !missing(t_ss) | !missing(t_sp)
replace m_eau_temps = 0 if missing(m_eau_temps) & inlist(s11q27a,1,2) & inlist(s11q27b,1,2)

/* -- Debarras des ordures : brulees(3), depotoir sauvage(5), autre(6).
      Cible 59,3 / 58,2 / 53,0 ; reproduit 59,3 / 58,2 / 53,0 (exact) -- */
gen byte m_ordures = inlist(s11q54, 3, 5, 6) if !missing(s11q54)

/* -- Surpeuplement : « plus de 3 personnes par piece » = AU MOINS 4 par
      piece (ratio >= 4), et non ratio > 3. Pieces = total occupe (s11q02).
      Cible 13,3 / 12,7 / 11,4 ; reproduit 13,3 / 12,7 / 11,4 (exact) -- */
gen int nb_pieces = s11q02

/* -- Combustible solide pour cuisiner (s11q53__1,2,3,7,8 >= 1).
      Cible 92,3 / 92,3 / 91,5 ; reproduit 92,3 / 92,3 / 91,5 (exact) -- */
gen byte m_combust = 0
foreach v of varlist s11q53__1 s11q53__2 s11q53__3 s11q53__7 s11q53__8 {
    replace m_combust = 1 if `v' >= 1 & !missing(`v')
}
egen byte nmc = rowmiss(s11q53__1 s11q53__2 s11q53__3 s11q53__7 s11q53__8)
replace m_combust = . if nmc > 0

keep grappe menage m_toilet m_partag m_eau_source m_eau_temps m_ordures ///
     m_combust nb_pieces
tempfile hab
save `hab'

/* ============================================================
   2. INSECURITE ALIMENTAIRE (FIES, s08a, menage)
      Membre ayant saute un repas / mange moins / manque / faim /
      journee sans manger (q04-q08 == 1). Cas complets.
      Cible 45,0 / 46,5 / 44,9 ; reproduit 45,0 / 46,5 / 44,9 (exact)
   ============================================================ */
use "$B18/s08a_me_sen2018.dta", clear
gen byte m_securite = 0
foreach v in s08aq04 s08aq05 s08aq06 s08aq07 s08aq08 {
    replace m_securite = 1 if `v' == 1 & !missing(`v')
}
egen byte nms = rowmiss(s08aq04 s08aq05 s08aq06 s08aq07 s08aq08)
replace m_securite = . if nms > 0
collapse (max) m_securite, by(grappe menage)
tempfile fies
save `fies'

/* ============================================================
   3. ROSTER s01 (individu) : acte de naissance, separation parentale
   ============================================================ */
use "$B18/s01_me_sen2018.dta", clear
rename s01q00a numind
/* -- Acte de naissance : absence (s01q05==2), pertinent < 15 ans.
      Cible 31,8 / 30,1 ; reproduit 31,8 / 30,0 -- */
gen byte m_acte = (s01q05 == 2) if !missing(s01q05)
/* -- Separation parentale : ne vit pas avec ses DEUX parents biologiques
      (pere s01q22==2 OU mere s01q29==2). Cas complets.
      Cible 36,5 / 41,8 / 52,8 ; reproduit 36,5 / 43,0 / 52,8 -- */
gen byte m_parents = .
replace m_parents = 1 if s01q22 == 2 | s01q29 == 2
replace m_parents = 0 if s01q22 == 1 & s01q29 == 1
keep grappe menage numind m_acte m_parents
tempfile roster
save `roster'

/* ============================================================
   4. TRAVAIL DES ENFANTS (s04, individu, 5-14) : eco. OU dom. >= 1h
      Cible 43,0 ; reproduit 41,8
   ============================================================ */
use "$B18/s04_me_sen2018.dta", clear
rename s01q00a numind
gen byte trav_eco = inlist(1, s04q06, s04q07, s04q08, s04q09)
egen h_dom = rowtotal(s04q01 s04q02 s04q03 s04q04 s04q05)
egen byte nrep = rownonmiss(s04q01 s04q02 s04q03 s04q04 s04q05 ///
                            s04q06 s04q07 s04q08 s04q09)
gen byte m_trav_enf = (trav_eco == 1 | h_dom >= 1) if nrep > 0 & !missing(nrep)
keep grappe menage numind m_trav_enf
tempfile trav
save `trav'

/* ============================================================
   5. ACCES SANTE (module communautaire s02_co, grappe)
      Acces a pied STRICT (definition ANSD "ne peut acceder A PIED") : le mode
      habituel pour rejoindre une structure de sante 5/6 est la marche
      (s02q02==1). L'existence locale n'implique pas l'acces a pied et n'est
      donc pas retenue (un OU inclusif "existe OU a pied" introduirait la
      condition non ecrite existe=>a-pied et abaisserait le taux a 48 %).
      Cible ANSD 79,3 / 78,5 / 75,2 ; reproduit 71,0 / 69,8 / 65,4. Le residu
      tient aux localites a structure sur place (mode non renseigne, surtout
      rurales) que le questionnaire ne permet pas de qualifier.
   ============================================================ */
use "$B18/s02_co_sen2018.dta", clear
keep if inlist(s02q00, 5, 6)
gen byte pfoot = (s02q02 == 1)   /* acces a pied STRICT : mode habituel = marche */
collapse (max) sante_pfoot = pfoot, by(grappe)
gen byte m_sante_acces = (sante_pfoot != 1)
keep grappe m_sante_acces
tempfile sante
save `sante'

/* ============================================================
   6. FUSION + INDICATEURS EDUCATION + CALCUL PONDERE
   ============================================================ */
use `base', clear
merge m:1 grappe menage        using `hab',    keep(master match) nogenerate
merge m:1 grappe menage        using `fies',   keep(master match) nogenerate
merge m:1 grappe menage numind using `roster', keep(master match) nogenerate
merge m:1 grappe menage numind using `trav',   keep(master match) nogenerate
merge m:1 grappe               using `sante',  keep(master match) nogenerate

/* Surpeuplement (necessite hhsize du base et nb_pieces de l'habitat) */
gen byte m_surpeup = (hhsize/nb_pieces >= 4) if !missing(nb_pieces) & nb_pieces > 0 & !missing(hhsize)

/* Education */
gen byte m_scol  = (scol == 0)  if age >= 5 & age <= 14 & !missing(scol)
gen byte m_alfab = (alfab == 0) if age >= 15 & age <= 17 & !missing(alfab)
gen byte m_neet  = (scol == 0 & activ7j != 1) if age >= 15 & age <= 17

/* Restrictions d'age */
replace m_acte     = . if age >= 15                 /* pertinent < 15 ans */

di _newline(2) "=== Taux de privation ponderes (hhweight) par indicateur et"
di    "    groupe d'age, EHCVM 2018 -- a comparer a la colonne MODA 2024 ANSD ==="

/* Indicateurs applicables a tous les groupes d'age */
foreach v in m_toilet m_partag m_eau_source m_eau_temps m_ordures m_surpeup ///
             m_securite m_combust m_sante_acces m_parents {
    di _newline "-- `v' (0-4 / 5-14 / 15-17) --"
    tabstat `v' [aw=hhweight], by(gmoda) stat(mean n) format(%7.4f)
}
/* Indicateurs a portee d'age restreinte */
di _newline "-- m_acte (0-4 / 5-14 ; < 15 ans) --"
tabstat m_acte [aw=hhweight] if age < 15, by(gmoda) stat(mean n) format(%7.4f)
di _newline "-- m_trav_enf (5-14 uniquement) --"
tabstat m_trav_enf [aw=hhweight] if gmoda==2, stat(mean n) format(%7.4f)
di _newline "-- m_scol : non-scolarisation (5-14 uniquement) --"
tabstat m_scol [aw=hhweight] if gmoda==2, stat(mean n) format(%7.4f)
di _newline "-- m_alfab : illettrisme (15-17 uniquement) --"
tabstat m_alfab [aw=hhweight] if gmoda==3, stat(mean n) format(%7.4f)
di _newline "-- m_neet : ECARTE de l'agregat (ANSD 85,7 incoherent) --"
tabstat m_neet [aw=hhweight] if gmoda==3, stat(mean n) format(%7.4f)

di _newline ">>> validation_ansd.do termine."
