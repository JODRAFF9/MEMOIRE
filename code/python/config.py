# ============================================================
#  config.py — Chemins, constantes et imports
# ============================================================

from pathlib import Path

BASE_2018 = Path("Base/2018-2019/SEN_2018_EHCVM_v02_M_Stata")
BASE_2021 = Path("Base/2021-2022/SEN_2021_EHCVM-2_v01_M_STATA14")

OUTPUT_DIR = Path("code/python/output")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

SEED          = 123
K_SEUIL       = 1/3    # seuil Alkire-Foster
N_BOOT        = 1000   # replications bootstrap
CODE_ETRANGER = 3      # modalite s13aq14 = "Etranger" (a confirmer)

ID = ["grappe", "menage"]
