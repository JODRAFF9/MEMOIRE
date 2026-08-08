/* ============================================================
   tout.do — Script unique contenant l'integralite du pipeline

   Ce fichier regroupe tous les codes du projet dans l'ordre
   d'execution logique. Il peut etre lance depuis la racine :
     do "code/stata/tout.do"

   Aucune ponderation par poids d'enquete (hhweight) : toutes les
   statistiques et estimations sont calculees sur effectifs bruts,
   avec erreurs-types clusterisees au niveau de la grappe.
   Traitement : transfert recu de l'etranger, quel que soit le lien de
   l'expediteur ; design principal = beneficiaires stables (recu aux
   deux editions) vs jamais beneficiaires.

   Pipeline :
     config       — chemins, constantes
     02_traitement  — variable D + identification panel
     03_deprivation — indicateurs MODA
     04_panel       — panel vrai
     05_psm_dd      — estimation PSM-DD (matching niveau enfant)
     06_stats_desc  — statistiques descriptives
     07_effets_dim  — effets par dimension
     08_carte_region— carte regionale
     09_placebo — tests placebo
   ============================================================ */
cd "C:\Users\Bmd\Documents\ISE\Cours\Archive_ISE3\Memoire"
capture log close _all
/* Si tout.log est verrouille par un autre programme (r(608)), on bascule sur
   un nom horodate. $LOGFILE retient le fichier reellement ouvert, recopie
   vers tout.log en fin de script. */
global LOGFILE "code/stata/logs/tout.log"
capture log using "$LOGFILE", replace text
if _rc {
    local horodate = subinstr("`c(current_date)'_`c(current_time)'", ":", "-", .)
    local horodate = subinstr("`horodate'", " ", "_", .)
    global LOGFILE "code/stata/logs/tout_`horodate'.log"
    log using "$LOGFILE", replace text
}
di ">>> Log ouvert : $LOGFILE"

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
global K_MODA            4        /* seuil MODA : >= 4 dimensions sur 7      */
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
    /* Transfert etranger, quel que soit le lien de l'expediteur au
       menage : le traitement retient tout transfert recu de l'etranger,
       sans exiger que l'expediteur ait vecu dans le menage. La solidarite
       transnationale deborde le seul ancien membre (parents eloignes,
       reseaux villageois), et conditionner au lien restreindrait le
       traitement sans que la theorie ne l'impose. Le lien reste observe
       (var_exmbr, s13aq12 en 2018 / s13q17 en 2021) a titre descriptif. */
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

    /* ── Intensite du traitement : montant annuel recu ────────────
       Meme perimetre que D (tout transfert recu de l'etranger).
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
    /* Transfert etranger, quel que soit le lien de l'expediteur au
       menage : le traitement retient tout transfert recu de l'etranger,
       sans exiger que l'expediteur ait vecu dans le menage. La solidarite
       transnationale deborde le seul ancien membre (parents eloignes,
       reseaux villageois), et conditionner au lien restreindrait le
       traitement sans que la theorie ne l'impose. Le lien reste observe
       (var_exmbr, s13aq12 en 2018 / s13q17 en 2021) a titre descriptif. */
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

   Approche : MODA Senegal (7 dimensions, k=4)

   Produit : $TEMP/enfants_dep_ANNEE.dta pour annee in {2018, 2021}
   ============================================================ */


/* --------------------------------------------------------------------------
   MODA — 7 dimensions, seuil k=4, unite = enfant. Definitions RETENUES
   (telles qu'implementees ci-dessous ; variables 2018 / 2021) :

   1. ASSAINISSEMENT   m_toilet (s11q55/54) ; m_partag_toi (s11q56/55)
   2. EAU             m_eau_source (s11q26a/b, filtre s11q32/31)
                      m_eau_temps  (s11q29a/28a, s11q31a/30a)
   3. LOGEMENT        m_ordures (s11q54/53) ; m_surpeup (hhsize / s11q02)
   4. NUTRITION       m_securite (s08a, 8 questions FIES)
   5. SANTE           m_combust (s11q53/52) ; m_sante_acces (s02_co, s02q02)
   6. PROTECTION      m_acte_nais (s01q05) ; m_trav_enf (s04)
                      m_parents (s01q22/s01q29) calcule a titre descriptif,
                      hors agregat
   7. EDUCATION       m_scol (scol) ; m_alfab (alfab)
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

    /* A1bis. Categorie socioprofessionnelle du chef de menage.
       Le fichier welfare ne la porte pas : elle est extraite du fichier
       individus, sur la ligne du chef (lien == 1). La variable csp n'est
       definie que pour les personnes en emploi ; les chefs sans emploi ou
       non renseignes (environ un quart) recoivent une modalite propre
       plutot que d'etre exclus de l'estimation. */
    preserve
        use "`base'/ehcvm_individu_sen`annee'.dta", clear
        keep if lien == 1
        bysort grappe menage: keep if _n == 1
        gen byte hcsp = csp
        replace  hcsp = 0 if missing(csp)
        label define csp_lbl 0 "Sans emploi ou non renseigne" ///
            1 "Cadre superieur" 2 "Cadre moyen" 3 "Ouvrier qualifie" ///
            4 "Ouvrier non qualifie" 5 "Manoeuvre, aide menagere" ///
            6 "Apprenti remunere" 7 "Apprenti non remunere" ///
            8 "Travailleur familial" 9 "Compte propre" 10 "Patron", replace
        label values hcsp csp_lbl
        label var hcsp "Categorie socioprofessionnelle du chef de menage"
        keep grappe menage hcsp
        tempfile csp_chef
        save `csp_chef'
        di "  CSP du chef `annee' :"
        tab hcsp
    restore
    merge m:1 grappe menage using `csp_chef', keepusing(hcsp) ///
        nogenerate keep(master match)

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
       un veritable panel d'ENFANTS, et non seulement de menages. */
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

    /* Les variables scol, lien, alfab/alfa sont deja presentes
       dans ehcvm_individu (chargee en A1) : aucune fusion supplementaire
       n'est necessaire pour la dimension Education. */

    /* A8. Sauvegarde de la base preparee (fusionnee, avant calcul),
       dans un dossier separe des bases finales avec indicateurs. */
    save "$PREP/base_prep_`annee'.dta", replace
    di ">>> Base preparee sauvegardee : $PREP/base_prep_`annee'.dta (" _N " obs)"

    /* ============================================================
       B. CALCUL DES INDICATEURS ET DES DIMENSIONS MODA, par
          dimension. Toutes les donnees sources sont deja fusionnees
          (etape A) : cette section ne contient plus aucun merge.
       ============================================================ */

    /* Groupes d'age MODA (utilises par plusieurs dimensions ci-dessous) */
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
       privee, ce qui evite de les perdre du MODA (analyse en cas
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
       >=1h, 5-17 ans)
       Combinaison par groupe d'age : 0-4 ans = ind.1 seul ;
       5-14 ans = ind.1 OU ind.2 ; 15-17 ans = ind.2 seul.
       La separation parentale a ete RETIREE de l'agregat : elle est une
       consequence directe de la migration, donc du traitement etudie. La
       maintenir reviendrait a imputer aux transferts une privation que le
       depart du parent produit mecaniquement. m_parents reste calculee a
       titre descriptif mais n'alimente plus dim_protect.
       Le travail des enfants est en consequence mesure jusqu'a 17 ans :
       sans cela les 15-17 ans n'auraient plus aucun indicateur de
       protection et seraient mesures sur six dimensions au lieu de sept,
       ce qui rendrait le seuil k = 4 non comparable entre groupes d'age.
       replace ... if hors 5-17 ans = non-applicabilite (pas une
       imputation de valeur manquante) : l'indicateur ne sert pas pour ce
       groupe d'age, quelle que soit l'info disponible. */
    gen byte m_acte_nais = (s01q05 == 2) if !missing(s01q05)
    replace  m_acte_nais = 0 if age > 14

    /* Denominateur = enfants 5-14 ayant repondu au module (nrep > 0). rowtotal
       renvoie 0 meme si toutes les heures sont manquantes : sans le garde-fou
       nrep, les enfants sans aucune reponse seraient comptes "ne travaille pas"
       plutot qu'exclus. */
    gen byte m_trav_enf = (eco == 1 | h_dom >= 1) ///
        if age >= 5 & age <= 17 & nrep > 0 & !missing(nrep)
    replace  m_trav_enf = 0 if age < 5

    /* Separation parentale, VARIABLE DESCRIPTIVE UNIQUEMENT (hors indice) :
       enfant ne vivant pas avec ses DEUX parents
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
    replace  dim_protect = (m_acte_nais == 1) ///
        if groupe_moda == 1 & !missing(m_acte_nais)
    replace  dim_protect = (m_acte_nais == 1 | m_trav_enf == 1) ///
        if groupe_moda == 2 & !missing(m_acte_nais) & !missing(m_trav_enf)
    replace  dim_protect = (m_trav_enf == 1) ///
        if groupe_moda == 3 & !missing(m_trav_enf)

    /* ── [Dimension 7/7 : Education] ──────────────────────────────
       Indicateur 1 - Illettrisme, ne sait ni lire ni ecrire (15-17 ans)
       Indicateur 2 - Non-scolarisation (5-14 ans)
       Combinaison par groupe d'age : 5-14 ans = ind.2 seul ;
       15-17 ans = ind.1 seul.
       */
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

    /* Versions NON plafonnees par l'age courant, utilisees pour mesurer
       les privations de 2021 SUR LA GRILLE DU GROUPE DE BASE : un enfant
       de la grille 5-14 devenu 15-17 en 2021 y reste evalue sur l'acte de
       naissance et la scolarisation. La limite est assumee et discutee
       dans le rapport : ces privations sont alors mesurees sur des
       enfants qui n'ont plus l'age de la grille. */
    gen byte m_acte_nc = (s01q05 == 2) if !missing(s01q05)
    gen byte m_scol_nc = (scol == 0)   if !missing(scol)
    gen byte m_alfab_nc = .
    if `annee' == 2018 {
        replace m_alfab_nc = (alfab == 0) if !missing(alfab)
    }
    else {
        capture confirm variable alfa
        if !_rc replace m_alfab_nc = (alfa == 0) if !missing(alfa)
    }

    /* Non applicable aux 0-4 ans (groupe_moda==1) : dim_educ = 0 par
       defaut. 15-17 ans : illettrisme seul (NEET retire). */
    gen byte dim_educ = 0
    replace  dim_educ = m_scol  if groupe_moda == 2
    replace  dim_educ = m_alfab if groupe_moda == 3 & !missing(m_alfab)
    replace  dim_educ = .        if groupe_moda == 3 & missing(m_alfab)

    /* ── Agregation MODA (union intra-dimension, seuil k=$K_MODA) ── */
    gen byte nb_dep = dim_assai + dim_eau + dim_logem + dim_nutri + ///
                      dim_sante + dim_protect + dim_educ
    gen byte pauvre_MODA = (nb_dep >= $K_MODA) if !missing(nb_dep)

    /* Intensite moyenne MODA (Annexe II : A = part des 7 dimensions
       en privation, calculee sur les enfants pauvres pauvre_MODA==1) */
    gen float intensite_moda = nb_dep / 7

    /* ── Affichage ── */
    di _newline "=== MODA `annee' (k=$K_MODA, 7 dimensions) ==="
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

   Exploite le suivi effectif des menages entre les deux vagues.
   Produit : $TEMP/panel_vrai.dta

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
       de l'etranger, quel que soit le lien de l'expediteur au menage
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
   traitement defini a la periode de base.
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
   DEPARTS DE MEMBRES ENTRE LES DEUX VAGUES

   Le questionnaire 2021 precharge chaque membre releve en 2018 et demande
   s'il fait toujours partie du menage (s01q00aa) et pour quelle raison il
   l'a quitte (s01q00b). Le motif distingue un depart a l'etranger d'un
   depart a l'interieur du pays : on peut donc mesurer si les menages
   temoins ont eux aussi perdu un adulte, ce que le design suppose sans le
   verifier.

   Trois retraitements sont necessaires. L'age precharge comporte des codes
   de non-reponse (9999) qui seraient comptes comme adultes. Le motif
   « etait visiteur » ne designe pas un depart mais une personne recensee a
   tort en 2018. Les deces ne relevent pas de la migration et sont isoles.

   Ce bloc ne modifie aucune estimation.
   ============================================================ */

