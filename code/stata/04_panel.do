/* ============================================================
   04_panel.do — Construction du panel vrai (PanelHH=1)

   Exploite le suivi effectif des menages entre les deux vagues.
   Produit : $TEMP/panel_vrai.dta
             $TEMP/panel_complet.dta (panel vrai + nouveaux menages)

   Variables cles :
     grappe menage  — identifiants communs aux deux vagues
     PanelHH        — 1 si menage suivi, 0 si nouveau (2021 seulement)
     t              — 0 (2018) / 1 (2021)
     D              — statut de traitement (transfert migrant)
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/* ============================================================
   1. Preparer chaque vague avec traitement et PanelHH
   ============================================================ */

foreach annee in 2018 2021 {

    if `annee' == 2018 local t_val 0
    else               local t_val 1

    use "$TEMP/enfants_dep_`annee'.dta", clear

    /* Traitement */
    merge m:1 grappe menage using "$TEMP/traitement_`annee'.dta", ///
        keepusing(D) nogenerate keep(master match)

    /* PanelHH : disponible directement dans traitement_2018/2021 */
    capture confirm variable PanelHH
    if _rc {
        /* Si absent (vague 2018 sans jointure panel_id), mettre a 1 */
        gen byte PanelHH = 1
    }

    gen byte t        = `t_val'
    gen log_pcexp     = log(pcexp + 1)

    /* Harmoniser les types pour les interactions Stata */
    foreach v in milieu region heduc hmstat {
        capture confirm variable `v'
        if _rc == 0 capture destring `v', replace
    }

    save "$TEMP/vague_`annee'.dta", replace
    di "Vague `annee' : " _N " enfants, dont " ///
       r(N) " ménages panel"
}

/* ============================================================
   2. Statut de traitement stable (fixe au niveau menage)

   L'estimateur DD requiert un indicateur de groupe de traitement
   FIXE dans le temps. On definit :
     - traites  (D_stable=1) : transfert etranger recu aux DEUX vagues
     - temoins  (D_stable=0) : aucun transfert etranger aux DEUX vagues
     - switchers (D_stable=.) : statut changeant entre les vagues,
       EXCLUS de l'analyse causale (Callaway & Sant'Anna 2021)
   ============================================================ */

use "$TEMP/traitement_2018.dta", clear
rename D D_2018
merge 1:1 grappe menage using "$TEMP/traitement_2021.dta", ///
    keepusing(D) keep(match) nogenerate
rename D D_2021
gen byte D_stable = .
replace D_stable = 1 if D_2018 == 1 & D_2021 == 1
replace D_stable = 0 if D_2018 == 0 & D_2021 == 0
label var D_stable "Traitement stable (1=recu 2 vagues, 0=jamais, .=switcher)"

di _newline ">>> Cellules de traitement (menages presents aux 2 vagues) :"
tab D_2018 D_2021
quietly count if D_stable == 1
di "  Traites stables   : " r(N)
quietly count if D_stable == 0
di "  Jamais traites    : " r(N)
quietly count if missing(D_stable)
di "  Switchers exclus  : " r(N)

keep grappe menage D_stable D_2018 D_2021
save "$TEMP/traitement_stable.dta", replace

/* ============================================================
   3. Panel vrai — uniquement les menages suivis (PanelHH=1)

   On conserve les menages qui apparaissent dans les DEUX vagues
   avec le meme identifiant grappe+menage, avec un statut de
   traitement stable (switchers exclus).
   ============================================================ */

/* Identifier les menages presents dans les deux vagues */
use "$TEMP/vague_2018.dta", clear
keep grappe menage
duplicates drop grappe menage, force
gen _in2018 = 1
tempfile id2018
save `id2018'

use "$TEMP/vague_2021.dta", clear
keep grappe menage PanelHH
duplicates drop grappe menage, force
keep if PanelHH == 1
gen _in2021 = 1
merge 1:1 grappe menage using `id2018'
keep if _merge == 3   /* presents dans les deux vagues */
keep grappe menage
tempfile ids_panel
save `ids_panel'

quietly count
di _newline "Menages vraiment suivis (presences dans les 2 vagues) : " r(N)

/* Construire le panel vrai en deux periodes */
use "$TEMP/vague_2018.dta", clear
merge m:1 grappe menage using `ids_panel', keep(match) nogenerate
tempfile panel_t0
save `panel_t0'

use "$TEMP/vague_2021.dta", clear
merge m:1 grappe menage using `ids_panel', keep(match) nogenerate
tempfile panel_t1
save `panel_t1'

use `panel_t0', clear
append using `panel_t1'
sort grappe menage t

/* Appliquer le statut de traitement STABLE et exclure les switchers */
merge m:1 grappe menage using "$TEMP/traitement_stable.dta", ///
    keepusing(D_stable) keep(master match) nogenerate
drop if missing(D_stable)
replace D = D_stable
drop D_stable
label var D "Traitement stable (1=transfert etranger aux 2 vagues)"

di _newline "=== Panel vrai (statut de traitement stable) ==="
di "Observations totales     : " _N
quietly count if t == 0
di "  - Periode t=0 (2018)  : " r(N)
quietly count if t == 1
di "  - Periode t=1 (2021)  : " r(N)
tabstat D, by(t) stat(mean sum n) format(%6.3f)

save "$TEMP/panel_vrai.dta", replace

/* ============================================================
   4. Panel complet — panel vrai + nouveaux menages 2021

   Utile pour les estimations sur echantillon elargi
   et les comparaisons de robustesse.
   ============================================================ */

use "$TEMP/vague_2018.dta", clear
append using "$TEMP/vague_2021.dta"
sort grappe menage t

di _newline "=== Panel complet (vague 2018 + vague 2021) ==="
di "Observations totales : " _N
tabstat D, by(t) stat(mean sum n) format(%6.3f)

save "$TEMP/panel_complet.dta", replace
