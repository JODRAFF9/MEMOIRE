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

# Welfare : pcexp, hhsize, region, milieu + caracteristiques du CM
wel_2018 <- lire_stata(BASE_2018, "ehcvm_welfare_sen2018.dta")
wel_2021 <- lire_stata(BASE_2021, "ehcvm_welfare_sen2021.dta")

ID <- c("grappe", "menage")

# ── Variables welfare selectionnees ──────────────────────────
# hgender (sexe CM), hage (age CM), heduc (education CM), hmstat (situation famille CM)
# region, milieu, hhsize, pcexp

VARS_WEL <- c(ID, "pcexp", "hhsize", "region", "milieu",
              "hgender", "hage", "heduc", "hmstat")

sel_wel <- function(wel) {
  vars_dispo <- intersect(VARS_WEL, names(wel))
  wel |>
    dplyr::select(dplyr::all_of(vars_dispo)) |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels))
}

# ── Fusion base analytique ────────────────────────────────────

construire_base <- function(enfants, traitement, welfare, annee, t_val) {
  enfants |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels)) |>
    dplyr::left_join(traitement |>
                       dplyr::mutate(dplyr::across(where(haven::is.labelled),
                                                   haven::zap_labels)) |>
                       dplyr::select(dplyr::all_of(c(ID, "D"))),
                     by = ID) |>
    dplyr::left_join(sel_wel(welfare), by = ID) |>
    dplyr::mutate(
      annee     = annee,
      t         = t_val,
      log_pcexp = log(pcexp + 1),
      # Facteurs pour le probit
      f_milieu  = as.factor(dplyr::coalesce(milieu, 1L)),
      f_region  = as.factor(dplyr::coalesce(region, 1L)),
      f_heduc   = as.factor(dplyr::coalesce(heduc,  0L)),
      f_hmstat  = as.factor(dplyr::coalesce(hmstat, 1L)),
      hgender_n = dplyr::coalesce(as.integer(hgender), 1L),
      hage_n    = dplyr::coalesce(as.numeric(hage), median(as.numeric(hage), na.rm=TRUE)),
      hhsize_n  = dplyr::coalesce(as.numeric(hhsize), median(as.numeric(hhsize), na.rm=TRUE))
    )
}

base_2018 <- construire_base(enfants_2018, traitement_2018, wel_2018, 2018, 0)
base_2021 <- construire_base(enfants_2021, traitement_2021, wel_2021, 2021, 1)

pseudo_panel <- dplyr::bind_rows(
  dplyr::mutate(base_2018, dplyr::across(where(haven::is.labelled), haven::zap_labels)),
  dplyr::mutate(base_2021, dplyr::across(where(haven::is.labelled), haven::zap_labels))
)

cat("Base analytique :", nrow(pseudo_panel),
    "obs | traites :", sum(pseudo_panel$D == 1, na.rm = TRUE), "\n")

# ── Statistiques descriptives par statut traitement ───────────

pseudo_panel |>
  dplyr::group_by(annee, D) |>
  dplyr::summarise(
    n          = dplyr::n(),
    pct_AF     = round(taux(pauvre_AF) * 100, 1),
    pct_MODA   = round(taux(pauvre_MODA) * 100, 1),
    score_moy  = round(taux(score_dep), 3),
    dep_moda   = round(taux(nb_dep), 2),
    pcexp_moy  = round(taux(pcexp), 0),
    .groups    = "drop"
  ) |>
  print()

# ── PSM : probit sur covariables (periode de base t=0) ───────
# Specification complete : caracteristiques du CM + composition + localisation

formule_probit <- D ~ hhsize_n + log_pcexp + f_milieu + f_region +
                      hgender_n + hage_n + f_heduc + f_hmstat

base_t0 <- base_2018 |>
  dplyr::filter(!is.na(D), !is.na(log_pcexp), !is.na(hhsize_n))

probit_mod <- glm(formule_probit, data = base_t0,
                  family = binomial(link = "probit"))
cat("\n=== Modele probit (score de propension) ===\n")
print(summary(probit_mod))

# Pseudo-R2 de McFadden
ll_null <- probit_mod$null.deviance / (-2)
ll_mod  <- probit_mod$deviance / (-2)
cat(sprintf("Pseudo-R2 McFadden : %.3f\n", 1 - ll_mod / ll_null))

base_t0 <- base_t0 |>
  dplyr::mutate(pscore = predict(probit_mod, type = "response"))

# Graphique overlap (support commun)
p_overlap <- ggplot2::ggplot(base_t0, ggplot2::aes(x = pscore, fill = factor(D))) +
  ggplot2::geom_density(alpha = 0.5) +
  ggplot2::scale_fill_manual(values = c("steelblue", "tomato"),
                              labels = c("Non-traites", "Traites")) +
  ggplot2::labs(title = "Distribution du score de propension — support commun",
                x = "Score de propension", y = "Densite", fill = "") +
  ggplot2::theme_minimal(base_size = 12)
ggplot2::ggsave(file.path(OUTPUT_DIR, "overlap.pdf"), p_overlap, width = 8, height = 5)

# ── Appariement 1 : k-NN (k=4, sans remplacement) ────────────

match_knn <- MatchIt::matchit(formule_probit, data = base_t0,
                               method = "nearest",
                               distance = "glm", link = "probit",
                               ratio = 4, replace = FALSE)
cat("\n=== Bilan appariement k-NN ===\n")
print(summary(match_knn, un = FALSE))

# Balance plot
cobalt::love.plot(match_knn,
                  threshold   = 0.1,
                  title       = "Balance avant/apres appariement (k-NN)",
                  var.order   = "unadjusted",
                  colors      = c("steelblue", "tomato"))

