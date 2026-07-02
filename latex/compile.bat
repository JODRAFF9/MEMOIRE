@echo off
REM ============================================================
REM  compile.bat — Compilation complete du memoire (Windows)
REM  Sequence obligatoire pour la bibliographie (biblatex+biber) :
REM    pdflatex -> biber -> pdflatex -> pdflatex
REM  Double-cliquer sur ce fichier depuis le dossier latex\
REM ============================================================
cd /d "%~dp0"

echo [1/4] pdflatex (premiere passe)...
pdflatex -interaction=nonstopmode main.tex >nul

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

echo [3/4] pdflatex (references croisees)...
pdflatex -interaction=nonstopmode main.tex >nul

echo [4/4] pdflatex (passe finale)...
pdflatex -interaction=nonstopmode main.tex >nul

echo.
echo Termine : main.pdf genere avec la bibliographie.
pause
