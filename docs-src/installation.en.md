# Installation

Complete installation guide for Job Tracker on Linux, macOS and Windows.

## Requirements

| System | Requirements |
|---|---|
| Linux / macOS | Python 3.10+, `pip`, `git`, `bash` |
| Windows (installer) | None — bundled Python |
| Windows (manual) | Python 3.10+ |
| Optional | `pystray` + `Pillow` for the tray icon |

## Linux / macOS — script

The recommended way is to run `install.sh`:

```bash
git clone https://github.com/rafaelkrause/job_tracker.git
cd job_tracker
./install.sh
```

The script:

1. Checks that Python 3.10+ is available.
2. Creates a virtual environment at `.venv/`.
3. Installs dependencies from `requirements.txt`.
4. Optionally installs `pystray` + `Pillow`.
5. Creates a `.desktop` shortcut if a graphical environment is detected.

Then run:

```bash
./job-tracker.sh
# or
python3 run.py
```

## Linux / macOS — manual

```bash
git clone https://github.com/rafaelkrause/job_tracker.git
cd job_tracker

python3 -m venv .venv
source .venv/bin/activate

pip install -r requirements.txt

# optional: tray support
pip install pystray Pillow

python3 run.py
```

Use `python3 run.py --no-browser` to skip auto-opening the browser.

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

## Build the installer from source

Only needed if you want to customize the Windows installer. Runs on a Linux host:

```bash
sudo apt install nsis
./installer/build_installer.sh 1.0.0
# output: installer/JobTracker-Setup-1.0.0.exe
```

The workflow `.github/workflows/build-installer.yml` does this automatically when a `v*` tag is pushed.

## Run at startup

### Linux — systemd (user unit)

Create `~/.config/systemd/user/job-tracker.service`:

```ini
[Unit]
Description=Job Tracker
After=network.target

[Service]
Type=simple
WorkingDirectory=%h/job_tracker
ExecStart=%h/job_tracker/.venv/bin/python run.py --no-browser
Restart=on-failure

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now job-tracker.service
```

### macOS — launchd

Create `~/Library/LaunchAgents/com.user.jobtracker.plist` with `<ProgramArguments>` pointing to `python` and `run.py`. Load with `launchctl load`.

### Windows — service via NSSM

The official installer offers this option. For manual installs, use [NSSM](https://nssm.cc/):

```powershell
nssm install JobTracker "C:\path\job_tracker\.venv\Scripts\python.exe" run.py --no-browser
nssm start JobTracker
```

## Update

### Linux / macOS

```bash
cd job_tracker
git pull
source .venv/bin/activate
pip install -r requirements.txt --upgrade
```

### Windows

Run the new `JobTracker-Setup-X.Y.Z.exe`. Data and configuration in `%APPDATA%\JobTracker` are preserved.

## Uninstall

- **Linux/macOS**: `rm -rf job_tracker/`. If applicable: `systemctl --user disable --now job-tracker.service`.
- **Windows**: Control Panel → Programs → Job Tracker → Uninstall.
- To also remove historical data: delete `data/` (Linux) or `%APPDATA%\JobTracker` (Windows).
