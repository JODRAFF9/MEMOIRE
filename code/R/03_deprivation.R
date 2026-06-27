# ============================================================
#  03_deprivation.R — Indicateurs de pauvrete multidimensionnelle
#
#  Approche 1 : Alkire-Foster (M0 = H x A, k = 1/3, 6 indicateurs)
#  Approche 2 : N-MODA Senegal (ANSD/UNICEF 2024)
#              7 dimensions, k = 4, approche union intra-dimension
#
#  Reference : Dangeot et al. (2024), ANSD/UNICEF — EHCVM 2018/19
#
#  Variables EHCVM utilisees (verifiees dans codebooks 2018 et 2021) :
#
#  ehcvm_individu : age, scol, mal30j, con30j, activ7j, lien
#                   alfab (2018) / alfa (2021)
#  ehcvm_menage   : eauboi_ss, eauboi_sp (binaires : 0=non ameliore)
#                   toilet (0=non sain), ordure (0=non sain)
#  s11_me         : s11q02 (nb pieces), s11q29a/s11q28a (tps eau SS),
#                   s11q31a (tps eau SP, 2018 seulement),
#                   s11q56/s11q55 (partage toilettes 1=Oui),
#                   s11q53__1..7 (2018) / s11q52__1..7 (2021) (combustible)
#  s01_me         : s01q05 (acte naissance : 1=Oui, 2=Non)
#  ehcvm_welfare  : pcexp, hhsize, region, milieu
#
#  NON DISPONIBLES en variable harmonisee :
#   - div_alim (diversite alimentaire) — calculable depuis s14_me
#   - insec_alim (insecurite alimentaire) — calculable depuis s20_me
#   - acces_sante — module communaute uniquement
# ============================================================

source("code/R/config.R")
source("code/R/utils.R")

ind_2018 <- lire_stata(BASE_2018, "ehcvm_individu_sen2018.dta")
ind_2021 <- lire_stata(BASE_2021, "ehcvm_individu_sen2021.dta")
men_2018 <- lire_stata(BASE_2018, "ehcvm_menage_sen2018.dta")
men_2021 <- lire_stata(BASE_2021, "ehcvm_menage_sen2021.dta")
wel_2018 <- lire_stata(BASE_2018, "ehcvm_welfare_sen2018.dta")
wel_2021 <- lire_stata(BASE_2021, "ehcvm_welfare_sen2021.dta")

# Fichiers bruts section 11 (logement/habitat)
s11_2018 <- lire_stata(BASE_2018, "s11_me_sen2018.dta")
s11_2021 <- lire_stata(BASE_2021, "s11_me_sen2021.dta")

# Fichiers bruts section 1 (roster individuel — acte de naissance)
s01_2018 <- lire_stata(BASE_2018, "s01_me_sen2018.dta")
s01_2021 <- lire_stata(BASE_2021, "s01_me_sen2021.dta")

ID     <- c("grappe", "menage")
ID_IND <- c("grappe", "menage", "numind")

# ── Helper ───────────────────────────────────────────────────

zap_int <- function(x, na_val = 0L) {
  dplyr::coalesce(as.integer(haven::zap_labels(x)), na_val)
}

var_ok <- function(df, v) v %in% names(df)

# ── Enfants 0-17 ans ─────────────────────────────────────────

extraire_enfants <- function(ind, annee) {
  ind |>
    dplyr::filter(age >= 0, age <= 17) |>
    dplyr::mutate(
      annee = annee,
      age   = as.integer(haven::zap_labels(age)),
      groupe_moda = dplyr::case_when(
        age <= 4             ~ "0-4 ans",
        age >= 5 & age <= 14 ~ "5-14 ans",
        age >= 15            ~ "15-17 ans"
      )
    ) |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels))
}

enfants_2018 <- extraire_enfants(ind_2018, 2018)
enfants_2021 <- extraire_enfants(ind_2021, 2021)
cat("Enfants 2018 :", nrow(enfants_2018), "| 2021 :", nrow(enfants_2021), "\n")

# ── Taille ménage depuis welfare ──────────────────────────────

wel_hhsize_2018 <- wel_2018 |>
  ajouter_hhid() |>
  dplyr::select(dplyr::all_of(c("hhid", ID, "hhsize"))) |>
  dplyr::mutate(hhsize = as.integer(haven::zap_labels(hhsize)))
