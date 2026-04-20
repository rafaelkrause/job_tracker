# API Reference

HTTP endpoints served by the local Job Tracker. All relative to `http://localhost:5000` (or the port configured in `config.json`).

## Conventions

- Content type: `application/json` (except CSV/TSV export).
- Dates: `YYYY-MM-DD` (ISO 8601, date only).
- Times: `HH:MM` (24h).
- Internal timestamps: ISO 8601 with timezone offset (`2026-04-19T14:32:10-03:00`).
- Max body size: **64 KB** (`MAX_CONTENT_LENGTH`).
- Errors return JSON `{"error": "description"}` with one of the codes listed at the end.

## HTML pages

| Route | Description |
|---|---|
| `GET /` | Main dashboard. |
| `GET /focus` | Triggered by the tray to re-focus an existing tab instead of opening a new one. |
| `GET /settings` | Settings page (shifts, theme, target, etc). |

## Activities

### `POST /api/activity/start`

Starts a new activity. If another one is in progress (active or paused), it is **finalized automatically** first.

**Body**

```json
{ "description": "Client XYZ meeting" }
```

**Validation**

- `description` required, string, up to 500 chars.

**Response `201`**

```json
{
  "id": "a1b2c3",
  "description": "Client XYZ meeting",
  "start": "2026-04-19T09:00:00-03:00",
  "state": "active",
  "pauses": []
}
```

### `POST /api/activity/pause`

Pauses the current activity. No body. `404` if none is active.

### `POST /api/activity/resume`

Resumes a paused activity. No body. `404` if none is paused.

### `POST /api/activity/stop`

Finalizes the current activity (active or paused). No body.

### `GET /api/activity/current`

Returns the in-progress activity (`active` or `paused`), or `null` if none.

```json
{
  "id": "a1b2c3",
  "description": "Client XYZ meeting",
  "start": "2026-04-19T09:00:00-03:00",
  "state": "active",
  "pauses": [
    {"start": "2026-04-19T09:10:00-03:00", "end": "2026-04-19T09:15:00-03:00"}
  ],
  "duration_minutes": 25
}
```

!!! note
    `duration_minutes` = elapsed time (so far) minus paused time.

### `PUT /api/activity/<id>`

Edits an existing activity. Accepted body fields: `description`, `start_time`, `end_time`.

```json
{
  "description": "Client ABC meeting",
  "start_time": "09:15",
  "end_time": "10:30"
}
```

- `start_time` / `end_time` in `HH:MM`; applied to the activity's same day.
- `404` if the id does not exist.

### `DELETE /api/activity/<id>`

Removes the activity from history. `204` response with no body.

## Listings

### `GET /api/activities`

Query parameters:

- `date=YYYY-MM-DD` — activities for a single day.
- `from=YYYY-MM-DD&to=YYYY-MM-DD` — range (inclusive). Max 1 year.

Returns array of activities (chronological).

### `GET /api/dashboard?date=YYYY-MM-DD[&period=day|week|month]`

Aggregated data for a day, week, or month. Defaults: `date` = today, `period` = `day`.

Parameters:

- `date` — anchor date (ISO `YYYY-MM-DD`). In `week` and `month` it just identifies which week/month.
- `period` — aggregation granularity:
    - `day` (default): single day.
    - `week`: Monday through Sunday (ISO) containing `date`.
    - `month`: calendar month of `date`.

`elapsed_shift_seconds` rule: past days count their full shift; today counts up to `now`; future days count zero. `shifts` and `day_name` are only populated in `day` mode (the hourly timeline renders only in that mode).

```json
{
  "date": "2026-04-20",
  "period": "week",
  "from_date": "2026-04-20",
  "to_date": "2026-04-26",
  "day_name": null,
  "activities": [ /* activities in the range (chronological) */ ],
  "shifts": [],
  "total_shift_seconds": 104400,
  "elapsed_shift_seconds": 21780,
  "tracked_seconds": 14400,
  "percentage": 66.1,
  "target_percentage": 90
}
```

## Export

### `GET /api/export?from=YYYY-MM-DD&to=YYYY-MM-DD&format=csv|tsv`

Exports **completed** activities in the range, in the requested format (`csv` or `tsv`). Max range: **1 year**.

Response `200` with:

- `Content-Type: text/csv` or `text/tab-separated-values`
- `Content-Disposition: attachment; filename="jobtracker_YYYY-MM-DD_YYYY-MM-DD.csv"`

Fields: date, description, start, end, duration (minutes).

## Configuration

### `GET /api/config`

Returns the current config object (includes `user_name`, `target_percentage`, `port`, `phrases_enabled`, `theme`).

### `PUT /api/config`

Updates fields. Allowed keys:

- `user_name` (string, ≤ 100 chars)
- `target_percentage` (0–100)
- `port` (1024–65535)
- `phrases_enabled` (boolean)
- `theme` (`auto` | `light` | `dark`)

Unknown keys are ignored.

### `GET /api/shifts`

Returns the current `shifts` object.

### `PUT /api/shifts`

Replaces all shifts. Body must contain the complete `shifts` object (7 days, up to 10 blocks per day).

## Utilities

### `GET /api/phrase/<category>`

Returns a random micro-phrase for display on the dashboard. Categories per `app/data/phrases.*.json` (e.g. `start`, `pause`, `resume`, `stop`).

Returns `{"phrase": null}` if `phrases_enabled` is disabled.

### `POST /api/lang`

Switches the UI language. Body:

```json
{ "lang": "pt_BR" }
```

or

```json
{ "lang": "en" }
```

Sets the `jt-lang` cookie. The next render uses the chosen language.

### `GET /api/revision`

Monotonic counter incremented on every state change (start/pause/resume/stop/edit/delete). Clients poll this endpoint to detect changes made by another tab or the tray without a full refresh.

```json
{ "revision": 42 }
```

## Error codes

| Code | Meaning |
|---|---|
| `400` | Invalid body, malformed date/time, missing field |
| `404` | Activity not found in the expected state |
| `413` | Body over 64 KB |
| `500` | Internal error (check server logs) |

## `curl` examples

```bash
# Start
curl -X POST http://localhost:5000/api/activity/start \
     -H "Content-Type: application/json" \
     -d '{"description": "Client email"}'

# Pause
curl -X POST http://localhost:5000/api/activity/pause

# Current activity
curl http://localhost:5000/api/activity/current

# Day's dashboard
curl "http://localhost:5000/api/dashboard?date=2026-04-19"

# Export week as TSV
curl "http://localhost:5000/api/export?from=2026-04-14&to=2026-04-19&format=tsv" \
     -o week.tsv

# Switch language
curl -X POST http://localhost:5000/api/lang \
     -H "Content-Type: application/json" \
     -d '{"lang": "en"}' -c cookies.txt
```
