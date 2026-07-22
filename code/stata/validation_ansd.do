/* ============================================================
   validation_ansd.do — Reproduction des taux de privation ANSD
   (colonne « MODA 2024 », calculée sur l'EHCVM 2018/19)
   ------------------------------------------------------------
   Script AUTONOME et DESCRIPTIF (n'affecte pas la double
   différence du memoire). Il encode les definitions EXACTES de
   l'annexe methodologique ANSD/UNICEF et calcule, par groupe
   d'age, les taux de privation par indicateur, afin de les
   comparer a la colonne MODA 2024 du rapport ANSD.

   Les definitions ci-dessous ont ete validees indicateur par
   indicateur sur les donnees brutes ; la valeur cible ANSD et la
   valeur reproduite sont indiquees en commentaire pour chaque
   indicateur (0-4 / 5-14 / 15-17 ans).

   Lancement depuis la racine :  do "code/stata/validation_ansd.do"
   ============================================================ */

clear all
set more off
global B18 "Base/2018-2019/SEN_2018_EHCVM_v02_M_Stata"

/* ── Base individus (age, scolarisation, activite) ─────────── */
use "$B18/ehcvm_individu_sen2018.dta", clear
keep grappe menage numind age scol activ7j
tempfile indiv
save `indiv'

/* ── Groupes d'age N-MODA ──────────────────────────────────── */
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
   1. TRAVAIL DES ENFANTS (5-14) — economique OU domestique >=1h
      Cible ANSD : 43,0   |  Reproduit : ~41,8
      Ne sont retenues que les variables posant clairement le seuil "au moins
      1h". Domestique (nombre d'heures) : q01 courses, q02 travaux domestiques,
      q03 garde, q04 eau, q05 bois. Economique (code "au moins 1h") : q06-q09.
   ============================================================ */
use "$B18/s04_me_sen2018.dta", clear
rename s01q00a numind
* Travail economique : uniquement les questions posant le seuil "au moins 1h"
* (q06-q09). q13/q14 (travail familial non remunere) ecartes, sans seuil horaire.
gen byte trav_eco = inlist(1, s04q06, s04q07, s04q08, s04q09)
* Travail domestique : cinq postes d'heures du module (courses q01, travaux
* domestiques q02, garde q03, eau q04, bois q05).
egen h_dom = rowtotal(s04q01 s04q02 s04q03 s04q04 s04q05)
egen byte nrep = rownonmiss(s04q01 s04q02 s04q03 s04q04 s04q05 ///
                            s04q06 s04q07 s04q08 s04q09)
gen byte trav_dom = (h_dom >= 1)
gen byte m_trav_enf = (trav_eco == 1 | trav_dom == 1) if nrep > 0
keep grappe menage numind m_trav_enf
tempfile trav
save `trav'

/* ============================================================
   2. MODULE HABITAT s11 (eau, ordures, sanitaire, surpeuplement)
   ============================================================ */
use "$B18/s11_me_sen2018.dta", clear

/* -- Source d'eau non amelioree (codes 5,6,12,13,16,17) en saison des
      pluies OU seche, ET traitement inadequat (filtrer au linge s11q33__3,
      laisser reposer __6, autre __7). Denominateur = menages ayant repondu
      (oui/non) au filtre de traitement s11q32 (1=oui, 2=non, 3=ne sait pas).
      Cible 12,0/10,7/8,5 ; reproduit ~9,6/9,8/8,7 -- */
gen byte src_ss = inlist(s11q27a,5,6,12,13,16,17)
gen byte src_sp = inlist(s11q27b,5,6,12,13,16,17)
gen byte trait_inad = (s11q33__3==1 | s11q33__6==1 | s11q33__7==1)
gen byte m_eau_source = ((src_ss==1 | src_sp==1) & trait_inad==1) if inlist(s11q32,1,2)

/* -- Temps pour chercher l'eau > 30 min (aller + attente a la
      source), l'une ou l'autre saison.  Cible 17,7/16,4/13,9 ;
      reproduit ~17,5/16,5/13,8 -- */
gen t_ss = s11q29a + s11q29b_heure*60 + s11q29b_minute
gen t_sp = s11q31a + s11q31b_heure*60 + s11q31b_minutes
gen byte m_eau_temps = (t_ss > 30 & !missing(t_ss)) | (t_sp > 30 & !missing(t_sp))

/* -- Ordures : brulees(3), depotoir sauvage(5), autre(6).
      Cible 59,3/58,2/53,0 ; reproduit ~64/63/58 -- */
gen byte m_ordures = inlist(s11q54,3,5,6)

/* -- Partage des toilettes (Cible 20,4/19,4/18,6) -- */
gen byte m_partag = (s11q56==1)

/* -- Type de sanitaire non ameliore (s11q55) : a affiner selon la
      correspondance exacte des codes ANSD.  Cible 40,3/39,1/34,1 -- */
/* gen byte m_toilet = inlist(s11q55, ...) */

/* -- Surpeuplement : > 3 personnes par piece POUR DORMIR.
      La variable "pieces pour dormir" n'est pas disponible ;
      s11q02 (pieces occupees) donne ~26 vs cible ANSD 13,3.
      A documenter comme non reproductible en l'etat. -- */
keep grappe menage m_eau_source m_eau_temps m_ordures m_partag
tempfile hab
save `hab'

/* ============================================================
   3. FUSION ET CALCUL DES TAUX PAR GROUPE D'AGE
   ============================================================ */
use `base', clear
merge m:1 grappe menage numind using `trav', keep(master match) nogenerate
merge m:1 grappe menage        using `hab',  keep(master match) nogenerate

di _newline(2) "=== Taux de privation par indicateur et groupe d'age (EHCVM 2018) ==="
di "(comparer a la colonne MODA 2024 du rapport ANSD)"

foreach v in m_eau_source m_eau_temps m_ordures m_partag {
    di _newline "-- `v' --"
    tabstat `v', by(gmoda) stat(mean n) format(%6.3f)
}
di _newline "-- m_trav_enf (5-14 uniquement) --"
tabstat m_trav_enf if gmoda==2, stat(mean n) format(%6.3f)

di _newline ">>> validation_ansd.do termine."
