#!/usr/bin/env bash
set -e

# ── Job Tracker — Instalador Linux ─────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
LAUNCHER="$SCRIPT_DIR/job-tracker.sh"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/job-tracker.desktop"

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${BOLD}$1${NC}"; }
ok()    { echo -e "${GREEN}✓ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠ $1${NC}"; }
fail()  { echo -e "${RED}✗ $1${NC}"; exit 1; }

echo ""
info "═══════════════════════════════════════"
info "  Job Tracker — Instalação (Linux)"
info "═══════════════════════════════════════"
echo ""

# ── 1. Verificar Python ────────────────────────────────────────────────

if ! command -v python3 &>/dev/null; then
    fail "python3 não encontrado. Instale o Python 3.8+ antes de continuar."
fi

PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PY_MAJOR=$(python3 -c "import sys; print(sys.version_info.major)")
PY_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")

if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 8 ]; }; then
    fail "Python 3.8+ necessário (encontrado: $PY_VERSION)"
fi
ok "Python $PY_VERSION"

# ── 2. Criar ambiente virtual ──────────────────────────────────────────

USE_VENV=true

if [ -d "$VENV_DIR" ]; then
    info "Ambiente virtual já existe em .venv"
else
    info "Criando ambiente virtual..."
    if python3 -m venv "$VENV_DIR" 2>/dev/null; then
        ok "Ambiente virtual criado"
    else
        warn "python3-venv não disponível."
        echo "   Para instalar (recomendado):"
        echo "     sudo apt install python3-venv    # Debian/Ubuntu"
        echo "     sudo dnf install python3-venv    # Fedora"
        echo ""
        echo -n "   Continuar sem venv (pip --user)? [S/n] "
        read -r REPLY
        if [[ "$REPLY" =~ ^[Nn]$ ]]; then
            exit 0
        fi
        USE_VENV=false
    fi
fi

if $USE_VENV; then
    PIP="$VENV_DIR/bin/pip"
    PYTHON="$VENV_DIR/bin/python3"
else
    PIP="pip3"
    PYTHON="python3"
fi

# ── 3. Instalar dependências ──────────────────────────────────────────

info "Instalando dependências..."
if $USE_VENV; then
    "$PIP" install --upgrade pip -q 2>/dev/null || true
    "$PIP" install -r "$SCRIPT_DIR/requirements.txt" -q
else
    pip3 install --user flask -q
fi
ok "Flask instalado"

# ── 4. Bandeja do sistema (opcional) ──────────────────────────────────

echo ""
echo -n "Instalar suporte a bandeja do sistema (pystray)? [s/N] "
read -r REPLY
if [[ "$REPLY" =~ ^[Ss]$ ]]; then
    info "Instalando pystray + Pillow..."
    if $USE_VENV; then
        "$PIP" install pystray Pillow -q
    else
        pip3 install --user pystray Pillow -q
    fi
    ok "Suporte a bandeja instalado"
fi

# ── 5. Criar script de inicialização ─────────────────────────────────

info "Criando launcher..."

if $USE_VENV; then
    cat > "$LAUNCHER" << LAUNCHER_EOF
#!/usr/bin/env bash
cd "$SCRIPT_DIR"
source "$VENV_DIR/bin/activate"
exec python3 run.py "\$@"
LAUNCHER_EOF
else
    cat > "$LAUNCHER" << LAUNCHER_EOF
#!/usr/bin/env bash
cd "$SCRIPT_DIR"
exec python3 run.py "\$@"
LAUNCHER_EOF
fi

chmod +x "$LAUNCHER"
ok "Launcher criado: $LAUNCHER"

# ── 6. Atalho no menu de aplicações ──────────────────────────────────

mkdir -p "$DESKTOP_DIR"

cat > "$DESKTOP_FILE" << DESKTOP_EOF
[Desktop Entry]
Version=1.0
Name=Job Tracker
GenericName=Tracking de Horas
Comment=Ferramenta de monitoramento de horas trabalhadas
Exec=$LAUNCHER
Terminal=false
Type=Application
Categories=Office;ProjectManagement;
StartupNotify=false
Icon=preferences-system-time
DESKTOP_EOF

update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
ok "Atalho criado no menu de aplicações"

# ── 7. Conclusão ─────────────────────────────────────────────────────

echo ""
info "═══════════════════════════════════════"
info "  Instalação concluída!"
info "═══════════════════════════════════════"
echo ""
echo "  Iniciar via terminal:"
echo "    $LAUNCHER"
echo ""
echo "  Ou procure 'Job Tracker' no menu de aplicações."
echo ""
echo "  Para desinstalar:"
echo "    rm -rf $VENV_DIR"
echo "    rm -f $LAUNCHER"
echo "    rm -f $DESKTOP_FILE"
echo ""
