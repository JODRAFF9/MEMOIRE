/* ============================================================
   03_deprivation.do — Indicateurs de pauvrete multidimensionnelle

   Approche 1 : Alkire-Foster (M0 = H x A, k = 1/3, 6 indicateurs)
   Approche 2 : N-MODA Senegal (ANSD/UNICEF 2024)
               7 dimensions, k = 4, approche union intra-dimension

   Variables EHCVM (verifiees dans codebooks 2018 et 2021) :
     ehcvm_individu : age, scol, mal30j, con30j, activ7j, lien
                      alfab (2018) / alfa (2021)
     ehcvm_menage   : eauboi_ss, eauboi_sp (0=non ameliore)
                      toilet (0=non sain), ordure (0=non sain)
     s11_me         : s11q02 (nb pieces)
                      s11q29a/s11q28a (tps eau saison seche, min)
                      s11q56/s11q55 (partage toilettes, 1=Oui)
                      s11q53__1..7 (2018) / s11q52__1..7 (2021) (combustible)
     s01_me         : s01q05 (acte naissance : 1=Oui 2=Non)
                      s01q00a (2018) / membres__id (2021) = cle individuelle
   ============================================================ */


/* ============================================================
   BOUCLE SUR LES DEUX ANNEES
   ============================================================ */