wel_hhsize_2021 <- wel_2021 |>
  ajouter_hhid() |>
  dplyr::select(dplyr::all_of(c("hhid", ID, "hhsize"))) |>
  dplyr::mutate(hhsize = as.integer(haven::zap_labels(hhsize)))

# ── Indicateurs menage — 7 dimensions N-MODA ─────────────────
#
# Dimensions 1-5 issues des fichiers menage (ehcvm_menage + s11_me) :
#
# Dim 1 ASSAINISSEMENT :
#   m_toilet    : toilet == 0 (non sain, binaire harmonise)
#   m_partag_toi: s11q56 == 1 (2018) / s11q55 == 1 (2021) (partage)
#
# Dim 2 EAU :
#   m_eau_source: eauboi_ss == 0 OU eauboi_sp == 0 (non amelioree, binaire)
#   m_eau_temps : s11q29a > 30 (2018) / s11q28a > 30 (2021) (min, saison seche)
#
# Dim 3 LOGEMENT :
#   m_ordures   : ordure == 0 (non sain, binaire harmonise)
#   m_surpeup   : hhsize / s11q02 > 3 (personnes par piece)
#
# Dim 4 NUTRITION (non disponible en variable harmonisee) :
#   m_diversite : non disponible — codee 0 (manque de donnees)
#   m_securite  : non disponible — codee 0 (manque de donnees)
#   [Calculable depuis s14_me (diversite) et s20_me (securite alim)]
#
# Dim 5 SANTE :
#   m_combust   : s11q53__1/2/3/7 >= 1 (2018) / s11q52__1/2/3/7 >= 1 (2021)
#                 (bois ramasse, bois achete, charbon, dechets animaux)
#   m_acces_sante: non disponible — codee 0 (module communaute seulement)

prep_s11 <- function(s11, annee) {
  s11_z <- s11 |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels))

  # Noms des variables qui different entre 2018 et 2021
  v_partag  <- if (annee == 2018) "s11q56"    else "s11q55"    # partage toilettes
  v_tps_ss  <- if (annee == 2018) "s11q29a"   else "s11q28a"   # temps eau saison seche
  v_comb_pf <- if (annee == 2018) "s11q53"    else "s11q52"    # prefixe combustible

  # Combustible solide : bois ramasse (__1), bois achete (__2),
  # charbon (__3), dechets animaux (__7) — 0=non, 1/2/3=oui (1er/2em/3em choix)
  comb_vars <- paste0(v_comb_pf, c("__1","__2","__3","__7"))
  comb_vars <- intersect(comb_vars, names(s11_z))
  m_combust_val <- if (length(comb_vars) > 0) {
    rowSums(s11_z[, comb_vars, drop = FALSE] >= 1, na.rm = TRUE) > 0
  } else {
    rep(FALSE, nrow(s11_z))
  }

  s11_z |>
    dplyr::mutate(
      m_partag_toi = dplyr::if_else(
        dplyr::coalesce(as.integer(.data[[v_partag]]), 2L) == 1L, 1L, 0L
      ),
      m_eau_temps = dplyr::if_else(
        dplyr::coalesce(as.numeric(.data[[v_tps_ss]]), 0) > 30, 1L, 0L
      ),
      m_surpeup_raw = dplyr::coalesce(as.numeric(s11q02), NA_real_),
      m_combust = as.integer(m_combust_val)
    ) |>
    dplyr::select(dplyr::all_of(ID),
                  m_partag_toi, m_eau_temps, m_surpeup_raw, m_combust)
}

s11_dep_2018 <- prep_s11(s11_2018, 2018)
s11_dep_2021 <- prep_s11(s11_2021, 2021)

# ── Acte de naissance depuis s01_me ──────────────────────────
# s01q05 : 1=Oui 2=Non (2018) / 1=Oui 2=Non 3=nc (2021)
# Cle individuelle : s01q00a (2018) / membres__id (2021) → renommee numind

prep_acte_nais <- function(s01, annee) {
  v_id <- if (annee == 2018) "s01q00a" else "membres__id"
  s01 |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels)) |>
    dplyr::rename(numind = dplyr::all_of(v_id)) |>
    dplyr::select(dplyr::all_of(c(ID_IND, "s01q05"))) |>
    dplyr::mutate(
      m_acte_nais = dplyr::if_else(
        dplyr::coalesce(as.integer(s01q05), 1L) == 2L, 1L, 0L
      )
    ) |>
    dplyr::select(dplyr::all_of(c(ID_IND, "m_acte_nais")))
}

