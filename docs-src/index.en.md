# Job Tracker

Lightweight, local hour-tracking tool built for agency professionals. Runs as a web server at `localhost:5000`, no database, with monthly JSON file storage.

!!! note "Language"
    The application UI is in pt-BR by default. The docs are bilingual: use the language selector at the top to switch between **English** and **Português (Brasil)**.

## Overview

| Topic | Description |
|---|---|
| [Installation](installation.md) | Install on Linux, macOS and Windows (script, manual, NSIS installer). |
| [User Guide](user-guide.md) | Activities, shifts, dashboard, export and API. |
| [Configuration](configuration.md) | Full reference of `config.json` and UI-editable options. |
| [API Reference](api.md) | All HTTP (REST) endpoints served by the local app. |
| [Troubleshooting](troubleshooting.md) | Common install and runtime errors. |
| [Contributing](contributing.md) | How to propose changes and open PRs. |
| [Language policy](language.md) | Why pt-BR + EN, and how to contribute translations. |

## Highlights

- `active → paused → active → completed` state machine; paused time is subtracted from total duration.
- Daily dashboard with timeline, shift-aware progress bar, and target percentage.
- Monthly JSON file storage (no ORM, no database).
- Configurable per-weekday shifts with multiple blocks (e.g. lunch break).
- CSV/TSV export for manual paste into iClips.
- Optional system tray via `pystray`.
- Auto-opens the browser on startup (disable with `--no-browser`).

## Quick links

- Source: [github.com/rafaelkrause/job_tracker](https://github.com/rafaelkrause/job_tracker)
- Releases: [GitHub Releases](https://github.com/rafaelkrause/job_tracker/releases)
- License: [MIT](https://github.com/rafaelkrause/job_tracker/blob/main/LICENSE)
