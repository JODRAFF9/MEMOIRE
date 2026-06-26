# ============================================================
#  03_deprivation.R — Indicateurs MODA par groupe d'âge
#
#  Cadre MODA (UNICEF) adapté à l'EHCVM Sénégal
#  Seuil de pauvreté multidimensionnelle : >= 2 privations simultanées
#
#  Dimensions et indicateurs par groupe d'âge :
#
#  Assainissement
#    dep_assai_type  : type de sanitaire non sain          [0-4, 5-14, 15-17]
#    dep_assai_part  : partage des toilettes                [0-4, 5-14, 15-17]
#  Eau
#    dep_eau_source  : source d'eau non améliorée           [0-4, 5-14, 15-17]
#    dep_eau_temps   : temps > 30 min pour aller chercher   [0-4, 5-14, 15-17]
#  Logement
#    dep_log_ordure  : débarras ordures ménagères non sain  [0-4, 5-14, 15-17]
#    dep_log_surp    : surpeuplement (> 3 pers/pièce)       [0-4, 5-14, 15-17]
#  Nutrition
#    dep_nutri_div   : diversité alimentaire faible         [5-14, 15-17]
#    dep_nutri_secu  : insécurité alimentaire               [0-4, 5-14, 15-17]
#  Santé
#    dep_sante       : malade non-consulté                  [0-4, 5-14, 15-17]
#  Protection de l'enfant
#    dep_naissance   : pas d'acte de naissance              [0-4, 5-14]
#    dep_travail     : travail des enfants (éco. + dom.)    [5-14]
#    dep_parents     : enfant ne vivant pas avec ses parents[0-4, 5-14, 15-17]
#  Éducation
#    dep_alfab       : non alphabétisé                      [15-17]
#    dep_scol        : non-scolarisé                        [5-14]
# ============================================================

source("code/R/config.R")
source("code/R/utils.R")

base_ind_2018 <- readRDS(file.path(OUTPUT_DIR, "base_individu_2018.rds"))
base_ind_2021 <- readRDS(file.path(OUTPUT_DIR, "base_individu_2021.rds"))

# ── Enfants 0-17 ans ─────────────────────────────────────────

extraire_enfants <- function(base_ind, annee) {
  base_ind |>
    dplyr::filter(age >= 0, age <= 17) |>
    dplyr::mutate(
      annee = annee,
      groupe_moda = dplyr::case_when(
        age <= 4              ~ "0-4 ans",
        age >= 5 & age <= 14  ~ "5-14 ans",
        age >= 15             ~ "15-17 ans"
      )
    )
}

enfants_2018 <- extraire_enfants(base_ind_2018, 2018)
enfants_2021 <- extraire_enfants(base_ind_2021, 2021)
cat("Enfants 2018 :", nrow(enfants_2018), "| 2021 :", nrow(enfants_2021), "\n")

# ── Proxy nutrition ───────────────────────────────────────────
# dep_nutri_secu : dépenses alimentaires per capita < 50% médiane (insécurité)
# dep_nutri_div  : proxy — pas de variable directe HDDS dans ehcvm_individu;
#                  on utilise pcexp < 25e percentile comme proxy diversité faible

ajouter_nutri <- function(df) {
  med_ali   <- median(df$pcexp * 0.6, na.rm = TRUE)  # 60% pcexp ≈ part alimentaire
  p25_pcexp <- quantile(df$pcexp, 0.25, na.rm = TRUE)
  df |>
    dplyr::mutate(
      dep_nutri_secu = dplyr::if_else(
        dplyr::coalesce(pcexp, Inf) * 0.6 < med_ali / 2, 1L, 0L),
      dep_nutri_div  = dplyr::if_else(
        dplyr::coalesce(pcexp, Inf) < p25_pcexp, 1L, 0L)
    )
}

enfants_2018 <- ajouter_nutri(enfants_2018)
enfants_2021 <- ajouter_nutri(enfants_2021)

# ── Score MODA par groupe d'âge ───────────────────────────────
#
# Chaque groupe a ses propres indicateurs actifs.
# nb_dep = nombre de privations observées pour ce groupe
# pauvre_MODA = 1 si nb_dep >= 4

construire_moda <- function(df) {
  df |>
    dplyr::rowwise() |>
    dplyr::mutate(
      nb_dep = dplyr::case_when(

        groupe_moda == "0-4 ans" ~ sum(c(
          dep_assai_type, dep_assai_part,
          dep_eau_source, dep_eau_temps,
          dep_log_ordure, dep_log_surp,
          dep_nutri_secu,
          dep_sante,
          dep_naissance, dep_parents
        ), na.rm = TRUE),

        groupe_moda == "5-14 ans" ~ sum(c(
          dep_assai_type, dep_assai_part,
          dep_eau_source, dep_eau_temps,
          dep_log_ordure, dep_log_surp,
          dep_nutri_div,  dep_nutri_secu,
          dep_sante,
          dep_naissance, dep_travail, dep_parents,
          dep_scol
        ), na.rm = TRUE),

        groupe_moda == "15-17 ans" ~ sum(c(
          dep_assai_type, dep_assai_part,
          dep_eau_source, dep_eau_temps,
          dep_log_ordure, dep_log_surp,
          dep_nutri_div,  dep_nutri_secu,
          dep_sante,
          dep_parents,
          dep_alfab
        ), na.rm = TRUE),

        TRUE ~ NA_real_
      ),
      pauvre_MODA = as.integer(!is.na(nb_dep) & nb_dep >= 4)
    ) |>
    dplyr::ungroup()
}

enfants_2018 <- construire_moda(enfants_2018)
enfants_2021 <- construire_moda(enfants_2021)

# ── Prévalence MODA par groupe et par année ───────────────────

for (annee in c(2018, 2021)) {
  df <- if (annee == 2018) enfants_2018 else enfants_2021
  cat(sprintf("\nMODA %d — prévalence par groupe :\n", annee))
  print(df |>
    dplyr::group_by(groupe_moda) |>
    dplyr::summarise(
      n           = dplyr::n(),
      pct_pauvre  = round(mean(pauvre_MODA, na.rm = TRUE) * 100, 1),
      nb_dep_moy  = round(mean(nb_dep, na.rm = TRUE), 2),
      .groups = "drop"
    ))
}

# ── Contribution par dimension ────────────────────────────────

dims <- c("dep_assai_type", "dep_assai_part",
          "dep_eau_source", "dep_eau_temps",
          "dep_log_ordure", "dep_log_surp",
          "dep_nutri_secu", "dep_nutri_div",
          "dep_sante",
          "dep_naissance",  "dep_travail", "dep_parents",
          "dep_alfab",      "dep_scol")

cat("\nContribution par dimension (enfants pauvres MODA) :\n")
for (annee in c(2018, 2021)) {
  df    <- if (annee == 2018) enfants_2018 else enfants_2021
  pauv  <- dplyr::filter(df, pauvre_MODA == 1)
  rates <- sapply(dims, function(v) {
    if (v %in% names(pauv)) round(mean(pauv[[v]], na.rm = TRUE) * 100, 1) else NA
  })
  cat(sprintf("\n  %d :\n", annee))
  print(rates[!is.na(rates)])
}

saveRDS(enfants_2018, file.path(OUTPUT_DIR, "enfants_dep_2018.rds"))
saveRDS(enfants_2021, file.path(OUTPUT_DIR, "enfants_dep_2021.rds"))
