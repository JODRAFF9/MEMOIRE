/* ============================================================
   utils.do — Programmes utilitaires reutilisables

   Chaque programme est precede de "capture program drop" pour
   eviter l'erreur r(110) "already defined" quand utils.do est
   appele plusieurs fois dans la meme session Stata.
   ============================================================ */

/* ── Exploration rapide d'un fichier ───────────────────────── */
capture program drop visiter
program define visiter
    args fichier nom
    use "`fichier'", clear
    di _newline "===== `nom' ====="
    di "Observations : " _N
    describe
    codebook, compact
end

/* ── Taux de privation (%) ──────────────────────────────────── */
capture program drop taux_dep
program define taux_dep
    args var nom
    quietly summarize `var'
    di "  `nom' : " %5.1f r(mean)*100 "%"
end

/* ── Prevalence par statut de traitement ────────────────────── */
capture program drop prev_D
program define prev_D
    args outcome
    tabstat `outcome', by(D) stat(mean n) format(%6.3f)
end

/* ── ATT PSM-DD avec IC bootstrap ──────────────────────────── */
/*
   Syntaxe : att_psmdd outcome poids nboot
   Affiche ATT, SE bootstrap, IC 95%, p-valeur
*/
capture program drop att_psmdd
program define att_psmdd
    args outcome poids nboot

    reg `outcome' i.t##i.D [pw = `poids'], ///
        vce(bootstrap, reps(`nboot') seed($SEED) nodots)

    lincom 1.t#1.D
    di "  ATT=" %8.4f r(estimate) "  SE=" %8.4f r(se) "  p=" %6.4f r(p)
end

/* ── Verification equilibre SMD ────────────────────────────── */
/*
   Affiche les SMD avant/apres appariement pour une liste de vars
*/
capture program drop check_balance
program define check_balance
    args varlist_str
    di _newline "=== Balance des covariables (SMD) ==="
    pstest `varlist_str', both
end