preserve
    use "$BASE_2021/s01_me_sen2021.dta", clear
    keep grappe menage membres__id s01qpreload_pid s01qpreload_sex ///
         s01qpreload_age s01q00aa s01q00b

    keep if !missing(s01qpreload_pid)   /* membres presents en 2018 */

    merge m:1 grappe menage using "$TEMP/ids_panel.dta", keep(match) nogenerate
    merge m:1 grappe menage using "$TEMP/traitement_2018.dta", ///
        keepusing(D) keep(master match) nogenerate
    replace D = 0 if missing(D)

    /* Age precharge : 9999 et valeurs aberrantes mises a manquant */
    replace s01qpreload_age = . if s01qpreload_age > 100

    gen byte parti = (s01q00aa == 2) if !missing(s01q00aa)

    /* Codes numeriques du motif, pour ne pas dependre du libelle */
    di _newline(2) "=== Departs de membres entre 2018 et 2021 (menages du panel) ==="
    di _newline "--- Motif du depart : codes numeriques ---"
    tab s01q00b if parti == 1, nolabel missing

    /* Categorie de depart. Le classement s'appuie sur le libelle : les
       modalites opposent explicitement « ailleurs dans le pays » et
       « a l'etranger ». */
    decode s01q00b, gen(motif_txt)
    gen byte motif_cat = .
    replace motif_cat = 1 if strpos(motif_txt, "tranger")            /* etranger */
    replace motif_cat = 2 if missing(motif_cat) & ///
        (strpos(motif_txt, "dans le p") | strpos(motif_txt, "Affectation"))
    replace motif_cat = 3 if missing(motif_cat) & strpos(motif_txt, "cès")
    replace motif_cat = 4 if missing(motif_cat) & strpos(motif_txt, "visiteur")
    replace motif_cat = 5 if missing(motif_cat) & !missing(motif_txt)
    label define motif_cat_lbl 1 "Migration a l'etranger" ///
        2 "Migration dans le pays" 3 "Deces" 4 "Etait visiteur" ///
        5 "Autre motif (mariage, demenagement...)", replace
    label values motif_cat motif_cat_lbl

    di _newline "--- Repartition des departs par categorie ---"
    tab motif_cat if parti == 1, missing

    /* Un depart au sens du canal du cout de l'absence : membre de 15 ans ou
       plus effectivement parti, hors deces et hors visiteurs. */
    gen byte depart_adulte = (parti == 1 & s01qpreload_age >= 15 & ///
        !missing(s01qpreload_age) & inlist(motif_cat, 1, 2, 5))
    gen byte depart_etranger = (depart_adulte == 1 & motif_cat == 1)
    gen byte depart_interne  = (depart_adulte == 1 & motif_cat == 2)

    di _newline "--- Motif du depart des 15 ans et plus, selon le statut du menage ---"
    tab motif_cat D if parti == 1 & s01qpreload_age >= 15 & ///
        !missing(s01qpreload_age), column

    collapse (max) depart_adulte depart_etranger depart_interne ///
             (first) D, by(grappe menage)

    di _newline "--- Menages ayant perdu un adulte (15 ans ou plus, hors deces et visiteurs) ---"
    tab depart_adulte D, column
    di _newline "--- dont depart a l'etranger ---"
    tab depart_etranger D, column
    di _newline "--- dont depart dans le pays ---"
    tab depart_interne D, column
restore



/* ============================================================
   SECTION : 05_PSM_DD — Estimation PSM-DD au niveau ENFANT

   Strategie :
     1. Panel d'enfants suivis entre les deux vagues (cle preload)
        puis logit au NIVEAU ENFANT sur t=0 -> score de propension
     2. Verification equilibre (SMD) sur les covariables menage ET enfant
     3. Appariement PSM (k-NN, kernel, caliper) au niveau enfant
     4. DD brute (sans appariement, reference)
     5. PSM-DD sur le panel d'enfants apparie (Heckman et al. 1997/1998)
     6. Heterogeneite (milieu, genre, age)
     7. Robustesse (seuil k, methodes d'appariement, agregat menage)

   Traitement : transfert recu de l'etranger, quel que soit le lien
   de l'expediteur au menage.
   ============================================================ */

/* ── 1a. Construction du panel d'enfants suivis ──────────────
   Cle : numind_2018, identifiant de 2018 precharge dans le roster 2021.
   Le rang dans le roster 2021 (numind) ne designe pas le meme individu
   qu'en 2018. */
use "$TEMP/enfants_dep_2018.dta", clear
keep grappe menage numind sexe age pauvre_MODA nb_dep intensite_moda groupe_moda ///
     dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect dim_educ ///
     m_parents m_toilet m_partag_toi m_eau_source m_eau_temps m_ordures m_surpeup m_securite m_combust m_sante_acces m_acte_nais m_trav_enf m_scol m_alfab ///
     m_acte_nc m_scol_nc m_alfab_nc ///
     hhweight hhsize pcexp region milieu hgender hage heduc hmstat hcsp
rename numind numind_2018
foreach v in sexe age pauvre_MODA nb_dep intensite_moda groupe_moda ///
             dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect dim_educ ///
             m_parents m_toilet m_partag_toi m_eau_source m_eau_temps m_ordures m_surpeup m_securite m_combust m_sante_acces m_acte_nais m_trav_enf m_scol m_alfab ///
             m_acte_nc m_scol_nc m_alfab_nc {
    rename `v' `v'18
}
tempfile enf18_psm
save `enf18_psm'

use "$TEMP/enfants_dep_2021.dta", clear
keep grappe menage numind sexe age pauvre_MODA nb_dep intensite_moda groupe_moda ///
     dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect dim_educ ///
     m_parents m_toilet m_partag_toi m_eau_source m_eau_temps m_ordures m_surpeup m_securite m_combust m_sante_acces m_acte_nais m_trav_enf m_scol m_alfab ///
     m_acte_nc m_scol_nc m_alfab_nc
foreach v in sexe age pauvre_MODA nb_dep intensite_moda groupe_moda ///
             dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect dim_educ ///
             m_parents m_toilet m_partag_toi m_eau_source m_eau_temps m_ordures m_surpeup m_securite m_combust m_sante_acces m_acte_nais m_trav_enf m_scol m_alfab ///
             m_acte_nc m_scol_nc m_alfab_nc {
    rename `v' `v'21
}
merge m:1 grappe menage numind using "$TEMP/lien_individus.dta", ///
    keepusing(numind_2018) keep(match) nogenerate
drop numind
merge 1:1 grappe menage numind_2018 using `enf18_psm', keep(match) nogenerate

/* Traitement defini a la periode de base (transfert de l'etranger
   recu en 2018) */
merge m:1 grappe menage using "$TEMP/traitement_2018.dta", ///
    keepusing(D) keep(match) nogenerate

/* Restriction aux menages du panel vrai */
merge m:1 grappe menage using "$TEMP/ids_panel.dta", keep(match) nogenerate

/* Statut aux deux vagues, pour la definition du design principal */
merge m:1 grappe menage using "$TEMP/traitement_stable.dta", ///
    keepusing(D_2018 D_2021) keep(master match) nogenerate

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

/* Cas complets sur les seules variables qui entrent dans l'estimation :
   le traitement, les covariables du score et les deux resultats. Les
   variables ecartees du score (log_pcexp, hhsize, hcsp) ne conditionnent
   plus l'echantillon : les exclure du modele tout en excluant les enfants
   dont elles manquent restreindrait le panel sans contrepartie. */
drop if missing(D) | missing(sexe18) | missing(age18) ///
       | missing(milieu) | missing(region) | missing(hgender) ///
       | missing(hage) | missing(heduc) | missing(hmstat) ///
       | missing(pauvre_MODA18) | missing(pauvre_MODA21)

/* ── DESIGN PRINCIPAL : beneficiaires stables vs jamais beneficiaires ──
   Le traitement du design principal est l'exposition continue : menages
   beneficiaires aux DEUX vagues (D_2018=1 et D_2021=1) contre menages
   jamais beneficiaires (0 aux deux vagues). Deux raisons commandent ce
   choix. La premiere est la definition meme du traitement : pres d'un
   beneficiaire de 2018 sur deux ne recoit plus en 2021, en partie parce
   que la pandemie de COVID-19 a interrompu les envois en 2020 ; classer
   ces menages parmi les traites reviendrait a mesurer l'effet d'un
   traitement largement eteint. La seconde est la lisibilite de l'effet :
   chez les stables, le flux est effectif sur toute la periode, et l'ATT
   se lit comme l'effet d'une exposition durable aux transferts.
   En contrepartie, le traitement est deja en cours a t=0 : la periode de
   base n'est pas une periode pre-traitement, et la DD s'interprete comme
   l'ecart de trajectoire entre exposition continue et absence continue.
   La definition a la periode de base (D de 2018, transitoires inclus)
   est conservee en robustesse (section 8).
   L'echantillon complet est sauvegarde avant restriction pour cette
   meme section 8. */
gen byte hage_cl = .
replace  hage_cl = 1 if hage <  35
replace  hage_cl = 2 if hage >= 35 & hage < 50
replace  hage_cl = 3 if hage >= 50 & hage < 65
replace  hage_cl = 4 if hage >= 65 & !missing(hage)
label define hagecl 1 "Moins de 35 ans" 2 "35-49 ans" ///
                    3 "50-64 ans" 4 "65 ans et plus", replace
label values hage_cl hagecl
label var hage_cl "Age du chef de menage, en classes"

save "$TEMP/panel_large_tous.dta", replace

quietly count
local n_avant = r(N)
keep if D_2018 == D_2021
di _newline "=== Design principal : stables vs jamais ==="
di "  Enfants suivis au total          : `n_avant'"
quietly count if D == 1
di "  Enfants de beneficiaires stables : " r(N)
quietly count if D == 0
di "  Enfants jamais beneficiaires     : " r(N)
quietly count
di "  Transitoires ecartes             : " `n_avant' - r(N)

/* ── Validation empirique de l'appariement individuel ─────────
   Deux verifications qu'un appariement arbitraire ne pourrait pas
   satisfaire. */
di _newline "--- Validation de l'appariement individuel ---"
quietly count if sexe18 == sexe21
di "  Concordance du genre entre vagues : " %5.1f 100*r(N)/_N "%"
quietly gen int ecart_age = age21 - age18
quietly summarize ecart_age, detail
di "  Ecart d'age : mediane " %4.1f r(p50) "  moyenne " %5.2f r(mean)
quietly count if inrange(ecart_age, 2, 4)
di "  Part avec ecart d'age dans [2 ; 4] ans : " %5.1f 100*r(N)/_N "%"
quietly count if ecart_age < 0
di "  Part avec ecart d'age negatif (erreur de declaration) : " %5.1f 100*r(N)/_N "%"
quietly drop ecart_age


/* ============================================================
   1a-bis. TESTS DE COMPARAISON AVANT L'ESTIMATION D'IMPACT

   Avant toute estimation, on documente l'ecart initial entre
   enfants beneficiaires et non beneficiaires. Trois tests :

     (i)   comparaison des caracteristiques observables a t=0
           (test de Student sur la difference de moyennes, erreurs-
           types clusterisees au niveau de la grappe) ;
     (ii)  comparaison des resultats a t=0 (indice MODA, nombre de
           privations, intensite, chaque dimension) : c'est l'ecart
           que la double difference doit neutraliser, et non
           attribuer au traitement ;
     (iii) test joint de l'ensemble des covariables (test du
           rapport de vraisemblance du logit de D). Le rejet de
           l'egalite jointe est le fait empirique qui justifie
           l'appariement : une comparaison directe des deux groupes
           serait biaisee.
   ============================================================ */

di _newline "=== 1a-bis. Tests de comparaison avant estimation ==="

quietly gen byte chef_f_t = (hgender == 2)
quietly gen byte urbain_t = (milieu  == 1)

di _newline "-- (i) Caracteristiques observables a t=0 --"
di "  variable            D=1        D=0      diff        p"
foreach v of varlist hhsize log_pcexp hage chef_f_t urbain_t sexe18 age18 {
    quietly summarize `v' if D == 1
    local m1 = r(mean)
    quietly summarize `v' if D == 0
    local m0 = r(mean)
    quietly regress `v' D, vce(cluster grappe)
    local p = 2*ttail(e(df_r), abs(_b[D]/_se[D]))
    di "  " %-16s "`v'" %9.3f `m1' %10.3f `m0' %10.3f `m1'-`m0' %9.4f `p'
}

