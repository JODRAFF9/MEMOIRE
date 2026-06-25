# ============================================================
#  02_traitement.R — Construction de la variable de traitement
#  D_i = 1 si menage a recu un transfert de l'etranger
#
#  s13aq14 / s13q19 : lieu de residence de l'expediteur
#    1 = Meme ville/village
#    2 = Meme region
#    3 = Ailleurs au pays (interieur Senegal)
#   >= 4 = pays etranger (Benin, Burkina, France, Espagne, etc.)
# ============================================================

source("code/R/config.R")
source("code/R/utils.R")

s13a1_2018 <- lire_stata(BASE_2018, "s13a_1_me_sen2018.dta")
s13a2_2018 <- lire_stata(BASE_2018, "s13a_2_me_sen2018.dta")
s13a1_2021 <- lire_stata(BASE_2021, "s13_1_me_sen2021.dta")
s13a2_2021 <- lire_stata(BASE_2021, "s13_2_me_sen2021.dta")

ID <- c("grappe", "menage")

# col_lieu : variable "lieu de residence de l'expediteur"
#   2018 -> s13aq14  |  2021 -> s13q19
# code_etr_min : seuil a partir duquel le lieu est a l'etranger (>= 4)
construire_traitement <- function(s13a1, s13a2, col_lieu,
                                  code_etr_min = CODE_ETRANGER_MIN) {
  etrangers <- s13a2 |>
    dplyr::filter(.data[[col_lieu]] >= code_etr_min) |>
    dplyr::distinct(across(all_of(ID))) |>
    dplyr::mutate(transfert_migrant = 1L)

  s13a1 |>
    dplyr::left_join(etrangers, by = ID) |>
    dplyr::mutate(D = dplyr::coalesce(transfert_migrant, 0L))
}

traitement_2018 <- construire_traitement(s13a1_2018, s13a2_2018, col_lieu = "s13aq14")
traitement_2021 <- construire_traitement(s13a1_2021, s13a2_2021, col_lieu = "s13q19")

cat("\n>>> Prevalence des transferts de migrants :\n")
prevalence(traitement_2018$D, "2018-2019")
prevalence(traitement_2021$D, "2021-2022")

saveRDS(traitement_2018, file.path(OUTPUT_DIR, "traitement_2018.rds"))
saveRDS(traitement_2021, file.path(OUTPUT_DIR, "traitement_2021.rds"))
