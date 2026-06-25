# ============================================================
#  03_deprivation.R — Indicateurs de pauvrete multidimensionnelle
#  Approche 1 : Alkire-Foster (M0 = H x A, k = 1/3)
#  Approche 2 : MODA UNICEF (par groupe d'age)
# ============================================================

source("code/R/config.R")
source("code/R/utils.R")

ind_2018 <- lire_stata(BASE_2018, "ehcvm_individu_sen2018.dta")
ind_2021 <- lire_stata(BASE_2021, "ehcvm_individu_sen2021.dta")

ID <- c("grappe", "menage")

# ── Enfants 0-17 ans ─────────────────────────────────────────

extraire_enfants <- function(ind, annee, col_age = "age") {
  ind |>
    dplyr::filter(.data[[col_age]] <= 17) |>
    dplyr::mutate(
      annee = annee,
      age   = .data[[col_age]],
      groupe_moda = dplyr::case_when(
        age <= 4              ~ "0-4 ans",
        age >= 5 & age <= 14  ~ "5-14 ans",
        age >= 15             ~ "15-17 ans"
      )
    )
}

enfants_2018 <- extraire_enfants(ind_2018, 2018)
enfants_2021 <- extraire_enfants(ind_2021, 2021)

cat("Enfants 2018 :", nrow(enfants_2018), "| 2021 :", nrow(enfants_2021), "\n")

# ── Alkire-Foster ─────────────────────────────────────────────
# 6 indicateurs, poids egaux (1/6)
# d1 Education | d2 Sante | d3 Nutrition | d4 Eau | d5 Assainissement | d6 Habitat

construire_af <- function(df) {
  df |>
    dplyr::mutate(
      d1_educ  = 0L,   # a construire : non-scolarise ou retard scolaire
      d2_sante = 0L,   # a construire : pas de suivi medical
      d3_nutri = 0L,   # a construire : malnutrition anthropometrique
      d4_eau   = 0L,   # a construire : source non amelioree
      d5_assai = 0L,   # a construire : assainissement non ameliore
      d6_habit = 0L,   # a construire : habitat precaire
    ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      score_dep = mean(c(d1_educ, d2_sante, d3_nutri, d4_eau, d5_assai, d6_habit)),
      pauvre_AF = as.integer(score_dep >= K_SEUIL)
    ) |>
    dplyr::ungroup()
}

enfants_2018 <- construire_af(enfants_2018)
enfants_2021 <- construire_af(enfants_2021)

# Indices H, A, M0
for (annee in c(2018, 2021)) {
  df <- if (annee == 2018) enfants_2018 else enfants_2021
  idx <- indices_af(df$score_dep)
  cat(sprintf("\nAlkire-Foster %d : H=%.3f  A=%.3f  M0=%.3f\n",
              annee, idx$H, idx$A, idx$M0))
}

# ── MODA UNICEF ───────────────────────────────────────────────
# Indicateurs specifiques par groupe d'age, seuil : >= 2 deprivations simultanees

construire_moda <- function(df) {
  df |>
    dplyr::mutate(
      m_sante = 0L,   # sante
      m_nutri = 0L,   # nutrition
      m_educ  = 0L,   # education
      m_eau   = 0L,   # eau
      m_assai = 0L,   # assainissement
      m_habit = 0L,   # habitat
      m_trav  = 0L,   # travail des enfants (15-17 ans)
    ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      nb_dep = dplyr::case_when(
        groupe_moda == "0-4 ans"   ~ sum(c(m_sante, m_nutri, m_eau, m_assai, m_habit)),
        groupe_moda == "5-14 ans"  ~ sum(c(m_educ,  m_sante, m_eau, m_assai, m_habit)),
        groupe_moda == "15-17 ans" ~ sum(c(m_educ,  m_trav,  m_eau, m_assai, m_habit)),
        TRUE ~ NA_integer_
      ),
      pauvre_MODA = as.integer(nb_dep >= 2)
    ) |>
    dplyr::ungroup()
}

enfants_2018 <- construire_moda(enfants_2018)
enfants_2021 <- construire_moda(enfants_2021)

# Prevalence MODA par groupe
for (annee in c(2018, 2021)) {
  df <- if (annee == 2018) enfants_2018 else enfants_2021
  cat(sprintf("\nMODA %d — prevalence par groupe :\n", annee))
  print(df |>
    dplyr::group_by(groupe_moda) |>
    dplyr::summarise(
      n         = dplyr::n(),
      pct_pauvre = round(taux(pauvre_MODA) * 100, 1),
      .groups = "drop"
    ))
}

saveRDS(enfants_2018, file.path(OUTPUT_DIR, "enfants_dep_2018.rds"))
saveRDS(enfants_2021, file.path(OUTPUT_DIR, "enfants_dep_2021.rds"))
