; =============================================================================
;  TimeTrack — Windows Installer (NSIS, MUI2)
;
;  Per-user install:   %LOCALAPPDATA%\Programs\TimeTrack
;  Per-user data:      %APPDATA%\TimeTrack
;  Python:             bundled embeddable (no system Python required)
;  Service wrapper:    NSSM (optional component)
;
;  Variables injected by build_installer.sh via /D flags on `makensis`:
;     APP_VERSION      (e.g. "1.0.0")
;     BUILD_DIR        (absolute path with: python\, app\, nssm\, wheels\, ...)
;     PY_EMBED_TAG     (e.g. "python311" — used to patch ._pth file)
; =============================================================================

Unicode true
SetCompressor /SOLID lzma

!ifndef APP_VERSION
  !define APP_VERSION "0.0.0-dev"
!endif
!ifndef BUILD_DIR
  !error "BUILD_DIR not defined — run via build_installer.sh"
!endif
!ifndef PY_EMBED_TAG
  !define PY_EMBED_TAG "python311"
!endif

!define APP_NAME          "TimeTrack"
!define APP_PUBLISHER     "Rafael Krause"
!define APP_URL           "https://github.com/rafaelkrause/TimeTrack"
!define APP_LAUNCH_EXE    "python\pythonw.exe"
!define APP_LAUNCH_ARGS   '"$INSTDIR\app\run.py"'
!define UNINST_KEY        "Software\Microsoft\Windows\CurrentVersion\Uninstall\TimeTrack"
!define APPDATA_KEY       "Software\TimeTrack"
!define SERVICE_NAME      "TimeTrack"

Name "${APP_NAME}"
OutFile "${BUILD_DIR}\..\TimeTrack-Setup-${APP_VERSION}.exe"
InstallDir "$LOCALAPPDATA\Programs\TimeTrack"
InstallDirRegKey HKCU "${APPDATA_KEY}" "InstallDir"
RequestExecutionLevel user
ShowInstDetails show
ShowUninstDetails show
BrandingText "TimeTrack ${APP_VERSION}"

VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey "ProductName"     "${APP_NAME}"
VIAddVersionKey "CompanyName"     "${APP_PUBLISHER}"
VIAddVersionKey "FileDescription" "TimeTrack Installer"
VIAddVersionKey "FileVersion"     "${APP_VERSION}"
VIAddVersionKey "ProductVersion"  "${APP_VERSION}"
VIAddVersionKey "LegalCopyright"  "© ${APP_PUBLISHER}"

; --- MUI2 -------------------------------------------------------------------
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "nsDialogs.nsh"
!include "WinMessages.nsh"

!define MUI_ICON   "${BUILD_DIR}\resources\timetrack.ico"
!define MUI_UNICON "${BUILD_DIR}\resources\timetrack.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN           "$INSTDIR\${APP_LAUNCH_EXE}"
!define MUI_FINISHPAGE_RUN_PARAMETERS '${APP_LAUNCH_ARGS}'
!define MUI_FINISHPAGE_RUN_TEXT      "Iniciar o TimeTrack"
!define MUI_FINISHPAGE_LINK          "Abrir no navegador"
!define MUI_FINISHPAGE_LINK_LOCATION "http://127.0.0.1:5000"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE      "${BUILD_DIR}\resources\LICENSE.txt"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "PortugueseBR"
!insertmacro MUI_LANGUAGE "English"

; --- Component descriptions --------------------------------------------------
LangString DESC_SecCore      ${LANG_PORTUGUESEBR} "Aplicação, Python embutido e bibliotecas (obrigatório)."
LangString DESC_SecDesktop   ${LANG_PORTUGUESEBR} "Criar atalho na Área de Trabalho."
LangString DESC_SecStartMenu ${LANG_PORTUGUESEBR} "Criar atalho no Menu Iniciar."
LangString DESC_SecService   ${LANG_PORTUGUESEBR} "Rodar em segundo plano como serviço do Windows (requer privilégios de administrador)."

