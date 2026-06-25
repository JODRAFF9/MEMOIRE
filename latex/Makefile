# Compilation du mémoire LaTeX
MAIN = main
LATEX = pdflatex
BIBER = biber

all: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).tex
	$(LATEX) $(MAIN)
	$(BIBER) $(MAIN)
	$(LATEX) $(MAIN)
	$(LATEX) $(MAIN)

clean:
	rm -f *.aux *.log *.toc *.lof *.lot *.out *.bbl *.bcf *.blg *.run.xml *.synctex.gz
	rm -f chapitres/*.aux annexes/*.aux styles/*.aux

cleanall: clean
	rm -f $(MAIN).pdf

.PHONY: all clean cleanall
