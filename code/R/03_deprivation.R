# ============================================================
#  03_deprivation.R — Indicateurs de pauvrete multidimensionnelle
#
#  Approche 1 : Alkire-Foster (M0 = H x A, k = 1/3, 6 dimensions)
#  Approche 2 : N-MODA Senegal (ANSD/UNICEF 2024)
#              7 dimensions, k = 4, approche union intra-dimension
#
#  Reference : Dangeot et al. (2024), ANSD/UNICEF — EHCVM 2018/19
#
#  Variables EHCVM utilisees :
#   ehcvm_individu : age, scol, mal30j, con30j, activ7j,
#                    acte_nais, alfab, lien  [* A VERIFIER dans donnees]
#   ehcvm_menage   : eauboi_ss, eauboi_sp, tps_eau_ss, tps_eau_sp,
#                    toilet, partag_toi, ordure, nbpiec,
#                    combust, acces_sante,
#                    mur, toi, sol         [* A VERIFIER dans donnees]
#   ehcvm_welfare  : pcexp, hhsize, region, milieu
# ============================================================

source("code/R/config.R")
source("code/R/utils.R")

ind_2018 <- lire_stata(BASE_2018, "ehcvm_individu_sen2018.dta")
ind_2021 <- lire_stata(BASE_2021, "ehcvm_individu_sen2021.dta")
men_2018 <- lire_stata(BASE_2018, "ehcvm_menage_sen2018.dta")
men_2021 <- lire_stata(BASE_2021, "ehcvm_menage_sen2021.dta")
wel_2018 <- lire_stata(BASE_2018, "ehcvm_welfare_sen2018.dta")
wel_2021 <- lire_stata(BASE_2021, "ehcvm_welfare_sen2021.dta")

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
  dplyr::select(dplyr::all_of(c(ID, "hhsize"))) |>
  dplyr::mutate(hhsize = as.integer(haven::zap_labels(hhsize)))
wel_hhsize_2021 <- wel_2021 |>
  dplyr::select(dplyr::all_of(c(ID, "hhsize"))) |>
  dplyr::mutate(hhsize = as.integer(haven::zap_labels(hhsize)))

# ── Indicateurs menage — 7 dimensions N-MODA ─────────────────
#
# Dimension 1 : ASSAINISSEMENT
#   m_toilet    : type de sanitaire non ameliore
#                 toilet in {2,3,4,5,6} (latrines SANPLAT/dallees, fosse,
#                 toilettes publiques, aucune, autre)
#                 Codes OMS non-ameliores — a verifier selon modalites EHCVM
#   m_partag_toi: partage des toilettes avec d'autres menages
#                 Variable : partag_toi (1=oui) — A VERIFIER
#
# Dimension 2 : EAU
#   m_eau_source: source non amelioree en saison seche OU pluies
#                 eauboi_ss ou eauboi_sp in {5,6,12,13,16,17}
#   m_eau_temps : temps > 30 min pour chercher l'eau
#                 tps_eau_ss OU tps_eau_sp > 30 — A VERIFIER variable name
#
# Dimension 3 : LOGEMENT
#   m_ordures   : evacuation ordures inadequate
#                 ordure in {3,5,6} (brulees, depot sauvage, autre) — A VERIFIER
#   m_surpeup   : surpeuplement > 3 personnes par piece
#                 hhsize / nbpiec > 3 — nbpiec A VERIFIER
#
# Dimension 4 : NUTRITION
#   m_diversite : diversite alimentaire insuffisante (< 4 groupes alimentaires)
#                 Variable specifique EHCVM — A VERIFIER (possible: s14q*)
#   m_securite  : insecurite alimentaire (non-acces nourriture, saut repas, faim)
#                 Variable specifique EHCVM — A VERIFIER (possible: s14q*)
#
# Dimension 5 : SANTE
#   m_combust   : combustible solide (bois, charbon, dechets)
#                 combust in {1,2,3,4,5} selon codage EHCVM — A VERIFIER
#   m_acces_sante: pas d'acces a pied a structure de sante
#                 Variable communaute ou menage — A VERIFIER
#
# Dimension 6 : PROTECTION DE L'ENFANT
#   m_acte_nais : pas d'acte de naissance (0-4, 5-14)
#                 acte_nais == 0 — A VERIFIER
#   m_trav_enf  : travail economique ou domestique >= 1h (5-14 seulement)
#                 activ7j in {1,2} pour economique
#   m_parents   : ne vit pas avec 2 parents biologiques (tous groupes)
#                 derive de lien (lien avec CM) — A VERIFIER
#
# Dimension 7 : EDUCATION
#   m_scol      : non-scolarise (5-14)
#   m_alfab     : pas de capacite lecture/ecriture (15-17) — A VERIFIER
#   m_neet      : sans emploi ni etudes ni formation (15-17)

