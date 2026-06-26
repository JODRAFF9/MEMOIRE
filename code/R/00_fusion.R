# ============================================================
#  00_fusion.R — Fusion des bases EHCVM par année
#
#  Sources utilisées :
#    ehcvm_individu  : âge, scol, alfab, lien, mal30j, con30j, activ7j, ...
#    ehcvm_menage    : toilet, eva_toi, eauboi_ss/sp, ordure, mur, toit, sol
#    ehcvm_welfare   : hhid, hhsize, pcexp, region, milieu, CM vars
#    s05_me          : s05q02 (nb pièces), s05q10 (partage toilettes),
#                      s05q14 (temps aller eau en minutes)
#    s01_me          : s01q19 (acte de naissance — 1=oui)
#    s13a_1 + s13a_2 : variable traitement D (transfert de l'étranger)
#
#  Clé principale : hhid
#    - ehcvm_menage, ehcvm_welfare ont hhid directement
#    - ehcvm_individu, s05, s13 ont grappe+menage → hhid = grappe*1000+menage
#    - s01_me a grappe+menage+numind
#
#  Sorties :
#    output/base_menage_2018.rds / base_menage_2021.rds
#    output/base_individu_2018.rds / base_individu_2021.rds
# ============================================================

source("code/R/config.R")
source("code/R/utils.R")

# ── Utilitaires clé de jointure ───────────────────────────────

ajouter_hhid <- function(df) {
  if (!"hhid" %in% names(df) && all(c("grappe", "menage") %in% names(df)))
    df <- dplyr::mutate(df, hhid = as.integer(grappe) * 1000L + as.integer(menage))
  df
}

# ── Fonction : variable traitement D ─────────────────────────

construire_traitement <- function(s13a1, s13a2, col_lieu) {
  s13a1 <- ajouter_hhid(s13a1)
  s13a2 <- ajouter_hhid(s13a2)

  etrangers <- s13a2 |>
    dplyr::filter(.data[[col_lieu]] >= CODE_ETRANGER_MIN) |>
    dplyr::distinct(hhid) |>
    dplyr::mutate(transfert_migrant = 1L)

  s13a1 |>
    dplyr::select(hhid) |>
    dplyr::distinct() |>
    dplyr::left_join(etrangers, by = "hhid") |>
    dplyr::mutate(D = dplyr::coalesce(transfert_migrant, 0L)) |>
    dplyr::select(hhid, D)
}

# ── Fonction : indicateurs ménage (MODA) ──────────────────────
# Indicateurs binaires privation (1 = privé)
#
# Assainissement
#   dep_assai_type  : type de sanitaire non sain     → toilet = 0
#   dep_assai_part  : partage des toilettes           → s05q10 = 1
# Eau
#   dep_eau_source  : source non améliorée            → eauboi_ss=0 OU eauboi_sp=0
#   dep_eau_temps   : temps aller chercher eau > 30mn → s05q14 > 30
# Logement
#   dep_log_ordure  : débarras ordures non sain       → ordure = 0
#   dep_log_surp    : surpeuplement (> 3 pers/pièce)  → hhsize / s05q02 > 3

prep_deprivation_menage <- function(men, s05, welfare) {
  men   <- ajouter_hhid(men)
  s05   <- ajouter_hhid(s05) |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels)) |>
    dplyr::select(hhid,
                  nb_pieces   = dplyr::any_of("s05q02"),
                  part_toi    = dplyr::any_of("s05q10"),
                  temps_eau   = dplyr::any_of("s05q14"))
  welfare <- ajouter_hhid(welfare) |>
    dplyr::select(hhid, hhsize)

  men |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels)) |>
    dplyr::left_join(s05,    by = "hhid") |>
    dplyr::left_join(welfare |> dplyr::select(hhid, hhsize), by = "hhid") |>
    dplyr::mutate(
      dep_assai_type = dplyr::if_else(
        dplyr::coalesce(as.integer(toilet), 1L) == 0L, 1L, 0L),
      dep_assai_part = dplyr::if_else(
        dplyr::coalesce(as.integer(part_toi), 0L) == 1L, 1L, 0L),
      dep_eau_source = dplyr::if_else(
        dplyr::coalesce(as.integer(eauboi_ss), 0L) == 0L |
        dplyr::coalesce(as.integer(eauboi_sp), 0L) == 0L, 1L, 0L),
      dep_eau_temps  = dplyr::if_else(
        dplyr::coalesce(as.numeric(temps_eau), 0) > 30, 1L, 0L),
      dep_log_ordure = dplyr::if_else(
        dplyr::coalesce(as.integer(ordure), 1L) == 0L, 1L, 0L),
      dep_log_surp   = dplyr::if_else(
        !is.na(nb_pieces) & nb_pieces > 0 &
        dplyr::coalesce(as.numeric(hhsize), 1) / as.numeric(nb_pieces) > 3,
        1L, 0L)
    ) |>
    dplyr::select(hhid, dep_assai_type, dep_assai_part,
                  dep_eau_source, dep_eau_temps,
                  dep_log_ordure, dep_log_surp)
}

