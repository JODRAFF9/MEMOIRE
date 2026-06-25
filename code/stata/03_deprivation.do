/* ============================================================
   03_deprivation.do — Indicateurs de pauvrete multidimensionnelle
   Approche 1 : Alkire-Foster (M0 = H x A, k = 1/3)
   Approche 2 : MODA UNICEF (par groupe d'age)
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/* ── Enfants 0-17 ans ──────────────────────────────────────── */

foreach annee in 2018 2021 {
    if `annee' == 2018 local base "$BASE_2018"
    else               local base "$BASE_2021"

    use "`base'/ehcvm_individu_sen`annee'.dta", clear
    keep if age <= 17 & !missing(age)     /* age = Age en annees */
    gen annee = `annee'

    /* Groupes d'age MODA */
    gen groupe_moda = .
    replace groupe_moda = 1 if age <= 4
    replace groupe_moda = 2 if age >= 5  & age <= 14
    replace groupe_moda = 3 if age >= 15 & age <= 17
    label define grp 1 "0-4 ans" 2 "5-14 ans" 3 "15-17 ans"
    label values groupe_moda grp

    /* ─ Alkire-Foster : 6 indicateurs ─ */
    gen d1_educ  = 0    /* non-scolarise / retard scolaire     - a construire */
    gen d2_sante = 0    /* pas de suivi medical                - a construire */
    gen d3_nutri = 0    /* malnutrition anthropometrique       - a construire */
    gen d4_eau   = 0    /* source d'eau non amelioree          - a construire */
    gen d5_assai = 0    /* assainissement non ameliore         - a construire */
    gen d6_habit = 0    /* habitat precaire                    - a construire */

    gen score_dep = (d1_educ + d2_sante + d3_nutri + d4_eau + d5_assai + d6_habit) / 6
    gen pauvre_AF = (score_dep >= $K_SEUIL) if !missing(score_dep)

    quietly summarize pauvre_AF
    scalar H = r(mean)
    quietly summarize score_dep if pauvre_AF == 1
    scalar A = r(mean)
    di "Alkire-Foster `annee' : H=" %6.3f H "  A=" %6.3f A "  M0=" %6.3f H*A

    /* ─ MODA UNICEF ─ */
    gen m_sante = 0
    gen m_nutri = 0
    gen m_educ  = 0
    gen m_eau   = 0
    gen m_assai = 0
    gen m_habit = 0
    gen m_trav  = 0

    gen nb_dep = .
    replace nb_dep = m_sante + m_nutri + m_eau + m_assai + m_habit   if groupe_moda == 1
    replace nb_dep = m_educ  + m_sante + m_eau + m_assai + m_habit   if groupe_moda == 2
    replace nb_dep = m_educ  + m_trav  + m_eau + m_assai + m_habit   if groupe_moda == 3

    gen pauvre_MODA = (nb_dep >= 2) if !missing(nb_dep)

    di "MODA `annee' — prevalence par groupe :"
    tabstat pauvre_MODA, by(groupe_moda) stat(mean n) format(%6.3f)

    save "$TEMP/enfants_dep_`annee'.dta", replace
}