foreach annee in 2018 2021 {

    if `annee' == 2018 local base "$BASE_2018"
    else               local base "$BASE_2021"

    /* ----------------------------------------------------------
       1. Individus 0-17 ans
    ---------------------------------------------------------- */

    use "`base'/ehcvm_individu_sen`annee'.dta", clear
    keep if age >= 0 & age <= 17 & !missing(age)
    gen annee = `annee'

    /* Groupes d'age MODA */
    gen byte groupe_moda = .
    replace  groupe_moda = 1 if age <= 4
    replace  groupe_moda = 2 if age >= 5  & age <= 14
    replace  groupe_moda = 3 if age >= 15 & age <= 17
    label define grp 1 "0-4 ans" 2 "5-14 ans" 3 "15-17 ans", replace
    label values groupe_moda grp

    di _newline ">>> Enfants `annee' : " _N

    /* ----------------------------------------------------------
       2. Indicateurs niveau menage — Dimensions 1 a 5
          Fusion ehcvm_menage (binaires harmonises)
    ---------------------------------------------------------- */

    merge m:1 grappe menage using "`base'/ehcvm_menage_sen`annee'.dta", ///
        keepusing(toilet eauboi_ss eauboi_sp ordure) ///
        nogenerate keep(master match)

    /* Dim 1 — ASSAINISSEMENT : toilet binaire (0=non sain) */
    gen byte m_toilet = (toilet == 0) if !missing(toilet)

    /* Dim 2 — EAU : eauboi_ss/sp binaires (0=non ameliore) */
    gen byte m_eau_source = (eauboi_ss == 0 | eauboi_sp == 0) ///
        if !missing(eauboi_ss) | !missing(eauboi_sp)

    /* Dim 3 — LOGEMENT : ordure binaire (0=non sain) */
    gen byte m_ordures = (ordure == 0) if !missing(ordure)

    /* ----------------------------------------------------------
       3. Indicateurs niveau menage — Fichier brut s11_me
    ---------------------------------------------------------- */

    /* Noms de variables qui different entre 2018 et 2021 */
    if `annee' == 2018 {
        local v_partag  "s11q56"    /* partage toilettes (1=Oui) */
        local v_tps_ss  "s11q29a"   /* temps eau saison seche (min) */
        local v_comb    "s11q53"    /* prefixe combustible */
    }
    else {
        local v_partag  "s11q55"
        local v_tps_ss  "s11q28a"
        local v_comb    "s11q52"
    }

    /* Variables de combustible a recuperer */
    local comb_vars "`v_comb'__1 `v_comb'__2 `v_comb'__3 `v_comb'__7"

    preserve
        use "`base'/s11_me_sen`annee'.dta", clear
        keep grappe menage s11q02 `v_partag' `v_tps_ss' `comb_vars'
        tempfile s11_temp
        save `s11_temp'
    restore

    merge m:1 grappe menage using `s11_temp', nogenerate keep(master match)

    /* Dim 1 — Partage toilettes */
    gen byte m_partag_toi = (`v_partag' == 1) if !missing(`v_partag')
    replace  m_partag_toi = 0 if missing(m_partag_toi)

    /* Dim 2 — Temps acces eau > 30 min */
    gen byte m_eau_temps = (`v_tps_ss' > 30 & !missing(`v_tps_ss'))
    replace  m_eau_temps = 0 if missing(`v_tps_ss')

    /* Dim 3 — Surpeuplement > 3 personnes par piece */
    /* hhsize depuis welfare — joint plus bas ; s11q02 = nb pieces */
    gen byte m_surpeup = .   /* sera calcule apres merge welfare */
    rename s11q02 nb_pieces

    /* Dim 5 — Combustible solide (bois, charbon, dechets animaux) */
    /* Codes 1/2/3 = 1er/2em/3em choix ; on prend >= 1 = mentionne */
    gen byte m_combust = 0
    foreach v of varlist `comb_vars' {
        replace m_combust = 1 if `v' >= 1 & !missing(`v')
    }

    /* ----------------------------------------------------------
       4. Welfare : hhsize pour surpeuplement + pcexp
    ---------------------------------------------------------- */

    merge m:1 grappe menage using ///
        "`base'/ehcvm_welfare_sen`annee'.dta", ///
        keepusing(hhsize pcexp region milieu ///
                  hgender hage heduc hmstat) ///
        nogenerate keep(master match)

    replace m_surpeup = (hhsize / nb_pieces > 3) ///
        if !missing(nb_pieces) & nb_pieces > 0 & !missing(hhsize)
    replace m_surpeup = 0 if missing(m_surpeup)

    /* ----------------------------------------------------------
       5. Acte de naissance depuis s01_me
          Cle individuelle : s01q00a (2018) / membres__id (2021)
    ---------------------------------------------------------- */

    preserve
        use "`base'/s01_me_sen`annee'.dta", clear
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

    /* ----------------------------------------------------------
       6. Indicateurs individuels — Dim 6 (Protection) et 7 (Education)
    ---------------------------------------------------------- */

    /* Dim 6 — Protection de l'enfant */

    /* Acte de naissance (0-14 ans) — deja calcule */
    replace m_acte_nais = 0 if age > 14

    /* Travail des enfants (5-14 ans) : activ7j = 1 (occupe) ou 2 (chomeur) */
    gen byte m_trav_enf = 0
    replace  m_trav_enf = 1 if age >= 5 & age <= 14 & ///
        (activ7j == 1 | activ7j == 2) & !missing(activ7j)

    /* Separation parentale : lien > 3 => pas fils/fille du CM */
    gen byte m_parents = (lien > 3) if !missing(lien)
    replace  m_parents = 0 if missing(m_parents)

    /* Dim 7 — Education */

    /* Non-scolarise (5-14 ans) */
    gen byte m_scol = 0
    replace  m_scol = 1 if age >= 5 & age <= 14 & ///
        (scol == 0 | missing(scol))

    /* Illettrisme (15-17 ans) */
    gen byte m_alfab = 0
    if `annee' == 2018 {
        replace m_alfab = 1 if age >= 15 & alfab == 0 & !missing(alfab)
    }
    else {
        /* 2021 : variable nommee "alfa" */
        capture confirm variable alfa
        if !_rc replace m_alfab = 1 if age >= 15 & alfa == 0 & !missing(alfa)
    }

    /* NEET (15-17 ans) : ni scolarise ni occupe */
    gen byte m_neet = 0
    replace  m_neet = 1 if age >= 15 & ///
        (scol == 0 | missing(scol)) & ///
        (activ7j == 0 | missing(activ7j))

    /* ----------------------------------------------------------
       7. Agregation par dimension (approche union intra-dimension)
    ---------------------------------------------------------- */

    /* Dim 4 NUTRITION : non disponible en variable harmonisee */
    /* A calculer depuis s14_me et s20_me — code a 0 provisoirement */
    gen byte m_diversite = 0
    gen byte m_securite  = 0

    /* Dim 5 SANTE : acces_sante non disponible (module communaute) */
    gen byte m_acces_sante = 0

    /* Union intra-dimension */
    gen byte dim_assai   = (m_toilet == 1 | m_partag_toi == 1)
    gen byte dim_eau     = (m_eau_source == 1 | m_eau_temps == 1)
    gen byte dim_logem   = (m_ordures == 1 | m_surpeup == 1)
    gen byte dim_nutri   = (m_diversite == 1 | m_securite == 1)
    gen byte dim_sante   = (m_combust == 1 | m_acces_sante == 1)

    /* Protection (varie selon groupe d'age) */
    gen byte dim_protect = 0
    replace  dim_protect = (m_acte_nais == 1 | m_parents == 1) ///
        if groupe_moda == 1
    replace  dim_protect = (m_acte_nais == 1 | m_trav_enf == 1 | m_parents == 1) ///
        if groupe_moda == 2
    replace  dim_protect = (m_parents == 1) if groupe_moda == 3

    /* Education (varie selon groupe d'age) */
    gen byte dim_educ = 0
    replace  dim_educ = m_scol if groupe_moda == 2
    replace  dim_educ = (m_alfab == 1 | m_neet == 1) if groupe_moda == 3

    /* ----------------------------------------------------------
       8. Indicateurs N-MODA (k = 4)
    ---------------------------------------------------------- */

    gen byte nb_dep = dim_assai + dim_eau + dim_logem + dim_nutri + ///
                      dim_sante + dim_protect + dim_educ

    gen byte pauvre_MODA = (nb_dep >= $K_MODA) if !missing(nb_dep)

    di _newline "=== N-MODA `annee' (k=4, 7 dimensions) ==="
    di "[Note] dim_nutri = 0 (s14_me/s20_me non harmonises)"
    quietly summarize pauvre_MODA
    di "  H (incidence)  = " %6.3f r(mean)*100 "%"
    quietly summarize nb_dep if pauvre_MODA == 1
    di "  A (intensite)  = " %6.3f r(mean)/7

    di "  Privation par dimension :"
    foreach dim in assai eau logem nutri sante protect educ {
        taux_dep dim_`dim' "`dim'"
    }

    di _newline "  Prevalence par groupe d'age :"
    tabstat pauvre_MODA nb_dep, by(groupe_moda) stat(mean n) format(%6.3f)

    /* ----------------------------------------------------------
       9. Alkire-Foster (conserve pour comparaison)
          6 indicateurs, poids egaux 1/6, k = 1/3
    ---------------------------------------------------------- */

    gen byte d1_educ  = 0
    replace  d1_educ  = 1 if age >= 6 & (scol == 0 | missing(scol))

    gen byte d2_sante = 0
    replace  d2_sante = 1 if mal30j == 1 & con30j == 0 & ///
        !missing(mal30j) & !missing(con30j)

    gen byte d3_nutri = 0
    replace  d3_nutri = 1 if age <= 4 & mal30j == 1 & !missing(mal30j)

    gen byte d4_eau   = m_eau_source
    gen byte d5_assai = m_toilet
    gen byte d6_habit = dim_logem

    gen score_dep = (d1_educ + d2_sante + d3_nutri + ///
                     d4_eau  + d5_assai + d6_habit) / 6

    gen byte pauvre_AF = (score_dep >= $K_SEUIL) if !missing(score_dep)

    di _newline "=== Alkire-Foster `annee' (k=1/3, 6 indicateurs) ==="
    quietly summarize pauvre_AF
    scalar H_af = r(mean)
    quietly summarize score_dep if pauvre_AF == 1
    scalar A_af = r(mean)
    di "  H=" %6.3f H_af "  A=" %6.3f A_af "  M0=" %6.3f H_af * A_af

    /* ----------------------------------------------------------
       10. Sauvegarde
    ---------------------------------------------------------- */

    save "$TEMP/enfants_dep_`annee'.dta", replace
    di _newline ">>> Sauvegarde : enfants_dep_`annee'.dta (" _N " obs)"

} /* fin boucle annees */
