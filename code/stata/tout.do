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
     05_psm_dd      — estimation PSM-DD (matching niveau enfant)
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

/* Donnees brutes : telechargement direct depuis le depot GitHub (public).
   Stata lit les fichiers .dta via https avec use/merge, sans copie locale
   prealable. Chaque execution re-telecharge les bases (~300 Mo au total),
   prevoir une bonne connexion. Les sorties (temp, output, logs) restent
   ecrites en local, car save ne peut pas ecrire vers une URL. */
global RAW       "https://raw.githubusercontent.com/JODRAFF9/MEMOIRE/main"
global BASE_2018 "$RAW/Base/2018-2019/SEN_2018_EHCVM_v02_M_Stata"
global BASE_2021 "$RAW/Base/2021-2022/SEN_2021_EHCVM-2_v01_M_STATA14"
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


/* ============================================================
   SECTION : 01_VISITATION — Exploration des deux bases EHCVM
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

   D = 1 si le menage a recu un transfert de l'etranger
   panel_id = identifiant unique grappe-menage pour le panel vrai

   NB : s13aq14 (2018) et s13q19 (2021) indiquent le pays de
        l'expediteur ; >= CODE_ETRANGER_MIN => transfert etranger
   ============================================================ */


/* ── Construction pour chaque vague ──────────────────────── */

di _newline ">>> Prevalence des transferts de migrants :"
local annee 2018
local var_lieu s13aq14
local var_exmbr s13aq12
local fich_det s13a_2
local fich_list s13a_1

    /* Resoudre le chemin de base selon l'annee (evite l'ambiguite $BASE_`annee') */
    if `annee' == 2018 local base "$BASE_2018"
    else               local base "$BASE_2021"

    /* Identifier les menages avec au moins un transfert etranger */
    use "`base'/`fich_det'_me_sen`annee'.dta", clear
    /* Transfert etranger ET expediteur ancien membre du menage (var_exmbr==1,
       s13aq12 en 2018 / s13q17 en 2021) : seuls ces transferts relevent de la
       migration d'un membre du menage (theorie des reseaux migratoires). Les
       transferts d'un expediteur n'ayant jamais vecu dans le menage sont
       ecartes du traitement. */
    keep if `var_lieu' >= $CODE_ETRANGER_MIN & !missing(`var_lieu') ///
        & `var_exmbr' == 1
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

    /* ── Intensite du traitement : montant annuel recu ────────────
       Meme perimetre que D (transfert etranger d'un ex-membre du menage).
       Le montant par envoi est annualise par la frequence declaree, puis
       somme sur l'ensemble des transferts eligibles du menage.
       v_montant / v_freq : s13aq17a/b en 2018, s13q22a/b en 2021. */
    if `annee' == 2018 {
        local v_montant s13aq17a
        local v_freq    s13aq17b
    }
    else {
        local v_montant s13q22a
        local v_freq    s13q22b
    }
    use "`base'/`fich_det'_me_sen`annee'.dta", clear
    keep if `var_lieu' >= $CODE_ETRANGER_MIN & !missing(`var_lieu') ///
        & `var_exmbr' == 1
    gen double mult = .
    replace mult = 12 if `v_freq' == 1   /* mois       */
    replace mult = 4  if `v_freq' == 2   /* trimestre  */
    replace mult = 2  if `v_freq' == 3   /* semestre   */
    replace mult = 1  if `v_freq' == 4   /* annee      */
    replace mult = 1  if `v_freq' == 5   /* irregulier : deja sur 12 mois */
    gen double montant = `v_montant' * mult
    collapse (sum) montant_transf = montant, by(grappe menage)
    drop if montant_transf <= 0
    label var montant_transf "Montant annuel de transferts recus (FCFA)"
    save "$TEMP/montant_`annee'.dta", replace
    di "  Montant annuel (menages beneficiaires, `annee') :"
    summarize montant_transf, detail