acte_2018 <- prep_acte_nais(s01_2018, 2018)
acte_2021 <- prep_acte_nais(s01_2021, 2021)

# ── Construction indicateurs niveau menage ────────────────────

prep_menage_nmoda <- function(men, wel_hhsize, s11_dep) {
  men |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels)) |>
    dplyr::left_join(wel_hhsize, by = "hhid") |>
    dplyr::left_join(s11_dep, by = ID) |>
    dplyr::mutate(
      # ── Dimension 1 : Assainissement ────────────────────────
      # toilet : binaire harmonise 0=non sain 1=sain
      m_toilet = dplyr::if_else(
        dplyr::coalesce(as.integer(toilet), 0L) == 0L, 1L, 0L
      ),
      # m_partag_toi vient de s11_dep (deja calcule)

      # ── Dimension 2 : Eau ───────────────────────────────────
      # eauboi_ss / eauboi_sp : binaires 0=non ameliore 1=ameliore
      m_eau_source = dplyr::if_else(
        dplyr::coalesce(as.integer(eauboi_ss), 0L) == 0L |
        dplyr::coalesce(as.integer(eauboi_sp), 0L) == 0L,
        1L, 0L
      ),
      # m_eau_temps vient de s11_dep (deja calcule)

      # ── Dimension 3 : Logement ──────────────────────────────
      # ordure : binaire harmonise 0=non sain 1=sain
      m_ordures = dplyr::if_else(
        dplyr::coalesce(as.integer(ordure), 0L) == 0L, 1L, 0L
      ),
      # surpeuplement : hhsize / nbpiec > 3 (s11q02 = m_surpeup_raw)
      m_surpeup = dplyr::if_else(
        !is.na(m_surpeup_raw) & m_surpeup_raw > 0 &
        dplyr::coalesce(as.numeric(hhsize), 0) / m_surpeup_raw > 3,
        1L, 0L
      ),

      # ── Dimension 4 : Nutrition (non dispo en variable harmonisee) ──
      # div_alim et insec_alim requierent le calcul depuis s14_me / s20_me
      # Code a 0 par defaut (sous-estimation de cette dimension)
      m_diversite = 0L,
      m_securite  = 0L,

      # ── Dimension 5 : Sante ─────────────────────────────────
      # m_combust vient de s11_dep (combustible solide — deja calcule)
      # acces_sante non disponible dans fichiers men/ind
      m_acces_sante = 0L
    ) |>
    dplyr::mutate(
      # Union intra-dimension : prive si au moins 1 indicateur
      dim_assai = dplyr::if_else(m_toilet == 1L | m_partag_toi == 1L, 1L, 0L),
      dim_eau   = dplyr::if_else(m_eau_source == 1L | m_eau_temps == 1L, 1L, 0L),
      dim_logem = dplyr::if_else(m_ordures == 1L | m_surpeup == 1L, 1L, 0L),
      dim_nutri = dplyr::if_else(m_diversite == 1L | m_securite == 1L, 1L, 0L),
      dim_sante = dplyr::if_else(m_combust == 1L | m_acces_sante == 1L, 1L, 0L)
    ) |>
    dplyr::select(dplyr::all_of(ID),
                  m_toilet, m_partag_toi, m_eau_source, m_eau_temps,
                  m_ordures, m_surpeup, m_diversite, m_securite,
                  m_combust, m_acces_sante,
                  dim_assai, dim_eau, dim_logem, dim_nutri, dim_sante)
}

dep_men_2018 <- prep_menage_nmoda(men_2018, wel_hhsize_2018, s11_dep_2018)
dep_men_2021 <- prep_menage_nmoda(men_2021, wel_hhsize_2021, s11_dep_2021)

# ── Fusion enfants + menage ───────────────────────────────────

enfants_2018 <- enfants_2018 |> dplyr::left_join(dep_men_2018, by = ID)
enfants_2021 <- enfants_2021 |> dplyr::left_join(dep_men_2021, by = ID)

# ── Indicateurs individu — Protection et Education ───────────

