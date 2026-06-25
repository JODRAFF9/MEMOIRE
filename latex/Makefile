# Compilation du mémoire LaTeX
# Utilise biber (pas bibtex) — requis par biblatex style=apa
MAIN = main

# Méthode recommandée : latexmk gère automatiquement les passes
pdf:
	latexmk -pdf $(MAIN).tex

# Méthode manuelle : 4 étapes dans l'ordre
manual:
	pdflatex -interaction=nonstopmode $(MAIN).tex
	biber $(MAIN)
	pdflatex -interaction=nonstopmode $(MAIN).tex
	pdflatex -interaction=nonstopmode $(MAIN).tex

clean:
	rm -f *.aux *.log *.toc *.lof *.lot *.out *.bbl *.bcf *.blg *.run.xml *.synctex.gz
	rm -f chapitres/*.aux annexes/*.aux styles/*.aux

cleanall: clean
	rm -f $(MAIN).pdf

.PHONY: pdf manual clean cleanall
