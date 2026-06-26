source("code/R/config.R")
source("code/R/utils.R")

codebook_base <- function(fichier) {
  df <- haven::read_dta(fichier)
  attrs <- lapply(df, function(col) {
    lbl <- attr(col, "labels")
    list(
      type    = class(col)[1],
      label   = attr(col, "label"),
      n_obs   = length(col),
      n_na    = sum(is.na(col)),
      n_vals  = dplyr::n_distinct(col, na.rm = TRUE),
      val_labels = if (!is.null(lbl) && length(lbl) <= 20)
                     paste(paste0(lbl, "=", names(lbl)), collapse = "; ")
                   else if (!is.null(lbl))
                     paste0("[", length(lbl), " modalites]")
                   else NA_character_
    )
  })
  cb <- dplyr::bind_rows(
    lapply(names(attrs), function(v) {
      a <- attrs[[v]]
      data.frame(
        variable    = v,
        type        = a$type,
        label       = a$label %||% NA_character_,
        n_obs       = a$n_obs,
        n_manquants = a$n_na,
        n_modalites = a$n_vals,
        modalites   = a$val_labels %||% NA_character_,
        stringsAsFactors = FALSE
      )
    })
  )
  cb
}

`%||%` <- function(a, b) if (!is.null(a)) a else b

produire_codebook <- function(dossier, pattern = "\\.dta$") {
  fichiers <- list.files(dossier, pattern = pattern,
                         full.names = TRUE, recursive = FALSE)
  if (length(fichiers) == 0) {
    cat("Aucun fichier .dta trouve dans", dossier, "\n")
    return(invisible(NULL))
  }
  cb_all <- lapply(fichiers, function(f) {
    cat("Lecture :", basename(f), "...\n")
    cb <- tryCatch(codebook_base(f), error = function(e) {
      cat("  ERREUR :", conditionMessage(e), "\n")
      NULL
    })
    if (!is.null(cb)) cb$fichier <- basename(f)
    cb
  })
  cb_all <- dplyr::bind_rows(Filter(Negate(is.null), cb_all))
  cb_all <- cb_all[, c("fichier", "variable", "type", "label",
                        "n_obs", "n_manquants", "n_modalites", "modalites")]
  cb_all
}

cb_2018 <- produire_codebook(BASE_2018)
cb_2021 <- produire_codebook(BASE_2021)

if (!is.null(cb_2018) && nrow(cb_2018) > 0) {
  out_2018 <- file.path(OUTPUT_DIR, "codebook_2018.csv")
  write.csv(cb_2018, out_2018, row.names = FALSE, fileEncoding = "UTF-8")
  cat("Codebook 2018 sauvegarde :", out_2018, "\n")
}
if (!is.null(cb_2021) && nrow(cb_2021) > 0) {
  out_2021 <- file.path(OUTPUT_DIR, "codebook_2021.csv")
  write.csv(cb_2021, out_2021, row.names = FALSE, fileEncoding = "UTF-8")
  cat("Codebook 2021 sauvegarde :", out_2021, "\n")
}

cat("\n=== Apercu codebook 2018 ===\n")
print(head(cb_2018, 20))
