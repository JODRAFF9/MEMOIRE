# ============================================================
#  config.R — Chemins, constantes et packages
# ============================================================

BASE_2018 <- "Base/2018-2019/SEN_2018_EHCVM_v02_M_Stata"
BASE_2021 <- "Base/2021-2022/SEN_2021_EHCVM-2_v01_M_STATA14"

OUTPUT_DIR <- "code/R/output"
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

SEED          <- 123
K_SEUIL       <- 1/3    # seuil Alkire-Foster
K_MODA        <- 4L     # seuil N-MODA : prive si >= 4 dimensions sur 7 (ANSD/UNICEF 2024)
N_BOOT        <- 1000   # replications bootstrap
CALIPER      <- 0.05
K_VOISINS    <- 4L
# s13aq14 / s13q19 : lieu de residence de l'expediteur
# 1 = Meme ville/village  |  2 = Meme region  |  3 = Ailleurs au pays
# >= 4 = pays etranger (Benin, Burkina, France, Espagne, Italie, etc.)
CODE_ETRANGER_MIN <- 4L  # transferts de migrants = code >= 4

packages <- c(
  "haven",       # lecture .dta
  "dplyr",       # manipulation
  "tidyr",       # reshape
  "ggplot2",     # visualisation
  "MatchIt",     # PSM
  "cobalt",      # bilan appariement
  "sandwich",    # erreurs robustes
  "lmtest",      # tests
  "stargazer",   # tables resultats
  "kableExtra",  # tables PDF/HTML
  "skimr"        # stats descriptives
)

installed <- rownames(installed.packages())
to_install <- packages[!packages %in% installed]
if (length(to_install)) install.packages(to_install)
invisible(lapply(packages, library, character.only = TRUE))

set.seed(SEED)
