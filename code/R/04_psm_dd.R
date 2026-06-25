# ============================================================
#  04_psm_dd.R — Estimation PSM-DD (Heckman et al. 1997/1998)
#  ATT sur pauvre_AF et pauvre_MODA
# ============================================================

source("code/R/config.R")
source("code/R/utils.R")

enfants_2018 <- readRDS(file.path(OUTPUT_DIR, "enfants_dep_2018.rds"))
enfants_2021 <- readRDS(file.path(OUTPUT_DIR, "enfants_dep_2021.rds"))
traitement_2018 <- readRDS(file.path(OUTPUT_DIR, "traitement_2018.rds"))
traitement_2021 <- readRDS(file.path(OUTPUT_DIR, "traitement_2021.rds"))

wel_2018 <- lire_stata(BASE_2018, "ehcvm_welfare_sen2018.dta")
wel_2021 <- lire_stata(BASE_2021, "ehcvm_welfare_sen2021.dta")

ID <- c("grappe", "menage")

# ── Fusion base analytique ────────────────────────────────────

construire_base <- function(enfants, traitement, welfare, annee, t) {
  enfants |>
    dplyr::left_join(traitement[c(ID, "D")], by = ID) |>
    dplyr::left_join(welfare[c(ID, "pcexp", "hhsize")], by = ID) |>
    dplyr::mutate(annee = annee, t = t,
                  log_pcexp = log(pcexp + 1))
}

base_2018 <- construire_base(enfants_2018, traitement_2018, wel_2018, 2018, 0)
base_2021 <- construire_base(enfants_2021, traitement_2021, wel_2021, 2021, 1)

pseudo_panel <- dplyr::bind_rows(
  dplyr::mutate(base_2018, dplyr::across(where(haven::is.labelled), haven::zap_labels)),
  dplyr::mutate(base_2021, dplyr::across(where(haven::is.labelled), haven::zap_labels))
)

cat("Base analytique :", nrow(pseudo_panel), "obs\n")

# ── Statistiques descriptives par statut traitement ───────────

pseudo_panel |>
  dplyr::group_by(annee, D) |>
  dplyr::summarise(
    n           = dplyr::n(),
    pct_AF      = round(taux(pauvre_AF) * 100, 1),
    pct_MODA    = round(taux(pauvre_MODA) * 100, 1),
    score_moy   = round(taux(score_dep), 3),
    dep_moda    = round(taux(nb_dep), 2),
    pcexp_moy   = round(taux(pcexp), 0),
    .groups     = "drop"
  ) |>
  print()

# ── PSM : probit sur covariables (periode de base 2018) ──────
# Covariables : a adapter selon variables disponibles dans l'EHCVM

covariables <- c("hhsize", "log_pcexp")  # a completer

formule_probit <- as.formula(
  paste("D ~", paste(covariables, collapse = " + "))
)

base_t0 <- base_2018 |> dplyr::filter(!is.na(D))

probit_mod <- glm(formule_probit, data = base_t0, family = binomial(link = "probit"))
summary(probit_mod)

base_t0 <- base_t0 |>
  dplyr::mutate(pscore = predict(probit_mod, type = "response"))

# Overlap
ggplot2::ggplot(base_t0, ggplot2::aes(x = pscore, fill = factor(D))) +
  ggplot2::geom_density(alpha = 0.5) +
  ggplot2::scale_fill_manual(values = c("steelblue","tomato"),
                              labels = c("Non-traites","Traites")) +
  ggplot2::labs(title = "Distribution du score de propension",
                x = "Score de propension", y = "Densite", fill = "") +
  ggplot2::theme_minimal()
ggplot2::ggsave(file.path(OUTPUT_DIR, "overlap.pdf"), width = 8, height = 5)

# ── Appariement (k=4 plus proches voisins) ────────────────────

match_knn <- MatchIt::matchit(formule_probit, data = base_t0,
                               method = "nearest", distance = "glm", link = "probit",
                               ratio = 4, replace = FALSE)
summary(match_knn)

# Bilan appariement (standardized bias)
cobalt::love.plot(match_knn, threshold = 0.1,
                  title = "Balance avant/apres appariement")

# ── Double Difference ─────────────────────────────────────────
# Y_it = alpha + beta*t + gamma*D + delta*(t x D) + eps
# delta = ATT_DD

for (outcome in c("pauvre_AF", "pauvre_MODA")) {
  formule_dd <- as.formula(paste(outcome, "~ factor(t) * D"))
  mod_dd <- lm(formule_dd, data = pseudo_panel)
  mod_dd_rob <- lmtest::coeftest(mod_dd, vcov = sandwich::vcovCL(mod_dd,
                                                                   cluster = ~grappe))
  cat(sprintf("\n=== DD — %s ===\n", outcome))
  print(mod_dd_rob)
}

# ── PSM-DD (Heckman et al. 1997/1998) ────────────────────────
# ATT_PSM-DD = somme sur les traites de [DeltaY_i - somme_j w_ij DeltaY_j]
# (a implementer apres construction du pseudo-panel grappe-level)

# ── Robustesse : bootstrap ────────────────────────────────────
# (a implementer avec le package boot)
