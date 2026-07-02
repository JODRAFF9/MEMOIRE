# Compilation du mémoire

## Le point essentiel : la bibliographie exige **biber**

Le document utilise `biblatex` avec le style APA, qui impose le moteur
**biber** (et non l'ancien `bibtex`). Si biber n'est jamais lancé, le PDF
compile mais la section « Références bibliographiques » reste vide.

## Trois façons de compiler

### 1. Windows, sans configuration : double-cliquer `compile.bat`
Il enchaîne `pdflatex → biber → pdflatex → pdflatex`.

### 2. En ligne de commande : `latexmk`
```bash
latexmk -pdf main.tex        # ou : make pdf
```
Le fichier `.latexmkrc` du dossier fait appeler biber automatiquement.

### 3. Depuis TeXstudio / TeXmaker
Configurer l'outil de bibliographie sur **biber** :
- **TeXstudio** : Options → Configurer TeXstudio → Production →
  Bibliographie par défaut : `Biber`.
- **TeXmaker** : Options → Configurer Texmaker → Compilation →
  Bib(la)tex : `biber %`.
Puis compiler avec F1 (compilation rapide), F11 (bibliographie), F1, F1.

## Dépannage

| Symptôme | Cause | Remède |
|---|---|---|
| Section références vide, citations en (auteur, année) | biber jamais lancé | lancer `biber main` puis 2× pdflatex |
| `Package biblatex Warning: Please (re)run Biber` | idem | idem |
| `biber : commande introuvable` | biber non installé | MiKTeX Console → Packages → `biber` ; TeX Live : `tlmgr install biber` |
| « file 'main.bbl' created by different version » | .bbl versionné incompatible avec votre biblatex | lancer `biber main` pour le régénérer localement |
| Citations `[auteur?]` | clé absente de `references.bib` | vérifier la clé citée |

## Fichiers versionnés volontairement

`main.bbl` et `main.bcf` sont suivis par git : ils permettent d'afficher la
bibliographie dès la première compilation `pdflatex`, même sans lancer biber
(tant que votre version de biblatex est compatible). Ne pas les supprimer du
suivi. `make clean` les efface localement ; `biber main` les régénère.
