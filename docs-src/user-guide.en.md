# User Guide

This guide covers the full Job Tracker flow: concepts, activities, dashboard, shifts, export and API.

!!! note
    The UI strings are in Brazilian Portuguese (pt-BR) by default. You can switch to English via the language dropdown in the UI (it sets the `jt-lang` cookie). This guide translates the concepts and button labels for English-speaking readers.

## First run

1. Start the server: `python3 run.py` (or `./job-tracker.sh`).
2. The browser opens at `http://localhost:5000`.
3. On first run a `config.json` is created with sensible defaults (shifts 09–12 / 13–18 Mon–Fri, auto theme, port 5000, 90% target).
4. Tune shifts and preferences under **Configurações** (Settings).

## Concepts

| Concept | Description |
|---|---|
| **Activity** | A block of work with description, start, pauses and end. |
| **Pause** | Interval inside an activity. Paused time is subtracted from total duration. |
| **Shift** | Expected working hours per weekday, with multiple blocks possible. |
| **Target %** | How much of the shift you plan to log as productive activity. |
| **State** | State machine: `active → paused → active → completed`. |

## Activities

### Start

Type the description and click **Iniciar** (Start). If another activity is running, it gets finalized automatically — no blocking prompt. Switching tasks is a single gesture.

### Pause / Resume

Use **Pausar** / **Retomar**. The timer stops/resumes; total duration is always elapsed time minus paused time.

### Stop

Click **Parar** (Stop). The activity becomes `completed` and joins the day's history, ready for export.

### Edit / Delete

Via the UI or `PUT /api/activity/<id>` (description, start/end time) and `DELETE /api/activity/<id>`.

### Limits

- Description: up to 500 characters
- Request body: up to 64 KB
- Time format: `HH:MM` (24h), server-validated

## Dashboard

The dashboard has three modes, chosen via the **Day / Week / Month** selector next to the date navigation:

- **Day** (default) — timeline, today's shift, and the day's activities.
- **Week** — Monday through Sunday of the selected date. Chevrons jump ±7 days.
- **Month** — calendar month of the selected date. Chevrons jump ±1 month.

The chosen mode is remembered across sessions (localStorage `jt-period`); the date resets to today on each reload.

What the dashboard shows:

- **Timeline** (Day only) — each activity placed at its real start/end time. The range is derived from the day's shift + 30 min padding on each side.
- **Current activity** — description and timer. The frontend increments the counter locally between polls (30s) to feel instant.
- **Tracked hours** (`Tracked`) — effective sum of activities in the period (excluding pauses).
- **Shift** — in Day mode, how much of today's shift has elapsed; in Week/Month, the total configured shift hours for the period.
- **Target** — percentage of tracked over **elapsed** shift time (past days count fully, today counts up to now, future days count 0). This rule prevents future hours from dragging progress down.
- **Activity table** — chronological order. In Week/Month a **Date** column is shown.

## Shifts

Each weekday can have zero, one, or more time blocks. Default:

```json
{
  "monday":    [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
  "tuesday":   [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
  "wednesday": [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
  "thursday":  [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
  "friday":    [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
  "saturday":  [],
  "sunday":    []
}
```

Edit via UI under **Configurações → Turnos** or directly in `config.json`.

## System tray

A tray icon appears with:

- Pause / Resume
- Stop
- Open in browser
- Quit

Tray actions talk to Flask over local HTTP — the same API the UI uses.

On pure GNOME desktops, the **AppIndicator** extension is required. On headless servers (no window manager) the app detects the missing tray and just runs the web server.

## Export

Spreadsheet format (CSV/TSV) for pasting into external time-entry systems that don't expose a public API.

- **UI**: **Exportar** (Export) page → pick date range + format (CSV/TSV) → Download.
- **API**: `GET /api/export?from=YYYY-MM-DD&to=YYYY-MM-DD&format=tsv`.
- Only **completed** activities are exported. Running or paused ones are skipped.
- Max range: 1 year.

## Where data lives

| Platform | Path |
|---|---|
| Linux / macOS | `data/YYYY-MM.json` in the project folder |
| Windows (installer) | `%APPDATA%\JobTracker\data\YYYY-MM.json` |

One file per month keeps each JSON small and inspectable by hand. Files older than 12 months are pruned automatically on startup.

If a JSON is corrupted on load, the app renames it to `.corrupted` and continues with an empty state for that month — you can recover manually.

Writes are **atomic**: temp file → `fsync` → `os.replace()`. Safe against crashes and power loss.

## Tips

- Keep a browser tab open on the dashboard.
- Use the tray to pause quickly without switching windows.
- Short, consistent descriptions make weekly logging into your spreadsheet / external system easier.
- Set up a system keyboard shortcut to focus the Job Tracker tab.
- When running as a service (`systemd` / NSSM), use `--no-browser`.
- For backup, periodically copy the `data/` folder. It's plain JSON.
