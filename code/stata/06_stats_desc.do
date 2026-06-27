/* ============================================================
   06_stats_desc.do — Statistiques descriptives

   Produit les tableaux et figures pour le chapitre 3 :
     - Profil des enfants et des menages
     - Evolution de la pauvrete entre les deux vagues
     - Comparaison traites / non-traites
   ============================================================ */

do "code/stata/config.do"
do "code/stata/utils.do"

/* ============================================================
   1. Incidence de la pauvrete par annee, milieu et region
   ============================================================ */

di _newline "=== Incidence de la pauvrete multidimensionnelle ==="

foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear

    di _newline "-- `annee' --"
    di "Pauvrete AF (H) :"
    tabstat pauvre_AF, by(milieu) stat(mean n) format(%6.3f)
    tabstat pauvre_AF, by(region) stat(mean n) format(%6.3f)

    di "Pauvrete N-MODA (H) :"
    tabstat pauvre_MODA, by(milieu) stat(mean n) format(%6.3f)
    tabstat pauvre_MODA, by(region) stat(mean n) format(%6.3f)

    di "Nombre moyen de privations (nb_dep) :"
    tabstat nb_dep, by(milieu) stat(mean sd n) format(%6.3f)
}

/* ============================================================
   2. Evolution entre les deux vagues (panel vrai)
   ============================================================ */

di _newline "=== Evolution sur le panel vrai (t=0 vs t=1) ==="
use "$TEMP/panel_vrai.dta", clear

tabstat pauvre_AF pauvre_MODA nb_dep score_dep, ///
    by(t) stat(mean sd n) format(%6.3f)

/* Par statut de traitement */
di "Par statut de traitement :"
tabstat pauvre_AF pauvre_MODA, ///
    by(D) stat(mean n) format(%6.3f)

/* ============================================================
   3. Profil des menages beneficiaires vs non-beneficiaires
   ============================================================ */

di _newline "=== Profil des menages (t=0, avant traitement) ==="
use "$TEMP/panel_vrai.dta", clear
keep if t == 0

tabstat pcexp hhsize hage, ///
    by(D) stat(mean sd n) format(%6.3f)

tab heduc D, row nofreq
tab milieu D, row nofreq
tab hgender D, row nofreq

/* ============================================================
   4. Graphique : evolution de la pauvrete par dimension
   ============================================================ */

di _newline "=== Privation par dimension — evolution 2018-2021 ==="
foreach annee in 2018 2021 {
    use "$TEMP/vague_`annee'.dta", clear
    di "Dimensions `annee' :"
    foreach dim in assai eau logem nutri sante protect educ {
        taux_dep dim_`dim' "`dim'"
    }
}

di _newline ">>> 06_stats_desc.do termine."