construire_ind_nmoda <- function(df, acte_nais_df) {
  # Joindre acte de naissance depuis s01_me
  df <- df |> dplyr::left_join(acte_nais_df, by = ID_IND)

  # alfab : variable nommee "alfab" en 2018, "alfa" en 2021
  v_alfab <- if ("alfab" %in% names(df)) "alfab" else if ("alfa" %in% names(df)) "alfa" else NULL

  df |>
    dplyr::mutate(
      # ── Dimension 6 : Protection de l'enfant ────────────────
      # Acte de naissance (0-14 ans) — s01q05 : 1=Oui 2=Non
      # m_acte_nais deja calcule et joint (1 = prive = pas d'acte)
      m_acte_nais = dplyr::if_else(
        age <= 14,
        dplyr::coalesce(m_acte_nais, 0L),
        0L
      ),
      # Travail des enfants (5-14 ans) — activ7j : 1=occupe, 2=chomeur
      m_trav_enf = dplyr::if_else(
        age >= 5 & age <= 14 &
        dplyr::coalesce(as.integer(haven::zap_labels(activ7j)), 0L) %in% c(1L, 2L),
        1L, 0L
      ),
      # Separation parentale : ne vit pas avec au moins un parent biologique
      # lien : 3=fils/fille du CM → si lien != 3, suppose parent absent
      # Approximation : lien > 3 suggere absence d'au moins un parent
      m_parents = dplyr::if_else(
        dplyr::coalesce(as.integer(lien), 99L) > 3L,
        1L, 0L
      ),

      # ── Dimension 7 : Education ─────────────────────────────
      # Non-scolarise (5-14 ans) — scol : 0=Non 1=Oui
      m_scol = dplyr::if_else(
        age >= 5 & age <= 14 &
        dplyr::coalesce(as.integer(haven::zap_labels(scol)), 0L) == 0L,
        1L, 0L
      ),
      # Illettrisme (15-17 ans) — alfab/alfa : 0=Non 1=Oui
      m_alfab = if (!is.null(v_alfab)) {
        dplyr::if_else(
          age >= 15 &
          dplyr::coalesce(as.integer(.data[[v_alfab]]), 1L) == 0L,
          1L, 0L
        )
      } else {
        0L
      },
      # NEET (15-17 ans) : ni scolarise ni occupe
      m_neet = dplyr::if_else(
        age >= 15 &
        dplyr::coalesce(as.integer(haven::zap_labels(scol)), 0L) == 0L &
        dplyr::coalesce(as.integer(haven::zap_labels(activ7j)), 0L) == 0L,
        1L, 0L
      )
    ) |>
    dplyr::mutate(
      dim_protect = dplyr::case_when(
        age <= 4  ~ dplyr::if_else(m_acte_nais == 1L | m_parents == 1L, 1L, 0L),
        age <= 14 ~ dplyr::if_else(m_acte_nais == 1L | m_trav_enf == 1L | m_parents == 1L, 1L, 0L),
        TRUE      ~ dplyr::if_else(m_parents == 1L, 1L, 0L)
      ),
      dim_educ = dplyr::case_when(
        age < 5   ~ 0L,
        age <= 14 ~ m_scol,
        TRUE      ~ dplyr::if_else(m_alfab == 1L | m_neet == 1L, 1L, 0L)
      )
    )
}

enfants_2018 <- construire_ind_nmoda(enfants_2018, acte_2018)
enfants_2021 <- construire_ind_nmoda(enfants_2021, acte_2021)

# ── N-MODA : compte des privations par dimension (k = 4) ─────
# 7 dimensions : assai, eau, logem, nutri, sante, protect, educ
# Note : dim_nutri = 0 partout (donnees manquantes s14_me/s20_me)

construire_moda <- function(df) {
  df |>
    dplyr::rowwise() |>
    dplyr::mutate(
      nb_dep = sum(c(dim_assai, dim_eau, dim_logem, dim_nutri,
                     dim_sante, dim_protect, dim_educ), na.rm = TRUE),
      pauvre_MODA = as.integer(nb_dep >= K_MODA)
    ) |>
    dplyr::ungroup()
}

enfants_2018 <- construire_moda(enfants_2018)
enfants_2021 <- construire_moda(enfants_2021)

# ── Alkire-Foster (conserve pour comparaison) ─────────────────
# 6 indicateurs, poids egaux 1/6, seuil k = 1/3

