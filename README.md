# Mémoire de fin d'études — ENSAE Pierre Ndiaye

**Titre :** Impact des transferts de migrants sur la pauvreté multidimensionnelle des enfants au Sénégal

**Auteur :** Sié Rachid TRAORÉ — Élève Ingénieur Statisticien Économiste (ISE)

**Institution :** École Nationale de la Statistique et de l'Analyse Économique (ENSAE Pierre Ndiaye), Dakar

**Année académique :** 2025-2026

---

## Pipeline d'analyse

```mermaid
flowchart TD
    %% ── Données brutes ──────────────────────────────────────
    A1[(EHCVM I\n2018-2019)] --> B
    A2[(EHCVM II\n2021-2022)] --> B

    %% ── Étape 1 : Visitation ────────────────────────────────
    B[01_visitation\nExploration des bases]
    B --> C1[ehcvm_individu]
    B --> C2[ehcvm_menage]
    B --> C3[ehcvm_welfare]
    B --> C4[S13A — Transferts reçus]

    %% ── Étape 2 : Variable de traitement ────────────────────
    C4 --> D[02_traitement\nVariable D_i]
    D --> D1{"s13aq14 / s13q19\n≥ 4 ?"}
    D1 -->|Oui| D2[D = 1\nTransfert de migrant]
    D1 -->|Non| D3[D = 0\nPas de transfert étranger]

    %% ── Étape 3 : Indicateurs de déprivation ───────────────
    C1 --> E[03_deprivation\nEnfants 0-17 ans]

    E --> F1[Alkire-Foster\n6 indicateurs · k = 1/3]
    F1 --> F2[score_dep = Σ w·d_j]
    F2 --> F3[pauvre_AF = 1 si score ≥ k\nM0 = H × A]

    E --> G1[MODA UNICEF\n3 groupes d'âge]
    G1 --> G2[0-4 ans\nsanté · nutrition · eau\nassainissement · habitat]
    G1 --> G3[5-14 ans\néducation · santé · eau\nassainissement · habitat]
    G1 --> G4[15-17 ans\néducation · travail · eau\nassainissement · habitat]
    G2 & G3 & G4 --> G5[pauvre_MODA = 1 si nb_dep ≥ 2]

    %% ── Étape 4 : PSM-DD ────────────────────────────────────
    D2 & D3 --> H[04_psm_dd\nEstimation PSM-DD]
    F3 --> H
    G5 --> H

    H --> I1[Probit → score de propension p̂X]
    I1 --> I2[Vérification overlap\nrégion de support commun]
    I2 --> I3[Appariement\nk-NN k=4 · Kernel · Caliper]

    I3 --> J[Double Différence\nY_it = α + β·t + γ·D + δ·t×D + ε]
    J --> K[PSM-DD\nHeckman et al. 1997-1998]

    K --> L1[ATT — pauvre_AF]
    K --> L2[ATT — pauvre_MODA]

    %% ── Robustesse ──────────────────────────────────────────
    L1 & L2 --> M[Robustesse]
    M --> M1[Bootstrap\n1000 réplications]
    M --> M2[Bornes de Rosenbaum]
    M --> M3[Hétérogénéité\nmilieu · région · sexe chef]

    %% ── Styles ──────────────────────────────────────────────
    classDef data fill:#dbeafe,stroke:#3b82f6,color:#1e3a5f
    classDef step fill:#dcfce7,stroke:#22c55e,color:#14532d
    classDef result fill:#fef9c3,stroke:#eab308,color:#713f12
    classDef robust fill:#fce7f3,stroke:#ec4899,color:#701a47

    class A1,A2 data
    class B,D,E,H step
    class F3,G5,L1,L2 result
    class M,M1,M2,M3 robust
```

---

## Résumé

Ce mémoire analyse l'impact des transferts de fonds des migrants sur la pauvreté multidimensionnelle des enfants au Sénégal. La mesure de la pauvreté repose sur deux approches complémentaires : la méthode **Alkire-Foster** (IPM-Enfant) et l'approche **MODA** (Multiple Overlapping Deprivation Analysis) développée par l'UNICEF. La stratégie d'identification mobilise un estimateur **PSM-DD** (Heckman et al., 1997/1998), permettant de contrôler à la fois les biais de sélection observables et les effets fixes inobservables invariants dans le temps.

**Données :** EHCVM I (2018-2019) et EHCVM II (2021-2022) — Enquête Harmonisée sur les Conditions de Vie des Ménages, ANSD/Banque Mondiale.

---

## Structure du dépôt

```
MEMOIRE/
├── latex/                        # Source LaTeX du mémoire
│   ├── main.tex                  # Fichier principal (compiler avec pdflatex + biber)
│   ├── references.bib            # Bibliographie (BibLaTeX/APA)
│   ├── chapitres/                # Chapitres et pages liminaires
│   │   ├── introduction.tex
│   │   ├── chapitre1.tex         # Revue de littérature
│   │   ├── chapitre2.tex         # Méthodologie (AF, MODA, PSM-DD)
│   │   ├── chapitre3.tex         # Statistiques descriptives
│   │   ├── chapitre4.tex         # Résultats et discussion
│   │   └── conclusion.tex
│   ├── styles/pagedeGarde.tex
│   └── annexes/
│
├── code/
│   ├── R/
│   │   ├── config.R              # Chemins, packages, constantes
│   │   ├── utils.R               # Fonctions utilitaires
│   │   ├── 01_visitation.R       # Exploration des bases
│   │   ├── 02_traitement.R       # Variable D (transferts migrants)
│   │   ├── 03_deprivation.R      # Indicateurs AF + MODA
│   │   ├── 04_psm_dd.R           # Estimation PSM-DD
│   │   ├── main.R                # Script maître
│   │   └── rapport.Rmd           # Rapport interactif
│   ├── stata/
│   │   ├── config.do · utils.do
│   │   ├── 01_visitation.do … 04_psm_dd.do
│   │   └── main.do
│   └── python/
│       ├── config.py · utils.py
│       ├── 01_visitation.py … 04_psm_dd.py
│       └── main.py
│
└── Base/                         # Données EHCVM (non versionnées)
    ├── 2018-2019/
    └── 2021-2022/
```

---

## Compilation LaTeX

```bash
cd latex
pdflatex main.tex
biber main
pdflatex main.tex
pdflatex main.tex
```

---

## Méthodologie

### Mesure de la pauvreté multidimensionnelle

| Approche | Référence | Groupes d'âge | Indicateurs |
|----------|-----------|---------------|-------------|
| Alkire-Foster (M0 = H × A) | Alkire & Foster (2011) | 0-17 ans | 6 indicateurs, seuil k = 1/3 |
| MODA (UNICEF) | De Neubourg et al. (2012) | 0-4 / 5-14 / 15-17 ans | Déprivations spécifiques par âge |

### Variable de traitement

Construite à partir de la **section S13A** de l'EHCVM :

| Code `s13aq14` / `s13q19` | Lieu de résidence expéditeur | Traitement |
|---------------------------|------------------------------|-----------|
| 1 | Même ville/village | D = 0 |
| 2 | Même région | D = 0 |
| 3 | Ailleurs au pays | D = 0 |
| ≥ 4 | Pays étranger (Bénin, France, Espagne…) | **D = 1** |

---

## Données

Les fichiers de données brutes (EHCVM) ne sont pas versionnés dans ce dépôt. Disponibles auprès de l'ANSD ou via le portail Banque Mondiale (MICRODATA).

---

## Contact

**Sié Rachid TRAORÉ** — sierachidtraore@gmail.com
