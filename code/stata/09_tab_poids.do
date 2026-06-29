/* ============================================================
   09_tab_poids.do - Tableaux avec et sans ponderation
   Comparaison des statistiques descriptives brutes (non ponderees)
   et ponderees par hhweight pour evaluer la representativite.

   Sorties :
     output/tables/tab_incidence_poids.csv   -- H N-MODA et AF avec/sans poids
     output/tables/tab_privations_poids.csv  -- privations par dimension avec/sans poids
     output/tables/tab_menages_poids.csv     -- caract. menages avec/sans poids
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

capture mkdir "$OUTPUT/tables"

/* ============================================================
   1. Incidence pauvrete multidimensionnelle avec / sans poids
   ============================================================ */

di _newline "=== 1. Incidence N-MODA et AF avec/sans ponderation ==="

clear
set obs 4
gen str6  annee    = ""
gen str4  poids    = ""
gen float H_MODA   = .
gen float A_MODA   = .
gen float M0_MODA  = .
gen float H_AF     = .
gen long  n_obs    = .

local r = 0
foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear

    /* Sans ponderation */
    local ++r
    quietly {
        summarize pauvre_MODA
        local H_moda_np  = r(mean)*100
        local n_np       = r(N)
        summarize intensite_moda if pauvre_MODA == 1
        local A_moda_np  = r(mean)*100
        local M0_moda_np = `H_moda_np' * `A_moda_np' / 100
        summarize pauvre_AF
        local H_af_np    = r(mean)*100
    }
    di "`annee' NON PONDERE : H_MODA=" %5.1f `H_moda_np' "% A=" %5.1f `A_moda_np' "% H_AF=" %5.1f `H_af_np' "% n=" `n_np'

    /* Avec ponderation */
    local ++r
    quietly {
        summarize pauvre_MODA [aw=hhweight]
        local H_moda_p   = r(mean)*100
        local n_p        = r(N)
        summarize intensite_moda [aw=hhweight] if pauvre_MODA == 1
        local A_moda_p   = r(mean)*100
        local M0_moda_p  = `H_moda_p' * `A_moda_p' / 100
        summarize pauvre_AF [aw=hhweight]
        local H_af_p     = r(mean)*100
    }
    di "`annee' PONDERE    : H_MODA=" %5.1f `H_moda_p' "% A=" %5.1f `A_moda_p' "% H_AF=" %5.1f `H_af_p' "% n=" `n_p'

    /* Stocker dans dataset */
    local r2 = `r' - 1
    foreach ri in `r2' `r' {
        local p = cond(`ri' == `r2', "non", "oui")
        local a = "`annee'"
        local H_m  = cond(`ri' == `r2', `H_moda_np',  `H_moda_p')
        local A_m  = cond(`ri' == `r2', `A_moda_np',  `A_moda_p')
        local M0_m = cond(`ri' == `r2', `M0_moda_np', `M0_moda_p')
        local H_a  = cond(`ri' == `r2', `H_af_np',    `H_af_p')
        local n    = cond(`ri' == `r2', `n_np',        `n_p')
        quietly {
            replace annee   = "`a'"  in `ri'
            replace poids   = "`p'"  in `ri'
            replace H_MODA  = `H_m'  in `ri'
            replace A_MODA  = `A_m'  in `ri'
            replace M0_MODA = `M0_m' in `ri'
            replace H_AF    = `H_a'  in `ri'
            replace n_obs   = `n'    in `ri'
        }
    }
}

export delimited using "$OUTPUT/tables/tab_incidence_poids.csv", replace
di ">>> tab_incidence_poids.csv sauvegarde"

/* ============================================================
   2. Privations par dimension avec / sans poids
   ============================================================ */

di _newline "=== 2. Privations par dimension avec/sans ponderation ==="

clear
set obs 28
gen str6  annee  = ""
gen str12 dim    = ""
gen str4  poids  = ""
gen float taux   = .
gen long  n_obs  = .

local r = 0
foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear
    foreach dim in assai eau logem nutri sante protect educ {
        /* Sans ponderation */
        local ++r
        quietly summarize dim_`dim'
        replace annee  = "`annee'" in `r'
        replace dim    = "`dim'"   in `r'
        replace poids  = "non"     in `r'
        replace taux   = r(mean)*100 in `r'
        replace n_obs  = r(N)      in `r'
        di "`annee' `dim' NON PONDERE : " %5.1f r(mean)*100 "%"

        /* Avec ponderation */
        local ++r
        quietly summarize dim_`dim' [aw=hhweight]
        replace annee  = "`annee'" in `r'
        replace dim    = "`dim'"   in `r'
        replace poids  = "oui"     in `r'
        replace taux   = r(mean)*100 in `r'
        replace n_obs  = r(N)      in `r'
        di "`annee' `dim' PONDERE    : " %5.1f r(mean)*100 "%"
    }
}

export delimited using "$OUTPUT/tables/tab_privations_poids.csv", replace
di ">>> tab_privations_poids.csv sauvegarde"

/* ============================================================
   3. Caracteristiques menages avec / sans poids
   ============================================================ */

di _newline "=== 3. Caracteristiques menages avec/sans ponderation ==="

clear
set obs 4
gen str6  annee     = ""
gen str4  poids     = ""
gen float hhsize    = .
gen float p_chef_f  = .
gen float p_urbain  = .
gen float p_transf  = .
gen float pcexp     = .
gen long  n_obs     = .

local r = 0
foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear
    bysort grappe menage: keep if _n == 1
    merge m:1 grappe menage using "$TEMP/traitement_`annee'.dta", ///
        keepusing(D) nogenerate keep(master match)
    replace D = 0 if missing(D)
    gen byte chef_f = (hgender == 2)
    gen byte urbain = (milieu == 1)

    foreach w in "non" "oui" {
        local ++r
        if "`w'" == "non" {
            quietly {
                summarize hhsize
                local s_size  = r(mean)
                local n       = r(N)
                summarize chef_f
                local s_chef  = r(mean)*100
                summarize urbain
                local s_urb   = r(mean)*100
                summarize D
                local s_D     = r(mean)*100
                summarize pcexp
                local s_pce   = r(mean)
            }
        }
        else {
            quietly {
                summarize hhsize [aw=hhweight]
                local s_size  = r(mean)
                local n       = r(N)
                summarize chef_f [aw=hhweight]
                local s_chef  = r(mean)*100
                summarize urbain [aw=hhweight]
                local s_urb   = r(mean)*100
                summarize D [aw=hhweight]
                local s_D     = r(mean)*100
                summarize pcexp [aw=hhweight]
                local s_pce   = r(mean)
            }
        }
        di "`annee' poids=`w' : hhsize=" %5.2f `s_size' " chef_f=" %5.1f `s_chef' "% urbain=" %5.1f `s_urb' "% D=" %5.1f `s_D' "% PCE=" %12.0f `s_pce'
        replace annee    = "`annee'" in `r'
        replace poids    = "`w'"     in `r'
        replace hhsize   = `s_size'  in `r'
        replace p_chef_f = `s_chef'  in `r'
        replace p_urbain = `s_urb'   in `r'
        replace p_transf = `s_D'     in `r'
        replace pcexp    = `s_pce'   in `r'
        replace n_obs    = `n'       in `r'
    }
}

export delimited using "$OUTPUT/tables/tab_menages_poids.csv", replace
di ">>> tab_menages_poids.csv sauvegarde"

di _newline ">>> 09_tab_poids.do termine."
di ">>> Sorties dans : $OUTPUT/tables/"