LangString DESC_SecCore      ${LANG_ENGLISH} "Application, embedded Python and libraries (required)."
LangString DESC_SecDesktop   ${LANG_ENGLISH} "Create a Desktop shortcut."
LangString DESC_SecStartMenu ${LANG_ENGLISH} "Create a Start Menu shortcut."
LangString DESC_SecService   ${LANG_ENGLISH} "Run in the background as a Windows service (requires administrator)."

; =============================================================================
; SECTIONS
; =============================================================================

Section "!TimeTrack (obrigatório)" SecCore
  SectionIn RO
  SetOutPath "$INSTDIR"

  ; ----- Python embeddable --------------------------------------------------
  DetailPrint "Copiando Python embutido..."
  SetOutPath "$INSTDIR\python"
  File /r "${BUILD_DIR}\python\*.*"

  ; Enable site-packages inside the embeddable distribution.
  DetailPrint "Habilitando site-packages..."
  Delete "$INSTDIR\python\${PY_EMBED_TAG}._pth"
  FileOpen $0 "$INSTDIR\python\${PY_EMBED_TAG}._pth" w
    FileWrite $0 "${PY_EMBED_TAG}.zip$\r$\n"
    FileWrite $0 ".$\r$\n"
    FileWrite $0 "Lib\site-packages$\r$\n"
    FileWrite $0 "import site$\r$\n"
  FileClose $0

  ; ----- Wheels (offline install) -------------------------------------------
  DetailPrint "Copiando wheels..."
  SetOutPath "$INSTDIR\wheels"
  File /r "${BUILD_DIR}\wheels\*.*"

  ; ----- Application source -------------------------------------------------
  DetailPrint "Copiando aplicação..."
  SetOutPath "$INSTDIR\app"
  File /r "${BUILD_DIR}\app\*.*"

  ; ----- Icon ---------------------------------------------------------------
  SetOutPath "$INSTDIR"
  File "${BUILD_DIR}\resources\timetrack.ico"
  File "${BUILD_DIR}\resources\LICENSE.txt"

  ; ----- pip bootstrap + install dependencies -------------------------------
  DetailPrint "Instalando pip..."
  nsExec::ExecToLog '"$INSTDIR\python\python.exe" "$INSTDIR\wheels\get-pip.py" --no-warn-script-location --no-index --find-links "$INSTDIR\wheels"'
  Pop $0
  ${If} $0 <> 0
    DetailPrint "AVISO: pip retornou código $0"
  ${EndIf}

  DetailPrint "Instalando Flask, pystray, Pillow..."
  nsExec::ExecToLog '"$INSTDIR\python\python.exe" -m pip install --no-warn-script-location --no-index --find-links "$INSTDIR\wheels" flask pystray Pillow'
  Pop $0
  ${If} $0 <> 0
    DetailPrint "AVISO: pip install retornou código $0"
  ${EndIf}

  ; ----- Generate timetrack.bat (console launcher) --------------------------
  FileOpen $0 "$INSTDIR\timetrack.bat" w
    FileWrite $0 '@echo off$\r$\n'
    FileWrite $0 'setlocal$\r$\n'
    FileWrite $0 'set "TIMETRACK_DATA_DIR=%APPDATA%\TimeTrack"$\r$\n'
    FileWrite $0 'cd /d "$INSTDIR\app"$\r$\n'
    FileWrite $0 '"$INSTDIR\python\python.exe" run.py %*$\r$\n'
  FileClose $0

  ; ----- Per-user data directory --------------------------------------------
  CreateDirectory "$APPDATA\TimeTrack"
  CreateDirectory "$APPDATA\TimeTrack\data"

  ; ----- Registry: Add/Remove Programs --------------------------------------
  WriteRegStr HKCU "${APPDATA_KEY}" "InstallDir"    "$INSTDIR"
  WriteRegStr HKCU "${APPDATA_KEY}" "Version"       "${APP_VERSION}"
  WriteRegStr HKCU "${APPDATA_KEY}" "DataDir"       "$APPDATA\TimeTrack"

  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName"     "${APP_NAME}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion"  "${APP_VERSION}"
  WriteRegStr HKCU "${UNINST_KEY}" "Publisher"       "${APP_PUBLISHER}"
  WriteRegStr HKCU "${UNINST_KEY}" "URLInfoAbout"    "${APP_URL}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon"     "$INSTDIR\timetrack.ico"
  WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1

  ; Size estimate (KB)
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" $0

  WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Atalho na Área de Trabalho" SecDesktop
  ; SetOutPath defines the shortcut's WorkingDir — run.py must resolve from $INSTDIR\app.
  SetOutPath "$INSTDIR\app"
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_LAUNCH_EXE}" '${APP_LAUNCH_ARGS}' "$INSTDIR\timetrack.ico" 0 SW_SHOWMINIMIZED
SectionEnd

