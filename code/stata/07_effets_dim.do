/* ============================================================
   07_effets_dim.do — ATT PSM-DD par dimension N-MODA
   Génère output/figures/fig_effets_dim.pdf
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

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
gen double weight_final = hhweight * weight_knn

/* ATT PSM-DD pour chaque dimension */
local dims    assai eau logem nutri sante protect educ
local n_dims  7

matrix ATT  = J(`n_dims', 1, .)
matrix LB   = J(`n_dims', 1, .)
matrix UB   = J(`n_dims', 1, .)

local i = 0
foreach dim of local dims {
    local ++i
    quietly reg dim_`dim' i.t##i.D [pw = weight_final], vce(cluster grappe)
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
    (bar att ordre, horizontal barwidth(0.6) color(navy%70)) ///
    (rcap lb ub ordre, horizontal lcolor(maroon) lwidth(medthick) msize(medium)), ///
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
