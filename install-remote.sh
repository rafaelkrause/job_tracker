#!/usr/bin/env bash
# =============================================================================
# install-remote.sh — remote installer for Job Tracker on Linux and macOS.
#
# Downloads the published wheel from GitHub Releases, installs it in an
# isolated virtualenv, writes a launcher on PATH, optionally registers a
# systemd user unit (Linux) or LaunchAgent (macOS) for autostart, and can
# uninstall everything it created.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/rafaelkrause/job_tracker/main/install-remote.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/rafaelkrause/job_tracker/main/install-remote.sh | bash -s -- --service
#
#   # Uninstall (keep user data):
#   curl -fsSL https://raw.githubusercontent.com/rafaelkrause/job_tracker/main/install-remote.sh | bash -s -- --uninstall
#
#   # Uninstall and wipe user data:
#   curl -fsSL https://raw.githubusercontent.com/rafaelkrause/job_tracker/main/install-remote.sh | bash -s -- --uninstall --purge-data
#
# Environment variables:
#   JT_VERSION=0.1.0   Pin a specific release (default: latest).
#   JT_NO_TRAY=1       Skip pystray + Pillow install.
#   JT_PREFIX=PATH     Install prefix (default: ~/.local/share/job-tracker).
# =============================================================================
set -euo pipefail

REPO="rafaelkrause/job_tracker"
SERVICE_LABEL="com.rafaelkrause.jobtracker"

PREFIX="${JT_PREFIX:-$HOME/.local/share/job-tracker}"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
VENV_DIR="$PREFIX/.venv"
DATA_DIR="$PREFIX/user"
LOGS_DIR="$PREFIX/logs"
LAUNCHER="$BIN_DIR/job-tracker"
DESKTOP_FILE="$DESKTOP_DIR/job-tracker.desktop"
SYSTEMD_UNIT="$HOME/.config/systemd/user/job-tracker.service"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/$SERVICE_LABEL.plist"

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'
info() { printf "${BOLD}%s${NC}\n" "$*"; }
ok()   { printf "${GREEN}✓ %s${NC}\n" "$*"; }
warn() { printf "${YELLOW}⚠ %s${NC}\n" "$*" >&2; }
die()  { printf "${RED}✗ %s${NC}\n" "$*" >&2; exit 1; }

ACTION=install
WITH_SERVICE=0
PURGE_DATA=0

usage() {
    sed -n '3,22p' "$0" 2>/dev/null || cat <<EOF
Usage: install-remote.sh [--service] [--uninstall [--purge-data]]
Env:   JT_VERSION=X.Y.Z, JT_NO_TRAY=1, JT_PREFIX=path
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --service)     WITH_SERVICE=1 ;;
        --uninstall)   ACTION=uninstall ;;
        --purge-data)  PURGE_DATA=1 ;;
        -h|--help)     usage; exit 0 ;;
        *) die "unknown flag: $1 (use --help)" ;;
    esac
    shift
done

# ---------------------------------------------------------------- OS detection
case "$(uname -s)" in
    Linux)  OS=linux  ;;
    Darwin) OS=macos  ;;
    *) die "unsupported OS: $(uname -s) — only Linux and macOS are handled by this script" ;;
esac

# ---------------------------------------------------------------- prerequisites
need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }
need python3
need curl

PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")')
PY_MAJOR=$(python3 -c 'import sys; print(sys.version_info[0])')
PY_MINOR=$(python3 -c 'import sys; print(sys.version_info[1])')
if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 10 ]; }; then
    die "Python 3.10+ required (found $PY_VER)"
fi

# =============================================================================
# SERVICE HELPERS
# =============================================================================

service_exists() {
    if [ "$OS" = linux ]; then
        [ -f "$SYSTEMD_UNIT" ]
    else
        [ -f "$LAUNCHD_PLIST" ]
    fi
}

service_stop_and_disable() {
    if [ "$OS" = linux ]; then
        if command -v systemctl >/dev/null 2>&1 && [ -f "$SYSTEMD_UNIT" ]; then
            systemctl --user disable --now job-tracker.service 2>/dev/null || true
        fi
    else
        if [ -f "$LAUNCHD_PLIST" ] && command -v launchctl >/dev/null 2>&1; then
            launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
        fi
    fi
}

