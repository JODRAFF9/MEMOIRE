# ============================================================
#  main.py — Script maitre (executer dans l'ordre)
# ============================================================

import runpy

scripts = [
    "code/python/01_visitation.py",
    "code/python/02_traitement.py",
    "code/python/03_deprivation.py",
    "code/python/05_panel.py",
    "code/python/04_psm_dd.py",
]

for script in scripts:
    print(f"\n{'#'*60}\n  {script}\n{'#'*60}")
    runpy.run_path(script)
