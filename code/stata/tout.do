/* ============================================================
   tout.do — Script unique contenant l'integralite du pipeline

   Ce fichier regroupe tous les codes du projet dans l'ordre
   d'execution logique. Il peut etre lance depuis la racine :
     do "code/stata/tout.do"

   Aucune ponderation par poids d'enquete (hhweight) : toutes les
   statistiques et estimations sont calculees sur effectifs bruts,
   avec erreurs-types clusterisees au niveau de la grappe.
   Traitement : statut STABLE (recu aux 2 vagues vs jamais recu).

   Pipeline :
     config       — chemins, constantes
     utils        — programmes utilitaires
     01_visitation  — exploration des bases brutes
     02_traitement  — variable D + identification panel
     03_deprivation — indicateurs IPM (AF et N-MODA)
     04_panel       — panel vrai + traitement stable
     05_psm_dd      — estimation PSM-DD (matching niveau menage)
     06_stats_desc  — statistiques descriptives
     07_effets_dim  — effets par dimension
     08_carte_region— carte regionale
     09_placebo_attrition — tests placebo et attrition
   ============================================================ */

capture log close
log using "code/stata/logs/tout.log", replace text

di _newline(2) ">>> DEBUT DU PIPELINE COMPLET <<<"
di "$(date)"

/* ============================================================
   SECTION 0 : CONFIG
   ============================================================ */
/* ============================================================
   config.do — Chemins, constantes et options globales
   ============================================================ */

global BASE_2018 "Base/2018-2019/SEN_2018_EHCVM_v02_M_Stata"
global BASE_2021 "Base/2021-2022/SEN_2021_EHCVM-2_v01_M_STATA14"
global OUTPUT    "code/stata/output"
global TEMP      "code/stata/temp"
global LOGS      "code/stata/logs"

/* Parametres methodologiques */
global SEED              123
global K_SEUIL           0.3333   /* seuil Alkire-Foster (2 indicateurs sur 6) */
global K_MODA            4        /* seuil N-MODA : >= 4 dimensions sur 7      */
global N_BOOT            1000
global CODE_ETRANGER_MIN 4        /* s13aq14 / s13q19 >= 4 = expediteur etranger */
global CALIPER           0.05
global K_VOISINS         4

set seed   $SEED
set more   off
set varabbrev off

/* Pas de ponderation par poids d'enquete (hhweight) dans ce projet :
   toutes les statistiques et estimations sont calculees sur effectifs
   bruts. Les erreurs-types sont clusterisees au niveau de la grappe
   (vce(cluster grappe)) pour tenir compte du plan de sondage en grappes,
   sans recourir aux poids de sondage. */

foreach d in "$OUTPUT" "$TEMP" "$LOGS" {
    capture mkdir "`d'"
}

/* ============================================================
   SECTION 0b : UTILS
   ============================================================ */
/* ============================================================
   utils.do — Programmes utilitaires reutilisables

   Chaque programme est precede de "capture program drop" pour
   eviter l'erreur r(110) "already defined" quand utils.do est
   appele plusieurs fois dans la meme session Stata.
   ============================================================ */

/* ── Exploration rapide d'un fichier ───────────────────────── */
capture program drop visiter
program define visiter
    args fichier nom
    use "`fichier'", clear
    di _newline "===== `nom' ====="
    di "Observations : " _N
    describe
    codebook, compact
end

/* ── Taux de privation (%) ──────────────────────────────────── */
capture program drop taux_dep
program define taux_dep
    args var nom
    quietly summarize `var'
    di "  `nom' : " %5.1f r(mean)*100 "%"
end

/* ── Prevalence par statut de traitement ────────────────────── */
capture program drop prev_D
program define prev_D
    args outcome
    tabstat `outcome', by(D) stat(mean n) format(%6.3f)
end

/* ── ATT PSM-DD avec SE cluster-robustes ────────────────────── */
/*
   Syntaxe : att_psmdd outcome poids nboot  (nboot ignoré)
   poids : poids d'appariement PSM (weight_knn/kernel/caliper), PAS un
   poids d'enquete. Aucune ponderation par hhweight dans ce projet ;
   les erreurs-types sont clusterisees au niveau de la grappe.
*/
capture program drop att_psmdd
program define att_psmdd
    args outcome poids nboot

    regress `outcome' i.t##i.D [aw=`poids'], vce(cluster grappe)

    lincom 1.t#1.D
    di "  ATT=" %8.4f r(estimate) "  SE=" %8.4f r(se) "  p=" %6.4f r(p)
end

