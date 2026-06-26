# ============================================================
#  00_fusion.R — Fusion des bases EHCVM par année
#
#  Pour chaque vague (2018 et 2021) on assemble :
#    - ehcvm_individu  : caractéristiques individuelles
#    - ehcvm_menage    : caractéristiques du ménage (eau, habitat, etc.)
#    - ehcvm_welfare   : dépenses, composition, CM, localisation
#    - s13a_1 + s13a_2 : modules transferts (construction variable D)
#
#  Clés de jointure :
#    - Niveau ménage  : grappe + menage
#    - Niveau individu: grappe + menage + numind
#
#  Sorties :
#    output/base_menage_2018.rds   — une ligne par ménage, 2018
#    output/base_menage_2021.rds   — une ligne par ménage, 2021
#    output/base_individu_2018.rds — une ligne par individu, 2018
#    output/base_individu_2021.rds — une ligne par individu, 2021
# ============================================================

source("code/R/config.R")
source("code/R/utils.R")

ID_MEN <- c("grappe", "menage")
ID_IND <- c("grappe", "menage", "numind")

# ── Fonction : variable traitement (transfert de l'étranger) ──
# s13a_1 : liste des ménages ayant déclaré recevoir des transferts
# s13a_2 : détail par envoi (lieu de résidence de l'expéditeur)
# Code >= CODE_ETRANGER_MIN → pays étranger

construire_traitement <- function(s13a1, s13a2, col_lieu) {
  etrangers <- s13a2 |>
    dplyr::filter(.data[[col_lieu]] >= CODE_ETRANGER_MIN) |>
    dplyr::distinct(dplyr::across(dplyr::all_of(ID_MEN))) |>
    dplyr::mutate(transfert_migrant = 1L)

  s13a1 |>
    dplyr::select(dplyr::all_of(ID_MEN)) |>
    dplyr::distinct() |>
    dplyr::left_join(etrangers, by = ID_MEN) |>
    dplyr::mutate(D = dplyr::coalesce(transfert_migrant, 0L)) |>
    dplyr::select(dplyr::all_of(ID_MEN), D)
}

# ── Fonction : indicateurs de privation niveau ménage ─────────

prep_deprivation_menage <- function(men) {
  men |>
    dplyr::mutate(
      dep_eau   = dplyr::if_else(
        dplyr::coalesce(as.integer(haven::zap_labels(eauboi_ss)), 0L) == 0L |
        dplyr::coalesce(as.integer(haven::zap_labels(eauboi_sp)), 0L) == 0L,
        1L, 0L
      ),
      dep_assai = dplyr::if_else(
        dplyr::coalesce(as.integer(haven::zap_labels(toilet)),  1L) == 0L |
        dplyr::coalesce(as.integer(haven::zap_labels(eva_toi)), 1L) == 0L,
        1L, 0L
      ),
      dep_habit = dplyr::if_else(
        dplyr::coalesce(as.integer(haven::zap_labels(mur)),  1L) == 0L |
        dplyr::coalesce(as.integer(haven::zap_labels(toit)), 1L) == 0L |
        dplyr::coalesce(as.integer(haven::zap_labels(sol)),  1L) == 0L,
        1L, 0L
      )
    ) |>
    dplyr::select(dplyr::all_of(ID_MEN), dep_eau, dep_assai, dep_habit)
}

# ── Fonction : fusion base ménage ─────────────────────────────
# Résultat : une ligne par ménage avec toutes les covariables

fusionner_menage <- function(men, wel, traitement, annee) {
  VARS_WEL <- c(ID_MEN, "pcexp", "hhsize", "region", "milieu",
                "hgender", "hage", "heduc", "hmstat")
  vars_dispo <- intersect(VARS_WEL, names(wel))

  dep_men <- prep_deprivation_menage(men)

  wel_sel <- wel |>
    dplyr::select(dplyr::all_of(vars_dispo)) |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels))

  dep_men |>
    dplyr::left_join(wel_sel,      by = ID_MEN) |>
    dplyr::left_join(traitement,   by = ID_MEN) |>
    dplyr::mutate(
      annee     = annee,
      D         = dplyr::coalesce(D, 0L),
      log_pcexp = log(dplyr::coalesce(pcexp, 1) + 1),
      f_milieu  = as.factor(dplyr::coalesce(milieu, 1L)),
      f_region  = as.factor(dplyr::coalesce(region, 1L)),
      f_heduc   = as.factor(dplyr::coalesce(heduc,  0L)),
      f_hmstat  = as.factor(dplyr::coalesce(hmstat, 1L)),
      hgender_n = dplyr::coalesce(as.integer(hgender), 1L),
      hage_n    = dplyr::coalesce(as.numeric(hage),
                                  median(as.numeric(hage), na.rm = TRUE)),
      hhsize_n  = dplyr::coalesce(as.numeric(hhsize),
                                  median(as.numeric(hhsize), na.rm = TRUE))
    )
}

