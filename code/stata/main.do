/* ============================================================
   main.do — Script maitre (executer dans l'ordre)
   ============================================================ */

capture log close
log using "code/stata/logs/analyse.log", replace

do "code/stata/01_visitation.do"
do "code/stata/02_traitement.do"
do "code/stata/03_deprivation.do"
do "code/stata/04_psm_dd.do"

log close