Section "Atalho no Menu Iniciar" SecStartMenu
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  SetOutPath "$INSTDIR\app"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_LAUNCH_EXE}" '${APP_LAUNCH_ARGS}' "$INSTDIR\timetrack.ico" 0 SW_SHOWMINIMIZED
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Abrir no navegador.lnk" "http://127.0.0.1:5000" "" "$INSTDIR\timetrack.ico" 0
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Desinstalar.lnk" "$INSTDIR\Uninstall.exe"
SectionEnd

Section /o "Rodar como serviço do Windows" SecService
  ; NSSM files
  DetailPrint "Instalando NSSM..."
  SetOutPath "$INSTDIR\nssm"
  File /r "${BUILD_DIR}\nssm\*.*"

  ; Generate service helper batches (must run elevated)
  FileOpen $0 "$INSTDIR\install-service.bat" w
    FileWrite $0 '@echo off$\r$\n'
    FileWrite $0 'net session >nul 2>&1$\r$\n'
    FileWrite $0 'if %errorlevel% neq 0 ($\r$\n'
    FileWrite $0 '  echo Este script requer privilegios de administrador.$\r$\n'
    FileWrite $0 '  pause$\r$\n'
    FileWrite $0 '  exit /b 1$\r$\n'
    FileWrite $0 ')$\r$\n'
    FileWrite $0 '"$INSTDIR\nssm\nssm.exe" install ${SERVICE_NAME} "$INSTDIR\python\pythonw.exe" "$INSTDIR\app\run.py" --no-browser$\r$\n'
    FileWrite $0 '"$INSTDIR\nssm\nssm.exe" set ${SERVICE_NAME} AppDirectory "$INSTDIR\app"$\r$\n'
    FileWrite $0 '"$INSTDIR\nssm\nssm.exe" set ${SERVICE_NAME} DisplayName "TimeTrack"$\r$\n'
    FileWrite $0 '"$INSTDIR\nssm\nssm.exe" set ${SERVICE_NAME} Description "TimeTrack - hour tracking web UI (localhost:5000)"$\r$\n'
    FileWrite $0 '"$INSTDIR\nssm\nssm.exe" set ${SERVICE_NAME} Start SERVICE_AUTO_START$\r$\n'
    FileWrite $0 '"$INSTDIR\nssm\nssm.exe" set ${SERVICE_NAME} AppEnvironmentExtra "TIMETRACK_DATA_DIR=$APPDATA\TimeTrack"$\r$\n'
    FileWrite $0 '"$INSTDIR\nssm\nssm.exe" set ${SERVICE_NAME} AppStdout "$APPDATA\TimeTrack\service.log"$\r$\n'
    FileWrite $0 '"$INSTDIR\nssm\nssm.exe" set ${SERVICE_NAME} AppStderr "$APPDATA\TimeTrack\service.log"$\r$\n'
    FileWrite $0 '"$INSTDIR\nssm\nssm.exe" set ${SERVICE_NAME} AppStdoutCreationDisposition 4$\r$\n'
    FileWrite $0 '"$INSTDIR\nssm\nssm.exe" set ${SERVICE_NAME} AppStderrCreationDisposition 4$\r$\n'
    FileWrite $0 '"$INSTDIR\nssm\nssm.exe" start ${SERVICE_NAME}$\r$\n'
    FileWrite $0 'echo.$\r$\n'
    FileWrite $0 'echo Servico instalado e iniciado.$\r$\n'
  FileClose $0

  FileOpen $0 "$INSTDIR\uninstall-service.bat" w
    FileWrite $0 '@echo off$\r$\n'
    FileWrite $0 'net session >nul 2>&1$\r$\n'
    FileWrite $0 'if %errorlevel% neq 0 ($\r$\n'
    FileWrite $0 '  echo Este script requer privilegios de administrador.$\r$\n'
    FileWrite $0 '  pause$\r$\n'
    FileWrite $0 '  exit /b 1$\r$\n'
    FileWrite $0 ')$\r$\n'
    FileWrite $0 '"$INSTDIR\nssm\nssm.exe" stop ${SERVICE_NAME} >nul 2>&1$\r$\n'
    FileWrite $0 '"$INSTDIR\nssm\nssm.exe" remove ${SERVICE_NAME} confirm$\r$\n'
    FileWrite $0 'echo Servico removido.$\r$\n'
  FileClose $0

  ; Register the service now — requires elevation.
  DetailPrint "Registrando serviço (UAC será solicitado)..."
  ExecShell "runas" "$INSTDIR\install-service.bat" "" SW_HIDE
  WriteRegDWORD HKCU "${APPDATA_KEY}" "ServiceInstalled" 1