local annee 2021
local var_lieu s13q19
local var_exmbr s13q17
local fich_det s13_2
local fich_list s13_1

    /* Resoudre le chemin de base selon l'annee (evite l'ambiguite $BASE_`annee') */
    if `annee' == 2018 local base "$BASE_2018"
    else               local base "$BASE_2021"

    /* Identifier les menages avec au moins un transfert etranger */
    use "`base'/`fich_det'_me_sen`annee'.dta", clear
    /* Transfert etranger ET expediteur ancien membre du menage (var_exmbr==1,
       s13aq12 en 2018 / s13q17 en 2021) : seuls ces transferts relevent de la
       migration d'un membre du menage (theorie des reseaux migratoires). Les
       transferts d'un expediteur n'ayant jamais vecu dans le menage sont
       ecartes du traitement. */
    keep if `var_lieu' >= $CODE_ETRANGER_MIN & !missing(`var_lieu') ///
        & `var_exmbr' == 1
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

   Approche : N-MODA Senegal (7 dimensions, k=4)

   Produit : $TEMP/enfants_dep_ANNEE.dta pour annee in {2018, 2021}
   ============================================================ */


/* --------------------------------------------------------------------------
   N-MODA — 7 dimensions, seuil k=4, unite = enfant. Definitions RETENUES
   (telles qu'implementees ci-dessous ; variables 2018 / 2021) :

   1. ASSAINISSEMENT   m_toilet (s11q55/54) ; m_partag_toi (s11q56/55)
   2. EAU             m_eau_source (s11q26a/b, filtre s11q32/31)
                      m_eau_temps  (s11q29a/28a, s11q31a/30a)
   3. LOGEMENT        m_ordures (s11q54/53) ; m_surpeup (hhsize / s11q02)
   4. NUTRITION       m_securite (s08a, 8 questions FIES)
   5. SANTE           m_combust (s11q53/52) ; m_sante_acces (s02_co, s02q02)
   6. PROTECTION      m_acte_nais (s01q05) ; m_trav_enf (s04) ;
                      m_parents (s01q22/s01q29)
   7. EDUCATION       m_scol (scol) ; m_alfab (alfab)
                      m_neet calcule a titre descriptif, hors agregat
   -------------------------------------------------------------------------- */

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
        local v_tps_ss_h "s11q29b_heure"
        local v_tps_ss_m "s11q29b_minute"
        local v_tps_sp_h "s11q31b_heure"
        local v_tps_sp_m "s11q31b_minutes"
        local v_comb   "s11q53"
        local v_src_ss "s11q27a"
        local v_src_sp "s11q27b"
        local v_treat  "s11q33"
        local v_gate   "s11q32"   /* filtre traitement de l'eau : 1=oui, 2=non,
                                     3=ne sait pas. Denominateur = repondants (1/2) */
        local v_ordure "s11q54"   /* mode de debarras des ordures menageres */
    }
    else {
        local v_partag "s11q55"
        local v_type_toi "s11q54"
        local v_tps_ss "s11q28a"
        local v_tps_sp "s11q30a"
        local v_tps_ss_h "s11q28b_heure"
        local v_tps_ss_m "s11q28b_minute"
        local v_tps_sp_h "s11q30b_heure"
        local v_tps_sp_m "s11q30b_minutes"
        local v_comb   "s11q52"
        local v_src_ss "s11q26a"
        local v_src_sp "s11q26b"
        local v_treat  "s11q32"   /* methode de traitement de l'eau EHCVM II
                                     (s11q31 = traite/non ; s11q32 = methode) */
        local v_gate   "s11q31"   /* filtre traitement de l'eau : 1=oui, 2=non,
                                     3=ne sait pas. Denominateur = repondants (1/2) */
        local v_ordure "s11q53"   /* mode de debarras des ordures menageres */
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
        keepusing(eauboi_ss eauboi_sp ordure) ///
        nogenerate keep(master match)

    /* A4. Module habitat (s11_me) : partage toilettes, temps d'acces
       a l'eau, nombre de pieces, combustible de cuisine. */
    preserve
        use "`base'/s11_me_sen`annee'.dta", clear
        local v_opt "`v_treat'* `v_tps_ss_h' `v_tps_ss_m' `v_tps_sp_h' `v_tps_sp_m'"
        capture keep grappe menage s11q02 `v_partag' `v_type_toi' `v_tps_ss' `v_tps_sp' ///
            `v_src_ss' `v_src_sp' `v_gate' `v_ordure' `comb_vars' `v_opt'
        if _rc {
            di as error ">>> ATTENTION : variables eau optionnelles (traitement `v_treat'__* et/ou temps a la source `v_tps_ss_h'...) introuvables pour `annee' : verifier les noms."
            keep grappe menage s11q02 `v_partag' `v_type_toi' `v_tps_ss' `v_tps_sp' ///
                `v_src_ss' `v_src_sp' `v_gate' `v_ordure' `comb_vars'
        }
        rename s11q02 nb_pieces
        tempfile s11_temp
        save `s11_temp'
    restore
    merge m:1 grappe menage using `s11_temp', nogenerate keep(master match)

    /* A4bis. Module communautaire (s02_co) : acces a pied a une structure
       de sante (hopital, service 5 ; autre centre de sante public, service 6).
       Structure du questionnaire : a la question 2.01 "Ce service existe-t-il
       dans la localite ?", une reponse OUI saute directement a 2.04, SANS
       poser le mode d'acces 2.02. Le mode (2.02, 1=Pieds) n'est donc renseigne
       que pour les services ABSENTS localement (trajet vers le plus proche).

       Est prive l'enfant dont le MODE habituel pour rejoindre une
       structure publique (services 5/6) n'est pas la marche (s02q02==1).
       L'existence d'une structure sur place n'est pas assimilee a un acces
       a pied. Agregation par grappe en OU : collapse (max) sur pfoot.
       Le residu par rapport a l'ANSD tient aux localites disposant d'une
       structure sur place, pour lesquelles le mode d'acces n'est pas
       renseigne. 2018 : identifiant du service dans
       s02q00. 2021 : s02q00 absent (26 services, meme ordre, 26 lignes/grappe
       -> identifiant = rang de la ligne). */
    preserve
        use "`base'/s02_co_sen`annee'.dta", clear
        gen long _ord = _n
        if `annee' == 2018  gen int svc_id = s02q00
        else                bysort grappe (_ord): gen int svc_id = _n
        keep if inlist(svc_id, 5, 6)
        /* Acces a pied STRICT : mode habituel = marche (s02q02==1).
           L'existence locale n'implique pas l'acces a pied -> non retenue. */
        gen byte pfoot = (s02q02 == 1)
        collapse (max) sante_pfoot = pfoot, by(grappe)
        tempfile s02_temp
        save `s02_temp'
    restore
    merge m:1 grappe using `s02_temp', keepusing(sante_pfoot) ///
        nogenerate keep(master match)
    gen byte m_sante_acces = (sante_pfoot != 1)

    /* A5. Securite alimentaire (s08a_me), variables brutes (traitement Non-retenu en calcul) */
    preserve
        use "`base'/s08a_me_sen`annee'.dta", clear
        keep grappe menage s08aq01 s08aq02 s08aq03 s08aq04 s08aq05 ///
                           s08aq06 s08aq07 s08aq08
        tempfile s08a_temp
        save `s08a_temp'
    restore
    merge m:1 grappe menage using `s08a_temp', nogenerate keep(master match)

    /* A6. Acte de naissance + presence des parents biologiques (s01_me),
       cle individuelle. s01q22 = "Le pere de [NOM] habite-t-il dans le
       menage ?" ; s01q29 = "La mere de [NOM] habite-t-elle dans le menage ?"
       (1=Oui, 2=Non, memes codes 2018/2021). */
    preserve
        use "`base'/s01_me_sen`annee'.dta", clear
        if `annee' == 2018 rename s01q00a numind
        else               rename membres__id numind
        keep grappe menage numind s01q05 s01q22 s01q29
        tempfile s01_temp
        save `s01_temp'
    restore

    /* A6bis. Table de correspondance individuelle entre les deux vagues.
       En 2021, le questionnaire precharge les membres du menage panel avec
       leur identifiant de 2018 (s01qpreload_pid, accompagne du sexe, de
       l'age et du lien de parente precharges). Cette variable, et non le
       rang dans le roster 2021 (membres__id), est la cle qui relie un
       individu a lui-meme d'une vague a l'autre. Elle permet de constituer
       un veritable panel d'ENFANTS, et non seulement de menages.
       Validation : sexe identique dans 98,5 % des cas et ecart d'age
       median de 3 ans, conforme a l'intervalle entre les deux passages. */
    if `annee' == 2021 {
        preserve
            use "`base'/s01_me_sen2021.dta", clear
            keep grappe menage membres__id s01qpreload_pid
            rename membres__id numind
            rename s01qpreload_pid numind_2018
            keep if !missing(numind_2018)
            save "$TEMP/lien_individus.dta", replace

            /* Verification de la cle : biunivocite dans les deux sens */
            di _newline "--- Table de correspondance individuelle 2018-2021 ---"
            di "  Individus relies : " _N
            quietly duplicates report grappe menage numind
            di "  Cle 2021 unique  : " cond(r(unique_value) == _N, "oui", "NON")
            quietly duplicates report grappe menage numind_2018
            di "  Cle 2018 unique  : " cond(r(unique_value) == _N, "oui", "NON")
        restore
    }
    merge m:1 grappe menage numind using `s01_temp', ///
        keepusing(s01q05 s01q22 s01q29) nogenerate keep(master match)

    /* A7. Travail des enfants (s04_me / s04a_me), heures de travail
       economique et domestique. 2018 : cle s01q00a. 2021 : s04a_me en
       format long (membres__id), collapse au niveau personne. */
    preserve
        if `annee' == 2018 {
            use "`base'/s04_me_sen2018.dta", clear
            rename s01q00a numind
            /* Travail domestique = somme des cinq postes d'heures du module
               (courses au marche q01, travaux domestiques q02, garde q03,
               eau q04, bois q05). rownonmiss > 0 = a repondu au module. */
            egen h_dom = rowtotal(s04q01 s04q02 s04q03 s04q04 s04q05)
            egen byte nrep = rownonmiss(s04q01 s04q02 s04q03 s04q04 s04q05 ///
                                        s04q06 s04q07 s04q08 s04q09)
            /* Travail economique : uniquement les questions posant clairement
               le seuil "au moins une heure" (q06 champ propre compte, q07
               commerce remunere, q08 entreprise/Etat, q09 apprenti). q13/q14
               (travail familial non remunere) sont ecartes : leur formulation
               ne fixe aucun seuil horaire. */
            gen byte eco = inlist(1, s04q06, s04q07, s04q08, s04q09)
        }
        else {
            use "`base'/s04a_me_sen2021.dta", clear
            rename membres__id numind
            collapse (max) s04q01 s04q02a s04q02b s04q02c s04q03 s04q04 s04q05 ///
                           s04q06 s04q07 s04q08 s04q09, ///
                     by(grappe menage numind)
            egen h_dom = rowtotal(s04q01 s04q02a s04q02b s04q02c s04q03 s04q04 s04q05)
            egen byte nrep = rownonmiss(s04q01 s04q02a s04q02b s04q02c s04q03 ///
                                        s04q04 s04q05 s04q06 s04q07 s04q08 s04q09)
            gen byte eco = inlist(1, s04q06, s04q07, s04q08, s04q09)
        }
        keep grappe menage numind h_dom eco nrep
        tempfile s04_trav
        save `s04_trav'
    restore
    merge m:1 grappe menage numind using `s04_trav', ///
        keepusing(h_dom eco nrep) nogenerate keep(master match)

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
       Indicateur 1 - Type de sanitaire non ameliore
       Indicateur 2 - Partage des toilettes avec un autre menage
       Analyse en cas complets : la dimension est manquante des qu'UN
       SEUL indicateur manque, meme si l'autre indicateur est renseigne
       et positif. Aucun "sauvetage" par un indicateur deja positif. */
    /* Toilettes non ameliorees : type de sanitaire (v_type_toi, soit
       s11q55 en 2018 et s11q54 en 2021) dans les categories
       7. Latrines SANPLAT ; 8. Latrines dallees simples ;
       9. Fosse rudimentaire ; 10. Toilettes publiques ;
       11. Aucune toilette ; 12. Autre. */
    gen byte m_toilet     = inlist(`v_type_toi', 7, 8, 9, 10, 11, 12) ///
        if !missing(`v_type_toi')
    /* Le partage des sanitaires n'est demande que si le menage dispose
       d'une installation propre : la question est sautee a 100% quand le
       type de sanitaire (v_type_toi) est "Aucune toilette" (code 11) ou
       "Toilettes publiques" (code 10). Denominateur ANSD : ces menages,
       sans installation privee a partager, sont EXCLUS de l'indicateur
       (m_partag_toi manquant) plutot que comptes comme "ne partage pas".
       Ils restent captes comme prives par m_toilet. */
    gen byte m_partag_toi = (`v_partag' == 1) if !missing(`v_partag')
    /* Dimension : privee si type non ameliore OU partage. m_toilet==1
       court-circuite le partage manquant des menages sans installation
       privee, ce qui evite de les perdre du N-MODA (analyse en cas
       complets). */
    gen byte dim_assai = .
    replace  dim_assai = 1            if m_toilet == 1
    replace  dim_assai = m_partag_toi if m_toilet == 0

    /* ── [Dimension 2/7 : Eau] ─────────────────────────────────────
       Indicateur 1 - Source d'eau de boisson non amelioree
       Indicateur 2 - Temps d'acces a l'eau > 30 min (saison seche OU pluies) */
    /* Definition ANSD (« Traitement de l'eau de sources non adequates ») :
       est prive l'enfant vivant dans un menage dont la source de boisson est
       NON AMELIOREE (codes 5, 6, 12, 13, 16, 17 -- puits ouvert cour/ailleurs,
       source non amenagee, fleuve/riviere/lac, vendeur ambulant, autre), a
       l'une ou l'autre saison (seche `v_src_ss' OU pluies `v_src_sp'), ET
       qui ne traite PAS son eau. « Ne traite pas » = filtre de traitement
       different de « Oui » (v_gate != 1) : cela reunit le « Non » (v_gate==2)
       et les « ne sait pas »/non-reponse, comptes comme non-traitement.
       v_gate : s11q32 en 2018, s11q31 en 2021 (1=oui, 2=non, 3=ne sait pas).
       Denominateur PLEIN : tous les enfants dont le type de source est
       renseigne. */
    /* ATTENTION : en 2021, la variable de saison des PLUIES (s11q26b) utilise
       un jeu de modalites decale par rapport a celui de la saison seche. Elle
       intercale "Eau en sachet" en 16, si bien que vendeur ambulant passe de
       16 a 17 et "Autre" de 17 a 18. Appliquer la meme liste aux deux saisons
       compterait l'eau en sachet comme non amelioree et laisserait echapper la
       modalite "Autre". Les codes de la saison des pluies sont donc definis
       separement (2018 : codage identique aux deux saisons). */
    gen byte src_ss = inlist(`v_src_ss', 5, 6, 12, 13, 16, 17)
    if `annee' == 2021 gen byte src_sp = inlist(`v_src_sp', 5, 6, 12, 13, 17, 18)
    else               gen byte src_sp = inlist(`v_src_sp', 5, 6, 12, 13, 16, 17)
    gen byte m_eau_source = ((src_ss == 1 | src_sp == 1) & (`v_gate' != 1)) ///
        if !missing(`v_src_ss') | !missing(`v_src_sp')
    drop src_ss src_sp
    /* Le temps d'acces (s11q29a/28a, s11q31a/30a) n'est demande que si le
       menage doit se deplacer pour s'approvisionner : le saut de question
       (verifie empiriquement, >94% de non-reponse) s'applique quand la
       source est un robinet dans le logement (code 1) ou dans la cour/
       concession (code 2), auquel cas le temps d'acces est nul par
       construction (eau sur place), et non manquant. */
    /* Definition ANSD : temps de collecte = temps pour aller a la source
       (`v_tps_ss'/`v_tps_sp', min) PLUS le temps passe une fois a la source
       (`v_tps_*_h' heures + `v_tps_*_m' minutes), l'une ou l'autre saison,
       > 30 min. Les menages a eau sur place (robinet
       logement/cour, codes 1-2) gardent un temps nul : non prives (0),
       conserves au denominateur. */
    gen double t_ss = `v_tps_ss'
    gen double t_sp = `v_tps_sp'
    capture confirm variable `v_tps_ss_h'
    if _rc == 0 replace t_ss = t_ss + `v_tps_ss_h'*60 + `v_tps_ss_m' ///
        if !missing(t_ss) & !missing(`v_tps_ss_h')
    capture confirm variable `v_tps_sp_h'
    if _rc == 0 replace t_sp = t_sp + `v_tps_sp_h'*60 + `v_tps_sp_m' ///
        if !missing(t_sp) & !missing(`v_tps_sp_h')
    gen byte m_eau_temps  = (t_ss >= 30 & !missing(t_ss)) | ///
                             (t_sp >= 30 & !missing(t_sp)) ///
        if !missing(t_ss) | !missing(t_sp)
    replace  m_eau_temps  = 0 if missing(m_eau_temps) & ///
        inlist(`v_src_ss', 1, 2) & inlist(`v_src_sp', 1, 2)
    drop t_ss t_sp
    gen byte dim_eau      = (m_eau_source == 1 | m_eau_temps == 1) ///
        if !missing(m_eau_source) & !missing(m_eau_temps)

    /* ── [Dimension 3/7 : Logement] ────────────────────────────────
       Indicateur 1 - Debarras des ordures menageres inadequat
       Indicateur 2 - Surpeuplement (> 3 personnes par piece) */
    /* Debarras des ordures inadequat (definition ANSD, codes bruts de
       v_ordure : s11q54 en 2018, s11q53 en 2021) : 3 brulees par le menage,
       5 depotoir sauvage, 6 autre. Les codes bruts sont retenus plutot que
       la variable pre-codee "ordure" du fichier menage, qui agrege
       differemment. */
    gen byte m_ordures = inlist(`v_ordure', 3, 5, 6) if !missing(`v_ordure')
    /* Surpeuplement ANSD : « plus de 3 personnes par piece » operationnalise
       comme AU MOINS 4 personnes par piece (ratio >= 4), et non ratio > 3 (qui
       compterait a tort 3,5 pers./piece comme surpeuple). Le nombre de pieces
       est le total occupe (s11q02), l'EHCVM ne distinguant pas les pieces
       reservees au sommeil. */
    gen byte m_surpeup = (hhsize / nb_pieces >= 4) ///
        if !missing(nb_pieces) & nb_pieces > 0 & !missing(hhsize)
    gen byte dim_logem = (m_ordures == 1 | m_surpeup == 1) ///
        if !missing(m_ordures) & !missing(m_surpeup)

    /* ── [Dimension 4/7 : Nutrition] ───────────────────────────────
       Indicateur unique - Insecurite alimentaire, echelle FIES COMPLETE
       (8 questions du module 8A, presentes dans LES DEUX vagues) :
         q01 inquietude de manquer de nourriture
         q02 impossibilite de manger sainement
         q03 alimentation peu variee
         q04 saut d'un repas
         q05 avoir mange moins que necessaire
         q06 plus de nourriture dans le menage
         q07 avoir eu faim sans manger
         q08 journee entiere sans manger
       Score FIES = somme des reponses "oui" (0 a 8) ; l'enfant est prive
       si le score est >= 1 (au moins une experience d'insecurite).
       Valeurs manquantes et 98/99 (NSP/refus) traitees comme "non" : le
       menage est suppose ne pas avoir manque de cette ressource (aucune
       observation n'est perdue).
       Diversite alimentaire NON RETENUE : le module correspondant n'a pas
       ete collecte en 2021, donc aucun comparateur entre vagues. */
    egen byte fies_score = anycount(s08aq01 s08aq02 s08aq03 s08aq04 ///
        s08aq05 s08aq06 s08aq07 s08aq08), values(1)
    gen byte m_securite = (fies_score >= 1)
    gen byte dim_nutri  = (m_securite == 1)

    /* ── [Dimension 5/7 : Sante] ────────────────────────────────────
       Indicateur 1 - Combustible solide pour cuisiner (bois, charbon,
       dechets animaux).
       Indicateur 2 - Absence d'acces a pied a une structure de sante
       (m_sante_acces, construite en A4bis a partir du module
       communautaire s02_co, disponible dans LES DEUX vagues).
       Dimension privee si combustible solide OU pas d'acces sante a pied.
       Analyse en cas complets : m_sante_acces n'est jamais manquant (0/1
       au niveau de la grappe) ; la dimension n'est donc manquante que si
       le combustible manque ET que l'acces sante n'etablit pas deja la
       privation. m_combust manquant des qu'UNE SEULE des options de
       combustible manque. */
    gen byte m_combust = 0
    foreach v of varlist `comb_vars' {
        replace m_combust = 1 if `v' >= 1 & !missing(`v')
    }
    egen byte n_miss_comb = rowmiss(`comb_vars')
    replace m_combust = . if n_miss_comb > 0
    drop n_miss_comb
    gen byte dim_sante = .
    replace  dim_sante = 1         if m_sante_acces == 1
    replace  dim_sante = m_combust if m_sante_acces == 0

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

    /* Denominateur = enfants 5-14 ayant repondu au module (nrep > 0). rowtotal
       renvoie 0 meme si toutes les heures sont manquantes : sans le garde-fou
       nrep, les enfants sans aucune reponse seraient comptes "ne travaille pas"
       plutot qu'exclus. */
    gen byte m_trav_enf = (eco == 1 | h_dom >= 1) ///
        if age >= 5 & age <= 14 & nrep > 0 & !missing(nrep)
    replace  m_trav_enf = 0 if age < 5 | age > 14

    /* Separation parentale : enfant ne vivant pas avec ses DEUX parents
       biologiques, identifie directement par les questions du roster
       (s01q22 pere dans le menage, s01q29 mere dans le menage ; 1=Oui, 2=Non).
       Prive (m_parents=1) des qu'au moins un parent ne vit pas dans le menage ;
       non prive (0) seulement si pere ET mere y vivent. Manquant si l'une des
       deux reponses manque (analyse en cas complets). Remplace l'ancien proxy
       fonde sur le lien au chef de menage (lien > 3), qui classait mal les
       enfants du chef dont un parent est absent. */
    gen byte m_parents = .
    replace  m_parents = 1 if s01q22 == 2 | s01q29 == 2
    replace  m_parents = 0 if s01q22 == 1 & s01q29 == 1

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
       Combinaison par groupe d'age : 5-14 ans = ind.2 seul ;
       15-17 ans = ind.1 seul.
       NEET (ni scolarise ni employe) hors agregat : m_neet est calcule a
       titre descriptif mais n'alimente pas dim_educ (cf. annexe E). */
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

    /* NEET : conserve pour la statistique descriptive (annexe), hors agregat. */
    gen byte m_neet = (scol == 0 & activ7j != 1) ///
        if age >= 15 & !missing(scol) & !missing(activ7j)
    replace  m_neet = 0 if age < 15

    /* Non applicable aux 0-4 ans (groupe_moda==1) : dim_educ = 0 par
       defaut. 15-17 ans : illettrisme seul (NEET retire). */
    gen byte dim_educ = 0
    replace  dim_educ = m_scol  if groupe_moda == 2
    replace  dim_educ = m_alfab if groupe_moda == 3 & !missing(m_alfab)
    replace  dim_educ = .        if groupe_moda == 3 & missing(m_alfab)

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

    /* Privation par dimension ET par tranche d'age, ponderee (hhweight),
       pour comparaison directe avec le rapport ANSD "Pauvrete de l'enfant
       au Senegal" (taux par dimension et groupe d'age 0-4/5-14/15-17). */
    di _newline "  === Privation par dimension x tranche d'age (%, pondere hhweight) ==="
    foreach dim in assai eau logem nutri sante protect educ {
        di _newline "  -- dim_`dim' --"
        tabstat dim_`dim' [aw=hhweight], by(groupe_moda) stat(mean n) format(%7.4f)
    }

    /* C. Sauvegarde */
    save "$TEMP/enfants_dep_`annee'.dta", replace
    di _newline ">>> Sauvegarde : enfants_dep_`annee'.dta (" _N " obs)"
}

/* ============================================================
   SECTION : 04_PANEL — Construction du panel vrai (PanelHH=1)

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
   2. Statut de traitement : defini a la periode de BASE (2018)

   Design principal : le statut de traitement est fixe par la situation
   de 2018, qui sert de reference avant l'observation des resultats
   ulterieurs. On definit :
     - traites (D_stable=1) : menage recevant en 2018 un transfert
       etranger d'un expediteur ayant deja vecu dans le menage
       (migration d'un membre du menage)
     - temoins (D_stable=0) : menage ne recevant aucun transfert
       etranger de ce type en 2018
   Le statut etant fige a la periode de base, il ne peut pas etre
   affecte par l'evolution des privations entre les deux vagues.
   ============================================================ */

use "$TEMP/traitement_2018.dta", clear
rename D D_2018
merge 1:1 grappe menage using "$TEMP/traitement_2021.dta", ///
    keepusing(D) keep(match) nogenerate
rename D D_2021
gen byte D_stable = D_2018
label var D_stable "Traitement (1=beneficiaire migrant en 2018, 0=non beneficiaire)"

di _newline ">>> Cellules de traitement (menages presents aux 2 vagues) :"
tab D_2018 D_2021
quietly count if D_stable == 1
di "  Beneficiaires 2018 (migrant) : " r(N)
quietly count if D_stable == 0
di "  Non beneficiaires 2018       : " r(N)

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
label var D "Traitement (1=beneficiaire migrant en 2018, 0=non beneficiaire)"

di _newline "=== Panel vrai (traitement defini en 2018) ==="
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
   SECTION : 05_PSM_DD — Estimation PSM-DD au niveau ENFANT

   Strategie :
     1. Panel d'enfants suivis entre les deux vagues (cle preload)
        puis probit au NIVEAU ENFANT sur t=0 -> score de propension
     2. Verification equilibre (SMD) sur les covariables menage ET enfant
     3. Appariement PSM (k-NN, kernel, caliper) au niveau enfant
     4. DD brute (sans appariement, reference)
     5. PSM-DD sur le panel d'enfants apparie (Heckman et al. 1997/1998)
     6. Heterogeneite (milieu, sexe, age)
     7. Robustesse (seuil k, methodes d'appariement, agregat menage)

   Traitement : defini a la periode de base (2018), transfert d'un
   expediteur residant hors du Senegal et ayant deja vecu dans le
   menage.
   ============================================================ */

/* ── 1a. Construction du panel d'enfants suivis ──────────────
   Cle : numind_2018, identifiant de 2018 precharge dans le roster 2021.
   Le rang dans le roster 2021 (numind) ne designe pas le meme individu
   qu'en 2018. */
use "$TEMP/enfants_dep_2018.dta", clear
keep grappe menage numind sexe age pauvre_MODA nb_dep groupe_moda ///
     dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect dim_educ ///
     hhweight hhsize pcexp region milieu hgender hage heduc hmstat
rename numind numind_2018
foreach v in sexe age pauvre_MODA nb_dep groupe_moda ///
             dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect dim_educ {
    rename `v' `v'18
}
tempfile enf18_psm
save `enf18_psm'

use "$TEMP/enfants_dep_2021.dta", clear
keep grappe menage numind sexe age pauvre_MODA nb_dep groupe_moda ///
     dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect dim_educ
foreach v in sexe age pauvre_MODA nb_dep groupe_moda ///
             dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect dim_educ {
    rename `v' `v'21
}
merge m:1 grappe menage numind using "$TEMP/lien_individus.dta", ///
    keepusing(numind_2018) keep(match) nogenerate
drop numind
merge 1:1 grappe menage numind_2018 using `enf18_psm', keep(match) nogenerate

/* Traitement defini a la periode de base (transfert 2018, expediteur
   ex-membre du menage) */
merge m:1 grappe menage using "$TEMP/traitement_2018.dta", ///
    keepusing(D) keep(match) nogenerate

/* Restriction aux menages du panel vrai */
merge m:1 grappe menage using "$TEMP/ids_panel.dta", keep(match) nogenerate

/* Intensite du traitement : montant annuel recu en 2018. Manquant pour les
   menages non beneficiaires, par construction. */
merge m:1 grappe menage using "$TEMP/montant_2018.dta", ///
    keepusing(montant_transf) keep(master match) nogenerate

gen log_pcexp = log(pcexp + 1)
foreach v in milieu region heduc hmstat {
    capture destring `v', replace
}

/* Un identifiant individuel unique, stable entre les deux vagues */
egen long enfid = group(grappe menage numind_2018)
label var enfid "Identifiant individuel de l'enfant (panel)"

drop if missing(D) | missing(log_pcexp) | missing(hhsize) ///
       | missing(sexe18) | missing(age18) | missing(pauvre_MODA18) ///
       | missing(pauvre_MODA21)

/* ── Validation empirique de l'appariement individuel ─────────
   La cle s01qpreload_pid n'est pas documentee dans la documentation
   officielle de l'enquete : sa validite est etablie par deux verifications
   qu'un appariement arbitraire ne pourrait pas satisfaire. */
di _newline "--- Validation de l'appariement individuel ---"
quietly count if sexe18 == sexe21
di "  Concordance du sexe entre vagues : " %5.1f 100*r(N)/_N "%"
quietly gen int ecart_age = age21 - age18
quietly summarize ecart_age, detail
di "  Ecart d'age : mediane " %4.1f r(p50) "  moyenne " %5.2f r(mean)
quietly count if inrange(ecart_age, 2, 4)
di "  Part avec ecart d'age dans [2 ; 4] ans : " %5.1f 100*r(N)/_N "%"
quietly count if ecart_age < 0
di "  Part avec ecart d'age negatif (erreur de declaration) : " %5.1f 100*r(N)/_N "%"
quietly drop ecart_age

di _newline "=== Probit ENFANT — score de propension (EHCVM I, panel d'enfants) ==="
di "Enfants suivis aux deux vagues : " _N

/* ── 1b. Probit au niveau enfant ─────────────────────────────
   Covariables du menage a t=0 + sexe et age de l'enfant. Erreurs-types
   clusterisees au niveau de la grappe (le traitement varie au niveau
   menage : la correlation intra-grappe couvre aussi l'intra-menage). */
probit D c.hhsize c.log_pcexp i.milieu i.region ///
         c.hgender c.hage i.heduc i.hmstat ///
         i.sexe18 c.age18, vce(cluster grappe) nolog

di "Pseudo-R2 McFadden : " %6.3f 1 - e(ll)/e(ll_0)

/* ── 1b-bis. Qualite d'ajustement du probit ──────────────────
   Le score de propension n'a pas vocation a predire le traitement, mais a
   resumer la selection sur observables. On en verifie neanmoins trois
   proprietes : le pouvoir discriminant (aire sous la courbe ROC), le taux
   de bon classement, et la calibration (probabilite predite vs frequence
   observee par decile de score). */
di _newline "--- Qualite d'ajustement du probit ---"

lroc, nograph
di "  Aire sous la courbe ROC : " %5.3f r(area)

estat classification, cutoff(0.1484)   /* seuil = part de traites */

predict pscore, pr
label var pscore "Score de propension (enfant)"

/* Calibration : score moyen predit vs part observee de traites, par decile */
di _newline "  Calibration par decile de score :"
di "  Decile   Predit   Observe   n"
xtile dec_ps = pscore, nquantiles(10)
forvalues d = 1/10 {
    quietly summarize pscore if dec_ps == `d'
    local pred = r(mean)
    local n    = r(N)
    quietly summarize D if dec_ps == `d'
    di "  " %4.0f `d' %10.3f `pred' %9.3f r(mean) %7.0f `n'
}
drop dec_ps

/* Graphique de densite (support commun) */
set dp comma
twoway ///
    (kdensity pscore if D == 0, lcolor(gs9) lwidth(medthick)) ///
    (kdensity pscore if D == 1, lcolor(orange) lwidth(medthick)), ///
    legend(order(1 "Enfants non bénéficiaires" 2 "Enfants bénéficiaires") ///
           pos(6) rows(1) region(color(white))) ///
    xtitle("Score de propension") ytitle("Densité") ///
    graphregion(color(white)) plotregion(color(white)) ///
    saving("$OUTPUT/overlap_panel.gph", replace)
set dp period
graph export "$OUTPUT/overlap_panel.pdf", replace

save "$TEMP/pscore_t0.dta", replace

/* ============================================================
   2. Appariement PSM au niveau ENFANT

   Trois algorithmes pour robustesse :
     a. k plus proches voisins (k=K_VOISINS, avec remise)
     b. Kernel Epanechnikov (h=0.06)
     c. Caliper (epsilon=CALIPER, sans remise)

   Chaque enfant traite est apparie a des enfants temoins de profil
   observable comparable, y compris en sexe et en age.
   ============================================================ */

local covbal hhsize log_pcexp i.milieu i.region hgender hage ///
             i.heduc i.hmstat i.sexe18 age18

/* -- 2a. k-NN ------------------------------------------------ */
di _newline "=== Appariement k-NN (k=$K_VOISINS, avec remise), niveau enfant ==="
psmatch2 D, pscore(pscore) neighbor($K_VOISINS) common

di _newline "Balance avant/apres (SMD) :"
pstest `covbal', both

rename _weight weight_knn
keep enfid grappe menage numind_2018 D pscore weight_knn _support
save "$TEMP/pscore_knn.dta", replace

di _newline "=== Appariement Kernel (Epanechnikov, h=0.06), niveau enfant ==="
use "$TEMP/pscore_t0.dta", clear
psmatch2 D, pscore(pscore) kernel kerneltype(epan) bwidth(0.06) common

di _newline "Balance avant/apres (SMD), methode kernel :"
pstest `covbal', both

rename _weight weight_kernel
keep enfid weight_kernel
save "$TEMP/poids_kernel.dta", replace

di _newline "=== Appariement Caliper (eps=$CALIPER, sans remise), niveau enfant ==="
use "$TEMP/pscore_t0.dta", clear
psmatch2 D, pscore(pscore) caliper($CALIPER) noreplacement common

di _newline "Balance avant/apres (SMD), methode caliper :"
pstest `covbal', both

rename _weight weight_caliper
keep enfid weight_caliper
save "$TEMP/poids_caliper.dta", replace

/* ── 2d. Panel d'enfants en format long ──────────────────────
   Chaque enfant apparait a t=0 et t=1 avec SON poids d'appariement, qui
   ne varie pas dans le temps : c'est exactement ce qu'exige la double
   difference appariee de Heckman et al. (1997, 1998). */
use "$TEMP/pscore_t0.dta", clear
merge 1:1 enfid using "$TEMP/poids_kernel.dta",  nogenerate
merge 1:1 enfid using "$TEMP/poids_caliper.dta", nogenerate
merge 1:1 enfid using "$TEMP/pscore_knn.dta", ///
    keepusing(weight_knn _support) nogenerate

reshape long pauvre_MODA nb_dep groupe_moda sexe age ///
             dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect dim_educ, ///
    i(enfid) j(periode)
gen byte t = (periode == 21)
label var t "0 = EHCVM I (2018-19), 1 = EHCVM II (2021-22)"
drop periode

save "$TEMP/panel_enfants_psm.dta", replace

di _newline "Panel d'enfants apparie : " _N " observations (" ///
    %6.0f `=_N/2' " enfants x 2 vagues)"

/* ============================================================
   3. Statistiques descriptives sur le panel
   ============================================================ */

use "$TEMP/panel_vrai.dta", clear
di _newline "=== Stats descriptives (panel vrai, traitement 2018) ==="
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
   5. PSM-DD sur le panel d'enfants apparie
      Specification : Y_it = a + b*t + c*D + d*(t#D) + e
      d = ATT estime, poids d'appariement k-NN (niveau ENFANT)
   ============================================================ */

use "$TEMP/panel_enfants_psm.dta", clear
keep if !missing(weight_knn) & weight_knn > 0

di _newline "Panel d'enfants apparie (k-NN) : " _N " observations"
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

/* ── Sensibilite au seuil inter-dimensionnel k ──────────────────
   Le seuil k=4 est une convention. On reestime l'ATT en definissant la
   pauvrete successivement a k=3, 4, 5 et 6 dimensions sur 7, pour verifier
   que la conclusion ne depend pas du seuil retenu. */
di _newline "=== Sensibilite de l'ATT au seuil de privation k ==="
di "  k     Incidence(t=0)   ATT      SE       p"
foreach k in 3 4 5 6 {
    quietly gen byte pauvre_k`k' = (nb_dep >= `k') if !missing(nb_dep)
    quietly summarize pauvre_k`k' [aw=hhweight] if t == 0
    local inc = r(mean)*100
    quietly regress pauvre_k`k' i.t##i.D [aw=weight_knn], vce(cluster grappe)
    quietly lincom 1.t#1.D
    di "  " %1.0f `k' %14.1f `inc' "%" %10.4f r(estimate) %9.4f r(se) %8.4f r(p)
    quietly drop pauvre_k`k'
}

/* ── PSM seul (transversal, sans double difference) ─────────────
   Decompose le PSM-DD en ses deux composantes transversales : l'ecart
   de niveau apparie a t=0 (avant traitement) et a t=1 (apres), ponderes
   par les poids d'appariement k-NN. Par construction,
   ATT_PSM-DD = ecart(t=1) - ecart(t=0). Alimente le tableau "PSM seul
   vs PSM-DD" de l'annexe A. */
di _newline "=== PSM seul (transversal, sans DD) — decomposition du PSM-DD ==="
di _newline "--- PSM seul, t=0 (niveau initial apparie) ---"
regress pauvre_MODA D [aw=weight_knn] if t == 0, vce(cluster grappe)
di "  ATT PSM (t=0) = " %8.4f _b[D] "  SE = " %8.4f _se[D] ///
   "  p = " %6.4f (2*ttail(e(df_r), abs(_b[D]/_se[D])))
di _newline "--- PSM seul, t=1 (EHCVM II, sans DD) ---"
regress pauvre_MODA D [aw=weight_knn] if t == 1, vce(cluster grappe)
di "  ATT PSM (t=1) = " %8.4f _b[D] "  SE = " %8.4f _se[D] ///
   "  p = " %6.4f (2*ttail(e(df_r), abs(_b[D]/_se[D])))
di _newline "  Rappel : ATT_PSM-DD = ATT_PSM(t=1) - ATT_PSM(t=0), par construction."

save "$TEMP/panel_apparie.dta", replace

/* ── Robustesse : agregat menage (design de comparaison) ─────
   Le design principal apparie les ENFANTS. On verifie ici que la
   conclusion ne tient pas a ce choix d'unite, en reproduisant la double
   difference sur l'ensemble des enfants du panel de menages (y compris
   ceux qui n'apparaissent qu'a une seule vague), sans appariement
   individuel. Un ecart important entre les deux signalerait un effet de
   recomposition de l'echantillon plutot qu'un effet du traitement. */
preserve
    use "$TEMP/panel_vrai.dta", clear
    di _newline "=== Robustesse : tous les enfants du panel de menages ==="
    di "  Observations : " _N
    regress pauvre_MODA i.t##i.D, vce(cluster grappe)
    lincom 1.t#1.D
    di "  ATT agregat menage = " %8.4f r(estimate) ///
       "  SE = " %8.4f r(se) "  p = " %6.4f r(p)
restore

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

di _newline "Test d'egalite (urbain vs rural) :"
gen byte urban = (milieu == 1)
foreach outcome in pauvre_MODA {
    regress `outcome' i.t##i.D##i.urban [aw=weight_knn], vce(cluster grappe)
    lincom 1.t#1.D#1.urban
    di "  Diff ATT (urbain - rural) : " %8.4f r(estimate) "  p = " %6.4f r(p)
}
drop urban

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

/* -- 6d. Par quintile de montant de transferts --------------
   H2 porte aussi sur l'intensite du traitement : un transfert plus eleve
   produit-il un effet different ? Les quintiles sont definis sur la
   distribution du montant annuel PARMI LES MENAGES BENEFICIAIRES ; chaque
   quintile d'enfants traites est ensuite compare a l'ensemble des enfants
   temoins apparies. Les quintiles sont preferes aux deciles : avec environ
   2 600 enfants traites, un decoupage en dix laisserait des sous-groupes
   trop petits pour une inference exploitable. */
di _newline "=== Heterogeneite par quintile de montant de transferts ==="

/* Quintiles construits au niveau MENAGE beneficiaire (un menage = un
   montant), pour que le decoupage ne soit pas deforme par le nombre
   d'enfants du menage. */
preserve
    keep if D == 1 & t == 0 & !missing(montant_transf)
    bysort grappe menage: keep if _n == 1
    xtile q_montant = montant_transf, nquantiles(5)
    keep grappe menage q_montant montant_transf
    tempfile quintiles
    save `quintiles'
    di "  Bornes des quintiles de montant annuel (FCFA) :"
    forvalues q = 1/5 {
        quietly summarize montant_transf if q_montant == `q'
        di "    Q`q' : " %10.0f r(min) " a " %10.0f r(max) ///
           "  (mediane " %10.0f r(mean) ", n=" %4.0f r(N) " menages)"
    }
restore

merge m:1 grappe menage using `quintiles', ///
    keepusing(q_montant) keep(master match) nogenerate

foreach outcome in pauvre_MODA {
    forvalues q = 1/5 {
        quietly count if q_montant == `q' & !missing(weight_knn)
        if r(N) > 30 {
            di _newline "--- Quintile `q' — `outcome' ---"
            regress `outcome' i.t##i.D [aw=weight_knn] ///
                if D == 0 | q_montant == `q', vce(cluster grappe)
            lincom 1.t#1.D
            di "  ATT = " %8.4f r(estimate) "  SE = " %8.4f r(se) ///
               "  p = " %6.4f r(p)
        }
    }
}

/* Test continu : l'effet varie-t-il avec le logarithme du montant ?
   Estime sur les seuls enfants traites, la reference etant l'ecart de
   trajectoire moyen. Plus puissant que la comparaison par quintiles, qui
   decoupe l'information. */
di _newline "Effet dose-reponse (montant en logarithme, enfants traites) :"
quietly gen double log_montant = log(montant_transf) if montant_transf > 0
regress pauvre_MODA i.t##c.log_montant [aw=weight_knn] if D == 1, ///
    vce(cluster grappe)
lincom 1.t#c.log_montant
di "  Pente dose-reponse = " %8.4f r(estimate) "  SE = " %8.4f r(se) ///
   "  p = " %6.4f r(p)
drop log_montant

/* ============================================================
   7. Robustesse
   ============================================================ */

di _newline "=== Comparaison des trois methodes d'appariement ==="
/* Les trois poids sont deja portes par panel_enfants_psm.dta (niveau enfant) */
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
   Chapitre 3 : profil ménages, pauvreté, privations, comparaison D=0/1

   Les statistiques de pauvrete/privation (incidence N-MODA, par dimension,
   par age, par milieu, par region) sont PONDEREES par les poids de sondage
   (hhweight) pour assurer la representativite nationale et la comparabilite
   avec les chiffres officiels de l'ANSD (cf. annexe E). Le profil des menages
   et la balance traites/non-traites restent sur effectifs bruts.

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
            summarize `v' [aw=hhweight]   /* caracteristiques ponderees (representativite nationale) */
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


/* ============================================================
   2. Balance traités / non-traités (EHCVM I, t=0)
   ============================================================ */

di _newline "=== 2. Balance traites / non-traites (niveau ENFANT) ==="

/* Alimente le tableau de selection de la section 2 : qui recoit des
   transferts ? L'unite est l'enfant, comme dans tout le memoire. */
use "$TEMP/vague_2018.dta", clear
merge m:1 grappe menage using "$TEMP/traitement_2018.dta", ///
    keepusing(D) nogenerate keep(master match)
replace D = 0 if missing(D)

gen byte chef_f = (hgender == 2)
gen byte urbain = (milieu  == 1)
gen byte fille  = (sexe == 2)

foreach v in fille age hhsize hage pcexp chef_f urbain {
    quietly summarize `v' [aw=hhweight] if D == 1
    local m1 = r(mean)
    quietly summarize `v' [aw=hhweight] if D == 0
    local m0 = r(mean)
    quietly regress `v' D, vce(cluster grappe)
    di "  " %-8s "`v'" " : D=1 " %10.2f `m1' "  D=0 " %10.2f `m0' ///
       "  p=" %6.4f (2*ttail(e(df_r), abs(_b[D]/_se[D])))
}
quietly count if D == 1
di "  Enfants traites : " r(N)
quietly count if D == 0
di "  Enfants temoins : " r(N)

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

    di _newline "-- N-MODA `annee' (pondéré hhweight) --"
    tabstat pauvre_MODA nb_dep [aw=hhweight], ///
        by(milieu) stat(mean n) format(%6.3f)
    tabstat pauvre_MODA nb_dep [aw=hhweight], ///
        by(groupe_moda) stat(mean n) format(%6.3f)
    /* Incidence ajustee : H (part de pauvres), A (intensite moyenne parmi les
       pauvres = nb_dep/7), M0 = H x A, ponderes par hhweight. */
    quietly summarize pauvre_MODA [aw=hhweight]
    local H = r(mean)
    quietly summarize intensite_moda [aw=hhweight] if pauvre_MODA == 1
    local A = r(mean)
    di "  Incidence ajustee `annee' : H=" %5.1f 100*`H' "%  A=" %5.1f 100*`A' ///
       "%  M0=" %5.3f `H'*`A'
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
        /* n_calc = enfants avec un statut N-MODA calcule ; n_tot = effectif
           total de la tranche (colonne "Obs." du tableau du rapport) */
        local nobs  = r(N)
        quietly count if groupe_moda == `g'
        local ntot  = r(N)
        local lbl   = cond(`g'==1,"0-4 ans",cond(`g'==2,"5-14 ans","15-17 ans"))
        di "  `annee' / `lbl' : H=" %5.1f `hmoda' "% (n_calc=`nobs', n_tot=`ntot')"
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