# ── Fonction : fusion base individuelle ───────────────────────
# Résultat : une ligne par individu avec covariables ménage jointes

fusionner_individu <- function(ind, base_men, annee, col_age = "age") {
  ind |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels)) |>
    dplyr::mutate(age = as.integer(.data[[col_age]])) |>
    dplyr::left_join(base_men, by = ID_MEN) |>
    dplyr::mutate(annee = annee)
}

# ============================================================
#  VAGUE 1 — 2018-2019
# ============================================================

cat("\n>>> Chargement EHCVM 2018-2019 ...\n")

ind_2018    <- lire_stata(BASE_2018, "ehcvm_individu_sen2018.dta")
men_2018    <- lire_stata(BASE_2018, "ehcvm_menage_sen2018.dta")
wel_2018    <- lire_stata(BASE_2018, "ehcvm_welfare_sen2018.dta")
s13a1_2018  <- lire_stata(BASE_2018, "s13a_1_me_sen2018.dta")
s13a2_2018  <- lire_stata(BASE_2018, "s13a_2_me_sen2018.dta")

traitement_2018 <- construire_traitement(s13a1_2018, s13a2_2018,
                                         col_lieu = "s13aq14")

base_men_2018 <- fusionner_menage(men_2018, wel_2018, traitement_2018, 2018)
base_ind_2018 <- fusionner_individu(ind_2018, base_men_2018, 2018)

cat(sprintf("  Ménages 2018 : %d  |  Individus : %d  |  Traités : %d (%.1f%%)\n",
    nrow(base_men_2018),
    nrow(base_ind_2018),
    sum(base_men_2018$D == 1, na.rm = TRUE),
    100 * mean(base_men_2018$D == 1, na.rm = TRUE)))

saveRDS(base_men_2018, file.path(OUTPUT_DIR, "base_menage_2018.rds"))
saveRDS(base_ind_2018, file.path(OUTPUT_DIR, "base_individu_2018.rds"))

# ============================================================
#  VAGUE 2 — 2021-2022
# ============================================================

cat("\n>>> Chargement EHCVM 2021-2022 ...\n")

ind_2021    <- lire_stata(BASE_2021, "ehcvm_individu_sen2021.dta")
men_2021    <- lire_stata(BASE_2021, "ehcvm_menage_sen2021.dta")
wel_2021    <- lire_stata(BASE_2021, "ehcvm_welfare_sen2021.dta")
s13a1_2021  <- lire_stata(BASE_2021, "s13_1_me_sen2021.dta")
s13a2_2021  <- lire_stata(BASE_2021, "s13_2_me_sen2021.dta")

traitement_2021 <- construire_traitement(s13a1_2021, s13a2_2021,
                                         col_lieu = "s13q19")

base_men_2021 <- fusionner_menage(men_2021, wel_2021, traitement_2021, 2021)
base_ind_2021 <- fusionner_individu(ind_2021, base_men_2021, 2021)

cat(sprintf("  Ménages 2021 : %d  |  Individus : %d  |  Traités : %d (%.1f%%)\n",
    nrow(base_men_2021),
    nrow(base_ind_2021),
    sum(base_men_2021$D == 1, na.rm = TRUE),
    100 * mean(base_men_2021$D == 1, na.rm = TRUE)))

saveRDS(base_men_2021, file.path(OUTPUT_DIR, "base_menage_2021.rds"))
saveRDS(base_ind_2021, file.path(OUTPUT_DIR, "base_individu_2021.rds"))

# ============================================================
#  Vérifications de cohérence
# ============================================================

cat("\n>>> Vérifications ...\n")

# Taux de correspondance individu → ménage
for (annee in c(2018, 2021)) {
  base_ind <- if (annee == 2018) base_ind_2018 else base_ind_2021
  pct_match <- mean(!is.na(base_ind$pcexp)) * 100
  cat(sprintf("  %d : %.1f%% des individus ont une correspondance welfare\n",
              annee, pct_match))
}

# Doublons sur clé ménage
for (annee in c(2018, 2021)) {
  base_men <- if (annee == 2018) base_men_2018 else base_men_2021
  n_dup <- sum(duplicated(base_men[, ID_MEN]))
  if (n_dup > 0)
    warning(sprintf("  %d doublons sur clé ménage — %d", annee, n_dup))
  else
    cat(sprintf("  %d : aucun doublon sur clé ménage ✓\n", annee))
}

cat("\nFusion terminée. Fichiers sauvegardés dans", OUTPUT_DIR, "\n")
