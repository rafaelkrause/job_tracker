# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Internal hour-tracking tool for a marketing agency professional. Runs as a background process serving a local web UI at `localhost:5000`. Designed for single-user, low-footprint operation on Linux and Windows. Data exports are formatted for manual paste into iClips (no API available). UI is pt-BR.

## Running

```bash
# Dev (Linux/macOS)
pip install -r requirements.txt
python3 run.py                  # opens browser
python3 run.py --no-browser     # headless

# Optional system tray
pip install pystray Pillow

# Helper script
./job-tracker.sh

# Full install
./install.sh
```

Windows: NSIS installer (`installer/build_installer.sh X.Y.Z` → `JobTracker-Setup-X.Y.Z.exe`). Per-user install to `%LOCALAPPDATA%\Programs\JobTracker`, data under `%APPDATA%\JobTracker`, embedded Python runtime bundled. Optional NSSM-based Windows service component.

## Stack

- **Backend:** Flask 3.0+ (no ORM, no database)
- **Frontend:** Bootstrap 5.3 (CDN) + vanilla JS
- **Persistence:** JSON files partitioned by month (`data/YYYY-MM.json`)
- **Config:** `config.json` in the user data dir
- **Tray:** optional `pystray` + `Pillow` (graceful fallback if absent)
- **Python:** 3.10+

## Architecture

**Entry point:** `run.py` — starts Flask server. If pystray is available, Flask runs in a daemon thread and pystray owns the main thread. Otherwise Flask runs in the main thread and the browser is auto-opened (unless `--no-browser`).

**User data dir resolution (`app/__init__.py::get_user_data_dir`):**
1. `$JOBTRACKER_DATA_DIR` (set by the Windows installer / service wrapper)
2. Project root (dev mode)

Resolves to `config.json` + `data/` under that directory.

**Backend modules:**
- `app/__init__.py` — Flask app factory, user-data-dir resolution, 64 KB body limit, startup data pruning.
- `app/models.py` — `Activity` and `Pause` dataclasses with state machine (active → paused → active → completed). Effective duration = wall-clock − pause intervals.
- `app/storage.py` — `Storage` class reads/writes monthly JSON. Activities filed by start-date month. `get_current_activity()` scans the last 3 months for any non-completed activity. `find_activity()` / `delete_activity()` / `cleanup_old_data()`.
- `app/config.py` — loads/saves `config.json` with defaults (shifts, target %, port, theme, user_name, phrases_enabled).
- `app/routes.py` — all Flask routes. REST API under `/api/`, HTML pages at `/`, `/focus`, `/settings`. Holds the in-process `_state_revision` counter.
- `app/export.py` — CSV/TSV export. Only exports completed activities.
- `app/tray.py` — optional system tray; pause/resume/stop via HTTP to the local Flask server.
- `app/data/phrases.json` — bundled micro-reward phrases served by `/api/phrase/<category>`.

**Frontend:** Single-page-like.
- `app/templates/` — `base.html`, `dashboard.html`, `settings.html`, `focus.html` (opened by tray to focus/re-open the dashboard tab).
- `app/static/js/app.js` — polling (current activity every 30s + revision check for cross-client sync), local-increment timer, timeline rendering, theme toggle (localStorage key `jt-theme`).
- `app/static/css/style.css`.

**Installer / packaging:**
- `installer/installer.nsi` — NSIS script. `installer/build_installer.sh` builds from a Linux host.
- `installer/resources/job-tracker-silent.vbs` — silent launcher used by the Windows shortcut.
- `.github/workflows/build-installer.yml` — CI build of the Windows installer.
- `.github/workflows/docs.yml` — builds and deploys the MkDocs site to GitHub Pages.

**Docs:**
- `docs-src/` — MkDocs Material source (bilingual via mkdocs-static-i18n, default pt-BR).
- Published at https://rafaelkrause.github.io/job_tracker/ by `.github/workflows/docs.yml`.
- Local preview: `mkdocs serve`.
- `README.md` — project overview.

## Key API endpoints

```
GET    /                               dashboard HTML
GET    /focus                          tray-triggered "focus existing tab" page
GET    /settings                       settings HTML

POST   /api/activity/start             body: {"description": "..."} — auto-stops current
POST   /api/activity/pause
POST   /api/activity/resume
POST   /api/activity/stop
GET    /api/activity/current
PUT    /api/activity/<id>              edit description / start_time / end_time
DELETE /api/activity/<id>

GET    /api/activities?date=YYYY-MM-DD
GET    /api/activities?from=YYYY-MM-DD&to=YYYY-MM-DD
GET    /api/dashboard?date=YYYY-MM-DD
GET    /api/export?from=...&to=...&format=csv|tsv   (max range: 1 year)

GET    /api/config
PUT    /api/config                     allowed: user_name, target_percentage, port, phrases_enabled, theme
GET    /api/shifts
PUT    /api/shifts

GET    /api/phrase/<category>          returns {"phrase": null} if disabled
GET    /api/revision                   monotonic counter; clients poll to detect external state changes
```

## Design decisions

- Starting a new activity auto-finalizes the current one (no blocking prompts).
- Shift-elapsed % only counts time already passed in the current day (doesn't penalize future hours).
- Dashboard timeline range is derived from the day's shift config with 30 min padding.
- All timestamps stored as ISO 8601 with timezone offset. Effective duration = wall-clock − pause intervals.
- Monthly JSON partitioning keeps files small and hand-inspectable.
- Data files older than 12 months are pruned on startup.
- `_state_revision` is a monotonic in-process counter, bumped by every state-changing action (start/pause/resume/stop/edit/delete). Browser tabs poll `/api/revision` to detect changes made by other tabs or the tray.
- `/focus` endpoint lets the tray click re-focus an already-open tab instead of opening a new one.

## Data safety

- All JSON writes (data + config) are **atomic**: write temp file → fsync → `os.replace()`. Safe against crashes and power loss. On Linux, the containing directory is fsynced after rename.
- Corrupted JSON files are detected on load, renamed to `.corrupted` for manual recovery; the app continues with empty data for that month.
- Request body limited to 64 KB (`MAX_CONTENT_LENGTH`).
- Input validation: description ≤ 500 chars, user_name ≤ 100 chars, time `HH:MM` validated, dates validated, config keys whitelisted, shift structure validated (≤ 10 shifts/day), port in `1024–65535`, target_percentage in `0–100`, theme ∈ {auto, light, dark}, export range ≤ 1 year.

## Language

- **Codebase**: English only (identifiers, comments, docstrings, logs, tests).
- **Application UI**: bilingual EN + pt-BR via Flask-Babel. Default locale `pt_BR`. Locale resolution: `jt-lang` cookie → `Accept-Language` header → default.
- **Documentation**: bilingual (pt-BR default, EN variants under `docs/en/` and `wiki/*-EN.md`).

Translation workflow:
- Extract: `pybabel extract -F app/i18n/babel.cfg -o app/i18n/messages.pot .`
- Update catalogs: `pybabel update -i app/i18n/messages.pot -d app/i18n`
- Compile: `pybabel compile -d app/i18n`
- Add a new language: `pybabel init -i app/i18n/messages.pot -d app/i18n -l <code>`

Note: `.mo` files are generated (not committed) and must be compiled before packaging or running the app.
