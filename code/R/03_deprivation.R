# ============================================================
#  03_deprivation.R — Indicateurs de pauvrete multidimensionnelle
#  Approche 1 : Alkire-Foster (M0 = H x A, k = 1/3)
#  Approche 2 : MODA UNICEF (par groupe d'age)
#
#  Variables EHCVM utilisees :
#   ehcvm_individu : scol, educ_scol, educ_hi, mal30j, con30j, age, numind
#   ehcvm_menage   : eauboi_ss, eauboi_sp, toilet, eva_toi, mur, toi, sol
#   ehcvm_welfare  : pcexp, hhsize, region, milieu, hgender, hage, heduc, hmstat
# ============================================================

source("code/R/config.R")
source("code/R/utils.R")

ind_2018 <- lire_stata(BASE_2018, "ehcvm_individu_sen2018.dta")
ind_2021 <- lire_stata(BASE_2021, "ehcvm_individu_sen2021.dta")
men_2018 <- lire_stata(BASE_2018, "ehcvm_menage_sen2018.dta")
men_2021 <- lire_stata(BASE_2021, "ehcvm_menage_sen2021.dta")

ID     <- c("grappe", "menage")
ID_IND <- c("grappe", "menage", "numind")

# ── Enfants 0-17 ans ─────────────────────────────────────────