# ── Fonction : indicateurs individu (MODA) ────────────────────
# dep_sante     : malade non-consulté (con30j=0 quand mal30j=1)
# dep_naissance : pas d'acte de naissance (s01q19 ≠ 1)
# dep_parents   : enfant ne vivant pas avec ses parents (lien ∉ {3,4,5})
# dep_travail   : enfant au travail éco. ou dom. (activ7j ∈ {1,2,3,4}, âge 5-14)
# dep_alfab     : non alphabétisé (alfab=0, 15-17 ans)
# dep_scol      : non-scolarisé (scol=0, 5-14 ans)
# dep_nutri     : proxy sécurité alimentaire (calculé dans 03_deprivation.R)

prep_deprivation_individu <- function(ind, s01) {
  s01 <- ajouter_hhid(s01) |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels))

  # Clé individu : grappe + menage + numind (= s01q00a dans s01_me)
  id_ind_s01 <- intersect(c("hhid", "numind", "s01q00a"), names(s01))
  if ("s01q00a" %in% names(s01) && !"numind" %in% names(s01))
    s01 <- dplyr::rename(s01, numind = s01q00a)

  s01_acte <- s01 |>
    dplyr::select(hhid, numind,
                  acte_naissance = dplyr::any_of("s01q19"))

  ind <- ajouter_hhid(ind) |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels))

  ind |>
    dplyr::left_join(s01_acte, by = c("hhid", "numind")) |>
    dplyr::mutate(
      dep_sante     = dplyr::if_else(
        dplyr::coalesce(as.integer(mal30j), 0L) == 1L &
        dplyr::coalesce(as.integer(con30j), 1L) == 0L, 1L, 0L),
      dep_naissance = dplyr::if_else(
        dplyr::coalesce(as.integer(acte_naissance), 0L) != 1L, 1L, 0L),
      dep_parents   = dplyr::if_else(
        !dplyr::coalesce(as.integer(lien), 0L) %in% c(1L, 2L, 3L, 4L, 5L),
        1L, 0L),
      dep_travail   = dplyr::if_else(
        dplyr::coalesce(as.integer(activ7j), 5L) %in% c(1L, 2L, 3L, 4L),
        1L, 0L),
      dep_alfab     = dplyr::if_else(
        dplyr::coalesce(as.integer(alfab), 1L) == 0L, 1L, 0L),
      dep_scol      = dplyr::if_else(
        dplyr::coalesce(as.integer(scol), 1L) == 0L, 1L, 0L)
    )
}

# ── Fonction : fusion base ménage ─────────────────────────────

fusionner_menage <- function(men, s05, wel, traitement, annee) {
  VARS_WEL <- c("pcexp", "hhsize", "region", "milieu",
                "hgender", "hage", "heduc", "hmstat")

  dep_men <- prep_deprivation_menage(men, s05, wel)

  wel <- ajouter_hhid(wel)
  vars_dispo <- intersect(c("hhid", VARS_WEL), names(wel))
  wel_sel <- wel |>
    dplyr::select(dplyr::all_of(vars_dispo)) |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels))

  dep_men |>
    dplyr::left_join(wel_sel,    by = "hhid") |>
    dplyr::left_join(traitement, by = "hhid") |>
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

fusionner_individu <- function(ind, s01, base_men, annee, col_age = "age") {
  ind_dep <- prep_deprivation_individu(ind, s01)
  ind_dep |>
    dplyr::mutate(age = as.integer(.data[[col_age]])) |>
    dplyr::left_join(base_men, by = "hhid") |>
    dplyr::mutate(annee = annee)
}