/* ── Verification equilibre SMD ────────────────────────────── */
/*
   Affiche les SMD avant/apres appariement pour une liste de vars
*/
capture program drop check_balance
program define check_balance
    args varlist_str
    di _newline "=== Balance des covariables (SMD) ==="
    pstest `varlist_str', both
end

/* ============================================================
   SECTION : 01_VISITATION — Exploration des deux bases EHCVM
   ============================================================ */
/* ============================================================
   01_visitation.do — Exploration des deux bases EHCVM
   ============================================================ */


/* ── EHCVM I (2018-2019) ──────────────────────────────────── */

visiter "$BASE_2018/ehcvm_individu_sen2018.dta"  "Individus 2018-2019"
visiter "$BASE_2018/ehcvm_menage_sen2018.dta"    "Menages 2018-2019"
visiter "$BASE_2018/ehcvm_welfare_sen2018.dta"   "Welfare 2018-2019"
visiter "$BASE_2018/s13a_1_me_sen2018.dta"       "Transferts S13A-1 (2018-2019)"
visiter "$BASE_2018/s13a_2_me_sen2018.dta"       "Transferts S13A-2 (2018-2019)"

/* ── EHCVM II (2021-2022) ─────────────────────────────────── */

visiter "$BASE_2021/ehcvm_individu_sen2021.dta"  "Individus 2021-2022"
visiter "$BASE_2021/ehcvm_menage_sen2021.dta"    "Menages 2021-2022"
visiter "$BASE_2021/ehcvm_welfare_sen2021.dta"   "Welfare 2021-2022"
visiter "$BASE_2021/s13_1_me_sen2021.dta"        "Transferts S13-1 (2021-2022)"
visiter "$BASE_2021/s13_2_me_sen2021.dta"        "Transferts S13-2 (2021-2022)"

/* ── Structure panel : variable PanelHH (s00_me_sen2021) ─── */

di _newline "===== Structure panel EHCVM II ====="
use "$BASE_2021/s00_me_sen2021.dta", clear
di "Total menages enquetes (2021) : " _N
tab PanelHH, missing
di "  --> PanelHH=1 : meme menage suivi depuis 2018"
di "  --> PanelHH=0 : nouveau menage (remplacement)"

/* Verification croisement grappe+menage entre les deux vagues */
preserve
    keep grappe menage PanelHH
    tempfile id_2021
    save `id_2021'
restore

use "$BASE_2018/s00_me_sen2018.dta", clear
merge 1:1 grappe menage using `id_2021', keepusing(PanelHH)
di _newline "Menages 2018 retrouves en 2021 (_merge==3) : " ///
   r(N) " (verif : doit etre proche de 6127)"
tab _merge

/* Modalites variables de transferts */
use "$BASE_2018/s13a_2_me_sen2018.dta", clear
di _newline "Modalites s13aq14 (lieu expediteur, 2018) :"
tabulate s13aq14, missing

use "$BASE_2021/s13_2_me_sen2021.dta", clear
di _newline "Modalites s13q19 (lieu expediteur, 2021) :"
tabulate s13q19, missing

/* ============================================================
   SECTION : 02_TRAITEMENT — Variable de traitement + identifiant panel
   ============================================================ */
/* ============================================================
   02_traitement.do — Variable de traitement + identifiant panel

   D = 1 si le menage a recu un transfert de l'etranger
   panel_id = identifiant unique grappe-menage pour le panel vrai

   NB : s13aq14 (2018) et s13q19 (2021) indiquent le pays de
        l'expediteur ; >= CODE_ETRANGER_MIN => transfert etranger
   ============================================================ */


/* ── Sous-programme : construire D pour une annee ─────────── */

capture program drop construire_traitement
program define construire_traitement
    /*
       args : annee  var_lieu  fichier_detail  fichier_liste
              annee      = 2018 ou 2021
              var_lieu   = nom de la variable lieu expediteur
              fichier_detail = s13a_2 (2018) ou s13_2 (2021)
              fichier_liste  = s13a_1 (2018) ou s13_1 (2021)
    */
    args annee var_lieu fich_det fich_list

    /* Resoudre le chemin de base selon l'annee (evite l'ambiguite $BASE_`annee') */
    if `annee' == 2018 local base "$BASE_2018"
    else               local base "$BASE_2021"

    /* Identifier les menages avec au moins un transfert etranger */
    use "`base'/`fich_det'_me_sen`annee'.dta", clear
    keep if `var_lieu' >= $CODE_ETRANGER_MIN & !missing(`var_lieu')
    bysort grappe menage: keep if _n == 1
    gen transfert_migrant = 1
    keep grappe menage transfert_migrant
    tempfile etrangers
    save `etrangers'

    /* Fusionner sur la liste exhaustive des menages */
    use "`base'/`fich_list'_me_sen`annee'.dta", clear
    merge m:1 grappe menage using `etrangers', ///
        keepusing(transfert_migrant) nogenerate
    replace transfert_migrant = 0 if missing(transfert_migrant)
    rename transfert_migrant D
    bysort grappe menage: keep if _n == 1
    label var D "Traitement : transfert de migrant recu (1=oui)"
    keep grappe menage D
    save "$TEMP/traitement_`annee'.dta", replace

    quietly summarize D
    di "  `annee' : " %5.1f r(mean)*100 "%  (" %4.0f r(sum) "/" %5.0f r(N) " menages)"