di _newline "-- (ii) Resultats a t=0 (ecart initial a neutraliser) --"
di "  variable            D=1        D=0      diff        p"
foreach v of varlist pauvre_MODA18 nb_dep18 intensite_moda18 ///
                     dim_assai18 dim_eau18 dim_logem18 dim_nutri18 ///
                     dim_sante18 dim_protect18 dim_educ18 {
    quietly summarize `v' if D == 1
    local m1 = r(mean)
    quietly summarize `v' if D == 0
    local m0 = r(mean)
    quietly regress `v' D, vce(cluster grappe)
    local p = 2*ttail(e(df_r), abs(_b[D]/_se[D]))
    di "  " %-16s "`v'" %9.3f `m1' %10.3f `m0' %10.3f `m1'-`m0' %9.4f `p'
}

di _newline "-- (iii) Test joint d'egalite des covariables --"
quietly logit D $COV_SCORE, nolog
local lr   = 2*(e(ll) - e(ll_0))
local ddl  = e(df_m)
di "  LR chi2(" `ddl' ") = " %8.2f `lr' ///
   "   p = " %6.4f chi2tail(`ddl', `lr')
di "  H0 : les deux groupes ont la meme distribution de covariables."
di "  Le rejet justifie l'appariement prealable a la double difference."

/* ============================================================
   1a-ter. TESTS D'ENDOGENEITE

   Une covariable du score de propension doit etre PREDETERMINEE :
   fixee avant le traitement, et non modifiee par lui. Une variable
   affectee par les transferts introduirait dans le score un canal
   par lequel le traitement agit, et l'appariement en absorberait
   une partie de l'effet ("bad control").

   Test retenu : pour chaque variable candidate mesuree aux deux
   vagues, on regresse sa valeur en 2021 sur le traitement de 2018
   en controlant sa valeur de 2018. Un coefficient significatif sur
   D signifie que le traitement deplace la variable : elle n'est pas
   predeterminee et ne peut pas servir de covariable d'appariement.

   Le meme test est applique a la separation parentale, non plus
   comme covariable mais comme indicateur de privation : s'il est
   positif, l'indice MODA contiendrait une privation que la
   migration produit mecaniquement, ce qui suffit a la retirer de
   l'agregat (cf. dimension Protection, section B).
   ============================================================ */

di _newline "=== 1a-ter. Tests d'endogeneite ==="

di _newline "-- Separation parentale : le traitement la produit-il ? --"
quietly regress m_parents21 D m_parents18, vce(cluster grappe)
di "  Effet de D sur la separation parentale en 2021 : " ///
   %7.4f _b[D] "  (et " %6.4f _se[D] ")  p = " ///
   %6.4f 2*ttail(e(df_r), abs(_b[D]/_se[D]))
di "  Un coefficient positif et significatif confirme que cet"
di "  indicateur est un RESULTAT du traitement, non une privation"
di "  independante : il est exclu de l'indice MODA."

di _newline "-- Dimensions MODA : lesquelles le traitement deplace-t-il ? --"
di "  (diagnostic, non un test de validite du score)"
foreach v in assai eau logem nutri sante protect educ {
    quietly regress dim_`v'21 D dim_`v'18, vce(cluster grappe)
    di "  dim_" %-8s "`v'" " : b(D) = " %7.4f _b[D] ///
       "   p = " %6.4f 2*ttail(e(df_r), abs(_b[D]/_se[D]))
}

drop m_parents18 m_parents21 chef_f_t urbain_t

di _newline "=== Logit ENFANT — score de propension (EHCVM I, panel d'enfants) ==="
di "Enfants suivis aux deux vagues : " _N

/* ── 1b. Logit au niveau enfant, SEPAREMENT PAR GROUPE D'AGE ──
   Covariables du menage a t=0 + genre et age de l'enfant. Erreurs-types
   clusterisees au niveau de la grappe (le traitement varie au niveau
   menage : la correlation intra-grappe couvre aussi l'intra-menage).

   Le score est estime a l'interieur de chaque groupe d'age MODA plutot
   que sur l'ensemble des enfants. Deux raisons. D'abord la mesure : les
   indicateurs qui composent l'indice ne sont pas les memes selon l'age,
   si bien qu'un enfant de 2 ans et un adolescent de 16 ans ne subissent
   pas les memes privations potentielles et ne sont pas des contrefactuels
   l'un de l'autre. Ensuite la selection : les determinants de la reception
   d'un transfert n'ont aucune raison de peser du meme poids selon l'age de
   l'enfant, et un score commun impose des coefficients identiques aux trois
   groupes. Estimer separement autorise ces coefficients a differer et
   garantit que chaque enfant traite est apparie a un temoin du meme groupe
   d'age. */

/* ── Specification du score de propension ───────────────────
   Trois covariables presentes dans une premiere version ont ete
   RETIREES parce qu'elles ne sont pas predeterminees : le traitement
   les modifie, et les inclure revient a controler un canal par lequel
   il agit ("bad control"), donc a absorber dans l'appariement une part
   de l'effet que l'on cherche a mesurer.

     - log_pcexp : la depense par tete est mecaniquement augmentee par
       le transfert recu, qui est une ressource du menage ;
     - hhsize    : la taille du menage enregistre le depart du migrant
       et, le cas echeant, l'accueil de nouveaux membres finance par
       les envois ;
     - hcsp      : la categorie socioprofessionnelle du chef reflete son
       activite, dont Ndiaye (2016) montre qu'elle est reduite par la
       reception de transferts.

   Sont conservees les seules caracteristiques qu'un transfert recu en
   2018 ne peut avoir modifiees : la localisation (milieu, region), le
   genre, l'age, le niveau d'education et le statut matrimonial du chef,
   le genre et l'age de l'enfant.

   Les trois variables retirees restent affichees dans les tests
   d'equilibre : on verifie ainsi que l'appariement les rapproche malgre
   tout, sans les avoir utilisees. */
/* L'age de l'enfant ne figure pas dans le score : l'estimation etant
   conduite a l'interieur de chaque groupe d'age, l'appariement est deja
   contraint par l'age, et la variable n'apporterait qu'une variation
   residuelle intra-groupe sans lien etabli avec la selection.
   L'age du chef entre en classes plutot qu'en continu : la relation entre
   l'age et la probabilite d'avoir un migrant dans le menage n'a aucune
   raison d'etre lineaire, un chef age etant plus souvent le parent reste
   au pays d'un enfant adulte parti. */
global COV_SCORE "i.milieu i.region c.hgender i.hage_cl i.heduc i.hmstat i.sexe18"

gen byte grp_psm = groupe_moda18
label values grp_psm grp
label var grp_psm "Groupe d'age MODA a la periode de base"

gen double pscore = .
label var pscore "Score de propension (enfant, estime par groupe d'age)"

forvalues g = 1/3 {
    di _newline "-- Logit, groupe d'age `g' --"
    quietly count if grp_psm == `g'
    di "   Enfants : " r(N)
    quietly count if grp_psm == `g' & D == 1
    di "   dont traites : " r(N)

    logit D $COV_SCORE if grp_psm == `g', vce(cluster grappe) nolog

    di "   Pseudo-R2 McFadden : " %6.3f 1 - e(ll)/e(ll_0)

    quietly predict double ps_tmp if e(sample), pr
    quietly replace pscore = ps_tmp if grp_psm == `g' & !missing(ps_tmp)
    drop ps_tmp
}

/* Un enfant dont le logit de son groupe n'a pas pu produire de prediction
   (colinearite parfaite sur une modalite rare) est ecarte : il ne pourrait
   pas etre apparie. */
quietly count if missing(pscore)
di _newline "Enfants sans score de propension (ecartes) : " r(N)
drop if missing(pscore)

/* ============================================================
   1c. ANALYSES DE CHEVAUCHEMENT (SUPPORT COMMUN)

   L'appariement n'a de sens que si chaque enfant beneficiaire trouve,
   parmi les non beneficiaires, des enfants de score comparable. C'est
   la seconde hypothese du PSM, celle du support commun. Elle ne se
   verifie pas par un test unique mais par un faisceau d'elements, tous
   produits ici, et separement dans chaque groupe d'age puisque le score
   y est estime separement.

     (i)   l'etendue des scores dans chaque groupe de traitement, d'ou
           se deduit la region de recouvrement ;
     (ii)  le nombre et la part d'enfants traites situes hors de cette
           region : ce sont ceux que l'appariement devra ecarter, et
           leur poids mesure la perte d'echantillon ;
     (iii) la repartition par decile de score, qui revele les zones ou
           les temoins se rarefient meme sans sortir du support ;
     (iv)  le coefficient de chevauchement, part de l'echantillon situee
           sous le minimum des deux densites, resume en un nombre ;
     (v)   les densites, avant et apres appariement.

   Un chevauchement insuffisant ne s'annule pas par un choix technique :
   il restreint la population sur laquelle l'effet est identifie, ce que
   le rapport doit dire plutot que masquer.
   ============================================================ */

di _newline "=== 1c. Analyses de chevauchement (support commun) ==="

forvalues g = 1/3 {

    di _newline "--- Groupe d'age `g' ---"

    /* (i) Etendue des scores et region de recouvrement */
    quietly summarize pscore if grp_psm == `g' & D == 1, detail
    local min1 = r(min)
    local max1 = r(max)
    local p50_1 = r(p50)
    quietly summarize pscore if grp_psm == `g' & D == 0, detail
    local min0 = r(min)
    local max0 = r(max)
    local p50_0 = r(p50)

    local binf = max(`min1', `min0')
    local bsup = min(`max1', `max0')

    di "  Traites  : min " %6.4f `min1' "  mediane " %6.4f `p50_1' ///
       "  max " %6.4f `max1'
    di "  Temoins  : min " %6.4f `min0' "  mediane " %6.4f `p50_0' ///
       "  max " %6.4f `max0'
    di "  Region de recouvrement : [" %6.4f `binf' " ; " %6.4f `bsup' "]"

    /* (ii) Traites hors region de recouvrement */
    quietly count if grp_psm == `g' & D == 1
    local n_tr = r(N)
    quietly count if grp_psm == `g' & D == 1 & (pscore < `binf' | pscore > `bsup')
    local n_hors = r(N)
    di "  Traites hors support : " `n_hors' " sur " `n_tr' ///
       "  (" %5.2f 100*`n_hors'/`n_tr' " %)"
    if 100*`n_hors'/`n_tr' > 5 {
        di "  ATTENTION : plus de 5 % des traites sont hors support."
        di "  L'effet estime ne vaut alors que pour la sous-population"
        di "  effectivement appariable, ce qui doit etre signale."
    }

    /* (iii) Repartition par decile de score */
    quietly xtile dec_ps = pscore if grp_psm == `g', nq(10)
    di _newline "  Repartition par decile de score :"
    di "    decile   traites   temoins   ratio temoins/traite"
    forvalues d = 1/10 {
        quietly count if grp_psm == `g' & dec_ps == `d' & D == 1
        local nd1 = r(N)
        quietly count if grp_psm == `g' & dec_ps == `d' & D == 0
        local nd0 = r(N)
        if `nd1' > 0 {
            di "    " %6.0f `d' %10.0f `nd1' %10.0f `nd0' %12.1f `nd0'/`nd1'
        }
        else {
            di "    " %6.0f `d' %10.0f `nd1' %10.0f `nd0' "        (aucun traite)"
        }
    }
    quietly drop dec_ps

    /* (iv) Coefficient de chevauchement des deux densites.
       Les deux densites sont estimees sur une grille commune de 100
       points ; le coefficient est l'aire situee sous leur minimum,
       comprise entre 0 (aucun recouvrement) et 1 (densites confondues). */
    capture noisily {
        tempvar gx d1 d0
        quietly kdensity pscore if grp_psm == `g' & D == 1, ///
            generate(`gx' `d1') n(100) nograph
        quietly kdensity pscore if grp_psm == `g' & D == 0, ///
            at(`gx') generate(`d0') nograph
        quietly summarize `gx'
        local pas = (r(max) - r(min)) / 99
        tempvar mn
        quietly gen double `mn' = min(`d1', `d0')
        quietly summarize `mn', meanonly
        di _newline "  Coefficient de chevauchement : " ///
           %5.3f r(sum)*`pas'
        drop `gx' `d1' `d0' `mn'
    }
    if _rc != 0 {
        di _newline "  Coefficient de chevauchement : non calculable"
    }
}

