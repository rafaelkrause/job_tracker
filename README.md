# Job Tracker

A lightweight, self-hosted hour-tracking tool that runs as a background process and serves a local web UI at `http://localhost:5000`. Built for single-user, low-footprint use on Linux and Windows. The UI is in Brazilian Portuguese (pt-BR); exports are formatted for manual paste into iClips.

📘 **Documentation / Documentação:** [rafaelkrause.github.io/job_tracker](https://rafaelkrause.github.io/job_tracker/) (pt-BR + English)

## Features

- Start / pause / resume / stop activities with a state machine that subtracts pause intervals from wall-clock time
- Daily dashboard with a timeline, shift-aware progress, and target percentage
- Monthly JSON storage (no database, no ORM) — one file per month under `data/`
- Configurable weekly shifts, port, theme (light / dark / auto), and target percentage
- CSV / TSV export for completed activities over a date range
- Optional system tray with pause / resume / stop actions (via `pystray`)
- Auto-opens the browser on startup (disable with `--no-browser`)

## Requirements

- Python 3.10+
- Flask 3.0+
- *(optional)* `pystray` and `Pillow` for system tray support

## Language / Idioma

The application UI and documentation are **bilingual** (English + Brazilian Portuguese, default `pt-BR`). The codebase itself (identifiers, comments, docstrings) is in English.

A aplicação e a documentação são **bilíngues** (inglês + português do Brasil, default `pt-BR`). O código-fonte (identificadores, comentários, docstrings) é em inglês.

## Installation

### Linux / macOS

```bash
git clone https://github.com/<your-user>/job_tracker.git
cd job_tracker
./install.sh
```

Or with the modern packaging workflow:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[tray]"            # runtime + tray
# For development:
pip install -e ".[dev,tray]"
```

Once installed, the `job-tracker` command is on your PATH:

```bash
job-tracker --no-browser
```

### Windows

Use the NSIS installer (`JobTracker-Setup-X.Y.Z.exe`). Per-user install to `%LOCALAPPDATA%\Programs\JobTracker`; data lives in `%APPDATA%\JobTracker`. Bundles an embedded Python runtime — no system Python required. The wizard offers desktop / Start Menu shortcuts and an optional Windows service component (NSSM-based; UAC prompt only if enabled).

To build the installer from source (Linux host):

```bash
sudo apt install nsis
./installer/build_installer.sh 1.0.0
# → installer/JobTracker-Setup-1.0.0.exe
```

## Running

```bash
python3 run.py               # starts the server and opens the browser
python3 run.py --no-browser  # starts the server without opening a browser
```

The server listens on `http://127.0.0.1:5000` by default. If `pystray` is installed, the tray icon owns the main thread and Flask runs in a daemon thread; otherwise Flask runs in the foreground.

A `job-tracker.sh` helper is included for launching from the Linux shell.

## Configuration

On first run a `config.json` is created at the project root with sensible defaults. Edit it directly or use the `/settings` page in the web UI.

```json
{
  "shifts": {
    "monday":    [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "tuesday":   [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "wednesday": [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "thursday":  [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "friday":    [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "saturday":  [],
    "sunday":    []
  },
  "theme": "auto",
  "port": 5000,
  "target_percentage": 90
}
```

## Data layout

- `data/YYYY-MM.json` — one file per month, holding that month's activities
- `config.json` — user configuration, auto-generated on first run

Both are gitignored; your activity history stays local.

## API reference

```
POST /api/activity/start      body: {"description": "..."}  (auto-stops any running activity)
POST /api/activity/pause
POST /api/activity/resume
POST /api/activity/stop
GET  /api/activity/current
GET  /api/dashboard?date=YYYY-MM-DD
GET  /api/export?from=YYYY-MM-DD&to=YYYY-MM-DD&format=csv|tsv
GET  /api/shifts
PUT  /api/shifts
PUT  /api/config
```

## Project layout

```
job_tracker/
├── run.py                 # entry point
├── requirements.txt
├── config.json            # user config (auto-generated, gitignored)
├── data/                  # monthly activity JSON (gitignored)
└── app/
    ├── __init__.py        # Flask app factory
    ├── config.py          # config load/save with defaults
    ├── models.py          # Activity / Pause dataclasses + state machine
    ├── storage.py         # monthly JSON persistence
    ├── routes.py          # REST API + HTML pages
    ├── export.py          # CSV/TSV export
    ├── tray.py            # optional pystray integration
    ├── static/
    └── templates/
```

## Design notes

- Starting a new activity auto-finalizes the current one — no blocking prompts.
- Shift-elapsed % only counts time already passed in the current day, so future hours don't drag the progress bar down.
- The dashboard timeline range is derived from the day's shift configuration with 30-minute padding.
- All timestamps are stored as ISO 8601 with a timezone offset; duration is wall-clock minus pause intervals.
- Monthly partitioning keeps individual JSON files small and easy to inspect by hand.

## License

[MIT](LICENSE) © 2026 Rafael Krause