prep_menage_nmoda <- function(men, wel_hhsize) {
  men_z <- men |>
    dplyr::mutate(dplyr::across(where(haven::is.labelled), haven::zap_labels)) |>
    dplyr::left_join(wel_hhsize, by = ID)

  men_z |>
    dplyr::mutate(
      # ── Dimension 1 : Assainissement ────────────────────────
      # Type de sanitaire non ameliore
      # Codes non-ameliores : latrines SANPLAT (2), latrines dallees (3),
      # fosse rudimentaire (4), toilettes publiques (5), aucune (6), autre (7)
      m_toilet = dplyr::if_else(
        dplyr::coalesce(as.integer(toilet), 1L) %in% c(2L, 3L, 4L, 5L, 6L, 7L),
        1L, 0L
      ),
      # Partage des toilettes — A VERIFIER : variable "partag_toi" ou equivalent
      m_partag_toi = dplyr::if_else(
        var_ok(men_z, "partag_toi") &
        dplyr::coalesce(as.integer(if (var_ok(men_z, "partag_toi")) partag_toi else NA_integer_), 0L) == 1L,
        1L, 0L
      ),

      # ── Dimension 2 : Eau ───────────────────────────────────
      # Source non amelioree : codes {5,6,12,13,16,17} en seche OU pluies
      m_eau_source = dplyr::if_else(
        dplyr::coalesce(as.integer(eauboi_ss), 1L) %in% c(5L,6L,12L,13L,16L,17L) |
        dplyr::coalesce(as.integer(eauboi_sp), 1L) %in% c(5L,6L,12L,13L,16L,17L),
        1L, 0L
      ),
      # Temps > 30 min — A VERIFIER : tps_eau_ss / tps_eau_sp
      m_eau_temps = dplyr::if_else(
        (var_ok(men_z, "tps_eau_ss") &
           dplyr::coalesce(as.integer(if (var_ok(men_z, "tps_eau_ss")) tps_eau_ss else NA_integer_), 0L) > 30L) |
        (var_ok(men_z, "tps_eau_sp") &
           dplyr::coalesce(as.integer(if (var_ok(men_z, "tps_eau_sp")) tps_eau_sp else NA_integer_), 0L) > 30L),
        1L, 0L
      ),

      # ── Dimension 3 : Logement ──────────────────────────────
      # Evacuation ordures inadequate (codes 3=brulees, 5=depot sauvage, 6=autre)
      # A VERIFIER : variable "ordure" ou equivalent dans EHCVM
      m_ordures = dplyr::if_else(
        var_ok(men_z, "ordure") &
        dplyr::coalesce(as.integer(if (var_ok(men_z, "ordure")) ordure else NA_integer_), 1L) %in% c(3L,5L,6L),
        1L, 0L
      ),
      # Surpeuplement : > 3 personnes par piece
      # A VERIFIER : variable "nbpiec" (nombre de pieces) dans EHCVM
      m_surpeup = dplyr::if_else(
        var_ok(men_z, "nbpiec") &
        dplyr::coalesce(as.numeric(hhsize), 0) /
          pmax(dplyr::coalesce(as.numeric(if (var_ok(men_z, "nbpiec")) nbpiec else NA_real_), 1), 1) > 3,
        1L, 0L
      ),

      # ── Dimension 4 : Nutrition ─────────────────────────────
      # Diversite alimentaire < 4 groupes — A VERIFIER variable EHCVM
      m_diversite = dplyr::if_else(
        var_ok(men_z, "div_alim") &
        dplyr::coalesce(as.integer(if (var_ok(men_z, "div_alim")) div_alim else NA_integer_), 1L) == 0L,
        1L, 0L
      ),
      # Insecurite alimentaire — A VERIFIER variable EHCVM (module securite alim)
      m_securite = dplyr::if_else(
        var_ok(men_z, "insec_alim") &
        dplyr::coalesce(as.integer(if (var_ok(men_z, "insec_alim")) insec_alim else NA_integer_), 0L) == 1L,
        1L, 0L
      ),

      # ── Dimension 5 : Sante ─────────────────────────────────
      # Combustible solide (bois ramasse=1, bois achete=2, charbon=3,
      # dechets animaux=4, autre=5) — A VERIFIER codes dans EHCVM
      m_combust = dplyr::if_else(
        var_ok(men_z, "combust") &
        dplyr::coalesce(as.integer(if (var_ok(men_z, "combust")) combust else NA_integer_), 6L) %in% c(1L,2L,3L,4L,5L),
        1L, 0L
      ),
      # Acces a pied a structure de sante — A VERIFIER variable EHCVM
      m_acces_sante = dplyr::if_else(
        var_ok(men_z, "acces_sante") &
        dplyr::coalesce(as.integer(if (var_ok(men_z, "acces_sante")) acces_sante else NA_integer_), 1L) == 0L,
        1L, 0L
      )
    ) |>
    dplyr::mutate(
      # Union intra-dimension : prive si au moins 1 indicateur de la dimension
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

dep_men_2018 <- prep_menage_nmoda(men_2018, wel_hhsize_2018)
dep_men_2021 <- prep_menage_nmoda(men_2021, wel_hhsize_2021)

# ── Fusion enfants + menage ───────────────────────────────────

enfants_2018 <- enfants_2018 |> dplyr::left_join(dep_men_2018, by = ID)
enfants_2021 <- enfants_2021 |> dplyr::left_join(dep_men_2021, by = ID)

# ── Indicateurs individu — Protection et Education ───────────

construire_ind_nmoda <- function(df) {
  df |>
    dplyr::mutate(
      # ── Dimension 6 : Protection de l'enfant ────────────────
      # Acte de naissance (0-4, 5-14) — A VERIFIER : "acte_nais" dans EHCVM
      m_acte_nais = dplyr::if_else(
        age <= 14 & var_ok(df, "acte_nais") &
        dplyr::coalesce(as.integer(if (var_ok(df, "acte_nais")) acte_nais else NA_integer_), 1L) == 0L,
        1L, 0L
      ),
      # Travail economique ou domestique >= 1h (5-14 seulement)
      m_trav_enf = dplyr::if_else(
        age >= 5 & age <= 14 &
        dplyr::coalesce(as.integer(haven::zap_labels(activ7j)), 0L) %in% c(1L, 2L),
        1L, 0L
      ),
      # Ne vit pas avec 2 parents biologiques — A VERIFIER : derive de "lien"
      # lien == 1 (CM) ou presence pere ET mere dans menage
      m_parents = dplyr::if_else(
        var_ok(df, "lien") &
        dplyr::coalesce(as.integer(if (var_ok(df, "lien")) lien else NA_integer_), 99L) > 2L,
        1L, 0L
      ),

      # ── Dimension 7 : Education ─────────────────────────────
      # Non-scolarise (5-14 ans)
      m_scol = dplyr::if_else(
        age >= 5 & age <= 14 &
        dplyr::coalesce(as.integer(haven::zap_labels(scol)), 0L) == 0L,
        1L, 0L
      ),
      # Pas de capacite lecture/ecriture (15-17) — A VERIFIER : "alfab" dans EHCVM
      m_alfab = dplyr::if_else(
        age >= 15 & var_ok(df, "alfab") &
        dplyr::coalesce(as.integer(if (var_ok(df, "alfab")) alfab else NA_integer_), 1L) == 0L,
        1L, 0L
      ),
      # NEET (15-17) : sans emploi, pas d'etudes, pas de formation
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

enfants_2018 <- construire_ind_nmoda(enfants_2018)
enfants_2021 <- construire_ind_nmoda(enfants_2021)

# ── N-MODA : compte des privations par dimension (k = 4) ─────
# 7 dimensions : assai, eau, logem, nutri, sante, protect, educ
# Seuil : pauvre_MODA = 1 si nb_dim >= 4

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
for (annee in c(2018, 2021)) {
  df  <- if (annee == 2018) enfants_2018 else enfants_2021
  idx <- indices_af(df$nb_dep / 7)        # score ramene a [0,1] pour M0
  cat(sprintf("MODA %d : H=%.3f  A=%.3f  M0=%.3f\n", annee, idx$H, idx$A, idx$M0))
  cat("  Privation par dimension :\n")
  dims <- c("dim_assai","dim_eau","dim_logem","dim_nutri","dim_sante","dim_protect","dim_educ")
  noms <- c("Assainissement","Eau","Logement","Nutrition","Sante","Protection","Education")
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

cat("\n[ATTENTION] Variables a verifier dans vos donnees EHCVM :\n")
cat("  Menage : partag_toi, tps_eau_ss/sp, ordure, nbpiec,\n")
cat("           div_alim, insec_alim, combust, acces_sante\n")
cat("  Individu : acte_nais, lien, alfab\n")
cat("  Voir : names(men_2018) et names(ind_2018)\n")
