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

/* Plan de sondage EHCVM : stratifié à 2 degrés
   - Strates : région (14) × milieu (2) = 28 strates
   - UPE : zones de dénombrement (grappe)
   - Poids : hhweight
   Usage : après avoir généré strate, appeler svyset_ehcvm
*/
capture program drop svyset_ehcvm
program define svyset_ehcvm
    args poids
    /* Construire la strate si absente */
    capture confirm variable strate
    if _rc {
        gen long strate = region * 10 + milieu
        label var strate "Strate (region x milieu)"
    }
    if "`poids'" == "" local poids "hhweight"
    svyset grappe [pw = `poids'], strata(strate) singleunit(centered)
end

foreach d in "$OUTPUT" "$TEMP" "$LOGS" {
    capture mkdir "`d'"
}
