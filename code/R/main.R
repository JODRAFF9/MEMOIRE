# ============================================================
#  main.R — Script maitre (executer dans l'ordre)
# ============================================================

source("code/R/00_fusion.R")        # 1. Fusion des bases brutes par année
source("code/R/01_visitation.R")    # 2. Exploration / statistiques descriptives
source("code/R/02_traitement.R")    # 3. Variable de traitement (D)
source("code/R/03_deprivation.R")   # 4. Indicateurs AF et MODA
source("code/R/05_panel.R")         # 5. Construction du panel vrai (PanelHH=1)
source("code/R/04_psm_dd.R")        # 6. Estimation PSM-DD