end

/* ── Construction pour chaque vague ──────────────────────── */

di _newline ">>> Prevalence des transferts de migrants :"
construire_traitement 2018 s13aq14 s13a_2 s13a_1
construire_traitement 2021 s13q19  s13_2  s13_1

/* ── Identifiant panel (PanelHH) ─────────────────────────── */
/*
   On recupere PanelHH depuis s00_me_sen2021 et on le joint
   au fichier traitement_2021 pour distinguer :
     - panel vrai  (PanelHH=1, grappe+menage communs aux 2 vagues)
     - remplacement (PanelHH=0, ménage nouveau en 2021)
*/

use "$BASE_2021/s00_me_sen2021.dta", clear
keep grappe menage PanelHH
label var PanelHH "Type de menage (1=Panel, 0=Nouveau)"
save "$TEMP/panel_id.dta", replace

/* Verifier cohérence : les memes (grappe,menage) en 2018 */
use "$TEMP/traitement_2018.dta", clear
merge 1:1 grappe menage using "$TEMP/panel_id.dta", ///
    keepusing(PanelHH) nogenerate
quietly count if PanelHH == 1
di _newline "Menages panel retrouves dans traitement_2018 : " r(N)
save "$TEMP/traitement_2018.dta", replace

di _newline ">>> Statut de traitement par type de menage (vague 2021) :"
use "$TEMP/traitement_2021.dta", clear
merge 1:1 grappe menage using "$TEMP/panel_id.dta", ///
    keepusing(PanelHH) nogenerate
tabstat D, by(PanelHH) stat(mean sum n) format(%6.3f)
save "$TEMP/traitement_2021.dta", replace

/* ============================================================
   SECTION : 03_DEPRIVATION — Indicateurs de pauvrete multidimensionnelle
   ============================================================ */
/* ============================================================
   03_deprivation.do — Indicateurs de pauvrete multidimensionnelle

   Approche 1 : Alkire-Foster (6 indicateurs, poids egaux, k=1/3)
   Approche 2 : N-MODA Senegal (7 dimensions, k=4)

   Produit : $TEMP/enfants_dep_ANNEE.dta pour annee in {2018, 2021}
   ============================================================ */


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
    /* Annexe I : combustible solide = bois ramasse(1), bois achete(2),
       charbon de bois(3), dechets animaux(7), autres(8). Exclut gaz(4),
       electricite(5), petrole/huile(6) consideres comme non solides. */
    local comb_vars "`v_comb'__1 `v_comb'__2 `v_comb'__3 `v_comb'__7 `v_comb'__8"

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
       charbon/dechets animaux/autres — cf. comb_vars) */
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

    /* Intensite moyenne N-MODA (Annexe II : A = part des 7 dimensions
       en privation, calculee sur les enfants pauvres pauvre_MODA==1) */
    gen float intensite_moda = nb_dep / 7

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

/* ============================================================
   SECTION : 04_PANEL — Construction du panel vrai (PanelHH=1)
   ============================================================ */
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

/* ============================================================
   SECTION : 05_PSM_DD — Estimation PSM-DD sur panel vrai
   ============================================================ */
/* ============================================================
   05_psm_dd.do — Estimation PSM-DD sur panel vrai

   Strategie :
     1. Probit au NIVEAU MENAGE sur t=0 -> score de propension
        (toutes les covariables du score sont des caracteristiques
        menage : l'appariement au niveau menage est l'approche
        correcte ; il evite les ex-aequo massifs qu'induirait un
        appariement au niveau enfant avec des scores identiques
        au sein d'un meme menage)
     2. Verification equilibre (SMD)
     3. Appariement PSM (k-NN, kernel, caliper) au niveau menage
     4. DD brute (sans appariement)
     5. PSM-DD sur panel vrai (Heckman et al. 1997/1998)
     6. Heterogeneite (milieu, sexe, age)
     7. Robustesse (seuil k, methodes d'appariement)

   Traitement : statut STABLE (transferts etrangers recus aux
   deux vagues vs jamais recus ; switchers exclus en 04_panel).

   Aucune ponderation par poids d'enquete (hhweight) : estimations
   sur effectifs bruts, erreurs-types clusterisees par grappe.
   Le seul poids utilise est le poids d'appariement PSM.
   ============================================================ */