/* ============================================================
   5. Graphiques
   ============================================================ */

di _newline "=== 5. Graphiques ==="

/* ── Fig 1 : Évolution de l'incidence N-MODA, beneficiaires vs
   non-beneficiaires. Les deux trajectoires rendent visible la logique de
   double difference : c'est l'ECART entre les groupes, et son evolution
   entre les deux vagues, qui porte l'information sur l'impact. ── */
use "$TEMP/panel_vrai.dta", clear
forvalues d = 0/1 {
    foreach tt in 0 1 {
        quietly summarize pauvre_MODA [aw=hhweight] if D == `d' & t == `tt'
        scalar H_d`d'_t`tt' = r(mean)*100
    }
}
clear
set obs 2
gen annee = 2018 in 1
replace annee = 2021 in 2
gen H_benef    = H_d1_t0 in 1
replace H_benef = H_d1_t1 in 2
gen H_nonbenef = H_d0_t0 in 1
replace H_nonbenef = H_d0_t1 in 2
gen str12 lbl_b  = subinstr(string(H_benef,    "%3.1f"), ".", ",", 1) + " %"
gen str12 lbl_nb = subinstr(string(H_nonbenef, "%3.1f"), ".", ",", 1) + " %"

set dp comma
twoway (connected H_nonbenef annee, lcolor(gs9) mcolor(gs9) msymbol(square) ///
        lwidth(medthick) mlabel(lbl_nb) mlabcolor(black) mlabpos(6) ///
        mlabgap(2) mlabsize(small)) ///
       (connected H_benef annee, lcolor(orange) mcolor(orange) msymbol(circle) ///
        lwidth(medthick) mlabel(lbl_b) mlabcolor(black) mlabpos(12) ///
        mlabgap(2) mlabsize(small)), ///
    xlabel(2018 2021) xscale(range(2017.7 2021.3)) xtitle("Vague EHCVM") ///
    ytitle("Incidence N-MODA H (%)") ///
    ylabel(0(20)100, grid) yscale(range(0 108)) ///
    legend(order(1 "Non-bénéficiaires" 2 "Bénéficiaires") pos(6) rows(1)) ///
    graphregion(color(white)) plotregion(color(white))
