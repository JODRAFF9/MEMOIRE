# ============================================================
#  00_pipeline_map.R — Carte visuelle du pipeline d'analyse
#  Necessite : DiagrammeR, htmlwidgets, webshot2
# ============================================================

source("code/R/config.R")

if (!requireNamespace("DiagrammeR", quietly = TRUE)) install.packages("DiagrammeR")
if (!requireNamespace("htmlwidgets", quietly = TRUE)) install.packages("htmlwidgets")
library(DiagrammeR)
library(htmlwidgets)

pipeline <- DiagrammeR::grViz('
digraph pipeline {

  graph [rankdir=TB, fontname="Helvetica", splines=ortho, nodesep=0.4, ranksep=0.55]
  node  [fontname="Helvetica", fontsize=10, style=filled, shape=box, margin="0.15,0.08"]
  edge  [color="#64748b", arrowsize=0.8]

  // ── Données ─────────────────────────────────────────────
  subgraph cluster_data {
    label="Données brutes EHCVM"
    style=filled; fillcolor="#eff6ff"; color="#3b82f6"
    EHCVM1 [label="EHCVM I (2018-2019)\nindividu · menage · welfare · S13A",
             fillcolor="#dbeafe", color="#3b82f6"]
    EHCVM2 [label="EHCVM II (2021-2022)\nindividu · menage · welfare · S13",
             fillcolor="#dbeafe", color="#3b82f6"]
  }

  // ── Étape 1 : Visitation ────────────────────────────────
  VISIT [label="01_visitation\nExploration & audit qualité",
         fillcolor="#dcfce7", color="#16a34a", fontcolor="#14532d", penwidth=2]

  // ── Étape 2 : Traitement ────────────────────────────────
  TRAIT [label="02_traitement — Variable D_i\ns13aq14 / s13q19 ≥ 4  →  D = 1 (étranger)\ns13aq14 / s13q19 ≤ 3  →  D = 0 (Sénégal)",
         fillcolor="#dcfce7", color="#16a34a", fontcolor="#14532d", penwidth=2]

  // ── Étape 3 : Déprivation ───────────────────────────────
  DEP [label="03_deprivation — Enfants 0-17 ans",
       fillcolor="#dcfce7", color="#16a34a", fontcolor="#14532d", penwidth=2]

  AF [label="Alkire-Foster\n6 indicateurs · k = 1/3\nscore_dep = Σ wⱼ·dⱼ\npauvre_AF = 1 si score ≥ k\nM0 = H × A",
      fillcolor="#fef9c3", color="#ca8a04"]

  MODA [label="MODA UNICEF\n0-4 ans : santé · nutrition · eau · assaini. · habitat\n5-14 ans : éduc. · santé · eau · assaini. · habitat\n15-17 ans : éduc. · travail · eau · assaini. · habitat\npauvre_MODA = 1 si nb_dep ≥ 2",
        fillcolor="#fef9c3", color="#ca8a04"]

  // ── Étape 4 : PSM-DD ────────────────────────────────────
  PSMDد [label="04_psm_dd — PSM-DD (Heckman et al. 1997/1998)",
          fillcolor="#dcfce7", color="#16a34a", fontcolor="#14532d", penwidth=2]

  PSM  [label="PSM — Score de propension\nProbit : D ~ X  →  p̂(X) = Φ(Xβ)\nVérification overlap",
        fillcolor="#fef9c3", color="#ca8a04"]

  MATCH [label="Appariement\nk-NN (k=4) · Kernel · Caliper",
         fillcolor="#fef9c3", color="#ca8a04"]

  DD   [label="Double Différence\nY_it = α + β·t + γ·D + δ·(t×D) + ε",
        fillcolor="#fef9c3", color="#ca8a04"]

  PSMDD [label="PSM-DD : ATT\nE[ΔY | D=1] − Σ wᵢⱼ E[ΔY | D=0]",
         fillcolor="#fef9c3", color="#ca8a04", penwidth=2]

  // ── Résultats ────────────────────────────────────────────
  ATT_AF   [label="ATT — pauvre_AF\nImpact sur M0 Alkire-Foster",
             fillcolor="#fef9c3", color="#ca8a04", penwidth=2]
  ATT_MODA [label="ATT — pauvre_MODA\nImpact sur déprivations MODA",
             fillcolor="#fef9c3", color="#ca8a04", penwidth=2]

  // ── Robustesse ───────────────────────────────────────────
  BOOT  [label="Bootstrap\n1 000 réplications", fillcolor="#fce7f3", color="#db2777"]
  ROSEN [label="Bornes de Rosenbaum\nsensibilité aux biais cachés", fillcolor="#fce7f3", color="#db2777"]
  HETER [label="Hétérogénéité\nmilieu · région · sexe chef", fillcolor="#fce7f3", color="#db2777"]

  // ── Flèches ──────────────────────────────────────────────
  EHCVM1 -> VISIT
  EHCVM2 -> VISIT
  VISIT  -> TRAIT
  VISIT  -> DEP
  TRAIT  -> PSMDد
  DEP    -> AF
  DEP    -> MODA
  AF     -> PSMDد
  MODA   -> PSMDد
  PSMDد  -> PSM
  PSM    -> MATCH
  MATCH  -> DD
  DD     -> PSMDD
  PSMDD  -> ATT_AF
  PSMDD  -> ATT_MODA
  ATT_AF   -> BOOT
  ATT_AF   -> ROSEN
  ATT_AF   -> HETER
  ATT_MODA -> BOOT
  ATT_MODA -> ROSEN
  ATT_MODA -> HETER
}
')

# Afficher dans le viewer RStudio
print(pipeline)

# Sauvegarder en HTML
out_html <- file.path(OUTPUT_DIR, "pipeline.html")
htmlwidgets::saveWidget(pipeline, out_html, selfcontained = TRUE)
cat("Pipeline sauvegarde :", out_html, "\n")

# Export PNG si webshot2 disponible
if (requireNamespace("webshot2", quietly = TRUE)) {
  out_png <- file.path(OUTPUT_DIR, "pipeline.png")
  webshot2::webshot(out_html, out_png, vwidth = 1200, vheight = 900)
  cat("Pipeline PNG :", out_png, "\n")
}
