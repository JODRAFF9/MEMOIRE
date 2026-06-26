# Compilation du mémoire LaTeX
# Utilise biber (pas bibtex) — requis par biblatex style=apa
#
# Usage :
#   make          → compilation complète via latexmk
#   make rebuild  → nettoyage + compilation manuelle (résout problèmes biber)
MAIN = main

# Méthode recommandée : latexmk avec .latexmkrc (add_cus_dep biber)
pdf:
	latexmk -pdf $(MAIN).tex

# Méthode manuelle garantie : pdflatex → biber → pdflatex × 2
# Utiliser si latexmk n'invoque pas biber (vieux .bbl bibtex)
manual:
	pdflatex -interaction=nonstopmode $(MAIN).tex
	biber $(MAIN)
	pdflatex -interaction=nonstopmode $(MAIN).tex
	pdflatex -interaction=nonstopmode $(MAIN).tex

clean:
	rm -f *.aux *.log *.toc *.lof *.lot *.out *.bbl *.bcf *.blg *.run.xml *.synctex.gz *.fdb_latexmk *.fls
	rm -f chapitres/*.aux annexes/*.aux styles/*.aux

# Nettoyage complet + recompilation manuelle propre
rebuild: clean manual

cleanall: clean
	rm -f $(MAIN).pdf

.PHONY: pdf manual clean cleanall rebuild