write_systemd_unit() {
    mkdir -p "$(dirname "$SYSTEMD_UNIT")"
    cat > "$SYSTEMD_UNIT" <<EOF
[Unit]
Description=Job Tracker (self-hosted hour tracker)
After=network.target

[Service]
Type=simple
Environment=JOBTRACKER_DATA_DIR=$DATA_DIR
ExecStart=$LAUNCHER --no-browser
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload
        systemctl --user enable --now job-tracker.service
        ok "systemd user service enabled and started"
        info "  Status: systemctl --user status job-tracker"
        info "  Logs:   journalctl --user -u job-tracker -f"
    else
        warn "systemctl not found — unit written to $SYSTEMD_UNIT but not started"
    fi
}

write_launchd_plist() {
    mkdir -p "$(dirname "$LAUNCHD_PLIST")" "$LOGS_DIR"
    cat > "$LAUNCHD_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$SERVICE_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$LAUNCHER</string>
        <string>--no-browser</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>JOBTRACKER_DATA_DIR</key>
        <string>$DATA_DIR</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>$LOGS_DIR/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$LOGS_DIR/stderr.log</string>
</dict>
</plist>
EOF
    if command -v launchctl >/dev/null 2>&1; then
        launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
        launchctl load -w "$LAUNCHD_PLIST"
        ok "LaunchAgent loaded"
        info "  Status: launchctl list | grep $SERVICE_LABEL"
        info "  Logs:   tail -f $LOGS_DIR/stdout.log"
    else
        warn "launchctl not found — plist written to $LAUNCHD_PLIST but not loaded"
    fi
}

# =============================================================================
# INSTALL
# =============================================================================

install_main() {
    info "═══════════════════════════════════════"
    info "  Job Tracker — remote install ($OS)"
    info "═══════════════════════════════════════"
    ok "Python $PY_VER"

    mkdir -p "$PREFIX" "$BIN_DIR" "$DATA_DIR" "$LOGS_DIR"

    # ---- Resolve wheel URL from GitHub Releases
    info "Resolving release from github.com/$REPO…"
    eval "$(
        JT_VERSION="${JT_VERSION:-}" REPO="$REPO" python3 - <<'PY'
import json, os, sys, urllib.request, shlex
tag = os.environ.get("JT_VERSION", "").strip()
repo = os.environ["REPO"]
url = (
    f"https://api.github.com/repos/{repo}/releases/tags/v{tag.lstrip('v')}"
    if tag else
    f"https://api.github.com/repos/{repo}/releases/latest"
)
try:
    with urllib.request.urlopen(url, timeout=30) as r:
        data = json.load(r)
except Exception as exc:
    sys.stderr.write(f"failed to query {url}: {exc}\n")
    sys.exit(1)
try:
    whl = next(a["browser_download_url"] for a in data["assets"] if a["name"].endswith(".whl"))
except StopIteration:
    sys.stderr.write(f"no .whl asset found on release {data.get('tag_name')}\n")
    sys.exit(1)
print(f"WHL_URL={shlex.quote(whl)}")
print(f"REL_TAG={shlex.quote(data['tag_name'])}")
PY
    )"
    ok "Release $REL_TAG — $WHL_URL"

    # ---- Virtualenv
    if [ ! -d "$VENV_DIR" ]; then
        info "Creating virtualenv at $VENV_DIR…"
        python3 -m venv "$VENV_DIR"
    else
        info "Reusing virtualenv at $VENV_DIR"
    fi
    PIP="$VENV_DIR/bin/pip"
    "$PIP" install --quiet --upgrade pip

    # ---- Install wheel (+tray unless disabled)
    # pip doesn't accept `url[extra]` syntax — it URL-encodes the brackets.
    # Use PEP 508 direct-URL form `name[extra] @ url` instead.
    info "Installing wheel…"
    if [ "${JT_NO_TRAY:-0}" = "1" ]; then
        "$PIP" install --quiet "$WHL_URL"
    else
        if ! "$PIP" install --quiet "job-tracker[tray] @ $WHL_URL"; then
            warn "tray extras failed (pystray/Pillow) — falling back to core install"
            "$PIP" install --quiet "$WHL_URL"
        fi
    fi
    ok "Job Tracker $REL_TAG installed"

    # ---- Launcher on PATH
    cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
