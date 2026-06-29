/* ============================================================
   06_stats_desc.do — Statistiques descriptives
   Chapitre 3 : profil ménages, pauvreté, privations, comparaison D=0/1

   Sorties :
     output/tab_menages.csv          — caractéristiques ménages (tab 5)
     output/tab_balance.csv          — balance traités/non-traités (tab 6)
     output/tab_prevalence_dim.csv   — privations par dimension (tab 7)
     output/tab_moda_age.csv         — N-MODA par groupe d'âge (tab 8)
     output/fig_evolution_ipm.pdf    — évolution H, A, M0 (fig 1)
     output/fig_privations_dim.pdf   — radar/barres privations (fig 2)
     output/fig_overlap.pdf          — overlap scores propension (fig 3)
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/* Créer les dossiers de sortie */
capture mkdir "$OUTPUT"
capture mkdir "$OUTPUT/figures"
capture mkdir "$OUTPUT/tables"

/* ============================================================
   1. Caractéristiques générales des ménages
   ============================================================ */

di _newline "=== 1. Profil des ménages ==="

foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear
    bysort grappe menage: keep if _n == 1   /* un ménage = une ligne */

    merge m:1 grappe menage using "$TEMP/traitement_`annee'.dta", ///
        keepusing(D) nogenerate keep(master match)
    replace D = 0 if missing(D)

    /* Taille ménage, âge CM, milieu, transferts */
    quietly {
        svyset_ehcvm hhweight
        gen byte chef_f = (hgender == 2)
        gen byte urbain = (milieu == 1)
        foreach v in hhsize hage pcexp chef_f urbain D {
            svy: mean `v'
            matrix m = e(b)
            if "`v'" == "hhsize" scalar m_hhsize_`annee' = m[1,1]
            if "`v'" == "hage"   scalar m_hage_`annee'   = m[1,1]
            if "`v'" == "pcexp"  scalar m_pcexp_`annee'  = m[1,1]
            if "`v'" == "chef_f" scalar p_chef_f_`annee' = m[1,1]*100
            if "`v'" == "urbain" scalar p_urbain_`annee' = m[1,1]*100
            if "`v'" == "D"      scalar p_D_`annee'      = m[1,1]*100
        }
        count
        scalar n_men_`annee' = r(N)
    }
    di "`annee' : " n_men_`annee' " ménages"
    di "  Taille moy : " %5.2f m_hhsize_`annee'
    di "  PCE moy    : " %12.0f m_pcexp_`annee' " FCFA/an"
    di "  Chef féminin  : " %5.1f p_chef_f_`annee' "%"
    di "  Milieu urbain : " %5.1f p_urbain_`annee' "%"
    di "  Transferts    : " %5.1f p_D_`annee'      "%"
}

/* Export CSV tableau ménages */
clear
set obs 2
gen str6 annee  = ""
replace annee   = "2018" in 1
replace annee   = "2021" in 2
gen hhsize      = .
gen pcexp       = .
gen p_chef_f    = .
gen p_urbain    = .
gen p_transfert = .
foreach a in 2018 2021 {
    local r = cond("`a'" == "2018", 1, 2)
    replace hhsize      = m_hhsize_`a'   in `r'
    replace pcexp       = m_pcexp_`a'    in `r'
    replace p_chef_f    = p_chef_f_`a'   in `r'
    replace p_urbain    = p_urbain_`a'   in `r'
    replace p_transfert = p_D_`a'        in `r'
}
export delimited using "$OUTPUT/tables/tab_menages.csv", replace
di ">>> tab_menages.csv sauvegardé"

/* ============================================================
   2. Balance traités / non-traités (EHCVM I, t=0)
   ============================================================ */

di _newline "=== 2. Balance traités / non-traités ==="

use "$TEMP/vague_2018.dta", clear
bysort grappe menage: keep if _n == 1

merge m:1 grappe menage using "$TEMP/traitement_2018.dta", ///
    keepusing(D) nogenerate keep(master match)
replace D = 0 if missing(D)

