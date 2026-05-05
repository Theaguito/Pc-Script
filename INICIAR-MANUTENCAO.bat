@echo off
title Manutencao Completa PC
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :RunScript
) else (
    echo Solicitando permissoes de administrador...
    powershell -Command "Start-Process cmd -ArgumentList '/c, %~f0' -Verb RunAs"
    exit
)
:RunScript
pushd "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Manutencao-PC.ps1"
pause