/* Verifier/installer psmatch2 si absent */
capture which psmatch2
if _rc {
    di "Installation de psmatch2 depuis SSC..."
    ssc install psmatch2, replace
}

/* ============================================================
   1. Score de propension (probit MENAGE sur t=0, panel vrai)
   ============================================================ */

use "$TEMP/panel_vrai.dta", clear
keep if t == 0 & !missing(D) & !missing(log_pcexp) & !missing(hhsize)
bysort grappe menage: keep if _n == 1   /* un menage = une observation */

di _newline "=== Probit menage — score de propension (EHCVM I, panel vrai) ==="
di "Menages : " _N

probit D c.hhsize c.log_pcexp i.milieu i.region ///
         c.hgender c.hage i.heduc i.hmstat, vce(cluster grappe) nolog

di "Pseudo-R2 McFadden : " %6.3f 1 - e(ll)/e(ll_0)

predict pscore, pr
label var pscore "Score de propension (menage)"

/* Graphique de densite (support commun) */
twoway ///
    (kdensity pscore if D == 0, lcolor(ltblue) lwidth(medthick)) ///
    (kdensity pscore if D == 1, lcolor(navy) lwidth(medthick)), ///
    legend(order(1 "Jamais traites" 2 "Traites stables")) ///
    xtitle("Score de propension") ytitle("Densité") ///
    title("Support commun — panel vrai (niveau ménage)") ///
    saving("$OUTPUT/overlap_panel.gph", replace)
graph export "$OUTPUT/overlap_panel.pdf", replace

save "$TEMP/pscore_t0.dta", replace

/* ============================================================
   2. Appariement PSM au niveau menage

   Trois algorithmes pour robustesse :
     a. k plus proches voisins (k=K_VOISINS, avec remise)
     b. Kernel Epanechnikov (h=0.06)
     c. Caliper (epsilon=CALIPER, sans remise)
   ============================================================ */

/* -- 2a. k-NN ------------------------------------------------ */
di _newline "=== Appariement k-NN (k=$K_VOISINS, avec remise) ==="
psmatch2 D, pscore(pscore) neighbor($K_VOISINS) common

di _newline "Balance avant/apres (SMD) :"
pstest hhsize log_pcexp i.milieu i.region hgender hage i.heduc i.hmstat, both

rename _weight weight_knn
keep grappe menage D pscore weight_knn _support
save "$TEMP/pscore_knn.dta", replace

/* -- 2b. Kernel Epanechnikov --------------------------------- */
di _newline "=== Appariement Kernel (Epanechnikov, h=0.06) ==="
use "$TEMP/pscore_t0.dta", clear
psmatch2 D, pscore(pscore) kernel kerneltype(epan) bwidth(0.06) common
rename _weight weight_kernel
keep grappe menage weight_kernel
save "$TEMP/poids_kernel.dta", replace

/* -- 2c. Caliper -------------------------------------------- */
di _newline "=== Appariement Caliper (eps=$CALIPER, sans remise) ==="
use "$TEMP/pscore_t0.dta", clear
psmatch2 D, pscore(pscore) caliper($CALIPER) noreplacement common
rename _weight weight_caliper
keep grappe menage weight_caliper
save "$TEMP/poids_caliper.dta", replace

/* ============================================================
   3. Statistiques descriptives sur le panel
   ============================================================ */

use "$TEMP/panel_vrai.dta", clear
di _newline "=== Stats descriptives (panel vrai, D stable) ==="
tabstat pauvre_AF pauvre_MODA nb_dep score_dep pcexp, ///
    by(D) stat(mean n) format(%6.3f)

/* ============================================================
   4. Double Difference brute (sans appariement, reference)
   ============================================================ */