foreach v in hhsize hage pcexp {
    di "  `v' par D :"
    tabstat `v' [aw = hhweight], by(D) stat(mean sd) format(%9.2f)
}
gen byte chef_f = (hgender == 2)
gen byte urbain = (milieu  == 1)
foreach v in chef_f urbain {
    di "  `v' par D (%) :"
    tabstat `v' [aw = hhweight], by(D) stat(mean n) format(%6.3f)
}

/* Tests tenant compte du plan de sondage */
svyset_ehcvm hhweight
foreach v in hhsize hage pcexp chef_f urbain {
    quietly svy: reg `v' D
    di "  Test svy `v' : diff=" %8.3f _b[D] ///
       "  SE=" %8.3f _se[D] ///
       "  p=" %6.4f (2*ttail(e(df_r), abs(_b[D]/_se[D])))
}

/* Export balance : moyennes pondérées + n non pondéré */
preserve
    gen n_obs = 1
    collapse (mean) hhsize hage pcexp chef_f urbain ///
             (sum)  n_obs [aw=hhweight], by(D)
    export delimited using "$OUTPUT/tables/tab_balance.csv", replace
    di ">>> tab_balance.csv sauvegardé"
restore

/* ============================================================
   3. Incidence N-MODA et AF par vague, milieu, groupe d'âge
   ============================================================ */

di _newline "=== 3. Incidence pauvreté multidimensionnelle ==="

foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear

    di _newline "-- N-MODA `annee' --"
    tabstat pauvre_MODA nb_dep [aw=hhweight], ///
        by(milieu) stat(mean n) format(%6.3f)
    tabstat pauvre_MODA nb_dep [aw=hhweight], ///
        by(groupe_moda) stat(mean n) format(%6.3f)

    di "-- Alkire-Foster `annee' --"
    tabstat pauvre_AF score_dep [aw=hhweight], ///
        by(milieu) stat(mean n) format(%6.3f)
}

/* Export tab_moda_age : H par groupe d'âge et vague */
clear
set obs 6
gen str8 annee       = ""
gen str12 groupe     = ""
gen H_MODA           = .
gen n_obs            = .

local r = 0
foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear
    foreach g in 1 2 3 {
        local ++r
        quietly summarize pauvre_MODA [aw=hhweight] if groupe_moda == `g'
        local hmoda = r(mean)*100
        local nobs  = r(N)
        local lbl   = cond(`g'==1,"0-4 ans",cond(`g'==2,"5-14 ans","15-17 ans"))
        di "  `annee' / `lbl' : H=" %5.1f `hmoda' "% (n=`nobs')"
    }
}

/* ============================================================
   4. Taux de privation par dimension
   ============================================================ */

di _newline "=== 4. Privation par dimension ==="

foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear
    di _newline "-- Dimensions `annee' --"
    foreach dim in assai eau logem nutri sante protect educ {
        quietly summarize dim_`dim' [aw=hhweight]
        di "  `dim' : " %5.1f r(mean)*100 "%"
    }
}

/* Export CSV privations */
foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear
    collapse (mean) dim_assai dim_eau dim_logem dim_nutri ///
                    dim_sante dim_protect dim_educ [aw=hhweight]
    gen annee = `annee'
    if `annee' == 2018 {
        tempfile dim_2018
        save `dim_2018'
    }
    else {
        append using `dim_2018'
        export delimited using "$OUTPUT/tables/tab_prevalence_dim.csv", replace
        di ">>> tab_prevalence_dim.csv sauvegardé"
    }
}

/* ============================================================
   5. Graphiques
   ============================================================ */

di _newline "=== 5. Graphiques ==="

/* ── Fig 1 : Évolution H N-MODA et AF par vague ── */
foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear
    quietly summarize pauvre_MODA [aw=hhweight]
    scalar H_moda_`annee' = r(mean)*100
    quietly summarize pauvre_AF   [aw=hhweight]
    scalar H_af_`annee'   = r(mean)*100
}
clear
set obs 2
gen annee  = 2018 in 1
replace annee  = 2021 in 2
gen H_MODA = H_moda_2018 in 1
replace H_MODA = H_moda_2021 in 2
gen H_AF   = H_af_2018 in 1
replace H_AF   = H_af_2021 in 2

