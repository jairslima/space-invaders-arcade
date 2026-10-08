@echo off
REM ============================================================
REM build.bat - Compila Space Invaders Arcade by Jair Lima (Harbour 3.0.0)
REM ============================================================
SET HB_PATH=C:\hb30\bin

echo Compilando Space Invaders Arcade...
"%HB_PATH%\hbmk2.exe" invaders.hbp

IF ERRORLEVEL 1 (
    echo.
    echo ERRO: Compilacao falhou!
    pause
) ELSE (
    echo.
    echo Compilacao concluida com sucesso: invaders.exe
)
