/* ============================================================
   03_deprivation.do — Indicateurs de pauvrete multidimensionnelle

   Approche 1 : Alkire-Foster (6 indicateurs, poids egaux, k=1/3)
   Approche 2 : N-MODA Senegal (7 dimensions, k=4)

   Produit : $TEMP/enfants_dep_ANNEE.dta pour annee in {2018, 2021}
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/*Annexe I : Sélection des paramètres pour l'analyse de
la pauvreté multidimensionnelle de l'enfant en
utilisant l'EHCVM 2018/19

Tableau 1. Liste des paramètres (dimensions, indicateurs et groupe d'âge)
de l'analyse de la pauvreté multidimensionnelle de l'enfant
Groupe d'âge
0-4
5-14
15-17
Dimensions Indicateurs Définition

1/Assainissement :
	Type de sanitaire (2018: s11q55;)
		Enfant vivant dans un ménage utilisant des toilettes
		non améliorées :
		7. Latrines SANPLAT;
		8. Latrines dallées simples;
		9. Fosse rudimentaire;
		10. Toilettes publiques;
		11. Aucune toilette;
		12. Autre

	Partage des toilettes (2018: s11q56;)
		Enfant vivant dans un ménage partageant les toilettes
		avec d'autres ménages

2/Eau :
	Source d'eau pour boire (2018: s11q27a et s11q27b; )
		Enfant vivant dans un ménage utilisant une source
		d'eau non adéquate en saison des pluies et ne la
		traitant pas de manière adéquate:
		- 5 Puits ouvert dans la cour/Concession;
		- 6 Puits ouvert ailleurs;
		- 12 Source non aménagée;
		- 13 Fleuve/Rivière/Lac/Barrage;
		- 16 Vendeur am-bulant;
		- 17 Autre (à préciser)
		OU en saison sèche:
		- 5 Puits ouvert dans la cour/Concession;
		- 6 Puits ouvert ailleurs;
		- 12 Source non aménagée;
		- 13 Fleuve/Rivière/Lac/Barrage;
		- 16 Vendeur ambulant;
		- 17 Autre (à préciser)
		Traitement non adéquat de l'eau:filtrer à travers linge;
		laisser reposer ;
		autre

	Temps pour aller chercher l'eau (2018: s11q31a ou s11q29a supérieur à 30; ):
		Enfant vivant dans un ménage ou le temps pour aller
		chercher l'eau excède 30mins en saison des pluies OU
		en saison sèche


3/Logement:
	Débarras des ordures ménagères (2018:s11q54; )
		Enfant vivant dans un ménage utilisant un mode inadéquat de débarras des ordures menagères:
			3 brulées ;
			5 dépotoir sauvage;
			6 autre

	Surpeuplement (hhsize/s11q02 supérieur à 3)
		Enfant vivant dans un ménage ou dorment plus de 3
		personnes par pièces

4/Nutrition :
	Diversité des repas
		Enfant vivant dans un ménage n'ayant pas consommé
		d'aliments des 4 groupes alimentaires (carbohydrates,
		protéines, fruits/légumes, graisses) une fois par jour
		sur la dernière semaine

	Sécurité alimentaire/ Non-accès à la nourri-ture pour se nourrir à sa faim
		Enfant vivant dans un ménage qui n'avait plus de nourriture, OU
		- avec un des membres ayant
		- dû sauter un repas,
		- mangé moins que ce qu'il pensait nécessaire,
		- eu faim mais sans avoir mangé
		- passé toute une journée sans manger
		- au moins une fois du-rant les 12 derniers mois par manque d'ar-gent ou d'autres ressources

5/Santé:
	Type de combustibles utilisés pour cuisiner
		Enfant vivant dans un ménage ou utilisant du combus-
		tible solide pour cuisiner : bois ramassé, bois acheté,
		charbon de bois, déchets animaux, autres

	Accès à une structure de santé: l'hôpital ou autre centre de santé
		Enfant vivant dans une localité d'où il/elle ne peut ac-
		céder à pied à une structure de santé

6/Protection de l'enfant:
	Disponibilité de l'acte de naissance
		Enfant n'ayant pas d'acte de naissance

	Travail des enfants (économique et domestique)
		Enfant effectuant travail économique ou do-mestique
		pendant au moins 1h

	Enfant vivant avec ses deux parents
		Enfant ne vivant pas avec ses deux parents biologique

7/Éducation:
	Capacité de lecture et d'écriture
		Enfant en capacité de lire et d'écrire

	Fréquentation scolaire
		Enfant n'étant pas à l'école

	Jeunes sans emploi ne poursuivant pas d'études et ne suivant pas de formation (NEET)
		Enfant sans emploi ne poursuivant pas d'études et ne
		suivant pas de formation (NEET)
*/