di _newline "=== Double Difference brute (sans appariement) ==="
foreach outcome in pauvre_AF pauvre_MODA {
    di _newline "--- DD `outcome' ---"
    regress `outcome' i.t##i.D, vce(cluster grappe)
    lincom 1.t#1.D
    di "  ATT_DD  = " %8.4f r(estimate) ///
       "  SE = " %8.4f r(se) "  p = " %6.4f r(p)
}

/* ============================================================
   5. PSM-DD sur panel vrai
      Specification : Y_it = a + b*t + c*D + d*(t#D) + e
      d = ATT estime, poids d'appariement k-NN (niveau menage)
   ============================================================ */

use "$TEMP/panel_vrai.dta", clear
merge m:1 grappe menage using "$TEMP/pscore_knn.dta", ///
    keepusing(weight_knn) keep(master match) nogenerate
keep if !missing(weight_knn) & weight_knn > 0

di _newline "Panel apparie (k-NN, niveau menage) : " _N " obs enfants"
tabstat D, by(t) stat(mean sum n) format(%6.3f)

di _newline "=== PSM-DD — ATT principal (Heckman 1997/1998) ==="
foreach outcome in pauvre_AF pauvre_MODA {
    di _newline "--- PSM-DD `outcome' ---"
    regress `outcome' i.t##i.D [aw=weight_knn], vce(cluster grappe)
    lincom 1.t#1.D
    di "  ATT_PSM-DD = " %8.4f r(estimate) ///
       "  SE = " %8.4f r(se) "  p = " %6.4f r(p)
}

save "$TEMP/panel_apparie.dta", replace

/* ============================================================
   6. Heterogeneite
   ============================================================ */

/* -- 6a. Par milieu de residence ---------------------------- */
di _newline "=== Heterogeneite par milieu ==="
foreach mil in 1 2 {
    if `mil' == 1 local lab_mil "Urbain"
    else          local lab_mil "Rural"

    foreach outcome in pauvre_AF pauvre_MODA {
        quietly count if milieu == `mil'
        if r(N) > 30 {
            di _newline "--- `lab_mil' — `outcome' ---"
            regress `outcome' i.t##i.D [aw=weight_knn] if milieu == `mil', ///
                vce(cluster grappe)
            lincom 1.t#1.D
            di "  ATT = " %8.4f r(estimate) "  p = " %6.4f r(p)
        }
    }
}

/* Test d'egalite urbain vs rural */
di _newline "Test d'egalite (urbain vs rural) :"
gen byte urban = (milieu == 1)
foreach outcome in pauvre_AF pauvre_MODA {
    regress `outcome' i.t##i.D##i.urban [aw=weight_knn], vce(cluster grappe)
    lincom 1.t#1.D#1.urban
    di "  Diff ATT (urbain - rural) : " %8.4f r(estimate) "  p = " %6.4f r(p)
}
drop urban

/* -- 6b. Par sexe de l'enfant ------------------------------- */
di _newline "=== Heterogeneite par sexe ==="
capture confirm variable sexe
if _rc == 0 {
    foreach outcome in pauvre_AF pauvre_MODA {
        foreach s in 1 2 {
            if `s' == 1 local lab_s "Garcons"
            else        local lab_s "Filles"
            quietly count if sexe == `s'
            if r(N) > 30 {
                di "--- `lab_s' — `outcome' ---"
                regress `outcome' i.t##i.D [aw=weight_knn] if sexe == `s', ///
                    vce(cluster grappe)
                lincom 1.t#1.D
                di "  ATT = " %8.4f r(estimate) "  p = " %6.4f r(p)
            }
        }
    }
}

/* -- 6c. Par groupe d'age ----------------------------------- */
di _newline "=== Heterogeneite par groupe d'age ==="
foreach g in 1 2 3 {
    foreach outcome in pauvre_AF pauvre_MODA {
        quietly count if groupe_moda == `g'
        if r(N) > 30 {
            di "--- Groupe `g' — `outcome' ---"
            regress `outcome' i.t##i.D [aw=weight_knn] if groupe_moda == `g', ///
                vce(cluster grappe)
            lincom 1.t#1.D
            di "  ATT = " %8.4f r(estimate) "  p = " %6.4f r(p)
        }
    }
}

/* ============================================================
   7. Robustesse
   ============================================================ */