SectionEnd

; --- Descriptions ------------------------------------------------------------
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecCore}      $(DESC_SecCore)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop}   $(DESC_SecDesktop)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecStartMenu} $(DESC_SecStartMenu)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecService}   $(DESC_SecService)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Function .onInit
  ; Language pick (pt-BR default)
  !insertmacro MUI_LANGDLL_DISPLAY

  ; Prevent duplicate installs
  ReadRegStr $0 HKCU "${UNINST_KEY}" "UninstallString"
  ${If} $0 != ""
    MessageBox MB_YESNO|MB_ICONQUESTION "Uma versão do TimeTrack já está instalada.$\n$\nDeseja desinstalar antes de continuar?" IDNO +2
      ExecWait '$0 /S _?=$INSTDIR'
  ${EndIf}
FunctionEnd

; =============================================================================
; UNINSTALL
; =============================================================================

Section "Uninstall"
  ; Stop and remove the service if it was registered.
  ReadRegDWORD $0 HKCU "${APPDATA_KEY}" "ServiceInstalled"
  ${If} $0 = 1
    DetailPrint "Removendo serviço (UAC será solicitado)..."
    ${If} ${FileExists} "$INSTDIR\uninstall-service.bat"
      ExecShell "runas" "$INSTDIR\uninstall-service.bat" "" SW_HIDE
      Sleep 2000
    ${EndIf}
  ${EndIf}

  ; Kill any running pythonw instance serving the app.
  DetailPrint "Encerrando instâncias em execução..."
  nsExec::ExecToLog 'taskkill /F /IM pythonw.exe /FI "WINDOWTITLE eq TimeTrack*"'
  Pop $0

  ; Remove shortcuts
  Delete "$DESKTOP\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Abrir no navegador.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Desinstalar.lnk"
  RMDir  "$SMPROGRAMS\${APP_NAME}"

  ; Remove install directory
  RMDir /r "$INSTDIR\python"
  RMDir /r "$INSTDIR\app"
  RMDir /r "$INSTDIR\wheels"
  RMDir /r "$INSTDIR\nssm"
  Delete "$INSTDIR\timetrack.bat"
  Delete "$INSTDIR\install-service.bat"
  Delete "$INSTDIR\uninstall-service.bat"
  Delete "$INSTDIR\timetrack.ico"
  Delete "$INSTDIR\LICENSE.txt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir  "$INSTDIR"

  ; Ask before wiping user data.
  MessageBox MB_YESNO|MB_ICONQUESTION "Remover também os dados do usuário em $APPDATA\TimeTrack (config.json e histórico)?" IDNO +2
    RMDir /r "$APPDATA\TimeTrack"

  ; Registry cleanup
  DeleteRegKey HKCU "${UNINST_KEY}"
  DeleteRegKey HKCU "${APPDATA_KEY}"
SectionEnd