/* ============================================================
   Sous-programme : indicateurs menage (niveau logement)
   Entree : base individus deja chargee (merge m:1 sur grappe menage)
   ============================================================ */

capture program drop indic_menage
program define indic_menage
    /*
       Fusionne ehcvm_menage et s11_me pour construire :
         m_toilet, m_eau_source, m_ordures,
         m_partag_toi, m_eau_temps, m_surpeup, m_combust
       Requiert : grappe menage hhsize deja presents
    */
    args annee

    if `annee' == 2018 {
        local base "$BASE_2018"
        local v_partag "s11q56"
        local v_tps_ss "s11q29a"
        local v_tps_sp "s11q31a"
        local v_comb   "s11q53"
    }
    else {
        local base "$BASE_2021"
        local v_partag "s11q55"
        local v_tps_ss "s11q28a"
        local v_tps_sp "s11q30a"
        local v_comb   "s11q52"
    }
    local comb_vars "`v_comb'__1 `v_comb'__2 `v_comb'__3 `v_comb'__7"

    /* Binaires harmonises depuis ehcvm_menage
       NB : ehcvm_menage n'a pas grappe/menage, seulement hhid
            2018 : hhid = grappe * 1000 + menage  (range 1001-598012)
            2021 : hhid = grappe * 100  + menage  (range 201-59812)  */
    capture drop hhid
    if `annee' == 2018 gen long hhid = grappe * 1000 + menage
    else               gen long hhid = grappe * 100  + menage
    merge m:1 hhid using ///
        "`base'/ehcvm_menage_sen`annee'.dta", ///
        keepusing(toilet eauboi_ss eauboi_sp ordure) ///
        nogenerate keep(master match)

    /* [Dim 1/7 : Assainissement] Indicateur 1 — Type de sanitaire
       (toilet, harmonise depuis s11q55 en 2018 / s11q54 en 2021) */
    gen byte m_toilet    = (toilet == 0)          if !missing(toilet)

    /* [Dim 2/7 : Eau] Indicateur 1 — Source d'eau de boisson
       (eauboi_ss/eauboi_sp, harmonise depuis s11q27a et s11q27b) */
    gen byte m_eau_source = (eauboi_ss == 0 | eauboi_sp == 0) ///
        if !missing(eauboi_ss) | !missing(eauboi_sp)

    /* [Dim 3/7 : Logement] Indicateur 1 — Debarras des ordures menageres
       (ordure, harmonise depuis s11q54) */
    gen byte m_ordures   = (ordure == 0)           if !missing(ordure)

    /* Variables brutes depuis s11_me */
    preserve
        use "`base'/s11_me_sen`annee'.dta", clear
        keep grappe menage s11q02 `v_partag' `v_tps_ss' `v_tps_sp' `comb_vars'
        tempfile s11_temp
        save `s11_temp'
    restore
    merge m:1 grappe menage using `s11_temp', nogenerate keep(master match)

    /* [Dim 1/7 : Assainissement] Indicateur 2 — Partage des toilettes
       (2018: s11q56 ; 2021: s11q55) */
    gen byte m_partag_toi = (`v_partag' == 1)       if !missing(`v_partag')
    replace  m_partag_toi = 0                        if missing(m_partag_toi)

    /* [Dim 2/7 : Eau] Indicateur 2 — Temps d'acces a l'eau
       Prive si > 30 min en saison seche OU en saison des pluies
       (2018: s11q29a / s11q31a ; 2021: s11q28a / s11q30a) */
    gen byte m_eau_temps  = (`v_tps_ss' > 30 & !missing(`v_tps_ss')) | ///
                             (`v_tps_sp' > 30 & !missing(`v_tps_sp'))
    replace  m_eau_temps  = 0 if missing(`v_tps_ss') & missing(`v_tps_sp')
    rename s11q02 nb_pieces

    /* [Dim 3/7 : Logement] Indicateur 2 — Surpeuplement
       Prive si hhsize/nb_pieces (s11q02) > 3 (calcule apres merge welfare) */
    gen byte m_surpeup = (hhsize / nb_pieces > 3) ///
        if !missing(nb_pieces) & nb_pieces > 0 & !missing(hhsize)
    replace  m_surpeup = 0 if missing(m_surpeup)

    /* [Dim 5/7 : Sante] Indicateur 1 — Combustible solide pour cuisiner
       (2018: s11q53 ; 2021: s11q52, modalites bois ramasse/achete/
       charbon/dechets animaux) */
    gen byte m_combust = 0
    foreach v of varlist `comb_vars' {
        replace m_combust = 1 if `v' >= 1 & !missing(`v')
    }

    /* [Dim 5/7 : Sante] Indicateur 2 — Acces a une structure de sante
       (module communautaire s02_co). Enfant prive si, dans sa localite
       (grappe), aucun des 3 services de sante (Hopital public/prive=5,
       Autre centre de sante public=6, Cabinet medical/Clinique privee=7)
       n'est accessible a pied (s02q02 == 1 "Pieds" comme principal moyen
       de locomotion).
       2018 : long format avec identifiant de service s02q00.
       2021 : long format sans identifiant explicite, mais 26 lignes/grappe
              dans le meme ordre que la liste de services 2018 ;
              service_id = rang (_n) au sein de la grappe. */
    preserve
        use "`base'/s02_co_sen`annee'.dta", clear
        if `annee' == 2018 {
            keep if inlist(s02q00, 5, 6, 7)
        }
        else {
            bysort grappe: gen byte service_id = _n
            keep if inlist(service_id, 5, 6, 7)
        }
        gen byte acces_pied = (s02q02 == 1) if !missing(s02q02)
        replace  acces_pied = 0 if missing(acces_pied)
        collapse (max) acces_pied, by(grappe)
        tempfile s02_temp
        save `s02_temp'
    restore
    merge m:1 grappe using `s02_temp', nogenerate keep(master match)
    gen byte m_acces_sante = (acces_pied == 0) if !missing(acces_pied)
    replace  m_acces_sante = 0 if missing(m_acces_sante)
    capture drop acces_pied

    /* [Dim 4/7 : Nutrition] Indicateur 1 — Securite alimentaire (FIES)
       (s08a — 2018 et 2021)
       Definition N-MODA : membre ayant saute un repas, mange moins que necessaire,
       manque de nourriture, eu faim ou passe une journee sans manger
       s08aq04 : saute repas | s08aq05 : mange moins | s08aq06 : plus de nourriture
       s08aq07 : faim        | s08aq08 : journee sans manger
       1=Oui 2=Non 98/99=NSP/Refus (traites comme Non)  */
    preserve
        use "`base'/s08a_me_sen`annee'.dta", clear
        gen byte m_securite = 0
        foreach v in s08aq04 s08aq05 s08aq06 s08aq07 s08aq08 {
            replace m_securite = 1 if `v' == 1 & !missing(`v')
        }
        keep grappe menage m_securite
        tempfile s08a_temp
        save `s08a_temp'
    restore
    merge m:1 grappe menage using `s08a_temp', ///
        keepusing(m_securite) nogenerate keep(master match)
    replace m_securite = 0 if missing(m_securite)

    /* [Dim 4/7 : Nutrition] Indicateur 2 — Diversite alimentaire
       (s08b1 — 2018 seulement)
       Definition N-MODA : 4 macro-groupes (carbohydrates, proteines,
       fruits/legumes, graisses) consommes chaque jour sur la semaine (7/7)
       Mapping s08b02a-j :
         Carbohydrates : max(a cereales, b tubercules)
         Proteines     : max(c legumineuses, e poisson/viande, g lait/oeufs)
         Fruits/legumes: max(d legumes, f fruits)
         Graisses      : h huile/graisse
       Prive si au moins un groupe < 7 jours (5-17 ans)  */
    gen byte m_diversite = 0
    if `annee' == 2018 {
        preserve
            use "`base'/s08b1_me_sen2018.dta", clear
            foreach v of varlist s08b02a-s08b02j {
                replace `v' = 0 if missing(`v')
            }
            gen g_carb  = max(s08b02a, s08b02b)
            gen g_prot  = max(s08b02c, s08b02e, s08b02g)
            gen g_fv    = max(s08b02d, s08b02f)
            gen g_gras  = s08b02h
            gen byte m_diversite = ///
                (g_carb < 7 | g_prot < 7 | g_fv < 7 | g_gras < 7)
            keep grappe menage m_diversite
            tempfile s08b_temp
            save `s08b_temp'
        restore
        merge m:1 grappe menage using `s08b_temp', ///
            keepusing(m_diversite) nogenerate keep(master match)
        replace m_diversite = 0 if missing(m_diversite)
    }
