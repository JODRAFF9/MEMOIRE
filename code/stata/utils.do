/* ============================================================
   utils.do — Programmes utilitaires reutilisables
   ============================================================ */

/* ── Exploration rapide d'un fichier ───────────────────────── */
program define visiter
    args fichier nom
    use "`fichier'", clear
    di _newline "===== `nom' ====="
    di "Observations : " _N
    describe
    codebook, compact
end

/* ── Taux de privation (%) ──────────────────────────────────── */
program define taux_dep
    args var nom
    quietly summarize `var'
    di "  `nom' : " %5.1f r(mean)*100 "%"
end

/* ── Prevalence par statut de traitement ────────────────────── */
program define prev_D
    args outcome
    tabstat `outcome', by(D) stat(mean n) format(%6.3f)
end

/* ── ATT PSM-DD avec IC bootstrap ──────────────────────────── */
/*
   Syntaxe : att_psmdd outcome poids nboot
   Affiche ATT, SE bootstrap, IC 95%, p-valeur
*/
program define att_psmdd
    args outcome poids nboot

    bootstrap att = _b[1.t#1.D], ///
        reps(`nboot') seed($SEED) nodots: ///
        reg `outcome' i.t##i.D [pw = `poids'], ///
        vce(cluster grappe)

    estat bootstrap, percentile all
end

/* ── Verification equilibre SMD ────────────────────────────── */
/*
   Affiche les SMD avant/apres appariement pour une liste de vars
*/
program define check_balance
    args varlist_str
    di _newline "=== Balance des covariables (SMD) ==="
    pstest `varlist_str', both
end