set dp period
graph export "$OUTPUT/figures/fig_evolution_ipm.pdf", replace
di ">>> fig_evolution_ipm.pdf sauvegardé"

/* ── Fig 2 : Taux de privation par dimension, beneficiaires vs
   non-beneficiaires a chaque vague (quatre barres par dimension). Permet de
   lire, dimension par dimension, l'ecart entre groupes et son evolution. ── */
use "$TEMP/panel_vrai.dta", clear
foreach dim in assai eau logem nutri sante protect educ {
    forvalues d = 0/1 {
        foreach tt in 0 1 {
            quietly summarize dim_`dim' [aw=hhweight] if D == `d' & t == `tt'
            scalar x_`dim'_`d'`tt' = r(mean)*100
        }
    }
}
clear
set obs 7
gen str12 dim = ""
replace dim = "Assainis."  in 1
replace dim = "Eau"        in 2
replace dim = "Logement"   in 3
replace dim = "Nutrition"  in 4
replace dim = "Santé"      in 5
replace dim = "Protection" in 6
replace dim = "Éducation"  in 7
gen ordre = _n
gen nb18 = .
gen b18  = .
gen nb21 = .
gen b21  = .
local dims assai eau logem nutri sante protect educ
forvalues i = 1/7 {
    local d : word `i' of `dims'
    replace nb18 = x_`d'_00 in `i'
    replace b18  = x_`d'_10 in `i'
    replace nb21 = x_`d'_01 in `i'
    replace b21  = x_`d'_11 in `i'
}
set dp comma
graph bar nb18 b18 nb21 b21, over(dim, sort(ordre) label(angle(30) labsize(small))) ///
    bar(1, color(gs11)) bar(2, color(gs7)) ///
    bar(3, color(orange*0.5)) bar(4, color(orange)) ///
    blabel(bar, position(outside) format(%4,0f) size(tiny)) ///
    legend(order(1 "Non-bénéf. 2018" 2 "Bénéf. 2018" ///
                 3 "Non-bénéf. 2021" 4 "Bénéf. 2021") pos(6) rows(2) size(small)) ///
    ytitle("Taux de privation (%)") ylabel(0(20)100, grid) ///
    graphregion(color(white)) plotregion(color(white))
