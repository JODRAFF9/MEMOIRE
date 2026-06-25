/* ============================================================
   utils.do — Programmes utilitaires
   ============================================================ */

/* Visitation rapide d'un fichier */
program define visiter
    args fichier nom
    use "`fichier'", clear
    di _newline "===== `nom' ====="
    di "Observations : " _N
    describe
    codebook, compact
end

/* Taux de deprivation */
program define taux_dep
    args var nom
    quietly summarize `var'
    di "  `nom' : " %5.1f r(mean)*100 "%"
end

/* Prevalence par statut de traitement */
program define prev_D
    args outcome
    tabstat `outcome', by(D) stat(mean n) format(%6.3f)
end