extraire_enfants <- function(ind, annee, col_age = "age") {
  ind |>
    dplyr::filter(.data[[col_age]] >= 0, .data[[col_age]] <= 17) |>
    dplyr::mutate(
      annee = annee,
      age   = as.integer(.data[[col_age]]),
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

# ── Indicateurs menage (eau, assainissement, habitat) ─────────
# Variables binaires : 1 = satisfaisant, 0 = deficient
# On inverse pour obtenir des indicateurs de privation (1 = prive)

prep_menage <- function(men) {
  men |>
    dplyr::mutate(
      # Eau potable : 1 si au moins une des saisons est non amelioree
      dep_eau   = dplyr::if_else(
        dplyr::coalesce(as.integer(haven::zap_labels(eauboi_ss)), 0L) == 0L |
        dplyr::coalesce(as.integer(haven::zap_labels(eauboi_sp)), 0L) == 0L,
        1L, 0L
      ),
      # Assainissement : toilettes non saines OU evacuation non saine
      dep_assai = dplyr::if_else(
        dplyr::coalesce(as.integer(haven::zap_labels(toilet)),  1L) == 0L |
        dplyr::coalesce(as.integer(haven::zap_labels(eva_toi)), 1L) == 0L,
        1L, 0L
      ),
      # Habitat : au moins un materiau precaire (mur, toit ou sol)
      dep_habit = dplyr::if_else(
        dplyr::coalesce(as.integer(haven::zap_labels(mur)), 1L) == 0L |
        dplyr::coalesce(as.integer(haven::zap_labels(toi)), 1L) == 0L |
        dplyr::coalesce(as.integer(haven::zap_labels(sol)), 1L) == 0L,
        1L, 0L
      )
    ) |>
    dplyr::select(dplyr::all_of(ID), dep_eau, dep_assai, dep_habit)
}

dep_men_2018 <- prep_menage(men_2018)
dep_men_2021 <- prep_menage(men_2021)

# ── Fusion enfants + menage ───────────────────────────────────

enfants_2018 <- enfants_2018 |>
  dplyr::left_join(dep_men_2018, by = ID)
enfants_2021 <- enfants_2021 |>
  dplyr::left_join(dep_men_2021, by = ID)

# ── Alkire-Foster ─────────────────────────────────────────────
# 6 indicateurs, poids egaux (1/6)
# d1 Education | d2 Sante | d3 Nutrition | d4 Eau | d5 Assainissement | d6 Habitat
#
# d1_educ  : non-scolarise (6-17 ans) ou retard scolaire >= 2 ans
#   scol = 1 (oui) / 0 (non) ; educ_scol = niveau actuel ; educ_hi = niveau atteint
# d2_sante : malade et n'a pas consulte dans les 30 derniers jours
#   mal30j = 1 (oui) ; con30j = 1 (oui)
# d3_nutri : proxy retard de croissance — mal30j pour les 0-4 ans (limitation : pas
#   de donnees anthropometriques directes dans ehcvm_individu)
# d4_eau   : source d'eau non amelioree (dep_eau)
# d5_assai : assainissement non ameliore (dep_assai)
# d6_habit : habitat precaire (dep_habit)

construire_af <- function(df) {
  df |>
    dplyr::mutate(
      # Education : non-scolarise pour 6-17 ans
      d1_educ = dplyr::case_when(
        age < 6  ~ 0L,
        age >= 6 & dplyr::coalesce(as.integer(haven::zap_labels(scol)), 0L) == 0L ~ 1L,
        TRUE     ~ 0L
      ),
      # Sante : malade non-consulte (proxy acces aux soins)
      d2_sante = dplyr::if_else(
        dplyr::coalesce(as.integer(haven::zap_labels(mal30j)), 0L) == 1L &
        dplyr::coalesce(as.integer(haven::zap_labels(con30j)), 1L) == 0L,
        1L, 0L
      ),
      # Nutrition : proxy pour 0-4 ans (maladie recente sans prise en charge)
      d3_nutri = dplyr::if_else(
        age <= 4 &
        dplyr::coalesce(as.integer(haven::zap_labels(mal30j)), 0L) == 1L,
        1L, 0L
      ),
      # Eau, assainissement, habitat deja construits
      d4_eau   = dplyr::coalesce(dep_eau,   0L),
      d5_assai = dplyr::coalesce(dep_assai, 0L),
      d6_habit = dplyr::coalesce(dep_habit, 0L)
    ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      score_dep = mean(c(d1_educ, d2_sante, d3_nutri, d4_eau, d5_assai, d6_habit),
                       na.rm = TRUE),
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

# Contribution de chaque dimension
cat("\nContribution par dimension (AF) :\n")
for (annee in c(2018, 2021)) {
  df <- if (annee == 2018) enfants_2018 else enfants_2021
  pauvres <- df[df$pauvre_AF == 1, ]
  cat(sprintf("  %d : educ=%.3f  sante=%.3f  nutri=%.3f  eau=%.3f  assai=%.3f  habit=%.3f\n",
    annee,
    taux(pauvres$d1_educ), taux(pauvres$d2_sante), taux(pauvres$d3_nutri),
    taux(pauvres$d4_eau),  taux(pauvres$d5_assai), taux(pauvres$d6_habit)
  ))
}

# ── MODA UNICEF ───────────────────────────────────────────────
# Indicateurs specifiques par groupe d'age, seuil : >= 2 deprivations simultanees
#
# 0-4  ans : sante + nutrition + eau + assainissement + habitat
# 5-14 ans : education + sante + eau + assainissement + habitat
# 15-17 ans: education + travail + eau + assainissement + information

construire_moda <- function(df) {
  df |>
    dplyr::mutate(
      # Education (5-17 ans)
      m_educ  = dplyr::case_when(
        age < 5  ~ 0L,
        dplyr::coalesce(as.integer(haven::zap_labels(scol)), 0L) == 0L ~ 1L,
        TRUE     ~ 0L
      ),
      # Sante : acces aux soins
      m_sante = d2_sante,
      # Nutrition : proxy 0-4 ans
      m_nutri = d3_nutri,
      # Eau, assainissement, habitat
      m_eau   = d4_eau,
      m_assai = d5_assai,
      m_habit = d6_habit,
      # Travail des enfants (15-17 ans) : actif7j ou activ12m
      m_trav  = dplyr::if_else(
        age >= 15 &
        dplyr::coalesce(as.integer(haven::zap_labels(activ7j)), 0L) %in% c(1L, 2L),
        1L, 0L
      )
    ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      nb_dep = dplyr::case_when(
        groupe_moda == "0-4 ans"   ~
          sum(c(m_sante, m_nutri, m_eau, m_assai, m_habit), na.rm = TRUE),
        groupe_moda == "5-14 ans"  ~
          sum(c(m_educ, m_sante, m_eau, m_assai, m_habit), na.rm = TRUE),
        groupe_moda == "15-17 ans" ~
          sum(c(m_educ, m_trav, m_eau, m_assai, m_habit), na.rm = TRUE),
        TRUE ~ NA_integer_
      ),
      pauvre_MODA = as.integer(!is.na(nb_dep) & nb_dep >= 2)
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
      n          = dplyr::n(),
      pct_pauvre = round(taux(pauvre_MODA) * 100, 1),
      nb_dep_moy = round(taux(nb_dep), 2),
      .groups = "drop"
    ))
}

saveRDS(enfants_2018, file.path(OUTPUT_DIR, "enfants_dep_2018.rds"))
saveRDS(enfants_2021, file.path(OUTPUT_DIR, "enfants_dep_2021.rds"))