# ============================================================
#  VAGUE 1 — 2018-2019
# ============================================================

cat("\n>>> Chargement EHCVM 2018-2019 ...\n")

ind_2018   <- lire_stata(BASE_2018, "ehcvm_individu_sen2018.dta")
men_2018   <- lire_stata(BASE_2018, "ehcvm_menage_sen2018.dta")
wel_2018   <- lire_stata(BASE_2018, "ehcvm_welfare_sen2018.dta")
s05_2018   <- lire_stata(BASE_2018, "s05_me_sen2018.dta")
s01_2018   <- lire_stata(BASE_2018, "s01_me_sen2018.dta")
s13a1_2018 <- lire_stata(BASE_2018, "s13a_1_me_sen2018.dta")
s13a2_2018 <- lire_stata(BASE_2018, "s13a_2_me_sen2018.dta")

traitement_2018 <- construire_traitement(s13a1_2018, s13a2_2018, col_lieu = "s13aq14")
base_men_2018   <- fusionner_menage(men_2018, s05_2018, wel_2018, traitement_2018, 2018)
base_ind_2018   <- fusionner_individu(ind_2018, s01_2018, base_men_2018, 2018)

cat(sprintf("  Ménages 2018 : %d  |  Individus : %d  |  Traités : %d (%.1f%%)\n",
    nrow(base_men_2018), nrow(base_ind_2018),
    sum(base_men_2018$D == 1, na.rm = TRUE),
    100 * mean(base_men_2018$D == 1, na.rm = TRUE)))

saveRDS(base_men_2018, file.path(OUTPUT_DIR, "base_menage_2018.rds"))
saveRDS(base_ind_2018, file.path(OUTPUT_DIR, "base_individu_2018.rds"))

# ============================================================
#  VAGUE 2 — 2021-2022
# ============================================================

cat("\n>>> Chargement EHCVM 2021-2022 ...\n")

ind_2021   <- lire_stata(BASE_2021, "ehcvm_individu_sen2021.dta")
men_2021   <- lire_stata(BASE_2021, "ehcvm_menage_sen2021.dta")
wel_2021   <- lire_stata(BASE_2021, "ehcvm_welfare_sen2021.dta")
s05_2021   <- lire_stata(BASE_2021, "s05_me_sen2021.dta")
s01_2021   <- lire_stata(BASE_2021, "s01_me_sen2021.dta")
s13a1_2021 <- lire_stata(BASE_2021, "s13_1_me_sen2021.dta")
s13a2_2021 <- lire_stata(BASE_2021, "s13_2_me_sen2021.dta")

traitement_2021 <- construire_traitement(s13a1_2021, s13a2_2021, col_lieu = "s13q19")
base_men_2021   <- fusionner_menage(men_2021, s05_2021, wel_2021, traitement_2021, 2021)
base_ind_2021   <- fusionner_individu(ind_2021, s01_2021, base_men_2021, 2021)

cat(sprintf("  Ménages 2021 : %d  |  Individus : %d  |  Traités : %d (%.1f%%)\n",
    nrow(base_men_2021), nrow(base_ind_2021),
    sum(base_men_2021$D == 1, na.rm = TRUE),
    100 * mean(base_men_2021$D == 1, na.rm = TRUE)))

saveRDS(base_men_2021, file.path(OUTPUT_DIR, "base_menage_2021.rds"))
saveRDS(base_ind_2021, file.path(OUTPUT_DIR, "base_individu_2021.rds"))

# ── Vérifications ─────────────────────────────────────────────

cat("\n>>> Vérifications ...\n")
for (annee in c(2018, 2021)) {
  base_ind <- if (annee == 2018) base_ind_2018 else base_ind_2021
  pct <- mean(!is.na(base_ind$pcexp)) * 100
  cat(sprintf("  %d : %.1f%% des individus ont une correspondance welfare\n", annee, pct))
}
for (annee in c(2018, 2021)) {
  base_men <- if (annee == 2018) base_men_2018 else base_men_2021
  n_dup <- sum(duplicated(base_men$hhid))
  if (n_dup > 0) warning(sprintf("%d doublons hhid — %d", annee, n_dup))
  else cat(sprintf("  %d : aucun doublon hhid ✓\n", annee))
}
cat("\nFusion terminée. Fichiers sauvegardés dans", OUTPUT_DIR, "\n")
