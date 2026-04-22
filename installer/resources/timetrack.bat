@echo off
rem Console launcher for TimeTrack.
rem %~dp0 expands to this batch's directory (INSTDIR), so the launcher works
rem regardless of where the app is installed.
setlocal
set "TIMETRACK_DATA_DIR=%APPDATA%\TimeTrack"
cd /d "%~dp0app"
"%~dp0python\python.exe" run.py %*
