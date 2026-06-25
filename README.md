# Mémoire de fin d'études — ENSAE Pierre Ndiaye

**Titre :** Impact des transferts de migrants sur la pauvreté multidimensionnelle des enfants au Sénégal

**Auteur :** Sié Rachid TRAORÉ — Élève Ingénieur Statisticien Économiste (ISE)

**Institution :** École Nationale de la Statistique et de l'Analyse Économique (ENSAE Pierre Ndiaye), Dakar

**Année académique :** 2025-2026

---

## Résumé

Ce mémoire analyse l'impact des transferts de fonds des migrants sur la pauvreté multidimensionnelle des enfants au Sénégal. La mesure de la pauvreté repose sur deux approches complémentaires : la méthode **Alkire-Foster** (IPM-Enfant) et l'approche **MODA** (Multiple Overlapping Deprivation Analysis) développée par l'UNICEF. La stratégie d'identification mobilise un estimateur **PSM-DD** (Appariement par score de propension combiné à la Double Différence), permettant de contrôler à la fois les biais de sélection observables et les effets fixes inobservables invariants dans le temps.

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
│   │   ├── conclusion.tex
│   │   ├── dedicace.tex
│   │   ├── remerciements.tex
│   │   ├── resume.tex
│   │   └── abstract.tex
│   ├── styles/
│   │   └── pagedeGarde.tex       # Page de garde ENSAE
│   └── annexes/
│       ├── annexe_A.tex
│       └── annexe_B.tex
│
├── Base/                         # Données EHCVM (non versionnées)
│   ├── 2018-2019/                # EHCVM I — SEN_2018_EHCVM_v02_M_Stata/
│   └── 2021-2022/                # EHCVM II — SEN_2021_EHCVM-2_v01_M_STATA14/
│
├── CodeStata.do                  # Script d'analyse Stata
├── CodeR.R                       # Script d'analyse R
├── CodeRmd.Rmd                   # Rapport R Markdown
└── memoires_ise_reference/       # Mémoires ISE de référence
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

> Deux passes `pdflatex` après `biber` sont nécessaires pour résoudre les références croisées et la bibliographie.

**Dépendances LaTeX :** `biblatex`, `biber`, `babel` (french), `geometry`, `fancyhdr`, `booktabs`, `longtable`, `multirow`, `tabularx`, `threeparttable`, `amsmath`, `hyperref`, `appendix`.

---

## Méthodologie

### Mesure de la pauvreté multidimensionnelle

| Approche | Référence | Groupes d'âge | Indicateurs |
|----------|-----------|---------------|-------------|
| Alkire-Foster (M0 = H × A) | Alkire & Foster (2011) | 0-17 ans | 6 indicateurs, seuil k = 1/3 |
| MODA (UNICEF) | De Neubourg et al. (2012) | 0-4 / 5-14 / 15-17 ans | Déprivations spécifiques par âge |

### Stratégie d'identification

- **PSM** : Probit sur les covariables observables → score de propension p(X)
- **DD** : Exploite la dimension temporelle EHCVM I/II (2018 → 2022)
- **PSM-DD** : Estimateur combiné (Heckman et al., 1997/1998) → contrôle biais observable + effets fixes

### Variable de traitement

Construite à partir de la **section S13A** de l'EHCVM :

- `s13aq04 = 1` : ménage ayant reçu des transferts monétaires
- `s13aq14` : lieu de résidence de l'expéditeur → filtre "Étranger" pour les transferts de migrants

```
D_i = 1  si le ménage a reçu au moins un transfert d'un expéditeur résidant à l'étranger
D_i = 0  sinon
```

---

## Données

Les fichiers de données brutes (EHCVM) ne sont pas versionnés dans ce dépôt (taille et confidentialité). Ils sont disponibles auprès de l'ANSD ou via le portail de la Banque Mondiale (MICRODATA).

---

## Contact

**Sié Rachid TRAORÉ** — sierachidtraore@gmail.com
