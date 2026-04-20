# Installation

Complete installation guide for Job Tracker on Linux, macOS and Windows.

## Requirements

| System | Requirements |
|---|---|
| Linux / macOS | Python 3.10+, `curl`, `bash` |
| Windows (installer) | None — bundled Python |
| Windows (manual) | Python 3.10+ |
| Optional | `pystray` + `Pillow` (tray icon, included by default in the remote script) |

## Linux / macOS — quick install (remote)

Recommended for most users. Downloads the published `.whl` from GitHub Releases, installs it inside an isolated virtualenv, and drops a `job-tracker` launcher on `PATH`.

```bash
curl -fsSL https://raw.githubusercontent.com/rafaelkrause/job_tracker/main/install-remote.sh | bash
```

Then:

```bash
job-tracker              # opens the browser at http://localhost:5000
job-tracker --no-browser # start the server only
```

### What gets created

| Path | Content |
|---|---|
| `~/.local/share/job-tracker/.venv/` | Isolated Python environment |
| `~/.local/share/job-tracker/user/` | `config.json` + `data/YYYY-MM.json` (your data) |
| `~/.local/bin/job-tracker` | Launcher on `PATH` |
| `~/.local/share/applications/job-tracker.desktop` | App-menu entry (Linux) |

If `~/.local/bin` is not on your `PATH`, the script warns you and prints the line to add to `~/.bashrc` or `~/.zshrc`.

### Options (environment variables)

```bash
# Pin a specific version (default: latest release)
JT_VERSION=0.1.0 curl -fsSL .../install-remote.sh | bash

# Skip tray support (pystray + Pillow)
JT_NO_TRAY=1 curl -fsSL .../install-remote.sh | bash

# Custom install prefix
JT_PREFIX=/opt/job-tracker curl -fsSL .../install-remote.sh | bash
```

### Autostart (optional)

The `--service` flag registers Job Tracker with the OS-native service manager:

- **Linux:** `systemd --user` unit at `~/.config/systemd/user/job-tracker.service`, enabled automatically. Starts at login.
- **macOS:** a `LaunchAgent` at `~/Library/LaunchAgents/com.rafaelkrause.jobtracker.plist`, loaded via `launchctl`. Starts at login.

```bash
curl -fsSL https://raw.githubusercontent.com/rafaelkrause/job_tracker/main/install-remote.sh | bash -s -- --service
```

To enable autostart on an existing installation (without reinstalling), just re-run the command above — the script detects the existing install and only adds the service.

### Uninstall

```bash
# Keeps your data at ~/.local/share/job-tracker/user/
curl -fsSL https://raw.githubusercontent.com/rafaelkrause/job_tracker/main/install-remote.sh | bash -s -- --uninstall

# Also wipes user data (irreversible)
curl -fsSL https://raw.githubusercontent.com/rafaelkrause/job_tracker/main/install-remote.sh | bash -s -- --uninstall --purge-data
```

The uninstaller stops and removes the service (if present), then deletes the launcher, menu entry and virtualenv. If you download the script instead of using `curl | bash`, running it interactively (`bash install-remote.sh --uninstall`) prompts before removing your data.

### Note on macOS (v0.1.0)

Windows ships a double-click `.exe` installer with a common-user experience; delivering the same level on macOS would require:

- Packaging as a `.app` via `py2app` or PyInstaller.
- An **Apple Developer account (US$99/year)** to code-sign the bundle.
- Going through Apple **notarization** — without it, Gatekeeper blocks the app as "unidentified developer".

Without that investment, any homemade `.app` triggers scary warnings. v0.1.0 therefore uses the `curl | bash` path documented above, which works with what macOS already ships (Python from Homebrew or python.org, `launchd` for autostart). It is the same pattern used by Homebrew, oh-my-zsh and Rust/rustup.

## Linux / macOS — from source (contributors)

To develop or modify the project:

```bash
git clone https://github.com/rafaelkrause/job_tracker.git
cd job_tracker
./install.sh            # creates .venv and installs dependencies
./job-tracker.sh        # run
```

Manual alternative:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev,tray]"   # editable install + dev tooling
python3 run.py
```

## Windows — NSIS installer

1. Download `JobTracker-Setup-X.Y.Z.exe` from the [releases page](https://github.com/rafaelkrause/job_tracker/releases).
2. Run the `.exe`. If SmartScreen blocks it, click **More info → Run anyway** (installer is not code-signed).
3. The wizard lets you choose:
    - Desktop shortcut
    - Start Menu entry
    - Optional Windows service component (NSSM)

### Details

- **Per-user install**, no UAC. Default path: `%LOCALAPPDATA%\Programs\JobTracker`
- **Embedded Python**: no system Python is installed
- **Data**: lives in `%APPDATA%\JobTracker` (preserved across updates)

## Windows — manual

1. Install [Python 3.10+](https://www.python.org/downloads/windows/). Check **Add Python to PATH**.
2. Download the code (release ZIP or `git clone`).
3. Open PowerShell in the project folder:

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python run.py
```

## Build the Windows installer from source

Only needed if you want to customize the Windows installer. Runs on a Linux host:

```bash
sudo apt install nsis
./installer/build_installer.sh 1.0.0
# output: installer/JobTracker-Setup-1.0.0.exe
```

The workflow `.github/workflows/build-installer.yml` does this automatically when a `v*` tag is pushed.

## Update

### Linux / macOS — via remote script

Re-run `install-remote.sh`: it detects the existing virtualenv, downloads the new version, reinstalls the wheel, and preserves your data at `~/.local/share/job-tracker/user/`.

### Linux / macOS — from source

```bash
cd job_tracker
git pull
source .venv/bin/activate
pip install -r requirements.txt --upgrade
```

### Windows

Run the new `JobTracker-Setup-X.Y.Z.exe`. Data and configuration under `%APPDATA%\JobTracker` are preserved.

## Uninstall

- **Linux/macOS (remote install):** see [Uninstall](#uninstall) above.
- **Linux/macOS (from source):** `rm -rf job_tracker/`. If applicable: `systemctl --user disable --now job-tracker.service`.
- **Windows:** Control Panel → Programs → Job Tracker → Uninstall.
