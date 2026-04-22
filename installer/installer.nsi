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
; Non-solid LZMA. Solid-mode installers share a strong fingerprint with
; malware packers (UPX-like compressed blobs of unsigned PEs), which amplifies
; ML-based heuristic detections such as Wacatac.C!ml. Per-file LZMA is still
; compact (22 MB for our payload) and significantly less flagged.
SetCompressor lzma

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
VIAddVersionKey "ProductName"      "${APP_NAME}"
VIAddVersionKey "CompanyName"      "${APP_PUBLISHER}"
VIAddVersionKey "FileDescription"  "TimeTrack — Hour Tracking Installer"
VIAddVersionKey "FileVersion"      "${APP_VERSION}"
VIAddVersionKey "ProductVersion"   "${APP_VERSION}"
VIAddVersionKey "LegalCopyright"   "© ${APP_PUBLISHER}"
VIAddVersionKey "OriginalFilename" "TimeTrack-Setup-${APP_VERSION}.exe"
VIAddVersionKey "InternalName"     "TimeTrackSetup"
VIAddVersionKey "Comments"         "Local hour-tracking app — serves a web UI on localhost:5000. Source: ${APP_URL}"

; --- MUI2 -------------------------------------------------------------------
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "nsDialogs.nsh"
!include "WinMessages.nsh"

!define MUI_ICON   "${BUILD_DIR}\resources\timetrack.ico"
!define MUI_UNICON "${BUILD_DIR}\resources\timetrack.ico"
!define MUI_ABORTWARNING
; MUI2's built-in Exec concatenation breaks when _PARAMETERS contains embedded
; quotes (it emits `Exec "$\"exe$\" params"` — our quoted script path closes
; the outer string and Exec sees two tokens). Use a custom function so we own
; the quoting explicitly with single-quoted Exec.
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_FUNCTION  "LaunchTimeTrack"
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
LangString DESC_SecService   ${LANG_PORTUGUESEBR} "Instala os arquivos do serviço Windows. Para registrar, use o atalho 'Instalar serviço (Admin)' no Menu Iniciar."

LangString DESC_SecCore      ${LANG_ENGLISH} "Application, embedded Python and libraries (required)."
LangString DESC_SecDesktop   ${LANG_ENGLISH} "Create a Desktop shortcut."
LangString DESC_SecStartMenu ${LANG_ENGLISH} "Create a Start Menu shortcut."
LangString DESC_SecService   ${LANG_ENGLISH} "Install the Windows service files. To register, use the 'Install service (Admin)' shortcut in the Start Menu."

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
  ; Fail loudly instead of silently: a broken install is worse than an aborted
  ; one, because the user ends up with shortcuts that launch a non-working app.
  DetailPrint "Instalando pip..."
  nsExec::ExecToLog '"$INSTDIR\python\python.exe" "$INSTDIR\wheels\get-pip.py" --no-warn-script-location --no-index --find-links "$INSTDIR\wheels"'
  Pop $0
  ${If} $0 <> 0
    MessageBox MB_OK|MB_ICONSTOP "Falha ao instalar o pip (código $0).$\n$\nVerifique os detalhes acima. A instalação será cancelada."
    Abort "pip bootstrap failed"
  ${EndIf}

  DetailPrint "Instalando dependências..."
  ; Drive from requirements.txt (shipped at $INSTDIR\app\requirements.txt) so
  ; this can't drift from what the app actually needs at runtime.
  nsExec::ExecToLog '"$INSTDIR\python\python.exe" -m pip install --no-warn-script-location --no-index --find-links "$INSTDIR\wheels" -r "$INSTDIR\app\requirements.txt"'
  Pop $0
  ${If} $0 <> 0
    MessageBox MB_OK|MB_ICONSTOP "Falha ao instalar as dependências (código $0).$\n$\nVerifique os detalhes acima. A instalação será cancelada."
    Abort "dependency install failed"
  ${EndIf}

  ; Smoke test — confirm the embedded Python can import every required module.
  ; Catches failure modes we saw in the wild: pip reports success but wheels
  ; are for the wrong ABI/platform, or a transitive dep is missing from the
  ; offline bundle. Covers every package in requirements.txt plus flask_babel
  ; (enabled by default for the pt-BR/EN UI).
  DetailPrint "Verificando dependências..."
  nsExec::ExecToLog '"$INSTDIR\python\python.exe" -c "import flask, flask_babel, pystray, PIL"'
  Pop $0
  ${If} $0 <> 0
    MessageBox MB_OK|MB_ICONSTOP "Uma ou mais dependências não puderam ser importadas (código $0).$\n$\nA instalação das wheels falhou silenciosamente. Verifique os detalhes acima."
    Abort "dependency smoke test failed"
  ${EndIf}

  ; Second smoke test — verify the full launch path works. This exercises the
  ; same sys.path logic run.py uses at startup, catching `ModuleNotFoundError:
  ; No module named 'app'` before the user ever double-clicks the shortcut.
  ; Uses CWD rather than path-escaping tricks to avoid quoting hell.
  DetailPrint "Verificando pacote da aplicação..."
  SetOutPath "$INSTDIR\app"
  nsExec::ExecToLog '"$INSTDIR\python\python.exe" -c "import os, sys; sys.path.insert(0, os.getcwd()); from app import create_app"'
  Pop $0
  ${If} $0 <> 0
    MessageBox MB_OK|MB_ICONSTOP "O pacote 'app' não pôde ser carregado (código $0).$\n$\nA aplicação não iniciará corretamente. Verifique os detalhes acima."
    Abort "app smoke test failed"
  ${EndIf}
  DetailPrint "OK — imports verificados."

  ; ----- Console launcher ---------------------------------------------------
  ; Pre-built batch (not generated at runtime — runtime script generation is
  ; a common antivirus heuristic trigger). Uses %~dp0 to locate INSTDIR.
  SetOutPath "$INSTDIR"
  File "${BUILD_DIR}\resources\timetrack.bat"

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

  ; Ship the service helper batches as pre-built files (not generated at
  ; install time). Both trigger UAC when run — the user right-clicks them and
  ; picks "Run as administrator". Having the installer itself elevate via
  ; ExecShell "runas" is a strong Defender heuristic and we avoid it.
  SetOutPath "$INSTDIR"
  File "${BUILD_DIR}\resources\install-service.bat"
  File "${BUILD_DIR}\resources\uninstall-service.bat"

  ; Add a Start Menu shortcut the user can right-click -> Run as administrator
  ; to finish service setup. No auto-elevation from the installer itself.
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Instalar serviço (Admin).lnk" "$INSTDIR\install-service.bat" "" "$INSTDIR\timetrack.ico" 0
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Remover serviço (Admin).lnk"  "$INSTDIR\uninstall-service.bat" "" "$INSTDIR\timetrack.ico" 0

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

; Finish-page "Run" launcher. Single-quoted Exec keeps the embedded
; double-quotes around each path intact, so spaces in $INSTDIR don't
; confuse CreateProcess.
Function LaunchTimeTrack
  Exec '"$INSTDIR\${APP_LAUNCH_EXE}" ${APP_LAUNCH_ARGS}'
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
  Delete "$SMPROGRAMS\${APP_NAME}\Instalar serviço (Admin).lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Remover serviço (Admin).lnk"
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
