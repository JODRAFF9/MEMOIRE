# ============================================================
#  05_panel.R — Construction du panel vrai (PanelHH=1)
# ============================================================

source("code/R/config.R")
source("code/R/utils.R")

base_men_2018 <- readRDS(file.path(OUTPUT_DIR, "base_menage_2018.rds"))
base_men_2021 <- readRDS(file.path(OUTPUT_DIR, "base_menage_2021.rds"))
base_ind_2018 <- readRDS(file.path(OUTPUT_DIR, "base_individu_2018.rds"))
base_ind_2021 <- readRDS(file.path(OUTPUT_DIR, "base_individu_2021.rds"))

# Ménages suivis dans les deux vagues (PanelHH=1)
ids_panel <- base_men_2021 |>
  dplyr::filter(PanelHH == 1L) |>
  dplyr::select(hhid) |>
  dplyr::distinct()

cat(sprintf("Ménages panel (PanelHH=1) : %d sur %d (%.1f%%)\n",
    nrow(ids_panel), nrow(base_men_2021),
    100 * nrow(ids_panel) / nrow(base_men_2021)))

# Panel vrai ménages
panel_men_vrai <- dplyr::bind_rows(
  base_men_2018 |> dplyr::semi_join(ids_panel, by = "hhid"),
  base_men_2021 |> dplyr::semi_join(ids_panel, by = "hhid")
)

# Panel vrai enfants
panel_ind_vrai <- dplyr::bind_rows(
  base_ind_2018 |> dplyr::semi_join(ids_panel, by = "hhid"),
  base_ind_2021 |> dplyr::semi_join(ids_panel, by = "hhid")
)

# Panel complet (toutes vagues, tous ménages)
panel_men_complet <- dplyr::bind_rows(base_men_2018, base_men_2021)
panel_ind_complet <- dplyr::bind_rows(base_ind_2018, base_ind_2021)

saveRDS(panel_men_vrai,    file.path(OUTPUT_DIR, "panel_men_vrai.rds"))
saveRDS(panel_ind_vrai,    file.path(OUTPUT_DIR, "panel_ind_vrai.rds"))
saveRDS(panel_men_complet, file.path(OUTPUT_DIR, "panel_men_complet.rds"))
saveRDS(panel_ind_complet, file.path(OUTPUT_DIR, "panel_ind_complet.rds"))

cat("Panel vrai ménages   :", nrow(panel_men_vrai), "obs\n")
cat("Panel vrai enfants   :", nrow(panel_ind_vrai), "obs\n")
cat("Panel complet ménages:", nrow(panel_men_complet), "obs\n")
cat("Panel complet enfants:", nrow(panel_ind_complet), "obs\n")
cat("\nFichiers panel sauvegardés dans", OUTPUT_DIR, "\n")
