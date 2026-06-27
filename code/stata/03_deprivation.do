/* ============================================================
   03_deprivation.do — Indicateurs de pauvrete multidimensionnelle

   Approche 1 : Alkire-Foster (6 indicateurs, poids egaux, k=1/3)
   Approche 2 : N-MODA Senegal (7 dimensions, k=4)

   Produit : $TEMP/enfants_dep_ANNEE.dta pour annee in {2018, 2021}
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/* ============================================================
   Sous-programme : indicateurs menage (niveau logement)
   Entree : base individus deja chargee (merge m:1 sur grappe menage)
   ============================================================ */

program define indic_menage
    /*
       Fusionne ehcvm_menage et s11_me pour construire :
         m_toilet, m_eau_source, m_ordures,
         m_partag_toi, m_eau_temps, m_surpeup, m_combust
       Requiert : grappe menage hhsize deja presents
    */
    args annee

    if `annee' == 2018 {
        local v_partag "s11q56"
        local v_tps_ss "s11q29a"
        local v_comb   "s11q53"
    }
    else {
        local v_partag "s11q55"
        local v_tps_ss "s11q28a"
        local v_comb   "s11q52"
    }
    local comb_vars "`v_comb'__1 `v_comb'__2 `v_comb'__3 `v_comb'__7"

    /* Binaires harmonises depuis ehcvm_menage */
    merge m:1 grappe menage using ///
        "$BASE_`annee'/ehcvm_menage_sen`annee'.dta", ///
        keepusing(toilet eauboi_ss eauboi_sp ordure) ///
        nogenerate keep(master match)

    gen byte m_toilet    = (toilet == 0)          if !missing(toilet)
    gen byte m_eau_source = (eauboi_ss == 0 | eauboi_sp == 0) ///
        if !missing(eauboi_ss) | !missing(eauboi_sp)
    gen byte m_ordures   = (ordure == 0)           if !missing(ordure)

    /* Variables brutes depuis s11_me */
    preserve
        use "$BASE_`annee'/s11_me_sen`annee'.dta", clear
        keep grappe menage s11q02 `v_partag' `v_tps_ss' `comb_vars'
        tempfile s11_temp
        save `s11_temp'
    restore
    merge m:1 grappe menage using `s11_temp', nogenerate keep(master match)

    gen byte m_partag_toi = (`v_partag' == 1)       if !missing(`v_partag')
    replace  m_partag_toi = 0                        if missing(m_partag_toi)
    gen byte m_eau_temps  = (`v_tps_ss' > 30 & !missing(`v_tps_ss'))
    replace  m_eau_temps  = 0                        if missing(`v_tps_ss')
    rename s11q02 nb_pieces

    /* Surpeuplement : calcule apres merge welfare (hhsize deja present) */
    gen byte m_surpeup = (hhsize / nb_pieces > 3) ///
        if !missing(nb_pieces) & nb_pieces > 0 & !missing(hhsize)
    replace  m_surpeup = 0 if missing(m_surpeup)

    /* Combustible solide */
    gen byte m_combust = 0
    foreach v of varlist `comb_vars' {
        replace m_combust = 1 if `v' >= 1 & !missing(`v')
    }
end

/* ============================================================
   Sous-programme : acte de naissance (s01_me)
   ============================================================ */

program define indic_acte_nais
    args annee

    preserve
        use "$BASE_`annee'/s01_me_sen`annee'.dta", clear
        if `annee' == 2018 rename s01q00a numind
        else               rename membres__id numind
        keep grappe menage numind s01q05
        gen byte m_acte_nais = (s01q05 == 2) if !missing(s01q05)
        tempfile s01_temp
        save `s01_temp'
    restore

    merge m:1 grappe menage numind using `s01_temp', ///
        keepusing(m_acte_nais) nogenerate keep(master match)
    replace m_acte_nais = 0 if missing(m_acte_nais)
end

/* ============================================================
   Sous-programme : agregation N-MODA et Alkire-Foster
   ============================================================ */

program define agreger_ipm
    args annee

    /* Groupes d'age MODA */
    gen byte groupe_moda = .
    replace  groupe_moda = 1 if age <= 4
    replace  groupe_moda = 2 if age >= 5  & age <= 14
    replace  groupe_moda = 3 if age >= 15 & age <= 17
    label define grp 1 "0-4 ans" 2 "5-14 ans" 3 "15-17 ans", replace
    label values groupe_moda grp

    /* ── Dimensions N-MODA (union intra-dimension) ── */

    gen byte dim_assai  = (m_toilet == 1 | m_partag_toi == 1)
    gen byte dim_eau    = (m_eau_source == 1 | m_eau_temps == 1)
    gen byte dim_logem  = (m_ordures == 1 | m_surpeup == 1)
    gen byte dim_nutri  = 0   /* s14/s20 non harmonises — placeholder */
    gen byte dim_sante  = (m_combust == 1)
    gen byte dim_educ   = 0
    replace  dim_educ   = m_scol  if groupe_moda == 2
    replace  dim_educ   = (m_alfab == 1 | m_neet == 1) if groupe_moda == 3
    gen byte dim_protect = 0
    replace  dim_protect = (m_acte_nais == 1 | m_parents == 1) ///
        if groupe_moda == 1
    replace  dim_protect = (m_acte_nais == 1 | m_trav_enf == 1 | m_parents == 1) ///
        if groupe_moda == 2
    replace  dim_protect = (m_parents == 1) if groupe_moda == 3

    gen byte nb_dep    = dim_assai + dim_eau + dim_logem + dim_nutri + ///
                         dim_sante + dim_protect + dim_educ
    gen byte pauvre_MODA = (nb_dep >= $K_MODA) if !missing(nb_dep)

    /* ── Indicateurs Alkire-Foster ── */

    gen byte d1_educ  = 0
    replace  d1_educ  = 1 if age >= 6 & (scol == 0 | missing(scol))
    gen byte d2_sante = 0
    replace  d2_sante = 1 if mal30j == 1 & con30j == 0 ///
        & !missing(mal30j) & !missing(con30j)
    gen byte d3_nutri = 0
    replace  d3_nutri = 1 if age <= 4 & mal30j == 1 & !missing(mal30j)
    gen byte d4_eau   = m_eau_source
    gen byte d5_assai = m_toilet
    gen byte d6_habit = dim_logem

    gen score_dep = (d1_educ + d2_sante + d3_nutri + ///
                     d4_eau  + d5_assai + d6_habit) / 6
    gen byte pauvre_AF = (score_dep >= $K_SEUIL) if !missing(score_dep)

    /* ── Affichage ── */

    di _newline "=== N-MODA `annee' (k=$K_MODA, 7 dimensions) ==="
    quietly summarize pauvre_MODA
    di "  H = " %6.3f r(mean)*100 "%"
    di "  Privation par dimension :"
    foreach dim in assai eau logem nutri sante protect educ {
        taux_dep dim_`dim' "`dim'"
    }
    tabstat pauvre_MODA nb_dep, by(groupe_moda) stat(mean n) format(%6.3f)

    di _newline "=== Alkire-Foster `annee' (k=$K_SEUIL, 6 indicateurs) ==="
    quietly summarize pauvre_AF
    scalar H_af = r(mean)
    quietly summarize score_dep if pauvre_AF == 1
    scalar A_af = r(mean)
    di "  H=" %6.3f H_af "  A=" %6.3f A_af "  M0=" %6.3f H_af * A_af
end

/* ============================================================
   Boucle principale sur les deux annees
   ============================================================ */

foreach annee in 2018 2021 {

    if `annee' == 2018 local base "$BASE_2018"
    else               local base "$BASE_2021"

    /* 1. Individus 0-17 ans */
    use "`base'/ehcvm_individu_sen`annee'.dta", clear
    keep if age >= 0 & age <= 17 & !missing(age)
    gen annee = `annee'
    di _newline ">>> Enfants `annee' : " _N

    /* 2. Welfare (hhsize, pcexp, covariables PSM) */
    merge m:1 grappe menage using ///
        "`base'/ehcvm_welfare_sen`annee'.dta", ///
        keepusing(hhsize pcexp region milieu hgender hage heduc hmstat) ///
        nogenerate keep(master match)

    /* 3. Indicateurs menage */
    indic_menage `annee'

    /* 4. Acte de naissance */
    indic_acte_nais `annee'

    /* 5. Indicateurs individuels */

    /* Non-scolarise (5-14 ans) */
    gen byte m_scol = 0
    replace  m_scol = 1 if age >= 5 & age <= 14 & (scol == 0 | missing(scol))

    /* Travail des enfants (5-14 ans) */
    gen byte m_trav_enf = 0
    replace  m_trav_enf = 1 if age >= 5 & age <= 14 & ///
        (activ7j == 1 | activ7j == 2) & !missing(activ7j)

    /* Separation parentale */
    gen byte m_parents = (lien > 3) if !missing(lien)
    replace  m_parents = 0 if missing(m_parents)

    /* Illettrisme (15-17 ans) */
    gen byte m_alfab = 0
    if `annee' == 2018 {
        replace m_alfab = 1 if age >= 15 & alfab == 0 & !missing(alfab)
    }
    else {
        capture confirm variable alfa
        if !_rc replace m_alfab = 1 if age >= 15 & alfa == 0 & !missing(alfa)
    }

    /* NEET (15-17 ans) */
    gen byte m_neet = 0
    replace  m_neet = 1 if age >= 15 & ///
        (scol == 0 | missing(scol)) & (activ7j == 0 | missing(activ7j))

    /* Acte de naissance non pertinent > 14 ans */
    replace m_acte_nais = 0 if age > 14

    /* 6. Agregation IPM */
    agreger_ipm `annee'

    /* 7. Sauvegarde */
    save "$TEMP/enfants_dep_`annee'.dta", replace
    di _newline ">>> Sauvegarde : enfants_dep_`annee'.dta (" _N " obs)"
}
