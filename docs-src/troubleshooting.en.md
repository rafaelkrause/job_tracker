# Troubleshooting

Common errors and how to fix them.

## Installation

### `ModuleNotFoundError: No module named 'flask'`

You're probably outside the virtual environment.

```bash
# Linux / macOS
source .venv/bin/activate

# Windows (PowerShell)
.venv\Scripts\Activate.ps1
```

### `python3: command not found` (Linux/macOS)

Install Python 3.10+:

```bash
# Ubuntu/Debian
sudo apt install python3 python3-venv python3-pip

# macOS (Homebrew)
brew install python@3.11
```

### `install.sh: Permission denied`

Make it executable:

```bash
chmod +x install.sh job-tracker.sh
```

### SmartScreen blocks the Windows installer

The `.exe` is not code-signed. Click **More info → Run anyway**. It's safe — the code is open and can be audited on the repo.

## Runtime

### Port 5000 in use

Typical message: `OSError: [Errno 98] Address already in use`.

Change the port in `config.json`:

```json
{ "port": 5050 }
```

Or identify and kill the process:

```bash
# Linux / macOS
lsof -i :5000
kill <PID>

# Windows (PowerShell)
Get-NetTCPConnection -LocalPort 5000
Stop-Process -Id <PID>
```

### The browser does not open automatically

Navigate manually to `http://localhost:5000`. To disable auto-opening:

```bash
python3 run.py --no-browser
```

### Tray icon does not appear

1. Make sure `pystray` and `Pillow` are installed in the venv:

    ```bash
    pip install pystray Pillow
    ```

2. On **pure GNOME** (Ubuntu 22.04+), install the **AppIndicator and KStatusNotifierItem Support** extension.
3. On Windows, check the "hidden icons" area of the tray.

## Data

### Corrupted JSON

If a `data/YYYY-MM.json` is corrupted, the app renames it to `.corrupted` and continues with an empty state for that month. To recover:

1. Stop the server.
2. Inspect the `.corrupted` file with an editor.
3. Fix it manually and rename back to `.json`.
4. Restart the server.

### File doesn't update

Writes are atomic and use `os.replace()`. If the file still does not change:

- Check permissions on the `data/` folder.
- Check free disk space.
- Look at server logs (stdout) for I/O errors.

### I lost `config.json`

No problem — it's regenerated with defaults on next startup. Your historical data in `data/` is untouched.

## Tray / service

### systemd service does not start

```bash
systemctl --user status job-tracker.service
journalctl --user -u job-tracker.service -n 50
```

Common causes:

- Wrong absolute path in `WorkingDirectory` / `ExecStart`.
- Forgot to run `systemctl --user daemon-reload` after editing.
- venv not where expected.

### Windows service does not start

In Services Manager (`services.msc`), check the "Job Tracker" status. If using NSSM:

```powershell
nssm status JobTracker
nssm edit JobTracker
```

and fix the executable path.

## Export

### CSV looks broken in Brazilian Excel

Brazilian Excel expects `;` as separator. Prefer **TSV** and paste straight into cells:

```
/api/export?format=tsv
```

### iClips rejects the paste

Make sure the correct cell range is selected before pasting. If needed, open the TSV in a spreadsheet first and copy from there.

## Still stuck?

- Open an issue: [github.com/rafaelkrause/job_tracker/issues](https://github.com/rafaelkrause/job_tracker/issues)
- Include: OS, Python version, server log snippet, and reproduction steps.