/* -- 7a. Sensibilite au seuil k (Alkire-Foster) ------------- */
di _newline "=== Sensibilite au seuil k (Alkire-Foster) ==="
foreach k_test in 0.1667 0.3333 0.5 {
    gen byte pauvre_ktest = (score_dep >= `k_test') if !missing(score_dep)
    regress pauvre_ktest i.t##i.D [aw=weight_knn], vce(cluster grappe)
    lincom 1.t#1.D
    di "  k=" %5.4f `k_test' " : ATT=" %8.4f r(estimate) "  p=" %6.4f r(p)
    drop pauvre_ktest
}

/* -- 7b. Robustesse aux trois methodes d'appariement -------- */
di _newline "=== Comparaison des trois methodes d'appariement ==="
foreach poids_var in weight_kernel weight_caliper {
    merge m:1 grappe menage using "$TEMP/poids_`=substr("`poids_var'",8,.)'.dta", ///
        keepusing(`poids_var') keep(master match) nogenerate
}
foreach poids_var in weight_knn weight_kernel weight_caliper {
    foreach outcome in pauvre_AF pauvre_MODA {
        quietly count if !missing(`poids_var') & `poids_var' > 0
        if r(N) > 0 {
            regress `outcome' i.t##i.D [aw=`poids_var'] ///
                if `poids_var' > 0, vce(cluster grappe)
            lincom 1.t#1.D
            di "  `poids_var' — `outcome' : ATT=" %8.4f r(estimate) ///
               "  p=" %6.4f r(p)
        }
    }
}

di _newline ">>> 05_psm_dd.do termine."

/* ============================================================
   SECTION : 06_STATS_DESC — Statistiques descriptives
   ============================================================ */
/* ============================================================
   06_stats_desc.do — Statistiques descriptives
   Chapitre 3 : profil ménages, pauvreté, privations, comparaison D=0/1

   Aucune ponderation par poids d'enquete (hhweight) : toutes les
   statistiques sont calculees sur effectifs bruts.

   Sorties :
     output/tab_menages.csv          — caractéristiques ménages (tab 5)
     output/tab_balance.csv          — balance traités/non-traités (tab 6)
     output/tab_prevalence_dim.csv   — privations par dimension (tab 7)
     output/tab_moda_age.csv         — N-MODA par groupe d'âge (tab 8)
     output/fig_evolution_ipm.pdf    — évolution H, A, M0 (fig 1)
     output/fig_privations_dim.pdf   — radar/barres privations (fig 2)
     output/fig_overlap.pdf          — overlap scores propension (fig 3)
   ============================================================ */


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
        gen byte chef_f = (hgender == 2)
        gen byte urbain = (milieu == 1)
        foreach v in hhsize hage pcexp chef_f urbain D {
            summarize `v'
            if "`v'" == "hhsize" scalar m_hhsize_`annee' = r(mean)
            if "`v'" == "hage"   scalar m_hage_`annee'   = r(mean)
            if "`v'" == "pcexp"  scalar m_pcexp_`annee'  = r(mean)
            if "`v'" == "chef_f" scalar p_chef_f_`annee' = r(mean)*100
            if "`v'" == "urbain" scalar p_urbain_`annee' = r(mean)*100
            if "`v'" == "D"      scalar p_D_`annee'      = r(mean)*100
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
    tabstat `v', by(D) stat(mean sd) format(%9.2f)
}
gen byte chef_f = (hgender == 2)
gen byte urbain = (milieu  == 1)
foreach v in chef_f urbain {
    di "  `v' par D (%) :"
    tabstat `v', by(D) stat(mean n) format(%6.3f)
}

/* Tests avec erreurs-types clusterisees au niveau de la grappe */
foreach v in hhsize hage pcexp chef_f urbain {
    quietly regress `v' D, vce(cluster grappe)
    di "  Test `v' : diff=" %8.3f _b[D] ///
       "  SE=" %8.3f _se[D] ///
       "  p=" %6.4f (2*ttail(e(df_r), abs(_b[D]/_se[D])))
}

/* Export balance : moyennes brutes + n */
preserve
    gen n_obs = 1
    collapse (mean) hhsize hage pcexp chef_f urbain ///
             (sum)  n_obs, by(D)
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
    tabstat pauvre_MODA nb_dep, ///
        by(milieu) stat(mean n) format(%6.3f)
    tabstat pauvre_MODA nb_dep, ///
        by(groupe_moda) stat(mean n) format(%6.3f)

    di "-- Alkire-Foster `annee' --"
    tabstat pauvre_AF score_dep, ///
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
        quietly summarize pauvre_MODA if groupe_moda == `g'
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
        quietly summarize dim_`dim'
        di "  `dim' : " %5.1f r(mean)*100 "%"
    }
}

/* Export CSV privations */
foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear
    collapse (mean) dim_assai dim_eau dim_logem dim_nutri ///
                    dim_sante dim_protect dim_educ
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
    quietly summarize pauvre_MODA
    scalar H_moda_`annee' = r(mean)*100
    quietly summarize pauvre_AF
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
        quietly summarize dim_`dim'
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
graph bar pauvre_MODA, over(groupe_moda) over(milieu) ///
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

