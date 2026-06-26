/* ============================================================
   config.do — Chemins, constantes et options globales
   ============================================================ */

global BASE_2018 "Base/2018-2019/SEN_2018_EHCVM_v02_M_Stata"
global BASE_2021 "Base/2021-2022/SEN_2021_EHCVM-2_v01_M_STATA14"
global OUTPUT    "code/stata/output"
global TEMP      "code/stata/temp"
global LOGS      "code/stata/logs"

global SEED              123
global K_SEUIL           0.3333   /* seuil Alkire-Foster */
global K_MODA            4        /* seuil N-MODA : >= 4 dimensions sur 7 */
global N_BOOT            1000
/* s13aq14 / s13q19 : >= 4 = etranger */
global CODE_ETRANGER_MIN 4

set seed $SEED
set more off
set varabbrev off

foreach d in "$OUTPUT" "$TEMP" "$LOGS" {
    capture mkdir "`d'"
}
