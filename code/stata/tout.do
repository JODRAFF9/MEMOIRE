/* ============================================================
   tout.do — Script unique contenant l'integralite du pipeline

   Ce fichier regroupe tous les codes du projet dans l'ordre
   d'execution logique. Il peut etre lance depuis la racine :
     do "code/stata/tout.do"

   Aucune ponderation par poids d'enquete (hhweight) : toutes les
   statistiques et estimations sont calculees sur effectifs bruts,
   avec erreurs-types clusterisees au niveau de la grappe.
   Traitement : design ENTRANTS (aucun transfert en 2018, transfert
   etranger recu en 2021, vs jamais beneficiaire aux deux vagues).

   Pipeline :
     config       — chemins, constantes
     (chargement direct des bases, sans sous-programmes)
     01_visitation  — exploration des bases brutes
     02_traitement  — variable D + identification panel
     03_deprivation — indicateurs N-MODA
     04_panel       — panel vrai + traitement entrants
     05_psm_dd      — estimation PSM-DD (matching niveau menage)
     06_stats_desc  — statistiques descriptives
     07_effets_dim  — effets par dimension
     08_carte_region— carte regionale
     09_placebo_attrition — tests placebo et attrition
   ============================================================ */
cd "C:\Users\Bmd\Documents\ISE\Cours\ISE3\Memoire"
capture log close _all
/* Si un ancien log est verrouille par un autre programme (r(608)),
   on bascule sur un nom horodate plutot que d'echouer */
capture log using "code/stata/logs/tout.log", replace text
if _rc {
    local horodate = subinstr("`c(current_date)'_`c(current_time)'", ":", "-", .)
    local horodate = subinstr("`horodate'", " ", "_", .)
    log using "code/stata/logs/tout_`horodate'.log", replace text
}

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
global PREP      "code/stata/temp/prepared"
global LOGS      "code/stata/logs"

/* Parametres methodologiques */
global SEED              123
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

foreach d in "$OUTPUT" "$TEMP" "$PREP" "$LOGS" {
    capture mkdir "`d'"
}


/* Aucun sous-programme : chaque etape est ecrite en ligne, en sequence. */


/* ============================================================
   SECTION : 01_VISITATION — Exploration des deux bases EHCVM
   ============================================================ */
/* ============================================================
   01_visitation.do — Exploration des deux bases EHCVM
   ============================================================ */


/* ── EHCVM I (2018-2019) ──────────────────────────────────── */

use "$BASE_2018/ehcvm_individu_sen2018.dta", clear
di _newline "===== Individus 2018-2019 ====="
di "Observations : " _N
describe
codebook, compact

use "$BASE_2018/ehcvm_menage_sen2018.dta", clear
di _newline "===== Menages 2018-2019 ====="
di "Observations : " _N
describe
codebook, compact

use "$BASE_2018/ehcvm_welfare_sen2018.dta", clear
di _newline "===== Welfare 2018-2019 ====="
di "Observations : " _N
describe
codebook, compact

use "$BASE_2018/s13a_1_me_sen2018.dta", clear
di _newline "===== Transferts S13A-1 (2018-2019) ====="
di "Observations : " _N
describe
codebook, compact

use "$BASE_2018/s13a_2_me_sen2018.dta", clear
di _newline "===== Transferts S13A-2 (2018-2019) ====="
di "Observations : " _N
describe
codebook, compact


/* ── EHCVM II (2021-2022) ─────────────────────────────────── */

use "$BASE_2021/ehcvm_individu_sen2021.dta", clear
di _newline "===== Individus 2021-2022 ====="
di "Observations : " _N
describe
codebook, compact

use "$BASE_2021/ehcvm_menage_sen2021.dta", clear
di _newline "===== Menages 2021-2022 ====="
di "Observations : " _N
describe
codebook, compact

use "$BASE_2021/ehcvm_welfare_sen2021.dta", clear
di _newline "===== Welfare 2021-2022 ====="
di "Observations : " _N
describe
codebook, compact

use "$BASE_2021/s13_1_me_sen2021.dta", clear
di _newline "===== Transferts S13-1 (2021-2022) ====="
di "Observations : " _N
describe
codebook, compact

use "$BASE_2021/s13_2_me_sen2021.dta", clear
di _newline "===== Transferts S13-2 (2021-2022) ====="
di "Observations : " _N
describe
codebook, compact


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


/* ── Construction pour chaque vague ──────────────────────── */

di _newline ">>> Prevalence des transferts de migrants :"
local annee 2018
local var_lieu s13aq14
local fich_det s13a_2
local fich_list s13a_1
    /*
       args : annee  var_lieu  fichier_detail  fichier_liste
              annee      = 2018 ou 2021
              var_lieu   = nom de la variable lieu expediteur
              fichier_detail = s13a_2 (2018) ou s13_2 (2021)
              fichier_liste  = s13a_1 (2018) ou s13_1 (2021)
    */

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

local annee 2021
local var_lieu s13q19
local fich_det s13_2
local fich_list s13_1
    /*
       args : annee  var_lieu  fichier_detail  fichier_liste
              annee      = 2018 ou 2021
              var_lieu   = nom de la variable lieu expediteur
              fichier_detail = s13a_2 (2018) ou s13_2 (2021)
              fichier_liste  = s13a_1 (2018) ou s13_1 (2021)
    */

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

   Approche : N-MODA Senegal (7 dimensions, k=4)

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
	Type de sanitaire (2018: s11q55;2021 :)
		Enfant vivant dans un ménage utilisant des toilettes
		non améliorées :
		7. Latrines SANPLAT;
		8. Latrines dallées simples;
		9. Fosse rudimentaire;
		10. Toilettes publiques;
		11. Aucune toilette;
		12. Autre

	Partage des toilettes (2018: s11q56;2021: )
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


/* ============================================================
   Sous-programme : acte de naissance (s01_me)

   [Dim 6/7 : Protection de l'enfant] Indicateur 1 — Disponibilite
   de l'acte de naissance (s01q05, identique 2018/2021)
   ============================================================ */


/* ============================================================
   Sous-programme : agregation N-MODA
   ============================================================ */


/* ============================================================
   Boucle principale sur les deux annees
   ============================================================ */