end

/* ============================================================
   Sous-programme : acte de naissance (s01_me)

   [Dim 6/7 : Protection de l'enfant] Indicateur 1 — Disponibilite
   de l'acte de naissance (s01q05, identique 2018/2021)
   ============================================================ */

capture program drop indic_acte_nais
program define indic_acte_nais
    args annee

    if `annee' == 2018 local base "$BASE_2018"
    else               local base "$BASE_2021"

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
end

/* ============================================================
   Sous-programme : agregation N-MODA et Alkire-Foster
   ============================================================ */

capture program drop agreger_ipm
program define agreger_ipm
    args annee

    /* Groupes d'age MODA */
    gen byte groupe_moda = .
    replace  groupe_moda = 1 if age <= 4
    replace  groupe_moda = 2 if age >= 5  & age <= 14
    replace  groupe_moda = 3 if age >= 15 & age <= 17
    label define grp 1 "0-4 ans" 2 "5-14 ans" 3 "15-17 ans", replace
    label values groupe_moda grp

    /* ── Dimensions N-MODA (union intra-dimension des indicateurs) ──
       Chaque dim_* combine les indicateurs construits ci-dessus, avec
       application des groupes d'age propres a l'Annexe I. */

    /* [Dim 1/7 : Assainissement] = indic.1 (type sanitaire) OU indic.2 (partage) */
    gen byte dim_assai  = (m_toilet == 1 | m_partag_toi == 1)

    /* [Dim 2/7 : Eau] = indic.1 (source) OU indic.2 (temps d'acces) */
    gen byte dim_eau    = (m_eau_source == 1 | m_eau_temps == 1)

    /* [Dim 3/7 : Logement] = indic.1 (ordures) OU indic.2 (surpeuplement) */
    gen byte dim_logem  = (m_ordures == 1 | m_surpeup == 1)

    /* [Dim 4/7 : Nutrition] = indic.1 securite alim (0-17 ans)
       OU indic.2 diversite alimentaire (5-17 ans seulement) */
    gen byte dim_nutri = 0
    replace  dim_nutri = 1 if m_securite == 1
    replace  dim_nutri = 1 if m_diversite == 1 & age >= 5

    /* [Dim 5/7 : Sante] = indic.1 (combustible) OU indic.2 (acces structure) */
    gen byte dim_sante  = (m_combust == 1 | m_acces_sante == 1)

    /* [Dim 7/7 : Education] selon groupe d'age :
       5-14 ans  -> indic.2 (scolarisation)
       15-17 ans -> indic.1 (lecture-ecriture) OU indic.3 (NEET) */
    gen byte dim_educ   = 0
    replace  dim_educ   = m_scol  if groupe_moda == 2
    replace  dim_educ   = (m_alfab == 1 | m_neet == 1) if groupe_moda == 3

    /* [Dim 6/7 : Protection de l'enfant] selon groupe d'age :
       0-4 ans   -> indic.1 (acte naissance) OU indic.3 (separation parentale)
       5-14 ans  -> indic.1 OU indic.2 (travail enfants) OU indic.3
       15-17 ans -> indic.3 seulement (acte naissance non pertinent > 14 ans) */
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
        keepusing(hhsize pcexp region milieu hgender hage heduc hmstat hhweight) ///
        nogenerate keep(master match)

    /* 3. Indicateurs menage */
    indic_menage `annee'

    /* 4. Acte de naissance */
    indic_acte_nais `annee'

    /* 5. Indicateurs individuels (ehcvm_individu : scol, activ7j, lien,
          alfab/alfa) — un bloc par dimension de l'Annexe I */

    /* [Dim 7/7 : Education] Indicateur 2 — Frequentation scolaire
       Non-scolarise, groupe d'age 5-14 ans (variable scol) */
    gen byte m_scol = 0
    replace  m_scol = 1 if age >= 5 & age <= 14 & (scol == 0 | missing(scol))

    /* [Dim 6/7 : Protection de l'enfant] Indicateur 2 — Travail des enfants
       Groupe d'age 5-14 ans, composante economique uniquement
       (activ7j : Occupe=1, Chomeur=2). L'EHCVM ne comporte pas de module
       time-use permettant de mesurer le travail domestique (corvees) ;
       cette composante de l'Annexe I n'est donc pas operationnalisable
       avec les donnees disponibles. */
    gen byte m_trav_enf = 0
    replace  m_trav_enf = 1 if age >= 5 & age <= 14 & ///
        (activ7j == 1 | activ7j == 2) & !missing(activ7j)

    /* [Dim 6/7 : Protection de l'enfant] Indicateur 3 — Separation parentale
       Prive si l'enfant ne vit pas avec ses deux parents biologiques
       (lien > 3, tous groupes d'age) */
    gen byte m_parents = (lien > 3) if !missing(lien)
    replace  m_parents = 0 if missing(m_parents)

    /* [Dim 7/7 : Education] Indicateur 1 — Capacite de lecture et d'ecriture
       Groupe d'age 15-17 ans (2018: alfab ; 2021: alfa) */
    gen byte m_alfab = 0
    if `annee' == 2018 {
        replace m_alfab = 1 if age >= 15 & alfab == 0 & !missing(alfab)
    }
    else {
        capture confirm variable alfa
        if !_rc replace m_alfab = 1 if age >= 15 & alfa == 0 & !missing(alfa)
    }

    /* [Dim 7/7 : Education] Indicateur 3 — NEET
       Groupe d'age 15-17 ans : ni scolarise ni employe
       (activ7j != 1 : inactifs + chomeurs) */
    gen byte m_neet = 0
    replace  m_neet = 1 if age >= 15 & ///
        (scol == 0 | missing(scol)) & (activ7j != 1 | missing(activ7j))

    /* Acte de naissance non pertinent > 14 ans */
    replace m_acte_nais = 0 if age > 14

    /* 6. Agregation IPM */
    agreger_ipm `annee'

    /* 7. Sauvegarde */
    save "$TEMP/enfants_dep_`annee'.dta", replace
    di _newline ">>> Sauvegarde : enfants_dep_`annee'.dta (" _N " obs)"
}