/* (v) Densites du score, par groupe d'age, AVANT appariement */
set dp comma
forvalues g = 1/3 {
    local titg : label grp `g'
    quietly twoway ///
        (kdensity pscore if D == 0 & grp_psm == `g', ///
         lcolor(gs9) lwidth(medthick)) ///
        (kdensity pscore if D == 1 & grp_psm == `g', ///
         lcolor(orange) lwidth(medthick)), ///
        legend(order(1 "Non bénéficiaires" 2 "Bénéficiaires") ///
               pos(6) rows(1) region(color(white))) ///
        xtitle("Score de propension") ytitle("Densité") ///
        xlabel(, format(%3.1f)) ///
        title("`titg'", size(medium)) ///
        graphregion(color(white)) plotregion(color(white)) ///
        name(ov`g', replace)
}
graph combine ov1 ov2 ov3, rows(1) ///
    graphregion(color(white)) ///
    saving("$OUTPUT/overlap_groupes.gph", replace)
graph export "$OUTPUT/figures/fig_overlap_groupes.pdf", replace
graph drop ov1 ov2 ov3

/* Densite d'ensemble (tous groupes confondus), conservee pour la
   comparaison avec la version anterieure du rapport */
twoway ///
    (kdensity pscore if D == 0, lcolor(gs9) lwidth(medthick)) ///
    (kdensity pscore if D == 1, lcolor(orange) lwidth(medthick)), ///
    legend(order(1 "Enfants non bénéficiaires" 2 "Enfants bénéficiaires") ///
           pos(6) rows(1) region(color(white))) ///
    xtitle("Score de propension") ytitle("Densité") ///
    xlabel(, format(%3.1f)) ///
    graphregion(color(white)) plotregion(color(white)) ///
    saving("$OUTPUT/overlap_panel.gph", replace)
set dp period
graph export "$OUTPUT/overlap_panel.pdf", replace

/* ── Variables d'equilibre ───────────────────────────────────
   Les variables categorielles sont eclatees en indicatrices : le biais
   standardise n'a de sens que modalite par modalite. La liste couvre la
   specification du score ET les trois variables qui en ont ete ecartees,
   afin de voir ce que l'appariement en fait sans les avoir utilisees. */
quietly tabulate region, generate(_beq_reg)
quietly tabulate heduc,  generate(_beq_edu)
quietly tabulate hmstat, generate(_beq_mst)
quietly tabulate hcsp,   generate(_beq_csp)
quietly tabulate hage_cl, generate(_beq_hag)
quietly generate byte _beq_urb   = (milieu == 1)
quietly generate byte _beq_fille = (sexe18 == 2)
global BALVARS "_beq_urb _beq_reg* _beq_edu* _beq_mst* hgender _beq_hag* _beq_fille hhsize log_pcexp _beq_csp*"

save "$TEMP/pscore_t0.dta", replace

/* ============================================================
   2. Appariement PSM au niveau ENFANT

   Trois algorithmes pour robustesse :
     a. k plus proches voisins (k=K_VOISINS, avec remise)
     b. Kernel Epanechnikov (h=0.06)
     c. Caliper (epsilon=CALIPER, sans remise)

   Chaque enfant traite est apparie a des enfants temoins de profil
   observable comparable, y compris en genre et en age.
   ============================================================ */

/* La liste d'equilibre est plus large que la specification du score :
   elle inclut les trois variables ecartees (hhsize, log_pcexp, hcsp),
   afin de montrer ce que l'appariement en fait sans les avoir utilisees. */
local covbal i.milieu i.region hgender i.hage_cl i.heduc i.hmstat ///
             i.sexe18 hhsize log_pcexp i.hcsp

/* ── Outil de mesure de l'equilibre ──────────────────────────
   pstest affiche un tableau lisible mais ne renvoie rien d'exploitable
   dans r() : le biais moyen doit donc etre recalcule ici pour pouvoir
   departager les trois algorithmes. Pour chaque covariable, l'ecart de
   moyennes entre traites et temoins apres appariement est rapporte a la
   dispersion commune AVANT appariement, convention de Rosenbaum et Rubin
   (1985) ; le programme renvoie la moyenne des valeurs absolues. */
capture program drop _biaismoyen
program define _biaismoyen, rclass
    syntax varlist(numeric), treat(varname) [pond(varname)]
    local somme = 0
    local k     = 0
    foreach v of local varlist {
        quietly summarize `v' if `treat' == 1
        local vT = r(Var)
        quietly summarize `v' if `treat' == 0
        local vC = r(Var)
        local den = sqrt((`vT' + `vC')/2)
        if `den' > 0 & !missing(`den') {
            if "`pond'" != "" {
                quietly summarize `v' if `treat' == 1 [aw=`pond']
                local mT = r(mean)
                quietly summarize `v' if `treat' == 0 [aw=`pond']
                local mC = r(mean)
            }
            else {
                quietly summarize `v' if `treat' == 1
                local mT = r(mean)
                quietly summarize `v' if `treat' == 0
                local mC = r(mean)
            }
            if !missing(`mT') & !missing(`mC') {
                local somme = `somme' + abs(100*(`mT' - `mC')/`den')
                local k     = `k' + 1
            }
        }
    }
    if `k' > 0   return scalar meanbias = `somme'/`k'
    else         return scalar meanbias = .
    return scalar nvar = `k'
end

/* Accumulateurs du desequilibre residuel, alimentes methode par methode
   et groupe par groupe, puis moyennes pour departager les trois
   algorithmes (section 2e). */
foreach m in knn kernel caliper {
    global BIAIS_`m' = 0
    global NOBS_`m'  = 0
}

/* Valeurs par defaut de la methode retenue. Elles sont ecrasees en
   section 2e par le resultat du critere d'equilibre. Les poser ici
   garantit qu'aucune section ulterieure ne s'interrompra sur un nom de
   variable vide, meme si le calcul du biais echoue. */
global METHODE         "knn"
global POIDS_PRINCIPAL "weight_knn"

/* L'appariement est effectue A L'INTERIEUR de chaque groupe d'age, avec
   le score estime sur ce meme groupe et un support commun propre au
   groupe. Les poids des trois groupes sont ensuite empiles : la double
   difference qui suit est inchangee, mais aucun appariement ne franchit
   plus une frontiere d'age. */

/* -- 2a. k-NN ------------------------------------------------ */
di _newline "=== Appariement k-NN (k=$K_VOISINS, avec remise), par groupe d'age ==="
tempfile knn_all
local premier = 1
forvalues g = 1/3 {
    use "$TEMP/pscore_t0.dta", clear
    keep if grp_psm == `g'
    di _newline "-- Groupe d'age `g' : " _N " enfants --"
    psmatch2 D, pscore(pscore) neighbor($K_VOISINS) common

    di _newline "Balance avant/apres (SMD), groupe `g' :"
    /* pstest estime un probit interne qui peut ne pas converger sur un
       groupe a tres faible effectif (r(430)) : son tableau est purement
       descriptif, l'echec ne doit pas interrompre le pipeline. Le biais
       retenu pour departager les methodes est calcule par _biaismoyen,
       independant de pstest. */
    capture noisily pstest `covbal', both
    if _rc di "  !! pstest non convergent sur ce groupe (r(" _rc ")) — ignore."
    quietly _biaismoyen $BALVARS, treat(D) pond(_weight)
    global BIAIS_knn = ${BIAIS_knn} + r(meanbias)*_N
    global NOBS_knn  = ${NOBS_knn}  + _N
    di "  Biais standardise moyen residuel, groupe `g' : " %5.2f r(meanbias) " %"

    rename _weight weight_knn
    keep enfid grappe menage numind_2018 D pscore weight_knn _support grp_psm
    if `premier' == 1 {
        save `knn_all', replace
        local premier = 0
    }
    else {
        append using `knn_all'
        save `knn_all', replace
    }
}
use `knn_all', clear
save "$TEMP/pscore_knn.dta", replace
di _newline ">>> k-NN : " _N " enfants apparies (trois groupes empiles)"

/* -- 2b. Kernel ---------------------------------------------- */
di _newline "=== Appariement Kernel (Epanechnikov, h=0.06), par groupe d'age ==="
tempfile ker_all
local premier = 1
forvalues g = 1/3 {
    use "$TEMP/pscore_t0.dta", clear
    keep if grp_psm == `g'
    di _newline "-- Groupe d'age `g' --"
    psmatch2 D, pscore(pscore) kernel kerneltype(epan) bwidth(0.06) common

    di _newline "Balance avant/apres (SMD), kernel, groupe `g' :"
    /* pstest estime un probit interne qui peut ne pas converger sur un
       groupe a tres faible effectif (r(430)) : son tableau est purement
       descriptif, l'echec ne doit pas interrompre le pipeline. Le biais
       retenu pour departager les methodes est calcule par _biaismoyen,
       independant de pstest. */
    capture noisily pstest `covbal', both
    if _rc di "  !! pstest non convergent sur ce groupe (r(" _rc ")) — ignore."
    quietly _biaismoyen $BALVARS, treat(D) pond(_weight)
    global BIAIS_kernel = ${BIAIS_kernel} + r(meanbias)*_N
    global NOBS_kernel  = ${NOBS_kernel}  + _N
    di "  Biais standardise moyen residuel, groupe `g' : " %5.2f r(meanbias) " %"

    rename _weight weight_kernel
    keep enfid weight_kernel
    if `premier' == 1 {
        save `ker_all', replace
        local premier = 0
    }
    else {
        append using `ker_all'
        save `ker_all', replace
    }
}
use `ker_all', clear
save "$TEMP/poids_kernel.dta", replace

/* -- 2c. Caliper --------------------------------------------- */
di _newline "=== Appariement Caliper (eps=$CALIPER, sans remise), par groupe d'age ==="
tempfile cal_all
local premier = 1
forvalues g = 1/3 {
    use "$TEMP/pscore_t0.dta", clear
    keep if grp_psm == `g'
    di _newline "-- Groupe d'age `g' --"
    psmatch2 D, pscore(pscore) caliper($CALIPER) noreplacement common

    di _newline "Balance avant/apres (SMD), caliper, groupe `g' :"
    /* pstest estime un probit interne qui peut ne pas converger sur un
       groupe a tres faible effectif (r(430)) : son tableau est purement
       descriptif, l'echec ne doit pas interrompre le pipeline. Le biais
       retenu pour departager les methodes est calcule par _biaismoyen,
       independant de pstest. */
    capture noisily pstest `covbal', both
    if _rc di "  !! pstest non convergent sur ce groupe (r(" _rc ")) — ignore."
    quietly _biaismoyen $BALVARS, treat(D) pond(_weight)
    global BIAIS_caliper = ${BIAIS_caliper} + r(meanbias)*_N
    global NOBS_caliper  = ${NOBS_caliper}  + _N
    di "  Biais standardise moyen residuel, groupe `g' : " %5.2f r(meanbias) " %"

    rename _weight weight_caliper
    keep enfid weight_caliper
    if `premier' == 1 {
        save `cal_all', replace
        local premier = 0
    }
    else {
        append using `cal_all'
        save `cal_all', replace
    }
}
use `cal_all', clear
save "$TEMP/poids_caliper.dta", replace

/* ── 2e. Choix de la methode d'appariement ───────────────────
   Les trois algorithmes sont conserves et leurs resultats presentes
   ensemble (section 7, robustesse). L'un d'eux fournit neanmoins le
   resultat de reference, et ce choix ne doit rien a la valeur de l'ATT
   qu'il produit : il se fonde sur le seul critere d'equilibre, le biais
   standardise moyen residuel sur les covariables apres appariement,
   moyenne sur les trois groupes d'age et pondere par leur effectif.
   L'algorithme qui rend les deux groupes les plus comparables est
   retenu ; les deux autres servent a verifier que la conclusion n'en
   depend pas.
   ============================================================ */

di _newline "=== 2e. Comparaison des trois methodes d'appariement ==="
di "  methode      biais standardise moyen apres appariement (%)"

local meilleure  ""
local biais_min  = .
foreach m in knn kernel caliper {
    local b = ${BIAIS_`m'} / ${NOBS_`m'}
    global BIAISMOY_`m' = `b'
    di "  " %-12s "`m'" %10.2f `b'
    if `b' < `biais_min' {
        local biais_min = `b'
        local meilleure = "`m'"
    }
}

/* Garde-fou : si aucun biais n'a pu etre calcule, l'execution se
   poursuit sur le k-NN plutot que de s'interrompre plus loin sur un nom
   de variable vide. */
if "`meilleure'" == "" {
    di "  !! Aucun biais calculable : repli sur le k-NN."
    local meilleure "knn"
}

