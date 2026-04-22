#!/usr/bin/env bash
# =============================================================================
# build_installer.sh — build the Windows NSIS installer from Linux
#
# Downloads Python embeddable, get-pip, Windows wheels, NSSM, then runs
# makensis to produce TimeTrack-Setup-<version>.exe.
#
# Requirements (Linux):
#   - bash, curl, unzip
#   - python3 with `pip download`
#   - nsis (`sudo apt install nsis` / `sudo pacman -S nsis`)
#
# Usage:
#   ./installer/build_installer.sh [version]
# =============================================================================
set -euo pipefail

VERSION="${1:-1.0.0}"

PY_VER="3.11.9"
PY_TAG="python311"                 # used to patch the ._pth file
NSSM_VER="2.24"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
CACHE_DIR="$SCRIPT_DIR/.cache"

# ------------------------------------------------------------------ utilities
log()  { printf "\033[1;36m[build]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[error]\033[0m %s\n" "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "dependency missing: $1"; }
need curl
need unzip
need python3
need makensis

# curl with retries — mirrors (nssm.cc, python.org, bootstrap.pypa.io) flake with
# transient 5xx, so never let a single hiccup fail the build.
fetch() {
  curl -fsSL --retry 5 --retry-all-errors --retry-delay 10 --connect-timeout 20 "$@"
}

mkdir -p "$BUILD_DIR" "$CACHE_DIR"

# ------------------------------------------------------------------ clean
log "Cleaning build dir..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ------------------------------------------------------------------ Python embeddable
PY_ZIP="$CACHE_DIR/python-${PY_VER}-embed-amd64.zip"
if [[ ! -f "$PY_ZIP" ]]; then
  log "Downloading Python ${PY_VER} embeddable..."
  fetch -o "$PY_ZIP" \
    "https://www.python.org/ftp/python/${PY_VER}/python-${PY_VER}-embed-amd64.zip"
fi
log "Extracting Python embeddable..."
mkdir -p "$BUILD_DIR/python"
unzip -q -o "$PY_ZIP" -d "$BUILD_DIR/python"

# ------------------------------------------------------------------ get-pip.py
GETPIP="$CACHE_DIR/get-pip.py"
if [[ ! -f "$GETPIP" ]]; then
  log "Downloading get-pip.py..."
  fetch -o "$GETPIP" "https://bootstrap.pypa.io/get-pip.py"
fi
mkdir -p "$BUILD_DIR/wheels"
cp "$GETPIP" "$BUILD_DIR/wheels/get-pip.py"

# ------------------------------------------------------------------ wheels (Windows)
log "Downloading Windows wheels from requirements.txt..."
# Drive the wheel download from requirements.txt so packaging can't drift from
# runtime deps. We download targeting CPython 3.11 on win_amd64.
# --only-binary=:all: forces wheels (no source); pure-python packages still
# resolve as universal wheels.
#
# `colorama` is added explicitly: it's a transitive dep of `click` declared as
# `colorama; platform_system == "Windows"`, and `pip download --platform
# win_amd64` on a Linux host does NOT reliably evaluate platform-conditional
# markers on transitive deps. Without this the Windows install aborts with
# "No matching distribution found for colorama".
python3 -m pip download \
    --dest "$BUILD_DIR/wheels" \
    --platform win_amd64 \
    --python-version 311 \
    --implementation cp \
    --abi cp311 \
    --only-binary=:all: \
    -r "$REPO_ROOT/requirements.txt" \
    pip setuptools wheel colorama \
  >/dev/null

# ------------------------------------------------------------------ NSSM
NSSM_ZIP="$CACHE_DIR/nssm-${NSSM_VER}.zip"
if [[ ! -f "$NSSM_ZIP" ]]; then
  log "Downloading NSSM ${NSSM_VER}..."
  fetch -o "$NSSM_ZIP" "https://nssm.cc/release/nssm-${NSSM_VER}.zip"
fi
log "Extracting NSSM..."
rm -rf "$CACHE_DIR/nssm-tmp"
mkdir -p "$CACHE_DIR/nssm-tmp"
unzip -q -o "$NSSM_ZIP" -d "$CACHE_DIR/nssm-tmp"
mkdir -p "$BUILD_DIR/nssm"
cp "$CACHE_DIR/nssm-tmp/nssm-${NSSM_VER}/win64/nssm.exe" "$BUILD_DIR/nssm/nssm.exe"

# ------------------------------------------------------------------ translation catalogs
log "Compiling translation catalogs..."
python3 -m pip install --quiet --disable-pip-version-check babel
python3 -m babel.messages.frontend compile -d "$REPO_ROOT/app/i18n"

# ------------------------------------------------------------------ app source
log "Staging application source..."
mkdir -p "$BUILD_DIR/app"
cp -r "$REPO_ROOT/app"            "$BUILD_DIR/app/"
cp    "$REPO_ROOT/run.py"         "$BUILD_DIR/app/"
cp    "$REPO_ROOT/requirements.txt" "$BUILD_DIR/app/" 2>/dev/null || true

# Strip any dev leftovers that shouldn't ship.
rm -rf "$BUILD_DIR/app/app/__pycache__" \
       "$BUILD_DIR/app"/**/__pycache__ 2>/dev/null || true
find "$BUILD_DIR/app" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
find "$BUILD_DIR/app" -type f -name "*.pyc" -delete 2>/dev/null || true

# ------------------------------------------------------------------ resources
log "Staging resources..."
mkdir -p "$BUILD_DIR/resources"
cp "$REPO_ROOT/LICENSE"                           "$BUILD_DIR/resources/LICENSE.txt"

# Ship the launcher and service-management batches pre-built (not generated at
# install time). Runtime `.bat` generation + immediate execution is a strong
# antivirus heuristic trigger; pre-built scripts look identical to any other
# legitimate installer payload.
cp "$SCRIPT_DIR/resources/timetrack.bat"          "$BUILD_DIR/resources/"
cp "$SCRIPT_DIR/resources/install-service.bat"    "$BUILD_DIR/resources/"
cp "$SCRIPT_DIR/resources/uninstall-service.bat"  "$BUILD_DIR/resources/"

# Icon — generate a minimal .ico if none exists yet.
if [[ -f "$SCRIPT_DIR/resources/timetrack.ico" ]]; then
  cp "$SCRIPT_DIR/resources/timetrack.ico" "$BUILD_DIR/resources/"
else
  log "No icon found — generating a minimal placeholder..."
  python3 - <<'PY' "$BUILD_DIR/resources/timetrack.ico"
import struct, sys, zlib, os
# Minimal 32x32 RGBA icon (a simple clock shape) encoded as BMP in ICO container.
# This is a throwaway placeholder; replace with a real .ico later.
from pathlib import Path

size = 32
# Build a raw RGBA buffer (dark circle with hand)
pixels = bytearray()
cx, cy, r = size/2, size/2, size/2 - 2
for y in range(size):
    for x in range(size):
        dx, dy = x - cx, y - cy
        dist = (dx*dx + dy*dy) ** 0.5
        on_circle = abs(dist - r) < 1.2
        hand_v    = (abs(dx) < 1) and (dy < 0) and (dy > -r*0.8)
        hand_h    = (abs(dy) < 1) and (dx > 0) and (dx < r*0.6)
        if on_circle or hand_v or hand_h:
            pixels += b'\xff\xff\xff\xff'
        else:
            pixels += b'\x00\x00\x00\x00'

# BMP DIB expects BGRA bottom-up
bgra = bytearray()
for row in range(size - 1, -1, -1):
    offset = row * size * 4
    for col in range(size):
        r_, g_, b_, a_ = pixels[offset + col*4 : offset + col*4 + 4]
        bgra += bytes([b_, g_, r_, a_])

# BITMAPINFOHEADER (40 bytes)
dib = struct.pack(
    "<IIIHHIIIIII",
    40,        # header size
    size,      # width
    size * 2,  # height (XOR + AND masks)
    1,         # planes
    32,        # bpp
    0, len(bgra), 0, 0, 0, 0,
)
# AND mask all zero (size*size bits, padded to 4-byte rows)
and_row = (size // 8 + 3) & ~3
and_mask = bytes(and_row * size)
image = dib + bytes(bgra) + and_mask

# ICO wrapper
icondir = struct.pack("<HHH", 0, 1, 1)
iconentry = struct.pack("<BBBBHHII",
    size if size < 256 else 0,
    size if size < 256 else 0,
    0, 0, 1, 32, len(image), 6 + 16)
out = Path(sys.argv[1])
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(icondir + iconentry + image)
print(f"wrote placeholder ico: {out}", file=sys.stderr)
PY
fi

# ------------------------------------------------------------------ makensis
log "Running makensis..."
cd "$SCRIPT_DIR"
makensis -V2 \
  -DAPP_VERSION="$VERSION" \
  -DBUILD_DIR="$BUILD_DIR" \
  -DPY_EMBED_TAG="$PY_TAG" \
  installer.nsi

OUT="$SCRIPT_DIR/TimeTrack-Setup-${VERSION}.exe"
if [[ -f "$OUT" ]]; then
  log "Done: $OUT"
  ls -lh "$OUT"
else
  die "Build finished but $OUT not found"
fi
