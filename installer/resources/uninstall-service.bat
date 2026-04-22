@echo off
rem Stop and remove the TimeTrack Windows service.
rem Must be run as Administrator.
setlocal

net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Este script precisa ser executado como Administrador.
  pause
  exit /b 1
)

set "INSTDIR=%~dp0"
if "%INSTDIR:~-1%"=="\" set "INSTDIR=%INSTDIR:~0,-1%"

"%INSTDIR%\nssm\nssm.exe" stop TimeTrack >nul 2>&1
"%INSTDIR%\nssm\nssm.exe" remove TimeTrack confirm

echo Servico removido.
pause