set dp period
graph export "$OUTPUT/figures/fig_privations_dim.pdf", replace
di ">>> fig_privations_dim.pdf sauvegardé"

/* ── Fig 3 : Pauvreté par groupe d'âge, beneficiaires vs non-beneficiaires
   aux deux vagues. Panneaux = groupe d'age ; barres = statut x vague. */
use "$TEMP/panel_vrai.dta", clear
keep pauvre_MODA groupe_moda D t hhweight
collapse (mean) pauvre_MODA [aw=hhweight], by(t D groupe_moda)
replace pauvre_MODA = pauvre_MODA * 100
gen byte serie = 1 + D + 2*t   /* 1 = nonbenef 2018, 2 = benef 2018,
                                  3 = nonbenef 2021, 4 = benef 2021 */
drop D t
reshape wide pauvre_MODA, i(groupe_moda) j(serie)

set dp comma   /* etiquettes decimales avec virgule */
graph bar pauvre_MODA1 pauvre_MODA2 pauvre_MODA3 pauvre_MODA4, ///
    over(groupe_moda) ///
    bar(1, color(gs11)) bar(2, color(gs7)) ///
    bar(3, color(orange*0.5)) bar(4, color(orange)) ///
    blabel(bar, position(outside) format(%4,0f) size(vsmall)) ///
    legend(order(1 "Non-bénéf. 2018" 2 "Bénéf. 2018" ///
                 3 "Non-bénéf. 2021" 4 "Bénéf. 2021") pos(6) rows(2) size(small)) ///
    ytitle("Incidence N-MODA (H, %)") ylabel(0(20)100, grid) ///
    graphregion(color(white)) plotregion(color(white))
