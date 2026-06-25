# ============================================================
#  02_traitement.R — Construction de la variable de traitement
#  D_i = 1 si menage a recu un transfert de l'etranger
# ============================================================

source("code/R/config.R")
source("code/R/utils.R")

s13a1_2018 <- lire_stata(BASE_2018, "s13a_1_me_sen2018.dta")
s13a2_2018 <- lire_stata(BASE_2018, "s13a_2_me_sen2018.dta")
s13a1_2021 <- lire_stata(BASE_2021, "s13_1_me_sen2021.dta")
s13a2_2021 <- lire_stata(BASE_2021, "s13_2_me_sen2021.dta")

ID <- c("grappe", "menage")

construire_traitement <- function(s13a1, s13a2, code_etr = CODE_ETRANGER) {
  etrangers <- s13a2 |>
    dplyr::filter(s13aq14 == code_etr) |>
    dplyr::distinct(across(all_of(ID))) |>
    dplyr::mutate(transfert_migrant = 1L)

  s13a1 |>
    dplyr::left_join(etrangers, by = ID) |>
    dplyr::mutate(D = dplyr::coalesce(transfert_migrant, 0L))
}

traitement_2018 <- construire_traitement(s13a1_2018, s13a2_2018)
traitement_2021 <- construire_traitement(s13a1_2021, s13a2_2021)

cat("\n>>> Prevalence des transferts de migrants :\n")
prevalence(traitement_2018$D, "2018-2019")
prevalence(traitement_2021$D, "2021-2022")

saveRDS(traitement_2018, file.path(OUTPUT_DIR, "traitement_2018.rds"))
saveRDS(traitement_2021, file.path(OUTPUT_DIR, "traitement_2021.rds"))
