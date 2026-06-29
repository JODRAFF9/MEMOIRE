/* ============================================================
   08_carte_region.do — Carte régionale N-MODA + pauvreté monétaire
   et diagramme de Venn monétaire/multidimensionnel

   Sorties :
     output/figures/fig_carte_nmoda.pdf      — carte H par région
     output/figures/fig_croisement_pauvrete.pdf — Venn monétaire/MODA
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/* ============================================================
   1. Incidence N-MODA par région (EHCVM I, 2018-2019)
   ============================================================ */

use "$TEMP/vague_2018.dta", clear

/* Moyenne pondérée par région */
svyset_ehcvm hhweight
matrix H_reg = J(14, 2, .)

levelsof region, local(regs)
local i = 0
foreach r of local regs {
    local ++i
    quietly svy, subpop(if region == `r'): mean pauvre_MODA
    matrix H_reg[`i', 1] = `r'
    matrix H_reg[`i', 2] = e(b)[1,1]*100
    local lbl : label (region) `r'
    di "Région `r' (`lbl') : H=" %5.1f e(b)[1,1]*100 "%"
}

/* ── Fig carte : barres horizontales par région (substitut à la carte) ── */
preserve
    clear
    svmat H_reg, names(col)
    rename c1 cod_reg
    rename c2 H_nmoda
    sort H_nmoda
    gen ordre = _n
    gen str30 nom_reg = ""
    /* Correspondance codes → noms régions Sénégal */
    replace nom_reg = "Dakar"        if cod_reg == 1
    replace nom_reg = "Ziguinchor"   if cod_reg == 2
    replace nom_reg = "Diourbel"     if cod_reg == 3
    replace nom_reg = "Saint-Louis"  if cod_reg == 4
    replace nom_reg = "Tambacounda"  if cod_reg == 5
    replace nom_reg = "Kaolack"      if cod_reg == 6
    replace nom_reg = "Thiès"        if cod_reg == 7
    replace nom_reg = "Louga"        if cod_reg == 8
    replace nom_reg = "Fatick"       if cod_reg == 9
    replace nom_reg = "Kolda"        if cod_reg == 10
    replace nom_reg = "Matam"        if cod_reg == 11
    replace nom_reg = "Kaffrine"     if cod_reg == 12
    replace nom_reg = "Kédougou"     if cod_reg == 13
    replace nom_reg = "Sédhiou"      if cod_reg == 14

    /* Labels y-axis depuis la variable */
    local ylab_str ""
    forvalues i = 1/14 {
        local lbl = nom_reg[`i']
        local ylab_str `"`ylab_str' `i' "`lbl'""'
    }

    twoway (bar H_nmoda ordre, horizontal barwidth(0.6) ///
            color("31 78 121") lcolor(white)), ///
        ylab(`ylab_str', angle(0) noticks labsize(small)) ///
        yscale(range(0.5 14.5)) ///
        xtitle("Incidence N-MODA H (%)") ytitle("") ///
        xlabel(0(10)100, grid) ///
        xline(58.9, lcolor("230 126 34") lpattern(dash) lwidth(medthick)) ///
        note("Ligne pointillée : moyenne nationale (58,9 %). EHCVM I (2018-2019)." ///
             "Estimations pondérées (plan de sondage stratifié).", size(vsmall)) ///
        title("Incidence N-MODA par région --- Sénégal, 2018-2019") ///
        graphregion(color(white)) plotregion(color(white))
    graph export "$OUTPUT/figures/fig_carte_nmoda.pdf", replace
    di ">>> fig_carte_nmoda.pdf sauvegardé"
restore

/* ============================================================
   2. Croisement pauvreté monétaire / N-MODA (EHCVM I)
   ============================================================ */

use "$TEMP/vague_2018.dta", clear

/* Seuil monétaire officiel ANSD 2018 : 276 305 FCFA/an */
gen byte pauvre_mon = (pcexp < 276305) if !missing(pcexp)
label var pauvre_mon "Pauvre monétaire (seuil ANSD 2018)"

/* Tableau croisé pondéré */
di _newline "=== Croisement pauvreté monétaire / N-MODA ==="
tab pauvre_mon pauvre_MODA [aw=hhweight], row col nofreq

/* Calcul des quatre cellules */
svyset_ehcvm hhweight
foreach pm in 0 1 {
    foreach md in 0 1 {
        quietly svy: mean pauvre_mon if pauvre_MODA == `md'
        /* prop conjointe */
        quietly count if pauvre_mon == `pm' & pauvre_MODA == `md'
        local n`pm'`md' = r(N)
    }
}

/* Proportions pondérées */
gen byte cat4 = .
replace cat4 = 1 if pauvre_mon == 0 & pauvre_MODA == 0  /* non pauvres */
replace cat4 = 2 if pauvre_mon == 1 & pauvre_MODA == 0  /* pauvres monet. seuls */
replace cat4 = 3 if pauvre_mon == 0 & pauvre_MODA == 1  /* pauvres multidim. seuls */
replace cat4 = 4 if pauvre_mon == 1 & pauvre_MODA == 1  /* doublement pauvres */
label define cat4l 1 "Non pauvres" 2 "Pauvres monet. seuls" ///
                   3 "Pauvres MODA seuls" 4 "Doublement pauvres"
label values cat4 cat4l

tabstat cat4 [aw=hhweight], by(cat4) stat(count) format(%9.0f)

quietly summarize pauvre_mon [aw=hhweight]
scalar p_mon = r(mean)*100
quietly summarize pauvre_MODA [aw=hhweight]
scalar p_moda = r(mean)*100

di _newline "Pauvreté monétaire : " %5.1f p_mon "%"
di "Pauvreté N-MODA    : " %5.1f p_moda "%"

/* ── Fig Venn simplifié : diagramme à barres empilées ── */
/* Proportions par catégorie calculées sans collapse pour éviter
   la perte des variables de stratification */
preserve
    gen long fw = round(hhweight)
    /* 4 catégories pour graphique */
    gen byte nn  = (pauvre_mon == 0 & pauvre_MODA == 0)  /* 1 */
    gen byte pm_only = (pauvre_mon == 1 & pauvre_MODA == 0)  /* 2 */
    gen byte md_only = (pauvre_mon == 0 & pauvre_MODA == 1)  /* 3 */
    gen byte both    = (pauvre_mon == 1 & pauvre_MODA == 1)  /* 4 */

    foreach v in nn pm_only md_only both {
        quietly summarize `v' [aw=hhweight]
        scalar p_`v' = r(mean)*100
        di "`v' : " %5.1f r(mean)*100 "%"
    }

    clear
    set obs 4
    gen str30 cat = ""
    replace cat = "Non pauvres (deux approches)" in 1
    replace cat = "Pauvres monétaires uniquement" in 2
    replace cat = "Pauvres N-MODA uniquement"     in 3
    replace cat = "Doublement pauvres"             in 4
    gen pct = .
    replace pct = p_nn      in 1
    replace pct = p_pm_only in 2
    replace pct = p_md_only in 3
    replace pct = p_both    in 4
    gen ordre = 4 - _n + 1
    sort ordre

    local ylab_str ""
    forvalues i = 1/4 {
        local lbl = cat[`i']
        local ylab_str `"`ylab_str' `i' "`lbl'""'
    }

    twoway (bar pct ordre, horizontal barwidth(0.65) ///
            color("168 199 232" "41 128 185" "230 126 34" "31 78 121")), ///
        ylab(`ylab_str', angle(0) noticks labsize(small)) ///
        yscale(range(0.5 4.5)) ///
        xtitle("Part des enfants 0--17 ans (%)") ytitle("") ///
        xlabel(0(10)60, grid) ///
        title("Croisement pauvreté monétaire et N-MODA") ///
        subtitle("Sénégal, EHCVM I (2018-2019) — enfants 0--17 ans") ///
        note("Estimations pondérées (plan de sondage stratifié).", size(vsmall)) ///
        legend(off) ///
        graphregion(color(white)) plotregion(color(white))
    graph export "$OUTPUT/figures/fig_croisement_pauvrete.pdf", replace
    di ">>> fig_croisement_pauvrete.pdf sauvegardé"
restore

di _newline ">>> 08_carte_region.do terminé."