global METHODE         "`meilleure'"
global POIDS_PRINCIPAL "weight_`meilleure'"
di _newline "  >>> Methode retenue : $METHODE (biais moyen " %5.2f `biais_min' " %)"

/* Chevauchement APRES appariement, methode retenue : la densite des
   temoins est ponderee par les poids d'appariement. Si l'appariement a
   fonctionne, les deux densites se superposent, la ou celles d'avant
   appariement se croisaient a peine. */
use "$TEMP/pscore_t0.dta", clear
merge 1:1 enfid using "$TEMP/pscore_knn.dta",    keepusing(weight_knn)     nogenerate
merge 1:1 enfid using "$TEMP/poids_kernel.dta",  keepusing(weight_kernel)  nogenerate
merge 1:1 enfid using "$TEMP/poids_caliper.dta", keepusing(weight_caliper) nogenerate
if "$POIDS_PRINCIPAL" == "" | "$POIDS_PRINCIPAL" == "weight_" {
    global METHODE         "knn"
    global POIDS_PRINCIPAL "weight_knn"
    di "  !! Methode non determinee en amont : repli sur le k-NN."
}
quietly keep if !missing($POIDS_PRINCIPAL) & $POIDS_PRINCIPAL > 0

di _newline "  Enfants sur support commun apres appariement : " _N
quietly count if D == 1
di "  dont traites : " r(N)

set dp comma
forvalues g = 1/3 {
    local titg : label grp `g'
    quietly twoway ///
        (kdensity pscore if D == 0 & grp_psm == `g' [aw=$POIDS_PRINCIPAL], ///
         lcolor(gs9) lwidth(medthick)) ///
        (kdensity pscore if D == 1 & grp_psm == `g' [aw=$POIDS_PRINCIPAL], ///
         lcolor(orange) lwidth(medthick)), ///
        legend(order(1 "Non bénéficiaires (pondérés)" 2 "Bénéficiaires") ///
               pos(6) rows(1) region(color(white))) ///
        xtitle("Score de propension") ytitle("Densité") ///
        xlabel(, format(%3.1f)) ///
        title("`titg'", size(medium)) ///
        graphregion(color(white)) plotregion(color(white)) ///
        name(ova`g', replace)
}
graph combine ova1 ova2 ova3, rows(1) graphregion(color(white))
set dp period
graph export "$OUTPUT/figures/fig_overlap_apres.pdf", replace
graph drop ova1 ova2 ova3
di "  >>> fig_overlap_apres.pdf sauvegarde (trois panneaux, un par groupe)"
di "      Les resultats des deux autres methodes restent presentes"
di "      integralement dans la section robustesse."

/* ── 2d. Panel d'enfants en format long ──────────────────────
   Chaque enfant apparait a t=0 et t=1 avec SON poids d'appariement, qui
   ne varie pas dans le temps : c'est exactement ce qu'exige la double
   difference appariee de Heckman et al. (1997, 1998). */
use "$TEMP/pscore_t0.dta", clear
merge 1:1 enfid using "$TEMP/poids_kernel.dta",  nogenerate
merge 1:1 enfid using "$TEMP/poids_caliper.dta", nogenerate
merge 1:1 enfid using "$TEMP/pscore_knn.dta", ///
    keepusing(weight_knn _support) nogenerate

/* Groupe d'age fige a la periode de base. Un enfant de 3 ans en 2018 en a
   6 en 2021 : recalcule a chaque vague, le groupe change en cours de panel
   et la double difference d'un sous-groupe ne compare plus le meme enfant a
   lui-meme. Le groupe de base suit l'enfant aux deux vagues, si bien que
   « 0-4 ans » se lit « age de 0 a 4 ans en 2018 ». */
clonevar groupe_base = groupe_moda18
label var groupe_base "Groupe d'age MODA a la periode de base (2018)"

reshape long pauvre_MODA nb_dep intensite_moda groupe_moda sexe age ///
             dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect dim_educ ///
             m_toilet m_partag_toi m_eau_source m_eau_temps m_ordures m_surpeup m_securite m_combust m_sante_acces m_acte_nais m_trav_enf m_scol m_alfab ///
             m_acte_nc m_scol_nc m_alfab_nc, ///
    i(enfid) j(periode)
gen byte t = (periode == 21)
label var t "0 = EHCVM I (2018-19), 1 = EHCVM II (2021-22)"
drop periode

/* ── GRILLE FIGEE A LA PERIODE DE BASE ───────────────────────
   La double difference exige que chaque enfant soit mesure sur la meme
   grille aux deux dates : les privations de 2021 sont donc recalculees
   sur la grille du groupe d'age DE BASE, a partir des versions non
   plafonnees des indicateurs individuels. Un enfant de la grille 5-14
   devenu 15-17 reste evalue sur l'acte de naissance et la scolarisation.
   La limite, assumee et discutee dans le rapport, est que ces privations
   sont mesurees en 2021 sur des enfants qui n'ont plus l'age de la
   grille. Les dimensions du cadre de vie (assainissement, eau, logement,
   nutrition, sante), identiques d'une grille a l'autre, sont inchangees. */
replace dim_protect = (m_acte_nc == 1) ///
    if t == 1 & groupe_base == 1 & !missing(m_acte_nc)
replace dim_protect = . ///
    if t == 1 & groupe_base == 1 & missing(m_acte_nc)
replace dim_protect = (m_acte_nc == 1 | m_trav_enf == 1) ///
    if t == 1 & groupe_base == 2 & !missing(m_acte_nc) & !missing(m_trav_enf)
replace dim_protect = . ///
    if t == 1 & groupe_base == 2 & (missing(m_acte_nc) | missing(m_trav_enf))
replace dim_protect = (m_trav_enf == 1) ///
    if t == 1 & groupe_base == 3 & !missing(m_trav_enf)
replace dim_protect = . ///
    if t == 1 & groupe_base == 3 & missing(m_trav_enf)

replace dim_educ = 0 if t == 1 & groupe_base == 1
replace dim_educ = m_scol_nc  if t == 1 & groupe_base == 2
replace dim_educ = m_alfab_nc if t == 1 & groupe_base == 3

/* Reagregation sur la grille figee */
replace nb_dep = dim_assai + dim_eau + dim_logem + dim_nutri + ///
                 dim_sante + dim_protect + dim_educ if t == 1
replace pauvre_MODA = (nb_dep >= $K_MODA) if t == 1 & !missing(nb_dep)
replace pauvre_MODA = . if t == 1 & missing(nb_dep)
replace intensite_moda = nb_dep / 7 if t == 1

quietly count if t == 1 & missing(pauvre_MODA)
di _newline ">>> Grille figee a la base : " r(N) ///
    " observations 2021 sans indice (cas incomplets sur la grille)"

save "$TEMP/panel_enfants_psm.dta", replace

di _newline "Panel d'enfants apparie : " _N " observations (" ///
    %6.0f `=_N/2' " enfants x 2 vagues)"

/* ── Ventilation des enfants suivis par statut de beneficiaire ──
   Alimente le tableau de repartition du traitement (chap. 2) et le
   tableau d'effectifs des statistiques descriptives (chap. 4) : les
   quatre statuts possibles au croisement des deux vagues, sur
   L'ENSEMBLE des enfants suivis (avant restriction du design principal
   aux stables et jamais beneficiaires), au total et par groupe d'age. */
use "$TEMP/panel_large_tous.dta", clear
gen str24 statut_stab = ""
replace statut_stab = "1. Beneficiaire stable"   if D_2018 == 1 & D_2021 == 1
replace statut_stab = "2. Beneficiaire 2018 slt" if D_2018 == 1 & D_2021 == 0
replace statut_stab = "3. Beneficiaire 2021 slt" if D_2018 == 0 & D_2021 == 1
replace statut_stab = "4. Jamais beneficiaire"   if D_2018 == 0 & D_2021 == 0
di _newline "=== Enfants suivis : les quatre statuts possibles ==="
tab statut_stab, missing
di _newline "=== Effectifs par statut et groupe d'age (periode de base) ==="
tab statut_stab groupe_moda18, missing
di _newline "=== Design principal : effectifs beneficiaires / non ==="
di "  (stables = traites ; jamais = temoins ; transitoires ecartes)"
tab statut_stab if D_2018 == D_2021

/* ============================================================
   3. Statistiques descriptives sur le panel
   ============================================================ */

use "$TEMP/panel_enfants_psm.dta", clear
di _newline "=== Stats descriptives (design principal : stables vs jamais) ==="
tabstat pauvre_MODA nb_dep pcexp, ///
    by(D) stat(mean n) format(%6.3f)

/* ── Incidence H, intensite A et indice ajuste M0 ────────────
   Les trois indices Alkire-Foster sont presentes ensemble : H seul
   confond sortie de pauvrete et attenuation des privations chez ceux
   qui restent pauvres. A est la part moyenne des sept dimensions en
   privation PARMI LES PAUVRES (s_i >= k), et M0 = H x A. Chaque bloc
   est decline par statut et par edition, puis par groupe d'age :
   c'est la matrice descriptive complete que le rapport commente. */
di _newline "=== H, A et M0 par statut et par edition ==="
forvalues d = 0/1 {
    forvalues tt = 0/1 {
        quietly summarize pauvre_MODA if D == `d' & t == `tt'
        local H = r(mean)
        quietly summarize intensite_moda if D == `d' & t == `tt' & pauvre_MODA == 1
        local A = r(mean)
        di "  D=`d' t=`tt' :  H = " %6.3f `H' ///
           "   A = " %6.3f `A' "   M0 = " %6.3f `H'*`A'
    }
}

di _newline "=== H, A et M0 par groupe d'age (periode de base) et statut ==="
forvalues g = 1/3 {
    local titg : label grp `g'
    di "  -- `titg' --"
    forvalues d = 0/1 {
        forvalues tt = 0/1 {
            quietly summarize pauvre_MODA if D == `d' & t == `tt' & groupe_base == `g'
            local H = r(mean)
            quietly summarize intensite_moda ///
                if D == `d' & t == `tt' & groupe_base == `g' & pauvre_MODA == 1
            local A = r(mean)
            di "    D=`d' t=`tt' :  H = " %6.3f `H' ///
               "   A = " %6.3f `A' "   M0 = " %6.3f `H'*`A'
        }
    }
}

/* ── CHEVAUCHEMENT DES PRIVATIONS (le "O" de MODA) ───────────
   L'analyse MODA est une analyse des privations qui se chevauchent :
   compter les enfants prives dimension par dimension ne dit pas si ce
   sont les memes enfants qui cumulent. Trois sorties :
     (i)   la repartition des enfants selon le nombre de privations
           simultanees (0, 1, ..., 7), par edition ;
     (ii)  la matrice de chevauchement deux a deux : part des enfants
           prives a la fois dans la dimension ligne et la dimension
           colonne (diagonale = taux de privation simple) ;
     (iii) parmi les enfants prives dans une dimension donnee, la part
           qui cumule au moins trois autres privations, qui mesure a
           quel point chaque privation est isolee ou enchassee. */

local dims_ov assai eau logem nutri sante protect educ

di _newline "=== Chevauchement des privations : nombre de privations simultanees ==="
forvalues tt = 0/1 {
    di "  -- edition t=`tt' --"
    tab nb_dep if t == `tt'
}

di _newline "=== Matrice de chevauchement deux a deux (%, edition 2018) ==="
foreach d1 of local dims_ov {
    local ligne "  `d1' :"
    foreach d2 of local dims_ov {
        quietly count if t == 0 & !missing(dim_`d1') & !missing(dim_`d2')
        local nn = r(N)
        quietly count if t == 0 & dim_`d1' == 1 & dim_`d2' == 1
        if `nn' > 0 local ligne "`ligne' `d2'=`: display %5.1f 100*r(N)/`nn''"
    }
    di "`ligne'"
}

di _newline "=== Matrice de chevauchement deux a deux (%, edition 2021) ==="
foreach d1 of local dims_ov {
    local ligne "  `d1' :"
    foreach d2 of local dims_ov {
        quietly count if t == 1 & !missing(dim_`d1') & !missing(dim_`d2')
        local nn = r(N)
        quietly count if t == 1 & dim_`d1' == 1 & dim_`d2' == 1
        if `nn' > 0 local ligne "`ligne' `d2'=`: display %5.1f 100*r(N)/`nn''"
    }
    di "`ligne'"
}

di _newline "=== Enchassement : parmi les prives d'une dimension, part cumulant >=4 privations ==="
forvalues tt = 0/1 {
    di "  -- edition t=`tt' --"
    foreach d1 of local dims_ov {
        quietly count if t == `tt' & dim_`d1' == 1
        local np = r(N)
        quietly count if t == `tt' & dim_`d1' == 1 & nb_dep >= 4 & !missing(nb_dep)
        if `np' > 0 di "    `d1' : " %5.1f 100*r(N)/`np' " %  (n=" `np' ")"
    }
}

/* Distribution du nombre de privations, par statut et edition */
di _newline "=== Distribution du nombre de privations (nb_dep) ==="
forvalues tt = 0/1 {
    di "  -- edition t=`tt' --"
    tab nb_dep D if t == `tt', column nofreq
}

/* ============================================================
   4. Double Difference brute (sans appariement, reference)

   Champ : enfants suivis, avant restriction au support commun.
   ============================================================ */

quietly count if t == 0
di _newline "=== Double Difference brute (enfants suivis, sans appariement) ==="
di "  Enfants suivis : " r(N)
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

/* Garde-fou local : si cette section est lancee seule (session neuve,
   globales des sections precedentes absentes) ou depuis une version du
   fichier ou la methode n'a pas ete determinee, la reference retombe
   sur le k-NN au lieu de mourir sur un nom de variable vide. */
if "$POIDS_PRINCIPAL" == "" | "$POIDS_PRINCIPAL" == "weight_" {
    global METHODE         "knn"
    global POIDS_PRINCIPAL "weight_knn"
    di "  !! Methode non determinee en amont : repli sur le k-NN."
}
use "$TEMP/panel_enfants_psm.dta", clear
keep if !missing($POIDS_PRINCIPAL) & $POIDS_PRINCIPAL > 0

di _newline "Panel d'enfants apparie (k-NN) : " _N " observations"
tabstat D, by(t) stat(mean sum n) format(%6.3f)

/* ── RESULTAT PRINCIPAL : ATT PAR GROUPE D'AGE ────────────────
   L'estimation de l'impact suit la logique de tout le dispositif : le
   score est estime par groupe d'age, l'appariement est fait par groupe
   d'age, et l'ATT est donc lui aussi estime SEPAREMENT dans chaque
   groupe. Un ATT global n'aurait pas d'interpretation propre, puisque
   les enfants n'y sont pas mesures sur les memes indicateurs : les
   trois ATT par groupe constituent le resultat principal. L'estimation
   d'ensemble est conservee a titre de synthese ponderee, et parce que
   le test placebo et la lecture par dimension s'y adossent. */

di _newline "=== PSM-DD — ATT PRINCIPAL, PAR GROUPE D'AGE ==="
forvalues g = 1/3 {
    local titg : label grp `g'
    /* Effectifs APRES appariement : enfants sur support commun et de
       poids strictement positif, seuls a entrer dans l'estimation. */
    quietly count if groupe_base == `g' & t == 0 & D == 1
    local n_tr = r(N)
    quietly count if groupe_base == `g' & t == 0 & D == 0
    local n_te = r(N)
    di _newline "--- Groupe `titg' ---"
    di "  Effectifs apres appariement (t=0) : traites `n_tr', temoins `n_te'"
    global NTR_G`g' = `n_tr'
    global NTE_G`g' = `n_te'
    regress pauvre_MODA i.t##i.D [aw=$POIDS_PRINCIPAL] ///
        if groupe_base == `g', vce(cluster grappe)
    lincom 1.t#1.D
    di "  ATT_PSM-DD (`titg') = " %8.4f r(estimate) ///
       "  SE = " %8.4f r(se) "  p = " %6.4f r(p)
    global ATT_G`g' = r(estimate)
}

di _newline "=== Effectifs avant / apres appariement, par groupe et methode ==="
di "  (avant = enfants du design principal ; apres = sur support, poids > 0)"
preserve
    use "$TEMP/pscore_t0.dta", clear
    merge 1:1 enfid using "$TEMP/pscore_knn.dta",    keepusing(weight_knn)     nogenerate
    merge 1:1 enfid using "$TEMP/poids_kernel.dta",  keepusing(weight_kernel)  nogenerate
    merge 1:1 enfid using "$TEMP/poids_caliper.dta", keepusing(weight_caliper) nogenerate
    forvalues g = 1/3 {
        local titg : label grp `g'
        di _newline "  -- `titg' --"
        quietly count if grp_psm == `g' & D == 1
        local a1 = r(N)
        quietly count if grp_psm == `g' & D == 0
        local a0 = r(N)
        di "    avant appariement        : traites " %6.0f `a1' "   temoins " %6.0f `a0'
        foreach m in knn kernel caliper {
            quietly count if grp_psm == `g' & D == 1 & weight_`m' > 0 & !missing(weight_`m')
            local b1 = r(N)
            quietly count if grp_psm == `g' & D == 0 & weight_`m' > 0 & !missing(weight_`m')
            local b0 = r(N)
            di "    apres (" %-7s "`m'" ")        : traites " %6.0f `b1' "   temoins " %6.0f `b0'
        }
    }
restore

/* Aucun resultat d'ensemble n'est presente : le score, l'appariement et
   l'impact sont estimes par groupe d'age, et un agregat qui melange des
   enfants mesures sur des indicateurs differents n'aurait pas
   d'interpretation. Les trois ATT ci-dessus sont LE resultat. */

/* ── ATT net des chocs locaux de periode (COVID-19) ──────────
   L'indicatrice de periode absorbe le choc COVID COMMUN aux deux
   groupes. Ce qu'elle n'absorbe pas, c'est un choc de periode qui varie
   selon le lieu : restrictions, fermetures et tensions de prix n'ont pas
   frappe uniformement les regions ni les milieux urbain et rural. Les
   interactions periode x region et periode x milieu permettent a chaque
   localite d'avoir son propre choc de periode ; l'ATT est alors identifie
   par la comparaison de traites et temoins AU SEIN d'une meme localite,
   soumis au meme choc local. Cette specification retire la part
   geographique de l'exposition differentielle a la pandemie. Elle ne
   peut rien contre une exposition differentielle au sein d'une meme
   localite, discutee dans les limites du rapport. */
di _newline "=== PSM-DD net des chocs locaux de periode (COVID-19), par groupe ==="
forvalues g = 1/3 {
    local titg : label grp `g'
    di _newline "-- `titg' --"
    regress pauvre_MODA i.t##i.D i.t#i.region i.t#i.milieu ///
        [aw=$POIDS_PRINCIPAL] if groupe_base == `g', vce(cluster grappe)
    lincom 1.t#1.D
    di "  ATT_net_chocs (`titg') = " %8.4f r(estimate) ///
       "  SE = " %8.4f r(se) "  p = " %6.4f r(p)
}
di "  (interactions periode x region et periode x milieu incluses)"

/* ── Sensibilite au seuil inter-dimensionnel k ──────────────────
   Le seuil k=4 est une convention. On reestime l'ATT en definissant la
   pauvrete successivement a chaque seuil de 1 a 7 dimensions sur 7, pour
   verifier que la conclusion ne depend pas du seuil retenu. */
di _newline "=== Sensibilite de l'ATT au seuil de privation k ==="
di "  k        ATT      SE       p"
forvalues k = 1/7 {
    quietly gen byte pauvre_k`k' = (nb_dep >= `k') if !missing(nb_dep)
    quietly regress pauvre_k`k' i.t##i.D [aw=$POIDS_PRINCIPAL], vce(cluster grappe)
    quietly lincom 1.t#1.D
    di "  " %1.0f `k' %11.4f r(estimate) %9.4f r(se) %8.4f r(p)
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
regress pauvre_MODA D [aw=$POIDS_PRINCIPAL] if t == 0, vce(cluster grappe)
di "  ATT PSM (t=0) = " %8.4f _b[D] "  SE = " %8.4f _se[D] ///
   "  p = " %6.4f (2*ttail(e(df_r), abs(_b[D]/_se[D])))
di _newline "--- PSM seul, t=1 (EHCVM II, sans DD) ---"
regress pauvre_MODA D [aw=$POIDS_PRINCIPAL] if t == 1, vce(cluster grappe)
di "  ATT PSM (t=1) = " %8.4f _b[D] "  SE = " %8.4f _se[D] ///
   "  p = " %6.4f (2*ttail(e(df_r), abs(_b[D]/_se[D])))
di _newline "  Rappel : ATT_PSM-DD = ATT_PSM(t=1) - ATT_PSM(t=0), par construction."

/* ── Fig DD : trajectoires beneficiaires vs temoins + contrefactuel ──
   Moyennes ponderees par les poids k-NN. Le contrefactuel applique la
   tendance des temoins au niveau initial des beneficiaires. */
quietly summarize pauvre_MODA if D==1 & t==0 [aw=$POIDS_PRINCIPAL]
scalar dd_b0 = r(mean)*100
quietly summarize pauvre_MODA if D==1 & t==1 [aw=$POIDS_PRINCIPAL]
scalar dd_b1 = r(mean)*100
quietly summarize pauvre_MODA if D==0 & t==0 [aw=$POIDS_PRINCIPAL]
scalar dd_c0 = r(mean)*100
quietly summarize pauvre_MODA if D==0 & t==1 [aw=$POIDS_PRINCIPAL]
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
    xtitle("Vague EHCVM") ytitle("Incidence MODA (H, %)") ///
    ylabel(0(20)100, grid) ///
    legend(order(2 "Bénéficiaires" 1 "Témoins appariés" ///
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
            regress `outcome' i.t##i.D [aw=$POIDS_PRINCIPAL] if milieu == `mil', ///
                vce(cluster grappe)
            lincom 1.t#1.D
            di "  ATT = " %8.4f r(estimate) "  p = " %6.4f r(p)
        }
    }
}

di _newline "Test d'egalite (urbain vs rural) :"
gen byte urban = (milieu == 1)
foreach outcome in pauvre_MODA {
    regress `outcome' i.t##i.D##i.urban [aw=$POIDS_PRINCIPAL], vce(cluster grappe)
    lincom 1.t#1.D#1.urban
    di "  Diff ATT (urbain - rural) : " %8.4f r(estimate) "  p = " %6.4f r(p)
}
drop urban

/* -- Par genre du chef de menage (hgender : 1 homme, 2 femme) -- */
di _newline "=== Heterogeneite par genre du chef de menage ==="
capture confirm variable hgender
if _rc == 0 {
    foreach outcome in pauvre_MODA {
        foreach h in 1 2 {
            if `h' == 1 local lab_h "Chef homme"
            else        local lab_h "Chef femme"
            quietly count if hgender == `h'
            if r(N) > 30 {
                di "--- `lab_h' — `outcome' ---"
                regress `outcome' i.t##i.D [aw=$POIDS_PRINCIPAL] if hgender == `h', ///
                    vce(cluster grappe)
                lincom 1.t#1.D
                di "  ATT = " %8.4f r(estimate) "  p = " %6.4f r(p)
            }
        }
    }

    di _newline "Test d'egalite (chef femme vs chef homme) :"
    gen byte chef_fem = (hgender == 2) if !missing(hgender)
    foreach outcome in pauvre_MODA {
        regress `outcome' i.t##i.D##i.chef_fem [aw=$POIDS_PRINCIPAL], vce(cluster grappe)
        lincom 1.t#1.D#1.chef_fem
        di "  Diff ATT (chef femme - chef homme) : " %8.4f r(estimate) ///
           "  p = " %6.4f r(p)
    }
    drop chef_fem
}

di _newline "=== Heterogeneite par groupe d'age (groupe fige en 2018) ==="
foreach g in 1 2 3 {
    foreach outcome in pauvre_MODA {
        quietly count if groupe_base == `g'
        if r(N) > 30 {
            di "--- Groupe `g' — `outcome' ---"
            quietly count if groupe_base == `g' & groupe_moda != groupe_base
            local n_chg = r(N)
            quietly count if groupe_base == `g'
            di "  Observations changeant de groupe d'age entre les vagues : " ///
               %5.1f 100*`n_chg'/r(N) "%"
            regress `outcome' i.t##i.D [aw=$POIDS_PRINCIPAL] if groupe_base == `g', ///
                vce(cluster grappe)
            lincom 1.t#1.D
            di "  ATT = " %8.4f r(estimate) "  p = " %6.4f r(p)
        }
    }
}

/* Trois groupes : un test joint d'abord (les trois ATT sont-ils egaux ?),
   puis les ecarts a la reference 0-4 ans, groupe sur lequel se concentre
   l'effet. */
di _newline "Test d'egalite des ATT entre groupes d'age :"
foreach outcome in pauvre_MODA {
    regress `outcome' i.t##i.D##ib1.groupe_base [aw=$POIDS_PRINCIPAL], ///
        vce(cluster grappe)
    testparm i.t#i.D#i.groupe_base
    di "  Test joint d'egalite des trois ATT : F = " %6.2f r(F) ///
       "  p = " %6.4f r(p)
    foreach g in 2 3 {
        if `g' == 2 local lab_g "5-14 ans"
        else        local lab_g "15-17 ans"
        capture lincom 1.t#1.D#`g'.groupe_base
        if _rc == 0 {
            di "  Diff ATT (`lab_g' - 0-4 ans) : " %8.4f r(estimate) ///
               "  p = " %6.4f r(p)
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
        quietly summarize montant_transf if q_montant == `q', detail
        di "    Q`q' : " %10.0f r(min) " a " %10.0f r(max) ///
           "  (mediane " %10.0f r(p50) ", n=" %4.0f r(N) " menages)"
    }
restore

merge m:1 grappe menage using `quintiles', ///
    keepusing(q_montant) keep(master match) nogenerate

foreach outcome in pauvre_MODA {
    forvalues q = 1/5 {
        quietly count if q_montant == `q' & !missing($POIDS_PRINCIPAL)
        if r(N) > 30 {
            di _newline "--- Quintile `q' — `outcome' ---"
            regress `outcome' i.t##i.D [aw=$POIDS_PRINCIPAL] ///
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
regress pauvre_MODA i.t##c.log_montant [aw=$POIDS_PRINCIPAL] if D == 1, ///
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

/* ── Variable de resultat continue : nombre de privations ──────
   Le statut binaire perd l'information sur l'intensite. On reestime l'ATT
   sur nb_dep (0 a 7) avec la DD simple et les trois appariements. */
di _newline "=== ATT sur le nombre de privations (0-7) ==="
preserve
    use "$TEMP/panel_enfants_psm.dta", clear
    quietly regress nb_dep i.t##i.D, vce(cluster grappe)
    quietly lincom 1.t#1.D
    di "  DD simple      : ATT=" %8.4f r(estimate) ///
       "  SE=" %7.4f r(se) "  p=" %6.4f r(p)
restore
foreach poids_var in weight_knn weight_kernel weight_caliper {
    quietly count if !missing(`poids_var') & `poids_var' > 0
    if r(N) > 0 {
        quietly regress nb_dep i.t##i.D [aw=`poids_var'] ///
            if `poids_var' > 0, vce(cluster grappe)
        quietly lincom 1.t#1.D
        di "  `poids_var' : ATT=" %8.4f r(estimate) ///
           "  SE=" %7.4f r(se) "  p=" %6.4f r(p)
    }
}

/* ── Validation croisee : diff (Villa 2016), score logit ───────
   Implementation independante du kernel PSM-DD. A comparer a la ligne
   weight_kernel. Installation : ssc install diff */
capture which diff
if _rc == 0 {
    di _newline "=== Validation croisee : diff (kernel, score logit) ==="
    diff pauvre_MODA, t(D) p(t) kernel id(enfid) logit ///
        cov(milieu hgender hage_cl heduc hmstat sexe) ///
        support cluster(grappe)
    di _newline "  Rappel estimateur maison (kernel) : voir ligne weight_kernel ci-dessus."
}
else {
    di _newline "(!) commande diff absente : ssc install diff pour la validation croisee."
}

/* ============================================================
   8. Robustesse : definition alternative du traitement
      (traitement defini a la periode de base, transitoires inclus)

   Le design principal compare les beneficiaires stables aux menages
   jamais beneficiaires. En robustesse, l'ATT est reestime avec la
   definition canonique de la DD : traitement fixe a la periode de base
   (transfert recu en 2018), quel que soit le statut de 2021. Ce design
   reintegre les beneficiaires transitoires ; il dilue l'exposition,
   puisque pres de la moitie des traites ne recoivent plus en 2021,
   mais il offre une periode de base au statut bien defini et une
   population complete. La convergence des deux designs est le
   veritable test : un effet present dans les deux ne depend ni de la
   dilution de l'un ni de l'absence de periode pre-traitement de
   l'autre.
   ============================================================ */

use "$TEMP/panel_large_tous.dta", clear
gen byte D_base_alt = D
label var D_base_alt "1=beneficiaire en 2018 (transitoires inclus)"

quietly count if D_base_alt == 1
local n_ben = r(N)
quietly count if D_base_alt == 0
local n_non = r(N)
di _newline "=== Robustesse : definition a la periode de base (2018) ==="
di "  Enfants de beneficiaires 2018 : `n_ben'"
di "  Enfants non beneficiaires 2018 : `n_non'"

/* Logit et appariement k-NN sur l'echantillon complet, en format large */
quietly logit D_base_alt $COV_SCORE, vce(cluster grappe)
di "  Pseudo-R2 logit (definition 2018) : " %6.3f 1 - e(ll)/e(ll_0)
quietly predict pscore_alt if e(sample), pr
quietly psmatch2 D_base_alt, pscore(pscore_alt) neighbor($K_VOISINS) common
rename _weight w_alt

di _newline "  Balance apres appariement (definition 2018) :"
capture noisily pstest i.milieu i.region hgender i.hage_cl i.heduc i.hmstat ///
    i.sexe18 hhsize log_pcexp i.hcsp, both

/* Panel long minimal pour la DD */
keep enfid grappe menage D_base_alt w_alt pauvre_MODA18 pauvre_MODA21
reshape long pauvre_MODA, i(enfid) j(periode)
gen byte t = (periode == 21)
drop periode

di _newline "--- DD brute, definition 2018 (transitoires inclus) ---"
regress pauvre_MODA i.t##i.D_base_alt, vce(cluster grappe)
lincom 1.t#1.D_base_alt
di "  ATT_DD_2018 = " %8.4f r(estimate) ///
   "  SE = " %8.4f r(se) "  p = " %6.4f r(p)

di _newline "--- PSM-DD, definition 2018 (transitoires inclus) ---"
quietly count if t == 0 & w_alt > 0 & !missing(w_alt)
di "  Enfants sur support commun : " r(N)
regress pauvre_MODA i.t##i.D_base_alt [aw=w_alt] ///
    if w_alt > 0 & !missing(w_alt), vce(cluster grappe)
lincom 1.t#1.D_base_alt
di "  ATT_PSMDD_2018 = " %8.4f r(estimate) ///
   "  SE = " %8.4f r(se) "  p = " %6.4f r(p)
di "  A comparer a l'ATT du design principal (stables vs jamais)."

di _newline ">>> 05_psm_dd.do termine."

/* ============================================================
   SECTION : 06_STATS_DESC — Statistiques descriptives
   Chapitre 3 : profil ménages, pauvreté, privations, comparaison D=0/1

   Les statistiques portant sur les ENFANTS sont calculees sur les enfants
   suivis individuellement d'une vague a l'autre (panel_enfants_psm.dta),
   c'est-a-dire sur l'echantillon meme de l'estimation d'impact avant la
   restriction au support commun. Un tableau descriptif et un coefficient
   estime decrivent ainsi les memes enfants. Le profil des MENAGES (bloc 1)
   reste sur le panel vrai, son unite etant le menage et non l'enfant.

   Les statistiques de pauvrete/privation (incidence MODA, par dimension,
   par age, par milieu, par region) sont PONDEREES par les poids de sondage
   (hhweight). Le profil des menages et la balance traites/non-traites
   restent sur effectifs bruts.
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
    local tt = cond(`annee' == 2018, 0, 1)
    use "$TEMP/panel_vrai.dta", clear
    keep if t == `tt'
    bysort grappe menage: keep if _n == 1   /* un ménage = une ligne */

    drop D
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
use "$TEMP/panel_enfants_psm.dta", clear
keep if t == 0

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
   3. Incidence MODA par vague, milieu, groupe d'âge
   ============================================================ */

di _newline "=== 3. Incidence pauvreté multidimensionnelle ==="

foreach annee in 2018 2021 {
    local tt = cond(`annee' == 2018, 0, 1)
    use "$TEMP/panel_enfants_psm.dta", clear
    keep if t == `tt'

    di _newline "-- MODA `annee' (pondéré hhweight) --"
    tabstat pauvre_MODA nb_dep [aw=hhweight], ///
        by(milieu) stat(mean n) format(%6.3f)
    tabstat pauvre_MODA nb_dep [aw=hhweight], ///
        by(groupe_base) stat(mean n) format(%6.3f)
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
    local tt = cond(`annee' == 2018, 0, 1)
    use "$TEMP/panel_enfants_psm.dta", clear
    keep if t == `tt'
    foreach g in 1 2 3 {
        local ++r
        quietly summarize pauvre_MODA [aw=hhweight] if groupe_base == `g'
        local hmoda = r(mean)*100
        /* n_calc = enfants avec un statut MODA calcule ; n_tot = effectif
           total de la tranche (colonne "Obs." du tableau du rapport) */
        local nobs  = r(N)
        quietly count if groupe_base == `g'
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
    local tt = cond(`annee' == 2018, 0, 1)
    use "$TEMP/panel_enfants_psm.dta", clear
    keep if t == `tt'
    di _newline "-- Dimensions `annee' --"
    foreach dim in assai eau logem nutri sante protect educ {
        quietly summarize dim_`dim' [aw=hhweight]
        di "  `dim' : " %5.1f r(mean)*100 "%"
    }
    di _newline "  -- Dimensions `annee' par tranche d'age --"
    foreach dim in assai eau logem nutri sante protect educ {
        quietly tabstat dim_`dim' [aw=hhweight], by(groupe_base) ///
            stat(mean n) format(%7.4f) save
        forvalues g = 1/3 {
            matrix M = r(Stat`g')
            local lbl = cond(`g'==1,"0-4 ans",cond(`g'==2,"5-14 ans","15-17 ans"))
            di "  `dim' / `lbl' : " %5.1f M[1,1]*100 "%   n=" %7.0f M[2,1]
        }
    }
    quietly summarize intensite_moda [aw=hhweight] if pauvre_MODA == 1
    local A = r(mean)
    quietly summarize pauvre_MODA [aw=hhweight]
    di "  Indice ajuste `annee' : H=" %5.1f 100*r(mean) "%  A=" %5.1f 100*`A' ///
       "%  M0=" %5.3f r(mean)*`A'
}


/* ============================================================
   5. Graphiques
   ============================================================ */

di _newline "=== 5. Graphiques ==="

/* ── Fig 1 : Évolution de l'incidence MODA, beneficiaires vs
   non-beneficiaires. Les deux trajectoires rendent visible la logique de
   double difference : c'est l'ECART entre les groupes, et son evolution
   entre les deux vagues, qui porte l'information sur l'impact. ── */
use "$TEMP/panel_enfants_psm.dta", clear
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
        lwidth(medthick) mlabel(lbl_nb) mlabcolor(black) mlabpos(12) ///
        mlabgap(2) mlabsize(small)) ///
       (connected H_benef annee, lcolor(orange) mcolor(orange) msymbol(circle) ///
        lwidth(medthick) mlabel(lbl_b) mlabcolor(black) mlabpos(12) ///
        mlabgap(2) mlabsize(small)), ///
    xlabel(2018 2021) xscale(range(2017.7 2021.3)) xtitle("Vague EHCVM") ///
    ytitle("Incidence MODA H (%)") ///
    ylabel(40(5)70, grid) yscale(range(38 72)) ///
    legend(order(1 "Non-bénéficiaires" 2 "Bénéficiaires") pos(6) rows(1)) ///
    graphregion(color(white)) plotregion(color(white))
set dp period
graph display, scale(1.35)   /* texte agrandi pour la projection */
graph export "$OUTPUT/figures/fig_evolution_ipm.pdf", replace
di ">>> fig_evolution_ipm.pdf sauvegardé"

/* ── Fig 2 : Distribution du nombre de dimensions en privation ──
   Abscisse : nombre exact de dimensions en privation (0 a 7).
   Ordonnee  : part des enfants (%), a l'image du rapport ANSD/UNICEF
   MODA. Ligne verticale placee apres la barre des 4 dimensions. */
tempname distrib
matrix `distrib' = J(8, 3, .)
foreach annee in 2018 2021 {
    local tt = cond(`annee' == 2018, 0, 1)
    use "$TEMP/panel_enfants_psm.dta", clear
    keep if t == `tt'
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
    , xline(4.5, lcolor(red) lpattern(dash) lwidth(medthick)) ///
    xlabel(0(1)7) xtitle("Nombre de dimensions en privation (sur 7)") ///
    ylabel(0(5)30, grid) ytitle("Part des enfants (%)") ///
    legend(order(1 "EHCVM I (2018-19)" 2 "EHCVM II (2021-22)") pos(6) rows(1)) ///
    graphregion(color(white)) plotregion(color(white))
set dp period
graph display, scale(1.35)   /* texte agrandi pour la projection */
graph export "$OUTPUT/figures/fig_distrib_dimensions.pdf", replace
di ">>> fig_distrib_dimensions.pdf sauvegardé"

/* ============================================================
   COMPARAISON BENEFICIAIRES / NON-BENEFICIAIRES x 2018-2021

   Coeur descriptif de la section : pour chaque dimension MODA et pour
   l'incidence globale, taux de privation des enfants selon le statut de
   traitement du menage (D=1 beneficiaire migrant en 2018 ; D=0 non
   beneficiaire) a chaque vague, ecart entre groupes a chaque date, et
   evolution de cet ecart (double difference descriptive, non ponderee
   par l'appariement). Echantillon : enfants suivis, ponderation hhweight.
   ============================================================ */

use "$TEMP/panel_enfants_psm.dta", clear

di _newline(2) "=== Privations : beneficiaires vs non-beneficiaires, 2018 et 2021 ==="
di "    (enfants suivis, pondere hhweight ; D=1 beneficiaire migrant 2018)"
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

/* Meme comparaison declinee par groupe d'age : chaque sous-section du
   rapport confronte les dimensions et le statut de beneficiaire au sein
   d'une tranche d'age. Le groupe est celui de la PERIODE DE BASE : sur un
   panel d'enfants suivis, un decoupage sur l'age courant ferait changer les
   sous-groupes de composition entre les deux vagues et la comparaison ne
   porterait plus sur les memes enfants. « 0-4 ans » se lit donc « age de 0 a
   4 ans en 2018 », et ces enfants ont 3 a 7 ans en 2021 : dim_educ, nulle
   par construction en 2018, devient applicable a une partie d'entre eux. */
forvalues g = 1/3 {
    if `g' == 1 local lbl "0-4 ans"
    if `g' == 2 local lbl "5-14 ans"
    if `g' == 3 local lbl "15-17 ans"
    di _newline(2) "=== Privations par dimension et statut — `lbl' ==="
    di "  Indicateur          D=0 2018  D=1 2018   Ecart |  D=0 2021  D=1 2021   Ecart |     DD    p18    p21"
    foreach v in dim_assai dim_eau dim_logem dim_nutri dim_sante dim_protect ///
                 dim_educ pauvre_MODA {
        quietly summarize `v' [aw=hhweight] if t == 0 & D == 0 & groupe_base == `g'
        local a0 = r(mean)*100
        quietly summarize `v' [aw=hhweight] if t == 0 & D == 1 & groupe_base == `g'
        local a1 = r(mean)*100
        quietly summarize `v' [aw=hhweight] if t == 1 & D == 0 & groupe_base == `g'
        local b0 = r(mean)*100
        quietly summarize `v' [aw=hhweight] if t == 1 & D == 1 & groupe_base == `g'
        local b1 = r(mean)*100
        local g0 = `a1' - `a0'
        local g1 = `b1' - `b0'
        local dd = `g1' - `g0'
        quietly regress `v' D if t == 0 & groupe_base == `g', vce(cluster grappe)
        local p0 = 2*ttail(e(df_r), abs(_b[D]/_se[D]))
        quietly regress `v' D if t == 1 & groupe_base == `g', vce(cluster grappe)
        local p1 = 2*ttail(e(df_r), abs(_b[D]/_se[D]))
        di "  " %-18s "`v'" %9.1f `a0' %10.1f `a1' %8.1f `g0' " |" ///
           %9.1f `b0' %10.1f `b1' %8.1f `g1' " |" %7.1f `dd' ///
           %7.3f `p0' %7.3f `p1'
    }
    quietly count if groupe_base == `g' & t == 0
    local n18 = r(N)
    quietly count if groupe_base == `g' & t == 1
    di "  Effectifs : `n18' enfants en 2018, " r(N) " en 2021"
}

/* Croisement genre du chef de menage x statut de beneficiaire x vague, pour
   l'ensemble des enfants puis pour chaque tranche d'age. Alimente le
   tableau par genre de chaque sous-section descriptive. */
forvalues g = 0/3 {
    if `g' == 0 local lbl "Ensemble 0-17 ans"
    if `g' == 1 local lbl "0-4 ans"
    if `g' == 2 local lbl "5-14 ans"
    if `g' == 3 local lbl "15-17 ans"
    di _newline(2) "=== Incidence MODA par genre du chef et statut — `lbl' ==="
    di "  Chef        D=0 2018  D=1 2018   Ecart |  D=0 2021  D=1 2021   Ecart |     DD    p18    p21      n18      n21"
    forvalues sx = 1/2 {
        local slbl = cond(`sx' == 1, "Chef homme", "Chef femme")
        if `g' == 0 local cond "hgender == `sx'"
        else        local cond "hgender == `sx' & groupe_base == `g'"
        quietly summarize pauvre_MODA [aw=hhweight] if t == 0 & D == 0 & `cond'
        local a0 = r(mean)*100
        quietly summarize pauvre_MODA [aw=hhweight] if t == 0 & D == 1 & `cond'
        local a1 = r(mean)*100
        quietly summarize pauvre_MODA [aw=hhweight] if t == 1 & D == 0 & `cond'
        local b0 = r(mean)*100
        quietly summarize pauvre_MODA [aw=hhweight] if t == 1 & D == 1 & `cond'
        local b1 = r(mean)*100
        local e0 = `a1' - `a0'
        local e1 = `b1' - `b0'
        quietly regress pauvre_MODA D if t == 0 & `cond', vce(cluster grappe)
        local p0 = 2*ttail(e(df_r), abs(_b[D]/_se[D]))
        quietly regress pauvre_MODA D if t == 1 & `cond', vce(cluster grappe)
        local p1 = 2*ttail(e(df_r), abs(_b[D]/_se[D]))
        quietly count if t == 0 & `cond'
        local n0 = r(N)
        quietly count if t == 1 & `cond'
        di "  " %-10s "`slbl'" %9.1f `a0' %10.1f `a1' %8.1f `e0' " |" ///
           %9.1f `b0' %10.1f `b1' %8.1f `e1' " |" %7.1f `e1'-`e0' ///
           %7.3f `p0' %7.3f `p1' %9.0f `n0' %9.0f r(N)
    }
}

/* Incidence MODA par quintile de montant recu, pour l'ensemble des enfants
   puis pour chaque tranche d'age. Les quintiles sont construits sur le
   montant annuel des menages beneficiaires, au niveau menage pour que le
   decoupage ne soit pas deforme par le nombre d'enfants. Les enfants de
   menages non beneficiaires forment la ligne de reference. */
capture drop montant_transf
capture drop q5_montant
merge m:1 grappe menage using "$TEMP/montant_2018.dta", ///
    keepusing(montant_transf) keep(master match) nogenerate

preserve
    keep if D == 1 & t == 0 & !missing(montant_transf)
    bysort grappe menage: keep if _n == 1
    xtile q5_montant = montant_transf, nquantiles(5)
    keep grappe menage q5_montant
    tempfile quint_desc
    save `quint_desc'
restore
merge m:1 grappe menage using `quint_desc', ///
    keepusing(q5_montant) keep(master match) nogenerate

forvalues g = 0/3 {
    if `g' == 0 local lbl "Ensemble 0-17 ans"
    if `g' == 1 local lbl "0-4 ans"
    if `g' == 2 local lbl "5-14 ans"
    if `g' == 3 local lbl "15-17 ans"
    if `g' == 0 local cond "1"
    else        local cond "groupe_base == `g'"
    di _newline(2) "=== Incidence MODA par quintile de montant — `lbl' ==="
    di "  Groupe          H 2018   H 2021      DD       n18      n21"
    quietly summarize pauvre_MODA [aw=hhweight] if t == 0 & D == 0 & `cond'
    local r0 = r(mean)*100
    quietly summarize pauvre_MODA [aw=hhweight] if t == 1 & D == 0 & `cond'
    local r1 = r(mean)*100
    quietly count if t == 0 & D == 0 & `cond'
    local m0 = r(N)
    quietly count if t == 1 & D == 0 & `cond'
    di "  " %-14s "Non-benef." %8.1f `r0' %9.1f `r1' %8.1f `r1'-`r0' ///
       %10.0f `m0' %9.0f r(N)
    forvalues q = 1/5 {
        quietly count if q5_montant == `q' & t == 0 & `cond'
        local n0 = r(N)
        if `n0' > 0 {
            quietly summarize pauvre_MODA [aw=hhweight] if t == 0 & q5_montant == `q' & `cond'
            local a0 = r(mean)*100
            quietly summarize pauvre_MODA [aw=hhweight] if t == 1 & q5_montant == `q' & `cond'
            local a1 = r(mean)*100
            quietly count if t == 1 & q5_montant == `q' & `cond'
            di "  " %-14s "Quintile `q'" %8.1f `a0' %9.1f `a1' ///
               %8.1f (`a1'-`a0')-(`r1'-`r0') %10.0f `n0' %9.0f r(N)
        }
    }
}

di _newline ">>> 06_stats_desc.do terminé."
di ">>> Sorties dans : $OUTPUT/tables/ et $OUTPUT/figures/"

/* ============================================================
   SECTION : 07_EFFETS_DIM — ATT PSM-DD par dimension MODA
   Génère output/figures/fig_effets_dim.pdf
   ============================================================ */


/* Joindre poids k-NN au panel vrai */
use "$TEMP/panel_enfants_psm.dta", clear

/* ── ATT par dimension, trois methodes d'appariement ───────────
   Verifie que la lecture dimensionnelle ne depend pas de l'algorithme. */
local dims assai eau logem nutri sante protect educ
di _newline "=== ATT par dimension, comparaison des trois appariements ==="
foreach poids_var in weight_knn weight_kernel weight_caliper {
    di _newline "--- `poids_var' ---"
    foreach dim of local dims {
        quietly count if !missing(`poids_var') & `poids_var' > 0
        if r(N) > 0 {
            quietly regress dim_`dim' i.t##i.D [aw=`poids_var'] ///
                if `poids_var' > 0, vce(cluster grappe)
            quietly lincom 1.t#1.D
            di "  dim_`dim' : ATT=" %8.4f r(estimate) ///
               "  SE=" %7.4f r(se) "  p=" %6.4f r(p)
        }
    }
}

if "$POIDS_PRINCIPAL" == "" | "$POIDS_PRINCIPAL" == "weight_" {
    global METHODE         "knn"
    global POIDS_PRINCIPAL "weight_knn"
    di "  !! Methode non determinee en amont : repli sur le k-NN."
}
keep if !missing($POIDS_PRINCIPAL) & $POIDS_PRINCIPAL > 0

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
    quietly regress dim_`dim' i.t##i.D [aw=$POIDS_PRINCIPAL], vce(cluster grappe)
    quietly lincom 1.t#1.D
    matrix ATT[`i',1] = r(estimate)
    matrix LB[`i',1]  = r(estimate) - 1.96*r(se)
    matrix UB[`i',1]  = r(estimate) + 1.96*r(se)
    di "  dim_`dim' : ATT=" %8.4f r(estimate) "  SE=" %7.4f r(se) "  p=" %6.4f r(p)
}

/* ── ATT par INDICATEUR ──────────────────────────────────────
   La dimension agrege ses indicateurs par la regle de l'union : elle
   passe a 1 des qu'un seul indicateur est positif. Un effet nul sur la
   dimension peut donc masquer deux mouvements de sens contraire, et un
   effet significatif ne dit pas lequel des indicateurs le porte.
   L'estimation est reprise indicateur par indicateur, sur le meme panel
   apparie et avec la meme specification. Chaque indicateur n'est defini
   que sur les groupes d'age auxquels il s'applique : la regression porte
   sur les enfants pour lesquels il n'est pas manquant, et l'effectif
   affiche permet de le verifier. */

di _newline "=== ATT PSM-DD par indicateur ($METHODE) ==="
di "  indicateur          n        ATT       SE        p"

foreach ind in m_toilet m_partag_toi m_eau_source m_eau_temps ///
               m_ordures m_surpeup m_securite m_combust m_sante_acces ///
               m_acte_nais m_trav_enf m_scol m_alfab {
    quietly count if !missing(`ind')
    local n_ind = r(N)
    if `n_ind' > 0 {
        quietly regress `ind' i.t##i.D [aw=$POIDS_PRINCIPAL], vce(cluster grappe)
        quietly lincom 1.t#1.D
        di "  " %-16s "`ind'" %8.0f `n_ind' %10.4f r(estimate) ///
           %9.4f r(se) %9.4f r(p)
    }
    else {
        di "  " %-16s "`ind'" "   non renseigne sur le panel"
    }
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
    xlabel(, format(%4.1f)) ///
    xline(0, lcolor(black) lpattern(dash)) ///
    legend(off) ///
    graphregion(color(white)) plotregion(color(white))

set dp period
graph display, scale(1.35)   /* texte agrandi pour la projection */
graph export "$OUTPUT/figures/fig_effets_dim.pdf", replace
di ">>> fig_effets_dim.pdf sauvegardé dans $OUTPUT/figures/"
di ">>> 07_effets_dim.do terminé."

/* ============================================================
   SECTION : 09_PLACEBO — Tests de validite (annexe A)

   1. Test placebo : 200 assignations aleatoires d'un faux
      traitement parmi les menages jamais traites ; la
      distribution des ATT placebo doit etre centree sur zero
      si l'hypothese de tendances paralleles est plausible.
      retrouves vs perdus en 2021 sur les covariables de base.

   Aucune ponderation par poids d'enquete.
   ============================================================ */


/* ============================================================
   1. Test placebo (200 replications)
   ============================================================ */

di _newline "=== Test placebo (200 replications) ==="

local n_rep 200
matrix PLA = J(`n_rep', 3, .)   /* une colonne par groupe d'age */

/* Echantillon : enfants suivis des menages jamais traites */
use "$TEMP/panel_enfants_psm.dta", clear
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
/* part de faux traites = part observee de traites */
preserve
    use "$TEMP/panel_enfants_psm.dta", clear
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

        /* DD placebo (moyennes des 4 cellules), par groupe d'age,
           comme l'estimation principale */
        forvalues g = 1/3 {
            summarize pauvre_MODA if t==1 & fakeD==1 & groupe_base==`g'
            local m11 = r(mean)
            summarize pauvre_MODA if t==0 & fakeD==1 & groupe_base==`g'
            local m01 = r(mean)
            summarize pauvre_MODA if t==1 & fakeD==0 & groupe_base==`g'
            local m10 = r(mean)
            summarize pauvre_MODA if t==0 & fakeD==0 & groupe_base==`g'
            local m00 = r(mean)
            matrix PLA[`r',`g'] = (`m11'-`m01') - (`m10'-`m00')
        }
    }
    if mod(`r', 50) == 0 di "  replication `r'/`n_rep'"
}

/* Statistiques de la distribution placebo, groupe par groupe : la
   distribution doit etre centree sur zero, et l'ATT du groupe doit se
   situer dans sa queue. */
clear
svmat PLA, names(col)
forvalues g = 1/3 {
    rename c`g' att_g`g'
    quietly summarize att_g`g'
    di _newline "Placebo groupe `g' : moyenne=" %7.4f r(mean) "  sd=" %6.4f r(sd)
    quietly count if !missing(att_g`g')
    local ntot = r(N)
    quietly count if att_g`g' < ${ATT_G`g'}
    di "  ATT du groupe (" %6.4f ${ATT_G`g'} ") : rang = " ///
       %4.1f 100*r(N)/`ntot' "e centile"
}

/* ── Fig placebo : distribution des ATT placebo vs ATT reel ──
   Verifie la plausibilite des tendances paralleles : la distribution
   placebo doit etre centree sur zero et l'ATT reel doit se situer dans
   sa queue. */
set dp comma
forvalues g = 1/3 {
    local titg : label grp `g'
    quietly histogram att_g`g', width(0.005) frequency ///
        color(gs9) lcolor(white) ///
        xline(0, lcolor(black) lpattern(solid)) ///
        xline(`=${ATT_G`g'}', lcolor(orange) lpattern(dash) lwidth(medthick)) ///
        xtitle("ATT placebo") ytitle("Réplications") ///
        title("`titg'", size(medium)) ///
        graphregion(color(white)) plotregion(color(white)) ///
        name(pla`g', replace)
}
graph combine pla1 pla2 pla3, rows(1) graphregion(color(white))
set dp period
graph export "$OUTPUT/figures/fig_placebo_dd.pdf", replace
graph drop pla1 pla2 pla3
di ">>> fig_placebo_dd.pdf sauvegardé (trois panneaux, un par groupe)"

di _newline ">>> 09_placebo.do termine."

/* ── Fig : taux de privation par dimension, ensemble et par groupe ──
   Barres horizontales, une paire par dimension (EHCVM I vs II),
   ponderees par hhweight. Remplace les tableaux du chapitre 3. */
use "$TEMP/panel_enfants_psm.dta", clear
foreach g in ens 1 2 3 {
    preserve
    if "`g'" != "ens" keep if groupe_base == `g'
    collapse (mean) dim_assai dim_eau dim_logem dim_nutri dim_sante ///
             dim_protect dim_educ [aw=hhweight], by(t)
    reshape long dim_, i(t) j(dm) string
    replace dim_ = 100*dim_
    reshape wide dim_, i(dm) j(t)
    gen byte ordre = .
    replace ordre = 1 if dm == "assai"
    replace ordre = 2 if dm == "eau"
    replace ordre = 3 if dm == "logem"
    replace ordre = 4 if dm == "nutri"
    replace ordre = 5 if dm == "sante"
    replace ordre = 6 if dm == "protect"
    replace ordre = 7 if dm == "educ"
    gen str22 lbl = ""
    replace lbl = "Assainissement" if dm == "assai"
    replace lbl = "Eau"            if dm == "eau"
    replace lbl = "Logement"       if dm == "logem"
    replace lbl = "Nutrition"      if dm == "nutri"
    replace lbl = "Santé"          if dm == "sante"
    replace lbl = "Protection"     if dm == "protect"
    replace lbl = "Éducation"      if dm == "educ"
    /* education non applicable aux 0-4 ans */
    if "`g'" == "1" drop if dm == "educ"
    sort ordre
    gen pos  = _n
    gen pos0 = pos - 0.19
    gen pos1 = pos + 0.19
    /* Etiquettes en toutes lettres, virgule decimale garantie */
    gen str8 l0 = subinstr(string(dim_0, "%3.1f"), ".", ",", 1)
    gen str8 l1 = subinstr(string(dim_1, "%3.1f"), ".", ",", 1)
    local ylab ""
    forvalues i = 1/`=_N' {
        local ylab `ylab' `i' "`=lbl[`i']'"
    }
    twoway (bar dim_0 pos0, horizontal barwidth(0.36) color(gs9)) ///
           (bar dim_1 pos1, horizontal barwidth(0.36) color(orange)) ///
           (scatter pos0 dim_0, msymbol(none) mlabel(l0) ///
                mlabcolor(black) mlabsize(vsmall) mlabpos(3)) ///
           (scatter pos1 dim_1, msymbol(none) mlabel(l1) ///
                mlabcolor(black) mlabsize(vsmall) mlabpos(3)), ///
        ylabel(`ylab', angle(0) nogrid) yscale(reverse) ytitle("") ///
        xlabel(0(20)100, grid) xtitle("Taux de privation (%)") ///
        legend(order(1 "EHCVM I (2018-19)" 2 "EHCVM II (2021-22)") ///
               pos(6) rows(1) region(color(white))) ///
        graphregion(color(white)) plotregion(color(white))
    local suf = cond("`g'"=="ens","ensemble", ///
        cond("`g'"=="1","0_4", cond("`g'"=="2","5_14","15_17")))
    graph export "$OUTPUT/figures/fig_dim_`suf'.pdf", replace
    di ">>> fig_dim_`suf'.pdf sauvegardé"
    restore
}

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

/* Ferme le log, puis recopie vers tout.log si la bascule horodatee a servi,
   pour que le fichier versionne porte toujours la sortie complete. */
capture log close _all
if "$LOGFILE" != "code/stata/logs/tout.log" {
    capture copy "$LOGFILE" "code/stata/logs/tout.log", replace
    if _rc {
        di ">>> tout.log verrouille. Pousse plutot $LOGFILE"
    }
    else {
        di ">>> Log recopie vers code/stata/logs/tout.log"
    }
}

