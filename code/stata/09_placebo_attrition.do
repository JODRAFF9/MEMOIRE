/* ============================================================
   09_placebo_attrition.do — Tests de validite (annexe A)

   1. Test placebo : 200 assignations aleatoires d'un faux
      traitement parmi les menages jamais traites ; la
      distribution des ATT placebo doit etre centree sur zero
      si l'hypothese de tendances paralleles est plausible.
   2. Test d'attrition : comparaison des menages de l'EHCVM I
      retrouves vs perdus en 2021 sur les covariables de base.

   Aucune ponderation par poids d'enquete.
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/* ============================================================
   1. Test placebo (200 replications)
   ============================================================ */

di _newline "=== Test placebo (200 replications) ==="

local n_rep 200
matrix PLA = J(`n_rep', 2, .)   /* col 1 = AF, col 2 = MODA */

/* Echantillon : menages jamais traites uniquement */
use "$TEMP/panel_vrai.dta", clear
keep if D == 0
tempfile never
save `never'

/* Liste des menages (une ligne par menage) */
bysort grappe menage: keep if _n == 1
keep grappe menage
tempfile liste_men
save `liste_men'
quietly count
local n_men = r(N)
/* part de faux traites = part observee de traites stables (~14.6%) */
local part_fake = 681/4662

forvalues r = 1/`n_rep' {
    quietly {
        use `liste_men', clear
        set seed `=1000+`r''
        gen u = runiform()
        sort u
        gen byte fakeD = (_n <= `part_fake'*`n_men')
        keep grappe menage fakeD
        tempfile fake
        save `fake'

        use `never', clear
        merge m:1 grappe menage using `fake', keep(match) nogenerate

        /* DD placebo (moyennes des 4 cellules) */
        foreach y in pauvre_AF pauvre_MODA {
            summarize `y' if t==1 & fakeD==1
            local m11 = r(mean)
            summarize `y' if t==0 & fakeD==1
            local m01 = r(mean)
            summarize `y' if t==1 & fakeD==0
            local m10 = r(mean)
            summarize `y' if t==0 & fakeD==0
            local m00 = r(mean)
            local att = (`m11'-`m01') - (`m10'-`m00')
            if "`y'" == "pauvre_AF"  matrix PLA[`r',1] = `att'
            else                     matrix PLA[`r',2] = `att'
        }
    }
    if mod(`r', 50) == 0 di "  replication `r'/`n_rep'"
}

/* Statistiques de la distribution placebo */
clear
svmat PLA, names(col)
rename c1 att_af
rename c2 att_moda
foreach y in af moda {
    quietly summarize att_`y'
    di _newline "Placebo `y' : moyenne=" %7.4f r(mean) "  sd=" %6.4f r(sd)
    quietly count if abs(att_`y') > 0.05
    di "  fraction |ATT|>0.05 : " %4.1f 100*r(N)/`n_rep' "%"
}

/* ============================================================
   2. Test d'attrition
   ============================================================ */

di _newline "=== Test d'attrition (menages avec enfants, EHCVM I) ==="

/* Menages 2018 (une ligne par menage) */
use "$TEMP/vague_2018.dta", clear
bysort grappe menage: keep if _n == 1
gen byte chef_f = (hgender == 2)
gen byte urbain = (milieu == 1)
tempfile men18
save `men18'

/* Menages retrouves en 2021 : variable officielle PanelHH (et non la
   presence dans panel_vrai.dta, qui exclut aussi les switchers et
   confondrait attrition et exclusion de l'echantillon d'analyse) */
use "$BASE_2021/s00_me_sen2021.dta", clear
keep if PanelHH == 1
bysort grappe menage: keep if _n == 1
keep grappe menage
gen byte suivi = 1
merge 1:1 grappe menage using `men18', keepusing(hhsize hage chef_f ///
    urbain log_pcexp D) keep(match using) nogenerate
replace suivi = 0 if missing(suivi)

di _newline "Menages suivis vs perdus :"
tabstat hhsize hage chef_f urbain log_pcexp D, by(suivi) ///
    stat(mean n) format(%7.3f)

foreach v in log_pcexp hhsize chef_f urbain hage D {
    quietly regress `v' suivi, vce(cluster grappe)
    di "  `v' : diff=" %8.3f _b[suivi] "  p=" %6.4f ///
       (2*ttail(e(df_r), abs(_b[suivi]/_se[suivi])))
}

di _newline ">>> 09_placebo_attrition.do termine."