set dp period
graph export "$OUTPUT/figures/fig_pauvrete_milieu_age.pdf", replace
di ">>> fig_pauvrete_milieu_age.pdf sauvegardé"

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

/* ============================================================
   COMPARAISON BENEFICIAIRES / NON-BENEFICIAIRES x 2018-2021

   Coeur descriptif de la section : pour chaque dimension N-MODA et pour
   l'incidence globale, taux de privation des enfants selon le statut de
   traitement du menage (D=1 beneficiaire migrant en 2018 ; D=0 non
   beneficiaire) a chaque vague, ecart entre groupes a chaque date, et
   evolution de cet ecart (double difference descriptive, non ponderee
   par l'appariement). Echantillon : panel vrai, ponderation hhweight.
   ============================================================ */

use "$TEMP/panel_vrai.dta", clear

di _newline(2) "=== Privations : beneficiaires vs non-beneficiaires, 2018 et 2021 ==="
di "    (panel vrai, pondere hhweight ; D=1 beneficiaire migrant 2018)"
di _newline "  Indicateur          D=0 2018  D=1 2018   Ecart |  D=0 2021  D=1 2021   Ecart |     DD"

foreach v in dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect ///
             dim_educ pauvre_MODA {
    quietly summarize `v' [aw=hhweight] if t == 0 & D == 0
    local a0 = r(mean)*100
    quietly summarize `v' [aw=hhweight] if t == 0 & D == 1
    local a1 = r(mean)*100
    quietly summarize `v' [aw=hhweight] if t == 1 & D == 0
    local b0 = r(mean)*100
    quietly summarize `v' [aw=hhweight] if t == 1 & D == 1
    local b1 = r(mean)*100
    local g0 = `a1' - `a0'      /* ecart benef - non benef en 2018 */
    local g1 = `b1' - `b0'      /* ecart benef - non benef en 2021 */
    local dd = `g1' - `g0'      /* evolution de l'ecart = DD descriptive */
    di "  " %-18s "`v'" %9.1f `a0' %10.1f `a1' %8.1f `g0' " |" ///
       %9.1f `b0' %10.1f `b1' %8.1f `g1' " |" %7.1f `dd'
}

/* Test de significativite de l'ecart entre groupes, a chaque vague */
di _newline "  Test de l'ecart beneficiaires/non-beneficiaires (p-valeurs) :"
foreach v in dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect ///
             dim_educ pauvre_MODA {
    quietly regress `v' D if t == 0, vce(cluster grappe)
    local p0 = 2*ttail(e(df_r), abs(_b[D]/_se[D]))
    quietly regress `v' D if t == 1, vce(cluster grappe)
    local p1 = 2*ttail(e(df_r), abs(_b[D]/_se[D]))
    di "  " %-18s "`v'" "  2018 : p=" %6.4f `p0' "   2021 : p=" %6.4f `p1'
}

di _newline ">>> 06_stats_desc.do terminé."
di ">>> Sorties dans : $OUTPUT/tables/ et $OUTPUT/figures/"

/* ============================================================
   SECTION : 07_EFFETS_DIM — ATT PSM-DD par dimension N-MODA
   Génère output/figures/fig_effets_dim.pdf
   ============================================================ */


/* Joindre poids k-NN au panel vrai */
use "$TEMP/panel_enfants_psm.dta", clear
keep if !missing(weight_knn) & weight_knn > 0

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
   SECTION : 09_PLACEBO_ATTRITION — Tests de validite (annexe A)

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
    /* Centile de l'ATT reel dans la distribution placebo (rang percentile) */
    quietly count if !missing(att_`y')
    local ntot = r(N)
    quietly count if att_`y' < $ATT_REEL
    di "  ATT reel (" %6.4f $ATT_REEL ") : rang = " %4.1f 100*r(N)/`ntot' "e centile"
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
    xlabel(-0.06 "-0,06" -0.04 "-0,04" -0.02 "-0,02" 0 "0" ///
           0.02 "0,02" 0.04 "0,04" 0.06 "0,06" 0.08 "0,08" 0.10 "0,10", grid) ///
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

di _newline ">>> Copie des figures vers latex/figures et Presentation/figures ..."
/* Copie dynamique de tous les PDF generes (toute figure future incluse)
   vers le rapport ET la presentation Beamer, pour les garder synchronises. */
local figs : dir "$OUTPUT/figures" files "*.pdf"
foreach f of local figs {
    foreach dest in "latex/figures" "Presentation/figures" {
        capture copy "$OUTPUT/figures/`f'" "`dest'/`f'", replace
        if _rc di "    !! echec copie `f' vers `dest' (rc=" _rc ")"
    }
    di "    ok `f'"
}
/* Graphique de support commun (a la racine de output) */
capture copy "$OUTPUT/overlap_panel.pdf" "latex/figures/overlap_panel.pdf", replace
capture copy "$OUTPUT/overlap_panel.pdf" "Presentation/figures/overlap.pdf", replace

di _newline ">>> FIN DU PIPELINE COMPLET <<<"

/* Ferme le log pour que code/stata/logs/tout.log soit complet et libere
   (il est versionne : pousse-le pour que toute la sortie soit relisible). */
capture log close _all

