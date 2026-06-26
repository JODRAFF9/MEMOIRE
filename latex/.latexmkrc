$pdf_mode = 1;
$pdflatex = 'pdflatex -interaction=nonstopmode -synctex=1 %O %S';

# Biber pour biblatex (remplace bibtex)
# Définition explicite de la dépendance .bcf -> .bbl via biber
add_cus_dep('bcf', 'bbl', 0, 'run_biber');
sub run_biber {
    return system("biber \"$_[0]\"");
}
