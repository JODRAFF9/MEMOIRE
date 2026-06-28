/* ============================================================
   main.do — Script maitre

   Pipeline :
     01_visitation  — exploration des bases brutes
     02_traitement  — variable D + identification panel
     03_deprivation — indicateurs IPM (AF et N-MODA)
     04_panel       — construction du panel vrai (PanelHH=1)
     06_stats_desc  — statistiques descriptives
     05_psm_dd      — estimation PSM-DD

   Executer depuis la racine du projet :
     do "code/stata/main.do"
   ============================================================ */

cd "C:\Users\Bmd\Documents\ISE\Cours\ISE3\Memoire"

capture log close
log using "code/stata/logs/analyse.log", replace text

do "code/stata/01_visitation.do"
do "code/stata/02_traitement.do"
do "code/stata/03_deprivation.do"
do "code/stata/04_panel.do"
do "code/stata/06_stats_desc.do"
do "code/stata/05_psm_dd.do"
do "code/stata/07_effets_dim.do"
do "code/stata/08_carte_region.do"

log close