foreach annee in 2018 2021 {

    if `annee' == 2018 local base "$BASE_2018"
    else               local base "$BASE_2021"

    /* ============================================================
       A. PREPARATION DES DONNEES — fusion de toutes les sections
          necessaires de l'annee, avant tout calcul d'indicateur.
       ============================================================ */

    /* A1. Individus 0-17 ans (ehcvm_individu) */
    use "`base'/ehcvm_individu_sen`annee'.dta", clear
    keep if age >= 0 & age <= 17 & !missing(age)
    gen annee = `annee'
    di _newline ">>> Enfants `annee' : " _N

    /* A2. Welfare : hhsize, pcexp, covariables PSM */
    merge m:1 grappe menage using ///
        "`base'/ehcvm_welfare_sen`annee'.dta", ///
        keepusing(hhsize pcexp region milieu hgender hage heduc hmstat hhweight) ///
        nogenerate keep(master match)

    /* A3. Menage (ehcvm_menage) : toilettes, eau, ordures.
       ehcvm_menage n'a pas grappe/menage, seulement hhid
       (2018 : hhid = grappe*1000+menage ; 2021 : grappe*100+menage). */
    if `annee' == 2018 {
        local v_partag "s11q56"
        local v_type_toi "s11q55"
        local v_tps_ss "s11q29a"
        local v_tps_sp "s11q31a"
        local v_comb   "s11q53"
        local v_src_ss "s11q27a"
        local v_src_sp "s11q27b"
    }
    else {
        local v_partag "s11q55"
        local v_type_toi "s11q54"
        local v_tps_ss "s11q28a"
        local v_tps_sp "s11q30a"
        local v_comb   "s11q52"
        local v_src_ss "s11q26a"
        local v_src_sp "s11q26b"
    }
    /* Annexe I : combustible solide = bois ramasse(1), bois achete(2),
       charbon de bois(3), dechets animaux(7), autres(8). Exclut gaz(4),
       electricite(5), petrole/huile(6) consideres comme non solides. */
    local comb_vars "`v_comb'__1 `v_comb'__2 `v_comb'__3 `v_comb'__7 `v_comb'__8"

    capture drop hhid
    if `annee' == 2018 gen long hhid = grappe * 1000 + menage
    else               gen long hhid = grappe * 100  + menage
    merge m:1 hhid using ///
        "`base'/ehcvm_menage_sen`annee'.dta", ///
        keepusing(toilet eauboi_ss eauboi_sp ordure) ///
        nogenerate keep(master match)

    /* A4. Module habitat (s11_me) : partage toilettes, temps d'acces
       a l'eau, nombre de pieces, combustible de cuisine. */
    preserve
        use "`base'/s11_me_sen`annee'.dta", clear
        keep grappe menage s11q02 `v_partag' `v_type_toi' `v_tps_ss' `v_tps_sp' ///
            `v_src_ss' `v_src_sp' `comb_vars'
        rename s11q02 nb_pieces
        tempfile s11_temp
        save `s11_temp'
    restore
    merge m:1 grappe menage using `s11_temp', nogenerate keep(master match)

    /* A5. Securite alimentaire (s08a_me), variables brutes (traitement Non-retenu en calcul) */
    preserve
        use "`base'/s08a_me_sen`annee'.dta", clear
        keep grappe menage s08aq04 s08aq05 s08aq06 s08aq07 s08aq08
        tempfile s08a_temp
        save `s08a_temp'
    restore
    merge m:1 grappe menage using `s08a_temp', nogenerate keep(master match)

    /* A6. Acte de naissance (s01_me), cle individuelle */
    preserve
        use "`base'/s01_me_sen`annee'.dta", clear
        if `annee' == 2018 rename s01q00a numind
        else               rename membres__id numind
        keep grappe menage numind s01q05
        tempfile s01_temp
        save `s01_temp'
    restore
    merge m:1 grappe menage numind using `s01_temp', ///
        keepusing(s01q05) nogenerate keep(master match)

    /* A7. Travail des enfants (s04_me / s04a_me), heures de travail
       economique et domestique. 2018 : cle s01q00a. 2021 : s04a_me en
       format long (membres__id), collapse au niveau personne. */
    preserve
        if `annee' == 2018 {
            use "`base'/s04_me_sen2018.dta", clear
            rename s01q00a numind
            egen h_dom = rowtotal(s04q02 s04q04 s04q05)
            gen byte eco = inlist(1, s04q06, s04q07, s04q08, s04q09)
        }
        else {
            use "`base'/s04a_me_sen2021.dta", clear
            rename membres__id numind
            collapse (max) s04q01 s04q02a s04q02b s04q02c s04q04 s04q05 ///
                           s04q06 s04q07 s04q08 s04q09, ///
                     by(grappe menage numind)
            egen h_dom = rowtotal(s04q01 s04q02a s04q02b s04q02c s04q04 s04q05)
            gen byte eco = inlist(1, s04q06, s04q07, s04q08, s04q09)
        }
        keep grappe menage numind h_dom eco
        tempfile s04_trav
        save `s04_trav'
    restore
    merge m:1 grappe menage numind using `s04_trav', ///
        keepusing(h_dom eco) nogenerate keep(master match)

    /* Les variables scol, activ7j, lien, alfab/alfa sont deja presentes
       dans ehcvm_individu (chargee en A1) : aucune fusion supplementaire
       n'est necessaire pour la dimension Education. */

    /* A8. Sauvegarde de la base preparee (fusionnee, avant calcul),
       dans un dossier separe des bases finales avec indicateurs. */
    save "$PREP/base_prep_`annee'.dta", replace
    di ">>> Base preparee sauvegardee : $PREP/base_prep_`annee'.dta (" _N " obs)"

    /* ============================================================
       B. CALCUL DES INDICATEURS ET DES DIMENSIONS N-MODA, par
          dimension. Toutes les donnees sources sont deja fusionnees
          (etape A) : cette section ne contient plus aucun merge.
       ============================================================ */

    /* Groupes d'age N-MODA (utilises par plusieurs dimensions ci-dessous) */
    gen byte groupe_moda = .
    replace  groupe_moda = 1 if age <= 4
    replace  groupe_moda = 2 if age >= 5  & age <= 14
    replace  groupe_moda = 3 if age >= 15 & age <= 17
    label define grp 1 "0-4 ans" 2 "5-14 ans" 3 "15-17 ans", replace
    label values groupe_moda grp

    /* ── [Dimension 1/7 : Assainissement] ────────────────────────
       Indicateur 1 - Type de sanitaire non ameliore (toilet)
       Indicateur 2 - Partage des toilettes avec un autre menage
       Analyse en cas complets : la dimension est manquante des qu'UN
       SEUL indicateur manque, meme si l'autre indicateur est renseigne
       et positif. Aucun "sauvetage" par un indicateur deja positif. */
    gen byte m_toilet     = (toilet == 0) if !missing(toilet)
    /* Le partage des sanitaires n'est demande que si le menage dispose
       d'une installation propre : verifie empiriquement, la question est
       sautee a 100% quand le type de sanitaire (v_type_toi) est "Aucune
       toilette" (code 11) ou "Toilettes publiques" (code 10). Dans ces
       deux cas, la question ne s'applique pas (pas de sanitaire prive a
       "partager"), et m_toilet suffit deja a etablir la privation. */
    gen byte m_partag_toi = (`v_partag' == 1) if !missing(`v_partag')
    replace  m_partag_toi = 0 if missing(m_partag_toi) & inlist(`v_type_toi', 10, 11)
    gen byte dim_assai    = (m_toilet == 1 | m_partag_toi == 1) ///
        if !missing(m_toilet) & !missing(m_partag_toi)

    /* ── [Dimension 2/7 : Eau] ─────────────────────────────────────
       Indicateur 1 - Source d'eau de boisson non amelioree
       Indicateur 2 - Temps d'acces a l'eau > 30 min (saison seche OU pluies) */
    gen byte m_eau_source = (eauboi_ss == 0 | eauboi_sp == 0) ///
        if !missing(eauboi_ss) | !missing(eauboi_sp)
    /* Le temps d'acces (s11q29a/28a, s11q31a/30a) n'est demande que si le
       menage doit se deplacer pour s'approvisionner : le saut de question
       (verifie empiriquement, >94% de non-reponse) s'applique quand la
       source est un robinet dans le logement (code 1) ou dans la cour/
       concession (code 2), auquel cas le temps d'acces est nul par
       construction (eau sur place), et non manquant. */
    gen byte m_eau_temps  = (`v_tps_ss' > 30 & !missing(`v_tps_ss')) | ///
                             (`v_tps_sp' > 30 & !missing(`v_tps_sp')) ///
        if !missing(`v_tps_ss') | !missing(`v_tps_sp')
    replace  m_eau_temps  = 0 if missing(m_eau_temps) & ///
        inlist(`v_src_ss', 1, 2) & inlist(`v_src_sp', 1, 2)
    gen byte dim_eau      = (m_eau_source == 1 | m_eau_temps == 1) ///
        if !missing(m_eau_source) & !missing(m_eau_temps)

    /* ── [Dimension 3/7 : Logement] ────────────────────────────────
       Indicateur 1 - Debarras des ordures menageres inadequat
       Indicateur 2 - Surpeuplement (> 3 personnes par piece) */
    gen byte m_ordures = (ordure == 0) if !missing(ordure)
    gen byte m_surpeup = (hhsize / nb_pieces > 3) ///
        if !missing(nb_pieces) & nb_pieces > 0 & !missing(hhsize)
    gen byte dim_logem = (m_ordures == 1 | m_surpeup == 1) ///
        if !missing(m_ordures) & !missing(m_surpeup)

    /* ── [Dimension 4/7 : Nutrition] ───────────────────────────────
       Indicateur unique - Insecurite alimentaire (FIES) : membre ayant
       saute un repas, mange moins que necessaire, manque de nourriture,
       eu faim ou passe une journee sans manger (1=Oui ; 98/99 traites Non).
       Diversite alimentaire (module s08b1, 2018 uniquement) NON RETENUE
       pour rester comparable entre les deux vagues. Analyse en cas
       complets : manquant des qu'UNE SEULE des 5 questions du module
       manque, meme si une autre question etablit deja la privation. */
    gen byte m_securite = 0
    foreach v in s08aq04 s08aq05 s08aq06 s08aq07 s08aq08 {
        replace m_securite = 1 if `v' == 1 & !missing(`v')
    }
    egen byte n_miss_sec = rowmiss(s08aq04 s08aq05 s08aq06 s08aq07 s08aq08)
    replace m_securite = . if n_miss_sec > 0
    drop n_miss_sec
    gen byte dim_nutri = (m_securite == 1)

    /* ── [Dimension 5/7 : Sante] ────────────────────────────────────
       Indicateur unique - Combustible solide pour cuisiner (bois,
       charbon, dechets animaux). Acces a une structure de sante NON
       RETENU (module communautaire non comparable entre les vagues).
       Analyse en cas complets : manquant des qu'UNE SEULE des options
       de combustible manque, meme si une autre etablit deja la
       privation. */
    gen byte m_combust = 0
    foreach v of varlist `comb_vars' {
        replace m_combust = 1 if `v' >= 1 & !missing(`v')
    }
    egen byte n_miss_comb = rowmiss(`comb_vars')
    replace m_combust = . if n_miss_comb > 0
    drop n_miss_comb
    gen byte dim_sante = (m_combust == 1)

    /* ── [Dimension 6/7 : Protection de l'enfant] ────────────────────
       Indicateur 1 - Absence d'acte de naissance (non pertinent > 14 ans)
       Indicateur 2 - Travail des enfants (economique OU domestique
       >=1h, 5-14 ans uniquement)
       Indicateur 3 - Separation parentale (ne vit pas avec ses 2 parents)
       Combinaison par groupe d'age : 0-4 ans = ind.1 OU ind.3 ;
       5-14 ans = ind.1 OU ind.2 OU ind.3 ; 15-17 ans = ind.3 seul.
       replace ... if age > 14/hors 5-14 ans = non-applicabilite (pas une
       imputation de valeur manquante) : l'indicateur ne sert pas pour ce
       groupe d'age, quelle que soit l'info disponible. */
    gen byte m_acte_nais = (s01q05 == 2) if !missing(s01q05)
    replace  m_acte_nais = 0 if age > 14

    gen byte m_trav_enf = (eco == 1 & !missing(eco)) | (h_dom >= 1 & !missing(h_dom)) ///
        if age >= 5 & age <= 14 & (!missing(eco) | !missing(h_dom))
    replace  m_trav_enf = 0 if age < 5 | age > 14

    gen byte m_parents = (lien > 3) if !missing(lien)

    /* dim_protect manquante des qu'UN SEUL indicateur pertinent pour le
       groupe d'age de l'enfant lui manque (analyse en cas complets). */
    gen byte dim_protect = .
    replace  dim_protect = (m_acte_nais == 1 | m_parents == 1) ///
        if groupe_moda == 1 & !missing(m_acte_nais) & !missing(m_parents)
    replace  dim_protect = (m_acte_nais == 1 | m_trav_enf == 1 | m_parents == 1) ///
        if groupe_moda == 2 & !missing(m_acte_nais) & !missing(m_trav_enf) & !missing(m_parents)
    replace  dim_protect = (m_parents == 1) if groupe_moda == 3 & !missing(m_parents)

    /* ── [Dimension 7/7 : Education] ──────────────────────────────
       Indicateur 1 - Illettrisme, ne sait ni lire ni ecrire (15-17 ans)
       Indicateur 2 - Non-scolarisation (5-14 ans)
       Indicateur 3 - NEET, ni scolarise ni employe (15-17 ans)
       Combinaison par groupe d'age : 5-14 ans = ind.2 seul ;
       15-17 ans = ind.1 OU ind.3. */
    gen byte m_scol = (scol == 0) if age >= 5 & age <= 14 & !missing(scol)
    replace  m_scol = 0 if age < 5 | age > 14

    gen byte m_alfab = .
    if `annee' == 2018 {
        replace m_alfab = (alfab == 0) if age >= 15 & !missing(alfab)
    }
    else {
        capture confirm variable alfa
        if !_rc replace m_alfab = (alfa == 0) if age >= 15 & !missing(alfa)
    }
    replace m_alfab = 0 if age < 15

    gen byte m_neet = (scol == 0 & activ7j != 1) ///
        if age >= 15 & !missing(scol) & !missing(activ7j)
    replace  m_neet = 0 if age < 15

    /* Non applicable aux 0-4 ans (groupe_moda==1) : dim_educ = 0 par
       defaut, pas de "sauvetage" pour les 5-14 et 15-17 ans. */
    gen byte dim_educ = 0
    replace  dim_educ = m_scol if groupe_moda == 2
    replace  dim_educ = (m_alfab == 1 | m_neet == 1) ///
        if groupe_moda == 3 & !missing(m_alfab) & !missing(m_neet)
    replace  dim_educ = . if groupe_moda == 3 & (missing(m_alfab) | missing(m_neet))

    /* ── Agregation N-MODA (union intra-dimension, seuil k=$K_MODA) ── */
    gen byte nb_dep = dim_assai + dim_eau + dim_logem + dim_nutri + ///
                      dim_sante + dim_protect + dim_educ
    gen byte pauvre_MODA = (nb_dep >= $K_MODA) if !missing(nb_dep)

    /* Intensite moyenne N-MODA (Annexe II : A = part des 7 dimensions
       en privation, calculee sur les enfants pauvres pauvre_MODA==1) */
    gen float intensite_moda = nb_dep / 7

    /* ── Affichage ── */
    di _newline "=== N-MODA `annee' (k=$K_MODA, 7 dimensions) ==="
    quietly summarize pauvre_MODA
    di "  H = " %6.3f r(mean)*100 "%"
    di "  Privation par dimension :"
    foreach dim in assai eau logem nutri sante protect educ {
        quietly summarize dim_`dim'
        di "  `dim' : " %5.1f r(mean)*100 "%"
    }
    tabstat pauvre_MODA nb_dep, by(groupe_moda) stat(mean n) format(%6.3f)

    /* C. Sauvegarde */
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
   2. Statut de traitement : design "entrants" (DD classique)

   Design principal : ne conserve que les menages SANS transfert
   etranger a la periode de base (D_2018=0). On definit :
     - traites (D_stable=1) : entrants — aucun transfert en 2018,
       transfert etranger recu en 2021 (D=0 -> D=1)
     - temoins (D_stable=0) : jamais beneficiaires aux deux vagues
     - exclus  (D_stable=.) : menages deja beneficiaires en 2018
       (beneficiaires stables et sortants), dont le traitement est
       anterieur a la periode d'observation
   Le traitement debute donc ENTRE les deux vagues, conformement au
   design DD canonique (periode pre-traitement observee a t=0).
   ============================================================ */

use "$TEMP/traitement_2018.dta", clear
rename D D_2018
merge 1:1 grappe menage using "$TEMP/traitement_2021.dta", ///
    keepusing(D) keep(match) nogenerate
rename D D_2021
gen byte D_stable = .
replace D_stable = 1 if D_2018 == 0 & D_2021 == 1
replace D_stable = 0 if D_2018 == 0 & D_2021 == 0
label var D_stable "Traitement entrant (1=D 0->1, 0=jamais, .=deja beneficiaire en 2018)"

di _newline ">>> Cellules de traitement (menages presents aux 2 vagues) :"
tab D_2018 D_2021
quietly count if D_stable == 1
di "  Entrants (D=0->1)          : " r(N)
quietly count if D_stable == 0
di "  Jamais beneficiaires       : " r(N)
quietly count if missing(D_stable)
di "  Exclus (benef. en 2018)    : " r(N)

keep grappe menage D_stable D_2018 D_2021
save "$TEMP/traitement_stable.dta", replace

/* ============================================================
   3. Panel vrai — uniquement les menages suivis (PanelHH=1)

   On conserve les menages qui apparaissent dans les DEUX vagues
   avec le meme identifiant grappe+menage, avec un statut de
   traitement entrant (menages deja beneficiaires en 2018 exclus).
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
save "$TEMP/ids_panel.dta", replace   /* liste complete de tous les menages
    suivis, reutilisee par l'analyse de robustesse "beneficiaires stables" */

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

/* Appliquer le statut de traitement ENTRANT et exclure les menages
   deja beneficiaires en 2018 (traitement anterieur a la periode) */
merge m:1 grappe menage using "$TEMP/traitement_stable.dta", ///
    keepusing(D_stable) keep(master match) nogenerate
drop if missing(D_stable)
replace D = D_stable
drop D_stable
label var D "Traitement entrant (1=transfert etranger recu en 2021, aucun en 2018)"

di _newline "=== Panel vrai (design entrants) ==="
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

   Traitement : design ENTRANTS (aucun transfert en 2018 puis
   transfert etranger en 2021, vs jamais beneficiaire ; menages
   deja beneficiaires en 2018 exclus en 04_panel).

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
set dp comma
twoway ///
    (kdensity pscore if D == 0, lcolor(gs9) lwidth(medthick)) ///
    (kdensity pscore if D == 1, lcolor(orange) lwidth(medthick)), ///
    legend(order(1 "Jamais beneficiaires" 2 "Entrants (D=0 vers 1)")) ///
    xtitle("Score de propension") ytitle("Densité") ///
    saving("$OUTPUT/overlap_panel.gph", replace)
set dp period
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

di _newline "Balance avant/apres (SMD), methode kernel :"
pstest hhsize log_pcexp i.milieu i.region hgender hage i.heduc i.hmstat, both

rename _weight weight_kernel
keep grappe menage weight_kernel
save "$TEMP/poids_kernel.dta", replace

/* -- 2c. Caliper -------------------------------------------- */
di _newline "=== Appariement Caliper (eps=$CALIPER, sans remise) ==="
use "$TEMP/pscore_t0.dta", clear
psmatch2 D, pscore(pscore) caliper($CALIPER) noreplacement common

di _newline "Balance avant/apres (SMD), methode caliper :"
pstest hhsize log_pcexp i.milieu i.region hgender hage i.heduc i.hmstat, both

rename _weight weight_caliper
keep grappe menage weight_caliper
save "$TEMP/poids_caliper.dta", replace

/* ============================================================
   3. Statistiques descriptives sur le panel
   ============================================================ */

use "$TEMP/panel_vrai.dta", clear
di _newline "=== Stats descriptives (panel vrai, design entrants) ==="
tabstat pauvre_MODA nb_dep pcexp, ///
    by(D) stat(mean n) format(%6.3f)

/* ============================================================
   4. Double Difference brute (sans appariement, reference)
   ============================================================ */

di _newline "=== Double Difference brute (sans appariement) ==="
foreach outcome in pauvre_MODA {
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
foreach outcome in pauvre_MODA {
    di _newline "--- PSM-DD `outcome' ---"
    regress `outcome' i.t##i.D [aw=weight_knn], vce(cluster grappe)
    lincom 1.t#1.D
    di "  ATT_PSM-DD = " %8.4f r(estimate) ///
       "  SE = " %8.4f r(se) "  p = " %6.4f r(p)
    global ATT_REEL = r(estimate)   /* reutilise par le test placebo */
}

save "$TEMP/panel_apparie.dta", replace

/* ── Fig DD : trajectoires beneficiaires vs temoins + contrefactuel ──
   Illustre visuellement la double difference et permet d'apprecier
   l'hypothese de tendances paralleles. Les 4 moyennes de cellule sont
   ponderees par les poids d'appariement k-NN. Le contrefactuel applique
   la tendance des temoins au niveau initial des beneficiaires ; l'ecart
   au point observe de 2021 est l'ATT. */
quietly summarize pauvre_MODA if D==1 & t==0 [aw=weight_knn]
scalar dd_b0 = r(mean)*100
quietly summarize pauvre_MODA if D==1 & t==1 [aw=weight_knn]
scalar dd_b1 = r(mean)*100
quietly summarize pauvre_MODA if D==0 & t==0 [aw=weight_knn]
scalar dd_c0 = r(mean)*100
quietly summarize pauvre_MODA if D==0 & t==1 [aw=weight_knn]
scalar dd_c1 = r(mean)*100
scalar dd_cf1 = dd_b0 + (dd_c1 - dd_c0)   /* contrefactuel sous tendances paralleles */

preserve
clear
set obs 2
gen annee   = 2018 in 1
replace annee   = 2021 in 2
gen benef   = dd_b0 in 1
replace benef   = dd_b1 in 2
gen temoin  = dd_c0 in 1
replace temoin  = dd_c1 in 2
gen contref = dd_b0 in 1
replace contref = dd_cf1 in 2
gen str8 lb_b = subinstr(string(benef,  "%3.1f"), ".", ",", 1) + " %"
gen str8 lb_t = subinstr(string(temoin, "%3.1f"), ".", ",", 1) + " %"
/* etiquette du contrefactuel affichee seulement en 2021 (2018 = point benef) */
gen str8 lb_c = ""
replace  lb_c = subinstr(string(contref, "%3.1f"), ".", ",", 1) + " %" in 2

/* Positions d'etiquette par point pour eviter tout chevauchement :
   temoin au-dessus (12) ; entrants a droite du point en 2021 (3),
   hors des courbes, en dessous en 2018 (6) ; contrefactuel en
   dessous (6), avec un ecart accru. */
gen byte vp_b = 6
replace  vp_b = 3 in 2

set dp comma
twoway (connected temoin annee, lcolor(gs7) mcolor(gs7) msymbol(square) lwidth(medthick) ///
            mlabel(lb_t) mlabcolor(black) mlabpos(12) mlabgap(3) mlabsize(small)) ///
       (connected benef annee, lcolor(orange) mcolor(orange) msymbol(circle) lwidth(medthick) ///
            mlabel(lb_b) mlabcolor(black) mlabvpos(vp_b) mlabgap(3) mlabsize(small)) ///
       (connected contref annee, lcolor(orange) lpattern(dash) msymbol(diamond_hollow) ///
            mcolor(orange) lwidth(medthick) ///
            mlabel(lb_c) mlabcolor(black) mlabpos(6) mlabgap(4.5) mlabsize(small)), ///
    xlabel(2018 2021) xscale(range(2017.7 2021.8)) ///
    xtitle("Vague EHCVM") ytitle("Incidence N-MODA (H, %)") ///
    ylabel(0(20)100, grid) ///
    legend(order(2 "Entrants" 1 "Témoins appariés" ///
                 3 "Contrefactuel (tendances parallèles)") pos(6) rows(2)) ///
    graphregion(color(white)) plotregion(color(white))
set dp period
graph export "$OUTPUT/figures/fig_dd_trajectoires.pdf", replace
di ">>> fig_dd_trajectoires.pdf sauvegardé"
restore

/* ============================================================
   6. Heterogeneite
   ============================================================ */

/* -- 6a. Par milieu de residence ---------------------------- */
di _newline "=== Heterogeneite par milieu ==="
foreach mil in 1 2 {
    if `mil' == 1 local lab_mil "Urbain"
    else          local lab_mil "Rural"

    foreach outcome in pauvre_MODA {
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
foreach outcome in pauvre_MODA {
    regress `outcome' i.t##i.D##i.urban [aw=weight_knn], vce(cluster grappe)
    lincom 1.t#1.D#1.urban
    di "  Diff ATT (urbain - rural) : " %8.4f r(estimate) "  p = " %6.4f r(p)
}
drop urban

/* -- 6b. Par sexe de l'enfant ------------------------------- */
di _newline "=== Heterogeneite par sexe ==="
capture confirm variable sexe
if _rc == 0 {
    foreach outcome in pauvre_MODA {
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
    foreach outcome in pauvre_MODA {
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

/* -- 7. Robustesse aux trois methodes d'appariement -------- */
di _newline "=== Comparaison des trois methodes d'appariement ==="
foreach poids_var in weight_kernel weight_caliper {
    merge m:1 grappe menage using "$TEMP/poids_`=substr("`poids_var'",8,.)'.dta", ///
        keepusing(`poids_var') keep(master match) nogenerate
}
foreach poids_var in weight_knn weight_kernel weight_caliper {
    foreach outcome in pauvre_MODA {
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

/* ============================================================
   8. Robustesse : definition alternative du traitement
      (beneficiaires stables)

   En complement du design principal (entrants, DD canonique avec
   periode pre-traitement observee), l'ATT est aussi estime en
   comparant les beneficiaires STABLES (D_2018=1 et D_2021=1) aux
   menages jamais beneficiaires, sur les memes menages panel. Ce
   design capte l'effet d'une exposition durable aux transferts,
   mais le traitement y est deja en cours a t=0 : la periode de
   base n'est pas une periode pre-traitement, ce qui fragilise
   l'interpretation causale canonique de la DD. Fourni ici a titre
   de comparaison.
   ============================================================ */

use "$TEMP/ids_panel.dta", clear
tempfile menages_panel
save `menages_panel'

use "$TEMP/vague_2018.dta", clear
merge m:1 grappe menage using `menages_panel', keep(match) nogenerate
merge m:1 grappe menage using "$TEMP/traitement_stable.dta", ///
    keepusing(D_2018 D_2021) keep(match) nogenerate
tempfile alt_t0
save `alt_t0'

use "$TEMP/vague_2021.dta", clear
merge m:1 grappe menage using `menages_panel', keep(match) nogenerate
merge m:1 grappe menage using "$TEMP/traitement_stable.dta", ///
    keepusing(D_2018 D_2021) keep(match) nogenerate
tempfile alt_t1
save `alt_t1'

use `alt_t0', clear
append using `alt_t1'

/* Restreindre aux menages a statut constant : beneficiaires stables
   (D=1 aux deux vagues) et jamais beneficiaires (D=0 aux deux vagues) */
keep if D_2018 == D_2021
gen byte D_stable_alt = D_2018
label var D_stable_alt "1=beneficiaire stable (2 vagues), 0=jamais beneficiaire"

quietly count if D_stable_alt == 1 & t == 0
local n_sta = r(N)
quietly count if D_stable_alt == 0 & t == 0
local n_jam = r(N)
di _newline "=== Robustesse : beneficiaires stables vs jamais beneficiaires ==="
di "  Beneficiaires stables (D=1 aux 2 vagues) : `n_sta' obs"
di "  Jamais beneficiaires (aux 2 vagues)      : `n_jam' obs"

di _newline "--- DD brute, beneficiaires stables vs jamais beneficiaires ---"
regress pauvre_MODA i.t##i.D_stable_alt, vce(cluster grappe)
lincom 1.t#1.D_stable_alt
di "  ATT_DD_stables = " %8.4f r(estimate) ///
   "  SE = " %8.4f r(se) "  p = " %6.4f r(p)

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

/* ── Fig profil : ménages bénéficiaires vs non-bénéficiaires ──
   Comparaison visuelle du profil socio-demographique selon le statut de
   transfert (EHCVM I), en complement du tableau de balance (tab_balance). */
preserve
    replace chef_f = chef_f * 100
    replace urbain = urbain * 100
    label define statutD 0 "Non-beneficiaires" 1 "Beneficiaires", replace
    label values D statutD
    set dp comma
    graph bar (mean) chef_f urbain, over(D) ///
        bar(1, color(gs9)) bar(2, color(orange)) ///
        blabel(bar, position(center) color(white) format(%4,1f)) ///
        legend(order(1 "Chef feminin (%)" 2 "Milieu urbain (%)") pos(6) rows(1)) ///
        ytitle("Part des menages (%)") ylabel(0(20)100, grid) ///
        graphregion(color(white)) plotregion(color(white))
    set dp period
    graph export "$OUTPUT/figures/fig_profil_statut.pdf", replace
    di ">>> fig_profil_statut.pdf sauvegardé"
restore

/* ============================================================
   2bis. Caracteristiques des transferts etrangers recus :
   motifs declares et montants annualises

   Source : module detail des transferts (une ligne par transfert).
   Restreint aux transferts dont l'expediteur reside a l'etranger
   (meme definition que le traitement D). Le montant annuel est
   obtenu en multipliant le montant par envoi par la frequence
   declaree (mois x12, trimestre x4, semestre x2, annee x1 ;
   irregulier = montant deja declare sur 12 mois, x1), puis somme
   au niveau menage sur l'ensemble de ses transferts etrangers.
   ============================================================ */

di _newline "=== 2bis. Motifs et montants des transferts etrangers ==="

foreach annee in 2018 2021 {

    if `annee' == 2018 {
        local base      "$BASE_2018"
        local fich_det  s13a_2
        local v_lieu    s13aq14
        local v_motif   s13aq15
        local v_montant s13aq17a
        local v_freq    s13aq17b
    }
    else {
        local base      "$BASE_2021"
        local fich_det  s13_2
        local v_lieu    s13q19
        local v_motif   s13q20
        local v_montant s13q22a
        local v_freq    s13q22b
    }

    use "`base'/`fich_det'_me_sen`annee'.dta", clear
    keep if `v_lieu' >= $CODE_ETRANGER_MIN & !missing(`v_lieu')

    quietly count
    di _newline "-- `annee' : " r(N) " transferts etrangers --"

    di "  Repartition des motifs (%):"
    tab `v_motif'

    /* Montant annualise par transfert */
    gen double mult = .
    replace mult = 12 if `v_freq' == 1   /* mois       */
    replace mult = 4  if `v_freq' == 2   /* trimestre  */
    replace mult = 2  if `v_freq' == 3   /* semestre   */
    replace mult = 1  if `v_freq' == 4   /* annee      */
    replace mult = 1  if `v_freq' == 5   /* irregulier : montant sur 12 mois */
    gen double montant_annuel = `v_montant' * mult

    /* Somme au niveau menage */
    collapse (sum) montant_annuel, by(grappe menage)
    di "  Montant annuel recu par menage beneficiaire (FCFA) :"
    summarize montant_annuel, detail
}

/* ============================================================
   3. Incidence N-MODA par vague, milieu, groupe d'âge
   ============================================================ */

di _newline "=== 3. Incidence pauvreté multidimensionnelle ==="

foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear

    di _newline "-- N-MODA `annee' --"
    tabstat pauvre_MODA nb_dep, ///
        by(milieu) stat(mean n) format(%6.3f)
    tabstat pauvre_MODA nb_dep, ///
        by(groupe_moda) stat(mean n) format(%6.3f)
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

/* ── Fig 1 : Évolution H N-MODA par vague ── */
foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear
    quietly summarize pauvre_MODA
    scalar H_moda_`annee' = r(mean)*100
}
clear
set obs 2
gen annee  = 2018 in 1
replace annee  = 2021 in 2
gen H_MODA = H_moda_2018 in 1
replace H_MODA = H_moda_2021 in 2
gen str12 lbl_H = subinstr(string(H_MODA, "%3.1f"), ".", ",", 1) + " %"

set dp comma
twoway (connected H_MODA annee, lcolor(orange) mcolor(orange) msymbol(circle)  lwidth(medthick) ///
        mlabel(lbl_H) mlabcolor(black) mlabpos(12) mlabgap(2) mlabsize(medium)), ///
    xlabel(2018 2021) xscale(range(2017.7 2021.3)) xtitle("Vague EHCVM") ytitle("Incidence H (%)") ///
    ylabel(0(20)100, grid) yscale(range(0 108)) ///
    legend(order(1 "N-MODA (k=4, 7 dim.)") pos(6) rows(1)) ///
    graphregion(color(white)) plotregion(color(white))
set dp period
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
set dp comma
graph bar v2018 v2021, over(dim, sort(ordre) label(angle(30))) ///
    bar(1, color(gs9)) bar(2, color(orange)) ///
    blabel(bar, position(center) color(white) format(%4,1f) size(vsmall)) ///
    legend(order(1 "EHCVM I (2018-19)" 2 "EHCVM II (2021-22)") pos(6) rows(1)) ///
    ytitle("Taux de privation (%)") ylabel(0(20)100, grid) ///
    graphregion(color(white)) plotregion(color(white))
set dp period
graph export "$OUTPUT/figures/fig_privations_dim.pdf", replace
di ">>> fig_privations_dim.pdf sauvegardé"

/* ── Fig 3 : Pauvreté par milieu et groupe d'âge (EHCVM I et II) ──
   Barres groupées : les deux vagues côte à côte pour chaque groupe
   d'âge, panneaux urbain/rural. */
use "$TEMP/vague_2018.dta", clear
keep pauvre_MODA groupe_moda milieu
gen byte vague = 1
tempfile mag_w1
save `mag_w1'

use "$TEMP/vague_2021.dta", clear
keep pauvre_MODA groupe_moda milieu
gen byte vague = 2
append using `mag_w1'

collapse (mean) pauvre_MODA, by(vague groupe_moda milieu)
replace pauvre_MODA = pauvre_MODA * 100
reshape wide pauvre_MODA, i(groupe_moda milieu) j(vague)

set dp comma   /* etiquettes decimales avec virgule */
graph bar pauvre_MODA1 pauvre_MODA2, over(groupe_moda) over(milieu) ///
    bar(1, color(gs9)) bar(2, color(orange)) ///
    blabel(bar, position(center) color(white) format(%4,1f) size(vsmall)) ///
    legend(order(1 "EHCVM I (2018-19)" 2 "EHCVM II (2021-22)") pos(6) rows(1)) ///
    ytitle("Incidence N-MODA (H, %)") ylabel(0(20)100, grid) ///
    graphregion(color(white)) plotregion(color(white))
set dp period
graph export "$OUTPUT/figures/fig_pauvrete_milieu_age.pdf", replace
di ">>> fig_pauvrete_milieu_age.pdf sauvegardé"

/* ── Fig 4 : Distribution nb_dep par statut de traitement ── */
use "$TEMP/vague_2018.dta", clear
merge m:1 grappe menage using "$TEMP/traitement_2018.dta", ///
    keepusing(D) nogenerate keep(master match)
replace D = 0 if missing(D)
label define dl 0 "Non-bénéficiaires" 1 "Bénéficiaires", replace
label values D dl

set dp comma
histogram nb_dep, by(D, cols(1) note("")) ///
    fraction width(1) gap(10) ///
    color(gs9) lcolor(white) ///
    xtitle("Nombre de dimensions en privation (sur 7)") ///
    ytitle("Fraction") ylabel(, format(%4.2f) grid) ///
    graphregion(color(white)) plotregion(color(white))
set dp period
graph export "$OUTPUT/figures/fig_distrib_nbdep.pdf", replace
di ">>> fig_distrib_nbdep.pdf sauvegardé"

/* ── Fig 5 : Distribution du nombre de dimensions en privation ──
   Abscisse : nombre exact de dimensions en privation (0 a 7).
   Ordonnee  : part des enfants (%), a l'image du rapport ANSD/UNICEF
   N-MODA. Ligne verticale entre 3 et 4 marquant le seuil k=4 retenu. */
tempname distrib
matrix `distrib' = J(8, 3, .)
foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear
    local col = cond(`annee' == 2018, 2, 3)
    quietly count if !missing(nb_dep)
    local n_tot = r(N)
    forvalues d = 0/7 {
        quietly count if nb_dep == `d' & !missing(nb_dep)
        matrix `distrib'[`d' + 1, 1] = `d'
        matrix `distrib'[`d' + 1, `col'] = r(N) / `n_tot' * 100
    }
}
clear
svmat `distrib', names(col)
rename c1 nb_dim
rename c2 pct_2018
rename c3 pct_2021
gen str8 lbl_18 = subinstr(string(pct_2018, "%3.1f"), ".", ",", 1)
gen str8 lbl_21 = subinstr(string(pct_2021, "%3.1f"), ".", ",", 1)
gen x_2018 = nb_dim - 0.19
gen x_2021 = nb_dim + 0.19

set dp comma
graph twoway ///
    (bar pct_2018 x_2018, barwidth(0.35) color(gs9)) ///
    (bar pct_2021 x_2021, barwidth(0.35) color(orange)) ///
    (scatter pct_2018 x_2018, msymbol(none) mlabel(lbl_18) ///
     mlabpos(12) mlabcolor(black) mlabsize(vsmall)) ///
    (scatter pct_2021 x_2021, msymbol(none) mlabel(lbl_21) ///
     mlabpos(12) mlabcolor(black) mlabsize(vsmall)) ///
    , xline(3.5, lcolor(red) lpattern(dash) lwidth(medthick)) ///
    xlabel(0(1)7) xtitle("Nombre de dimensions en privation (sur 7)") ///
    ylabel(0(5)30, grid) ytitle("Part des enfants (%)") ///
    legend(order(1 "EHCVM I (2018-19)" 2 "EHCVM II (2021-22)") pos(6) rows(1)) ///
    graphregion(color(white)) plotregion(color(white))
set dp period
graph export "$OUTPUT/figures/fig_distrib_dimensions.pdf", replace
di ">>> fig_distrib_dimensions.pdf sauvegardé"

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

/* Etiquettes de valeur (virgule decimale), placees au-dela des IC */
gen str8 lbl_att = subinstr(string(att, "%4.1f"), ".", ",", 1)
gen xlbl = ub + 1.2 if att >= 0
replace xlbl = lb - 1.2 if att < 0

/* Graphique à barres horizontales avec IC 95 % */
set dp comma
twoway ///
    (bar att ordre, horizontal barwidth(0.6) color(gs9)) ///
    (rcap lb ub ordre, horizontal lcolor(orange) lwidth(medthick) msize(medium)) ///
    (scatter ordre xlbl, msymbol(none) mlabel(lbl_att) ///
     mlabpos(0) mlabcolor(black) mlabsize(small)), ///
    ylab(`ylab_str', angle(0) noticks) ///
    yscale(range(0.5 7.5)) ///
    ytitle("") xtitle("ATT (points de pourcentage)") ///
    xline(0, lcolor(black) lpattern(dash)) ///
    legend(off) ///
    graphregion(color(white)) plotregion(color(white))

set dp period
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
   1. Incidence N-MODA par région (EHCVM I et II)
   ============================================================ */

/* Moyenne brute par région, pour chacune des deux vagues */
matrix H_reg = J(14, 3, .)
foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear
    local col = cond(`annee' == 2018, 2, 3)
    quietly summarize pauvre_MODA
    scalar H_nat_`annee' = r(mean)*100
    levelsof region, local(regs)
    local i = 0
    foreach r of local regs {
        local ++i
        quietly summarize pauvre_MODA if region == `r'
        matrix H_reg[`i', 1] = `r'
        matrix H_reg[`i', `col'] = r(mean)*100
        local lbl : label (region) `r'
        di "Région `r' (`lbl'), `annee' : H=" %5.1f r(mean)*100 "%"
    }
}

/* ── Fig carte : barres horizontales par région, deux vagues côte
   à côte (gris = EHCVM I, orange = EHCVM II) ── */
preserve
    clear
    svmat H_reg, names(col)
    rename c1 cod_reg
    rename c2 H_2018
    rename c3 H_2021
    sort H_2018
    gen ordre = _n
    gen str30 nom_reg = ""
    /* Correspondance codes vers noms régions Sénégal */
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

    /* Lignes de reference nationales : valeurs figees en local AVANT
       set dp comma (l'expansion `=...' sous dp comma produirait une
       virgule qui casserait la syntaxe de xline) */
    local xl_2018 = scalar(H_nat_2018)
    local xl_2021 = scalar(H_nat_2021)
    set dp comma
    /* Positions decalees : EHCVM I au-dessus, EHCVM II en dessous */
    gen y_2018 = ordre + 0.19
    gen y_2021 = ordre - 0.19
    gen mid_2018 = H_2018/2
    gen mid_2021 = H_2021/2

    twoway (bar H_2018 y_2018, horizontal barwidth(0.35) ///
            color(gs9) lcolor(white)) ///
           (bar H_2021 y_2021, horizontal barwidth(0.35) ///
            color(orange) lcolor(white)) ///
           (scatter y_2018 mid_2018, msymbol(none) ///
            mlabel(H_2018) mlabformat(%4,1f) mlabcolor(white) mlabpos(0) mlabsize(tiny)) ///
           (scatter y_2021 mid_2021, msymbol(none) ///
            mlabel(H_2021) mlabformat(%4,1f) mlabcolor(white) mlabpos(0) mlabsize(tiny)), ///
        legend(order(1 "EHCVM I (2018-19)" 2 "EHCVM II (2021-22)") pos(6) rows(1)) ///
        ylab(`ylab_str', angle(0) noticks labsize(small)) ///
        yscale(range(0.5 14.5)) ///
        xtitle("Incidence N-MODA H (%)") ytitle("") ///
        xlabel(0(10)100, grid) ///
        xline(`xl_2018', lcolor(gs9) lpattern(dash) lwidth(medthin)) ///
        xline(`xl_2021', lcolor(orange) lpattern(dash) lwidth(medthin)) ///
        graphregion(color(white)) plotregion(color(white))
    set dp period
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

    /* Etiquette au centre (blanc) pour les barres longues, a droite
       (noir) pour les barres trop courtes */
    gen mid_lbl = pct/2 if pct >= 10
    gen out_lbl = pct + 2.5 if pct < 10
    set dp comma
    twoway (bar pct ordre, horizontal barwidth(0.45) ///
            color(gs9) lcolor(white)) ///
           (scatter ordre mid_lbl, msymbol(none) ///
            mlabel(pct) mlabformat(%4,1f) mlabcolor(white) mlabpos(0) mlabsize(small)) ///
           (scatter ordre out_lbl, msymbol(none) ///
            mlabel(pct) mlabformat(%4,1f) mlabcolor(black) mlabpos(0) mlabsize(small)), ///
        ylab(`ylab_str', angle(0) noticks labsize(small)) ///
        yscale(range(0.5 4.5)) ysize(3.2) xsize(6.8) ///
        xtitle("Part des enfants 0-17 ans (%)") ytitle("") ///
        xlabel(0(20)100, grid) ///
        legend(off) ///
        graphregion(color(white)) plotregion(color(white))
    set dp period
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
matrix PLA = J(`n_rep', 1, .)   /* col 1 = MODA */

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
/* part de faux traites = part observee de traites (entrants) parmi les
   menages du panel d'analyse, calculee dynamiquement */
preserve
    use "$TEMP/panel_vrai.dta", clear
    keep if t == 0
    bysort grappe menage: keep if _n == 1
    quietly summarize D
    local part_fake = r(mean)
restore
di "  Part de faux traites appliquee : " %6.4f `part_fake'

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
        foreach y in pauvre_MODA {
            summarize `y' if t==1 & fakeD==1
            local m11 = r(mean)
            summarize `y' if t==0 & fakeD==1
            local m01 = r(mean)
            summarize `y' if t==1 & fakeD==0
            local m10 = r(mean)
            summarize `y' if t==0 & fakeD==0
            local m00 = r(mean)
            local att = (`m11'-`m01') - (`m10'-`m00')
            matrix PLA[`r',1] = `att'
        }
    }
    if mod(`r', 50) == 0 di "  replication `r'/`n_rep'"
}

/* Statistiques de la distribution placebo */
clear
svmat PLA, names(col)
rename c1 att_moda
foreach y in moda {
    quietly summarize att_`y'
    di _newline "Placebo `y' : moyenne=" %7.4f r(mean) "  sd=" %6.4f r(sd)
    quietly count if abs(att_`y') > 0.05
    di "  fraction |ATT|>0.05 : " %4.1f 100*r(N)/`n_rep' "%"
}

/* ── Fig placebo : distribution des ATT placebo vs ATT reel ──
   Verifie la plausibilite des tendances paralleles : la distribution
   placebo doit etre centree sur zero et l'ATT reel doit se situer dans
   sa queue. */
scalar att_reel = $ATT_REEL   /* ATT PSM-DD principal, sauvegarde en section 5 */
local xl_att = scalar(att_reel)
set dp comma
histogram att_moda, width(0.005) frequency ///
    color(gs9) lcolor(white) ///
    xline(0, lcolor(black) lpattern(solid)) ///
    xline(`xl_att', lcolor(orange) lpattern(dash) lwidth(medthick)) ///
    xtitle("ATT placebo (faux traitement aléatoire)") ///
    ytitle("Nombre de réplications") ///
    xlabel(-0.06(0.02)0.10, grid) ///
    graphregion(color(white)) plotregion(color(white))
set dp period
graph export "$OUTPUT/figures/fig_placebo_dd.pdf", replace
di ">>> fig_placebo_dd.pdf sauvegardé"

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
   presence dans panel_vrai.dta, qui exclut aussi les menages deja beneficiaires en 2018 et
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

/* ============================================================
   SECTION FINALE : copie des figures vers le rapport LaTeX
   ------------------------------------------------------------
   Recopie automatiquement les PDF generes dans output/figures
   vers latex/figures, pour que le memoire compile toujours les
   dernieres versions sans manipulation manuelle.
   ============================================================ */

di _newline ">>> Copie des figures vers latex/figures ..."
local figs fig_evolution_ipm fig_privations_dim fig_pauvrete_milieu_age ///
           fig_distrib_nbdep fig_effets_dim fig_carte_nmoda fig_croisement_pauvrete ///
           fig_dd_trajectoires fig_placebo_dd fig_profil_statut fig_distrib_dimensions
foreach f of local figs {
    capture copy "$OUTPUT/figures/`f'.pdf" "latex/figures/`f'.pdf", replace
    if _rc di "    !! echec copie `f'.pdf (rc=" _rc ")"
    else   di "    ok `f'.pdf"
}
/* Graphique de support commun (a la racine de output) */
capture copy "$OUTPUT/overlap_panel.pdf" "latex/figures/overlap_panel.pdf", replace

di _newline ">>> FIN DU PIPELINE COMPLET <<<"