twoway (connected H_MODA annee, lcolor(navy) mcolor(navy) msymbol(circle)  lwidth(medthick)) ///
       (connected H_AF   annee, lcolor(orange) mcolor(orange) msymbol(diamond) lwidth(medthick)), ///
    xlabel(2018 2021) xtitle("Vague EHCVM") ytitle("Incidence H (%)") ///
    ylabel(30(10)80, grid) ///
    legend(order(1 "N-MODA (k=4, 7 dim.)" 2 "Alkire-Foster (k=1/3, 6 ind.)") pos(6) rows(1)) ///
    title("Évolution de la pauvreté multidimensionnelle des enfants") ///
    subtitle("Sénégal, 2018-2019 → 2021-2022") ///
    graphregion(color(white)) plotregion(color(white))
graph export "$OUTPUT/figures/fig_evolution_ipm.pdf", replace
di ">>> fig_evolution_ipm.pdf sauvegardé"

/* ── Fig 2 : Taux de privation par dimension (barres groupées) ── */
foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear
    foreach dim in assai eau logem nutri sante protect educ {
        quietly summarize dim_`dim' [aw=hhweight]
        scalar d_`dim'_`annee' = r(mean)*100
    }
}
clear
set obs 7
gen str10 dim = ""
replace dim = "Assainis." in 1
replace dim = "Eau"       in 2
replace dim = "Logement"  in 3
replace dim = "Nutrition" in 4
replace dim = "Santé"     in 5
replace dim = "Protection" in 6
replace dim = "Éducation"  in 7
gen ordre = _n
gen v2018 = .
gen v2021 = .
local dims assai eau logem nutri sante protect educ
forvalues i = 1/7 {
    local d : word `i' of `dims'
    replace v2018 = d_`d'_2018 in `i'
    replace v2021 = d_`d'_2021 in `i'
}
graph bar v2018 v2021, over(dim, sort(ordre) label(angle(30))) ///
    bar(1, color(navy)) bar(2, color(orange)) ///
    legend(order(1 "EHCVM I (2018-19)" 2 "EHCVM II (2021-22)") pos(6) rows(1)) ///
    ytitle("Taux de privation (%)") ylabel(0(20)100, grid) ///
    title("Prévalence des privations par dimension N-MODA") ///
    graphregion(color(white)) plotregion(color(white))
graph export "$OUTPUT/figures/fig_privations_dim.pdf", replace
di ">>> fig_privations_dim.pdf sauvegardé"

/* ── Fig 3 : Pauvreté par milieu et groupe d'âge (EHCVM I) ── */
use "$TEMP/vague_2018.dta", clear
graph bar pauvre_MODA [aw=hhweight], over(groupe_moda) over(milieu) ///
    bar(1, color(navy)) ///
    ytitle("Incidence N-MODA (H, %)") ylabel(0(0.1)0.8, format(%3.1f) grid) ///
    title("Pauvreté N-MODA par groupe d'âge et milieu (2018-19)") ///
    legend(off) ///
    graphregion(color(white)) plotregion(color(white))
graph export "$OUTPUT/figures/fig_pauvrete_milieu_age.pdf", replace
di ">>> fig_pauvrete_milieu_age.pdf sauvegardé"

/* ── Fig 4 : Distribution nb_dep par statut de traitement ── */
use "$TEMP/vague_2018.dta", clear
merge m:1 grappe menage using "$TEMP/traitement_2018.dta", ///
    keepusing(D) nogenerate keep(master match)
replace D = 0 if missing(D)
label define dl 0 "Non-bénéficiaires" 1 "Bénéficiaires", replace
label values D dl

gen long fw = round(hhweight)
histogram nb_dep [fw=fw], by(D, cols(1) note("") ///
    title("Distribution du nombre de privations (2018-19)")) ///
    fraction width(1) gap(10) ///
    color(ltblue) lcolor(white) ///
    xtitle("Nombre de dimensions en privation (sur 7)") ///
    ytitle("Fraction") ylabel(, format(%4.2f) grid) ///
    graphregion(color(white)) plotregion(color(white))
graph export "$OUTPUT/figures/fig_distrib_nbdep.pdf", replace
di ">>> fig_distrib_nbdep.pdf sauvegardé"

di _newline ">>> 06_stats_desc.do terminé."
di ">>> Sorties dans : $OUTPUT/tables/ et $OUTPUT/figures/"
