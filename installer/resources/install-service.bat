@echo off
rem Register TimeTrack as a Windows service via NSSM.
rem Must be run as Administrator (right-click -> Run as administrator).
setlocal

net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Este script precisa ser executado como Administrador.
  echo Clique com o botao direito e escolha "Executar como administrador".
  pause
  exit /b 1
)

set "INSTDIR=%~dp0"
if "%INSTDIR:~-1%"=="\" set "INSTDIR=%INSTDIR:~0,-1%"

"%INSTDIR%\nssm\nssm.exe" install TimeTrack "%INSTDIR%\python\pythonw.exe" "%INSTDIR%\app\run.py" --no-browser
"%INSTDIR%\nssm\nssm.exe" set TimeTrack AppDirectory "%INSTDIR%\app"
"%INSTDIR%\nssm\nssm.exe" set TimeTrack DisplayName "TimeTrack"
"%INSTDIR%\nssm\nssm.exe" set TimeTrack Description "TimeTrack - hour tracking web UI (localhost:5000)"
"%INSTDIR%\nssm\nssm.exe" set TimeTrack Start SERVICE_AUTO_START
"%INSTDIR%\nssm\nssm.exe" set TimeTrack AppEnvironmentExtra "TIMETRACK_DATA_DIR=%APPDATA%\TimeTrack"
"%INSTDIR%\nssm\nssm.exe" set TimeTrack AppStdout "%APPDATA%\TimeTrack\service.log"
"%INSTDIR%\nssm\nssm.exe" set TimeTrack AppStderr "%APPDATA%\TimeTrack\service.log"
"%INSTDIR%\nssm\nssm.exe" set TimeTrack AppStdoutCreationDisposition 4
"%INSTDIR%\nssm\nssm.exe" set TimeTrack AppStderrCreationDisposition 4
"%INSTDIR%\nssm\nssm.exe" start TimeTrack

echo.
echo Servico instalado e iniciado.
pause