# Job Tracker launcher — installed by install-remote.sh
export JOBTRACKER_DATA_DIR="\${JOBTRACKER_DATA_DIR:-$DATA_DIR}"
exec "$VENV_DIR/bin/job-tracker" "\$@"
EOF
    chmod +x "$LAUNCHER"
    ok "Launcher: $LAUNCHER"

    if ! printf '%s' ":$PATH:" | grep -q ":$BIN_DIR:"; then
        warn "$BIN_DIR is not on PATH — add it to your shell rc file:"
        warn "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc   # or ~/.zshrc"
    fi

    # ---- Linux desktop entry
    if [ "$OS" = linux ]; then
        mkdir -p "$DESKTOP_DIR"
        cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Job Tracker
GenericName=Hour Tracker
Comment=Self-hosted hour-tracking tool
Exec=$LAUNCHER
Terminal=false
Categories=Office;ProjectManagement;
StartupNotify=false
Icon=preferences-system-time
EOF
        command -v update-desktop-database >/dev/null 2>&1 \
            && update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
        ok "Menu entry: $DESKTOP_FILE"
    fi

    # ---- Service (optional)
    if [ "$WITH_SERVICE" = "1" ]; then
        info "Setting up autostart service…"
        if [ "$OS" = linux ]; then
            write_systemd_unit
        else
            write_launchd_plist
        fi
    fi

    echo
    info "═══════════════════════════════════════"
    info "  Install complete"
    info "═══════════════════════════════════════"
    echo
    echo "  Run:        job-tracker"
    echo "  Headless:   job-tracker --no-browser"
    echo "  UI:         http://localhost:5000"
    echo "  Data dir:   $DATA_DIR"
    if [ "$WITH_SERVICE" = "0" ]; then
        echo
        echo "  Autostart (optional):"
        echo "    curl -fsSL https://raw.githubusercontent.com/$REPO/main/install-remote.sh | bash -s -- --service"
    fi
    echo
    echo "  Uninstall:  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install-remote.sh | bash -s -- --uninstall"
    echo
}

# =============================================================================
# UNINSTALL
# =============================================================================

uninstall_main() {
    info "═══════════════════════════════════════"
    info "  Job Tracker — uninstall ($OS)"
    info "═══════════════════════════════════════"

    if service_exists; then
        info "Stopping and disabling service…"
        service_stop_and_disable
        rm -f "$SYSTEMD_UNIT" "$LAUNCHD_PLIST"
        if [ "$OS" = linux ] && command -v systemctl >/dev/null 2>&1; then
            systemctl --user daemon-reload 2>/dev/null || true
        fi
        ok "Service removed"
    fi

    [ -f "$LAUNCHER" ] && rm -f "$LAUNCHER" && ok "Launcher removed"
    [ -f "$DESKTOP_FILE" ] && rm -f "$DESKTOP_FILE" && ok "Desktop entry removed"
    [ -d "$VENV_DIR" ] && rm -rf "$VENV_DIR" && ok "Virtualenv removed"
    [ -d "$LOGS_DIR" ] && rm -rf "$LOGS_DIR" && ok "Logs removed"

    # ---- Data handling
    if [ -d "$DATA_DIR" ]; then
        local purge="$PURGE_DATA"
        if [ "$purge" = "0" ] && [ -t 0 ]; then
            printf "\n%b" "${YELLOW}Remove user data at $DATA_DIR? [y/N] ${NC}"
            read -r reply
            case "$reply" in [yY]|[yY][eE][sS]) purge=1 ;; esac
        fi
        if [ "$purge" = "1" ]; then
            rm -rf "$DATA_DIR"
            ok "User data removed"
        else
            info "Keeping user data at $DATA_DIR"
            info "  Re-run with --purge-data to remove it."
        fi
    fi

    # ---- PREFIX itself (only if empty)
    if [ -d "$PREFIX" ] && [ -z "$(ls -A "$PREFIX" 2>/dev/null)" ]; then
        rmdir "$PREFIX"
        ok "Install prefix removed"
    fi

    echo
    info "═══════════════════════════════════════"
    info "  Uninstall complete"
    info "═══════════════════════════════════════"
    echo
}

# =============================================================================
# DISPATCH
# =============================================================================

case "$ACTION" in
    install)    install_main ;;
    uninstall)  uninstall_main ;;
esac