# ── Appariement 2 : Kernel (Epanechnikov) ────────────────────

match_kernel <- MatchIt::matchit(formule_probit, data = base_t0,
                                  method  = "full",
                                  distance = "glm", link = "probit",
                                  estimand = "ATT")

# ── Appariement 3 : Caliper (epsilon = 0.05) ─────────────────

match_cal <- MatchIt::matchit(formule_probit, data = base_t0,
                               method   = "nearest",
                               distance = "glm", link = "probit",
                               caliper  = 0.05, std.caliper = FALSE,
                               ratio = 1)

# ── Base appariee pour la DD ──────────────────────────────────

matched_data_knn <- MatchIt::match.data(match_knn)

# Reconstituer le pseudo-panel sur la base appariee
# (traites kNN + temoins correspondants pour t=0 et t=1)
id_traites <- matched_data_knn |>
  dplyr::filter(D == 1) |>
  dplyr::select(dplyr::all_of(ID)) |>
  dplyr::distinct()

id_temoins <- matched_data_knn |>
  dplyr::filter(D == 0) |>
  dplyr::select(dplyr::all_of(ID)) |>
  dplyr::distinct()

panel_apparie <- pseudo_panel |>
  dplyr::semi_join(
    dplyr::bind_rows(id_traites, id_temoins),
    by = ID
  )

cat("Panel apparie :", nrow(panel_apparie), "obs\n")

# ── Double Difference (DD simple, sans appariement) ──────────
# Y_it = alpha + beta*t + gamma*D + delta*(t x D) + eps
# delta = ATT_DD

cat("\n=== Double Difference (sans appariement) ===\n")
for (outcome in c("pauvre_AF", "pauvre_MODA")) {
  formule_dd <- as.formula(paste(outcome, "~ factor(t) + D + factor(t):D"))
  mod_dd <- lm(formule_dd, data = pseudo_panel)
  mod_dd_rob <- lmtest::coeftest(
    mod_dd,
    vcov = sandwich::vcovCL(mod_dd, cluster = ~grappe)
  )
  cat(sprintf("\n--- DD %s ---\n", outcome))
  print(mod_dd_rob)
}

# ── PSM-DD (Heckman et al. 1997/1998) ────────────────────────
# ATT_PSM-DD = (1/nT) * sum_{i in T} [DeltaY_i - sum_j w_ij DeltaY_j]

cat("\n=== PSM-DD (Heckman 1997/1998) ===\n")
for (outcome in c("pauvre_AF", "pauvre_MODA")) {
  formule_dd <- as.formula(paste(outcome, "~ factor(t) + D + factor(t):D"))
  mod_psm_dd <- lm(formule_dd, data = panel_apparie,
                   weights = panel_apparie$weights)
  mod_psm_dd_rob <- lmtest::coeftest(
    mod_psm_dd,
    vcov = sandwich::vcovCL(mod_psm_dd, cluster = ~grappe)
  )
  cat(sprintf("\n--- PSM-DD %s ---\n", outcome))
  print(mod_psm_dd_rob)
}

# ── Heterogeneite ─────────────────────────────────────────────

cat("\n=== Heterogeneite par milieu ===\n")
for (mil in c(1, 2)) {
  panel_mil <- panel_apparie |> dplyr::filter(f_milieu == mil)
  label_mil <- if (mil == 1) "Urbain" else "Rural"
  for (outcome in c("pauvre_AF", "pauvre_MODA")) {
    formule_dd <- as.formula(paste(outcome, "~ factor(t) + D + factor(t):D"))
    if (nrow(panel_mil) > 30) {
      mod <- lm(formule_dd, data = panel_mil)
      mod_rob <- lmtest::coeftest(mod,
        vcov = sandwich::vcovCL(mod, cluster = ~grappe))
      cat(sprintf("\n--- %s — %s ---\n", label_mil, outcome))
      print(mod_rob)
    }
  }
}

# ── Test tendances paralleles (pre-trend placebo) ─────────────
# Verifier que les tendances etaient similaires avant 2018 (si donnees disponibles)
# ou tester sur une sous-periode interne
cat("\n[Note] Test de tendances paralleles : necessite donnees pre-2018 ou",
    "regression pre-trend sur covariables.\n")
cat("Effectuer test de Rosenbaum pour sensibilite au biais cache (annexe A).\n")

# ── Robustesse : bootstrap (N_BOOT replications) ─────────────

set.seed(SEED)
psm_dd_boot <- function(data, outcome, B = N_BOOT) {
  n <- nrow(data)
  att_boot <- numeric(B)
  for (b in seq_len(B)) {
    idx  <- sample(seq_len(n), n, replace = TRUE)
    boot <- data[idx, ]
    f    <- as.formula(paste(outcome, "~ factor(t) + D + factor(t):D"))
    m    <- try(lm(f, data = boot, weights = boot$weights), silent = TRUE)
    if (!inherits(m, "try-error")) {
      coef_name <- grep("factor\\(t\\)1:D", names(coef(m)), value = TRUE)
      att_boot[b] <- if (length(coef_name)) coef(m)[coef_name] else NA_real_
    }
  }
  att_boot <- att_boot[!is.na(att_boot)]
  list(mean = mean(att_boot), se = sd(att_boot),
       ci95 = quantile(att_boot, c(0.025, 0.975)))
}

cat("\n=== Bootstrap PSM-DD (", N_BOOT, "replications) ===\n")
for (outcome in c("pauvre_AF", "pauvre_MODA")) {
  res <- psm_dd_boot(panel_apparie, outcome)
  cat(sprintf("  %s : ATT=%.4f  SE=%.4f  IC95=[%.4f, %.4f]\n",
              outcome, res$mean, res$se, res$ci95[1], res$ci95[2]))
}