histogram nb_dep, by(D, cols(1) note("") ///
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

/* ============================================================
   SECTION : 07_EFFETS_DIM — ATT PSM-DD par dimension N-MODA
   ============================================================ */
/* ============================================================
   07_effets_dim.do — ATT PSM-DD par dimension N-MODA
   Génère output/figures/fig_effets_dim.pdf
   ============================================================ */


/* Joindre poids k-NN au panel vrai */
use "$TEMP/pscore_knn.dta", clear
keep grappe menage weight_knn
drop if missing(weight_knn)
duplicates drop grappe menage, force
tempfile poids_knn
save `poids_knn'

use "$TEMP/panel_vrai.dta", clear
merge m:1 grappe menage using `poids_knn', keepusing(weight_knn) nogenerate
keep if !missing(weight_knn)

/* ATT PSM-DD pour chaque dimension (poids d'appariement PSM uniquement,
   pas de poids d'enquete ; erreurs-types clusterisees au niveau grappe) */
local dims    assai eau logem nutri sante protect educ
local n_dims  7

matrix ATT  = J(`n_dims', 1, .)
matrix LB   = J(`n_dims', 1, .)
matrix UB   = J(`n_dims', 1, .)

local i = 0
foreach dim of local dims {
    local ++i
    quietly regress dim_`dim' i.t##i.D [aw=weight_knn], vce(cluster grappe)
    quietly lincom 1.t#1.D
    matrix ATT[`i',1] = r(estimate)
    matrix LB[`i',1]  = r(estimate) - 1.96*r(se)
    matrix UB[`i',1]  = r(estimate) + 1.96*r(se)
    di "  dim_`dim' : ATT=" %8.4f r(estimate) "  SE=" %7.4f r(se) "  p=" %6.4f r(p)
}

/* Construire dataset pour le graphique */
clear
set obs `n_dims'
gen ordre = _n
gen str12 dim = ""
replace dim = "Assainissement" in 1
replace dim = "Eau"            in 2
replace dim = "Logement"       in 3
replace dim = "Nutrition"      in 4
replace dim = "Santé"          in 5
replace dim = "Protection"     in 6
replace dim = "Éducation"      in 7
gen att = .
gen lb  = .
gen ub  = .
forvalues i = 1/`n_dims' {
    replace att = ATT[`i',1]*100 in `i'
    replace lb  = LB[`i',1]*100  in `i'
    replace ub  = UB[`i',1]*100  in `i'
}

/* Trier par ATT croissant et réaffecter le rang */
sort att
replace ordre = _n

/* Construire les labels ylabel à partir des valeurs de dim triées */
local ylab_str ""
forvalues i = 1/`n_dims' {
    local lbl = dim[`i']
    local ylab_str `"`ylab_str' `i' "`lbl'""'
}

/* Graphique à barres horizontales avec IC 95 % */
twoway ///
    (bar att ordre, horizontal barwidth(0.6) color(navy)) ///
    (rcap lb ub ordre, horizontal lcolor(orange) lwidth(medthick) msize(medium)), ///
    ylab(`ylab_str', angle(0) noticks) ///
    yscale(range(0.5 7.5)) ///
    ytitle("") xtitle("ATT (points de pourcentage)") ///
    xline(0, lcolor(black) lpattern(dash)) ///
    legend(off) ///
    title("Impact des transferts par dimension N-MODA") ///
    subtitle("Estimateur PSM-DD — IC 95 %") ///
    note("Erreurs-types clusterisées au niveau de la grappe. Appariement k-NN (k=4)." ///
         "Aucun effet n'est significatif au seuil de 10 %.", size(vsmall)) ///
    graphregion(color(white)) plotregion(color(white))

graph export "$OUTPUT/figures/fig_effets_dim.pdf", replace
di ">>> fig_effets_dim.pdf sauvegardé dans $OUTPUT/figures/"
di ">>> 07_effets_dim.do terminé."

/* ============================================================
   SECTION : 08_CARTE_REGION — Carte régionale N-MODA + pauvreté monétaire
   ============================================================ */
/* ============================================================
   08_carte_region.do — Carte régionale N-MODA + pauvreté monétaire
   et diagramme de Venn monétaire/multidimensionnel

   Sorties :
     output/figures/fig_carte_nmoda.pdf      — carte H par région
     output/figures/fig_croisement_pauvrete.pdf — Venn monétaire/MODA
   ============================================================ */


/* ============================================================
   1. Incidence N-MODA par région (EHCVM I, 2018-2019)
   ============================================================ */

use "$TEMP/vague_2018.dta", clear

/* Moyenne brute par région (pas de ponderation par poids d'enquete) */
matrix H_reg = J(14, 2, .)

levelsof region, local(regs)
local i = 0
foreach r of local regs {
    local ++i
    quietly summarize pauvre_MODA if region == `r'
    matrix H_reg[`i', 1] = `r'
    matrix H_reg[`i', 2] = r(mean)*100
    local lbl : label (region) `r'
    di "Région `r' (`lbl') : H=" %5.1f r(mean)*100 "%"
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
            color(navy) lcolor(white)), ///
        ylab(`ylab_str', angle(0) noticks labsize(small)) ///
        yscale(range(0.5 14.5)) ///
        xtitle("Incidence N-MODA H (%)") ytitle("") ///
        xlabel(0(10)100, grid) ///
        xline(58.9, lcolor(orange) lpattern(dash) lwidth(medthick)) ///
        note("Ligne pointillée : moyenne nationale (58,9 %). EHCVM I (2018-2019)." ///
             "Estimations sur effectifs bruts (sans ponderation).", size(vsmall)) ///
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

/* Tableau croisé brut (sans ponderation) */
di _newline "=== Croisement pauvreté monétaire / N-MODA ==="
tab pauvre_mon pauvre_MODA, row col nofreq

/* Calcul des quatre cellules */
foreach pm in 0 1 {
    foreach md in 0 1 {
        quietly count if pauvre_mon == `pm' & pauvre_MODA == `md'
        local n`pm'`md' = r(N)
    }
}

/* Proportions brutes */
gen byte cat4 = .
replace cat4 = 1 if pauvre_mon == 0 & pauvre_MODA == 0  /* non pauvres */
replace cat4 = 2 if pauvre_mon == 1 & pauvre_MODA == 0  /* pauvres monet. seuls */
replace cat4 = 3 if pauvre_mon == 0 & pauvre_MODA == 1  /* pauvres multidim. seuls */
replace cat4 = 4 if pauvre_mon == 1 & pauvre_MODA == 1  /* doublement pauvres */
label define cat4l 1 "Non pauvres" 2 "Pauvres monet. seuls" ///
                   3 "Pauvres MODA seuls" 4 "Doublement pauvres"
label values cat4 cat4l

tabstat cat4, by(cat4) stat(count) format(%9.0f)

quietly summarize pauvre_mon
scalar p_mon = r(mean)*100
quietly summarize pauvre_MODA
scalar p_moda = r(mean)*100

di _newline "Pauvreté monétaire : " %5.1f p_mon "%"
di "Pauvreté N-MODA    : " %5.1f p_moda "%"

/* ── Fig Venn simplifié : diagramme à barres empilées ── */
/* Proportions par catégorie calculées sans collapse pour éviter
   la perte des variables de stratification */
preserve
    /* 4 catégories pour graphique */
    gen byte nn  = (pauvre_mon == 0 & pauvre_MODA == 0)  /* 1 */
    gen byte pm_only = (pauvre_mon == 1 & pauvre_MODA == 0)  /* 2 */
    gen byte md_only = (pauvre_mon == 0 & pauvre_MODA == 1)  /* 3 */
    gen byte both    = (pauvre_mon == 1 & pauvre_MODA == 1)  /* 4 */

    foreach v in nn pm_only md_only both {
        quietly summarize `v'
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
            color(ltblue midblue orange navy)), ///
        ylab(`ylab_str', angle(0) noticks labsize(small)) ///
        yscale(range(0.5 4.5)) ///
        xtitle("Part des enfants 0--17 ans (%)") ytitle("") ///
        xlabel(0(10)60, grid) ///
        title("Croisement pauvreté monétaire et N-MODA") ///
        subtitle("Sénégal, EHCVM I (2018-2019) — enfants 0--17 ans") ///
        note("Estimations sur effectifs bruts (sans ponderation).", size(vsmall)) ///
        legend(off) ///
        graphregion(color(white)) plotregion(color(white))
    graph export "$OUTPUT/figures/fig_croisement_pauvrete.pdf", replace
    di ">>> fig_croisement_pauvrete.pdf sauvegardé"
restore

di _newline ">>> 08_carte_region.do terminé."

/* ============================================================
   SECTION : 09_PLACEBO_ATTRITION — Tests de validite (annexe A)
   ============================================================ */
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

/* Menages retrouves dans le panel a t=1 */
use "$TEMP/panel_vrai.dta", clear
keep if t == 1
bysort grappe menage: keep if _n == 1
keep grappe menage
gen byte suivi = 1
merge 1:1 grappe menage using `men18', keepusing(hhsize hage chef_f ///
    urbain log_pcexp D) nogenerate
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

/* ============================================================
   FIN DU PIPELINE
   ============================================================ */

di _newline(2) ">>> PIPELINE COMPLET TERMINE <<<"
log close
