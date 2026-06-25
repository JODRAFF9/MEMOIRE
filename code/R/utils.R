# ============================================================
#  utils.R — Fonctions utilitaires
# ============================================================

# Lecture fichier Stata
lire_stata <- function(base, fichier) {
  haven::read_dta(file.path(base, fichier))
}

# Resume rapide d'un data.frame
visiter <- function(df, nom = "") {
  cat("\n====", nom, "====\n")
  cat("Dimensions :", nrow(df), "x", ncol(df), "\n")
  print(skimr::skim(df))
}

# Taux avec NA
taux <- function(x) mean(x, na.rm = TRUE)

# Score de deprivation pondere (Alkire-Foster)
score_af <- function(df_dep, poids = NULL) {
  n <- ncol(df_dep)
  if (is.null(poids)) poids <- rep(1/n, n)
  as.vector(as.matrix(df_dep) %*% poids)
}

# Indicateurs M0, H, A
indices_af <- function(score, k = K_SEUIL) {
  pauvre <- as.integer(score >= k)
  H  <- taux(pauvre)
  A  <- taux(score[pauvre == 1])
  M0 <- H * A
  list(H = H, A = A, M0 = M0, pauvre = pauvre)
}

# Afficher prevalence
prevalence <- function(x, nom) {
  cat(sprintf("  %-35s : %.1f%%\n", nom, taux(x) * 100))
}