construire_af <- function(df) {
  df |>
    dplyr::mutate(
      d1_educ  = dplyr::case_when(
        age < 6  ~ 0L,
        dplyr::coalesce(as.integer(scol), 0L) == 0L ~ 1L,
        TRUE ~ 0L
      ),
      d2_sante = dplyr::if_else(
        dplyr::coalesce(as.integer(mal30j), 0L) == 1L &
        dplyr::coalesce(as.integer(con30j), 1L) == 0L,
        1L, 0L
      ),
      d3_nutri = dplyr::if_else(age <= 4 & dplyr::coalesce(as.integer(mal30j), 0L) == 1L, 1L, 0L),
      d4_eau   = dplyr::coalesce(m_eau_source, 0L),
      d5_assai = dplyr::coalesce(m_toilet, 0L),
      d6_habit = dplyr::if_else(dim_logem == 1L, 1L, 0L)
    ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      score_dep = mean(c(d1_educ, d2_sante, d3_nutri, d4_eau, d5_assai, d6_habit), na.rm = TRUE),
      pauvre_AF = as.integer(score_dep >= K_SEUIL)
    ) |>
    dplyr::ungroup()
}

enfants_2018 <- construire_af(enfants_2018)
enfants_2021 <- construire_af(enfants_2021)

# ── Indices N-MODA (H, A, M0) ────────────────────────────────

cat("\n=== N-MODA (k=4, 7 dimensions) ===\n")
cat("[Note] dim_nutri codee 0 (variables s14_me/s20_me non harmonisees)\n\n")
for (annee in c(2018, 2021)) {
  df  <- if (annee == 2018) enfants_2018 else enfants_2021
  idx <- indices_af(df$nb_dep / 7)
  cat(sprintf("MODA %d : H=%.3f  A=%.3f  M0=%.3f\n", annee, idx$H, idx$A, idx$M0))
  cat("  Privation par dimension :\n")
  dims <- c("dim_assai","dim_eau","dim_logem","dim_nutri","dim_sante","dim_protect","dim_educ")
  noms <- c("Assainissement","Eau           ","Logement      ","Nutrition     ",
            "Sante         ","Protection    ","Education     ")
  for (i in seq_along(dims)) {
    cat(sprintf("    %-16s : %.1f%%\n", noms[i], taux(df[[dims[i]]]) * 100))
  }
}

# ── Indices Alkire-Foster ─────────────────────────────────────

cat("\n=== Alkire-Foster (k=1/3, 6 indicateurs) ===\n")
for (annee in c(2018, 2021)) {
  df  <- if (annee == 2018) enfants_2018 else enfants_2021
  idx <- indices_af(df$score_dep)
  cat(sprintf("AF %d : H=%.3f  A=%.3f  M0=%.3f\n", annee, idx$H, idx$A, idx$M0))
}

# ── Prevalence MODA par groupe d'age ─────────────────────────

cat("\n=== Prevalence N-MODA par groupe d'age ===\n")
for (annee in c(2018, 2021)) {
  df <- if (annee == 2018) enfants_2018 else enfants_2021
  cat(sprintf("\n%d :\n", annee))
  print(df |>
    dplyr::group_by(groupe_moda) |>
    dplyr::summarise(
      n            = dplyr::n(),
      pct_pauvre   = round(taux(pauvre_MODA) * 100, 1),
      nb_dim_moyen = round(taux(nb_dep), 2),
      .groups = "drop"))
}

# ── Sauvegarde ───────────────────────────────────────────────

saveRDS(enfants_2018, file.path(OUTPUT_DIR, "enfants_dep_2018.rds"))
saveRDS(enfants_2021, file.path(OUTPUT_DIR, "enfants_dep_2021.rds"))

cat("\n[INFO] Correspondance variables brutes EHCVM :\n")
cat("  Partage toilettes : s11q56 (2018) / s11q55 (2021)\n")
cat("  Temps eau saison seche : s11q29a (2018) / s11q28a (2021)\n")
cat("  Nb pieces : s11q02 (2018 et 2021)\n")
cat("  Combustible solide : s11q53__1/2/3/7 (2018) / s11q52__1/2/3/7 (2021)\n")
cat("  Acte de naissance : s01q05 dans s01_me (1=Oui 2=Non)\n")
cat("  Alphabetisation : alfab (2018) / alfa (2021) dans ehcvm_individu\n")
cat("  dim_nutri = 0 : a calculer depuis s14_me (div) et s20_me (securite)\n")
