@echo off
REM ============================================================
REM  compile.bat — Compilation complete du memoire (Windows)
REM  Moteur : LuaLaTeX (police systeme Times New Roman via fontspec).
REM  Sequence obligatoire pour la bibliographie (biblatex+biber) :
REM    lualatex -> biber -> lualatex -> lualatex
REM  Prerequis : biber (MiKTeX Console > Packages).
REM  Double-cliquer sur ce fichier depuis le dossier latex\
REM ============================================================
cd /d "%~dp0"

REM Nettoyage des fichiers auxiliaires (evite les residus \IeC issus d'un
REM ancien compilateur pdflatex, incompatibles avec LuaLaTeX).
REM main.bcf et main.bbl sont regeneres : les supprimer evite que biber
REM lise une version perimee citant des cles qui n'existent plus.
del /q main.aux main.toc main.stoc main.out main.lof main.lot main.bcf main.bbl 2>nul

echo [1/3] lualatex (premiere passe)...
lualatex -interaction=nonstopmode main.tex >nul
if not exist main.bcf (
    echo.
    echo ERREUR : la premiere passe a echoue, main.bcf n'a pas ete produit.
    echo Relancez sans masquer la sortie :  lualatex main.tex
    pause
    exit /b 1
)

echo [2/3] biber (bibliographie)...
biber main
if errorlevel 1 (
    echo.
    echo ERREUR : biber a echoue ou n'est pas installe.
    echo Verifiez avec :  biber --version
    echo Sous MiKTeX : ouvrir MiKTeX Console ^> Packages ^> installer "biber".
    pause
    exit /b 1
)

echo [3/3] lualatex (deux passes finales)...
lualatex -interaction=nonstopmode main.tex >nul
lualatex -interaction=nonstopmode main.tex >nul

echo.
echo Termine : main.pdf genere avec la bibliographie.
pause
