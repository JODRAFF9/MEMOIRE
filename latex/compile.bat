@echo off
REM ============================================================
REM  compile.bat — Compilation complete du memoire (Windows)
REM  Moteur : XeLaTeX (police systeme Times New Roman via fontspec).
REM  Sequence obligatoire pour la bibliographie (biblatex+biber) :
REM    xelatex -> biber -> xelatex -> xelatex
REM  Double-cliquer sur ce fichier depuis le dossier latex\
REM ============================================================
cd /d "%~dp0"

REM Nettoyage des fichiers auxiliaires (evite les residus \IeC issus d'un
REM ancien compilateur pdflatex, incompatibles avec XeLaTeX).
del /q main.aux main.toc main.stoc main.out main.lof main.lot 2>nul

echo [0/4] figures fig_privind (Python, mise en page ANSD ponderee)...
python "..\code\python\gen_fig_privind.py" 2>nul || python3 "..\code\python\gen_fig_privind.py" 2>nul
if errorlevel 1 (
    echo    Python indisponible ^(pandas/matplotlib^) : figures versionnees conservees.
)

echo [1/4] xelatex (premiere passe)...
xelatex -interaction=nonstopmode main.tex >nul

echo [2/4] biber (bibliographie)...
biber main
if errorlevel 1 (
    echo.
    echo ERREUR : biber a echoue ou n'est pas installe.
    echo Verifiez avec :  biber --version
    echo Sous MiKTeX : ouvrir MiKTeX Console ^> Packages ^> installer "biber".
    pause
    exit /b 1
)

echo [3/4] xelatex (references croisees)...
xelatex -interaction=nonstopmode main.tex >nul

echo [4/4] xelatex (passe finale)...
xelatex -interaction=nonstopmode main.tex >nul

echo.
echo Termine : main.pdf genere avec la bibliographie.
pause
