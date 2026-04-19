import io
import json
import random
import re
from datetime import date, datetime
from pathlib import Path

from flask import (
    Blueprint,
    current_app,
    jsonify,
    make_response,
    render_template,
    request,
    send_file,
)
from flask_babel import get_locale
from flask_babel import gettext as _

from app import SUPPORTED_LOCALES
from app.config import save_config
from app.export import export_activities
from app.models import Activity
from app.storage import Storage

bp = Blueprint("main", __name__)

# ── Validation helpers ────────────────────────────────────────────────

MAX_DESCRIPTION_LEN = 500
MAX_USERNAME_LEN = 100
_TIME_RE = re.compile(r"^\d{2}:\d{2}$")
_VALID_DAYS = {"monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"}
MAX_SHIFTS_PER_DAY = 10


def _get_json_body():
    """Get parsed JSON body or None."""
    return request.get_json(silent=True)


def _validate_time(t: str) -> bool:
    if not isinstance(t, str) or not _TIME_RE.match(t):
        return False
    h, m = int(t[:2]), int(t[3:])
    return 0 <= h <= 23 and 0 <= m <= 59


def _parse_date(s: str) -> date | None:
    try:
        return date.fromisoformat(s)
    except (ValueError, TypeError):
        return None


# Monotonic counter bumped on every state-changing action (start/pause/resume/stop).
# Browser tabs poll this to detect changes made from other sources (tray, other tabs).
_state_revision = 0


def _bump_revision():
    global _state_revision
    _state_revision += 1


def get_storage() -> Storage:
    return Storage(current_app.config["DATA_DIR"])


def get_config() -> dict:
    return current_app.config["APP_CONFIG"]


# ── Pages ──────────────────────────────────────────────────────────────


@bp.route("/")
def dashboard():
    config = get_config()
    return render_template(
        "dashboard.html",
        theme=config.get("theme", "auto"),
        user_name=config.get("user_name", ""),
    )


@bp.route("/focus")
def focus():
    """Opened by the tray icon. Tries to focus an existing tab; opens a new one if none exists."""
    return render_template("focus.html")


@bp.route("/settings")
def settings():
    config = get_config()
    return render_template("settings.html", theme=config.get("theme", "auto"), config=config)


# ── Activity API ───────────────────────────────────────────────────────


@bp.route("/api/activity/current")
def get_current():
    storage = get_storage()
    activity = storage.get_current_activity()
    if activity:
        return jsonify(
            {
                "activity": activity.to_dict(),
                "effective_duration": activity.effective_duration_formatted(),
                "effective_seconds": activity.effective_duration_seconds(),
            }
        )
    return jsonify({"activity": None})


@bp.route("/api/activity/start", methods=["POST"])
def start_activity():
    data = _get_json_body()
    if data is None:
        return jsonify({"error": _("Invalid request body")}), 400
    description = str(data.get("description", "")).strip()
    if not description:
        return jsonify({"error": _("Description is required")}), 400
    if len(description) > MAX_DESCRIPTION_LEN:
        return jsonify(
            {
                "error": _(
                    "Description too long (max %(max)d characters)",
                    max=MAX_DESCRIPTION_LEN,
                )
            }
        ), 400

    storage = get_storage()

    # Auto-stop current activity
    current = storage.get_current_activity()
    if current:
        current.stop()
        storage.save_activity(current)

    activity = Activity.create(description)
    storage.save_activity(activity)
    _bump_revision()
    return jsonify({"activity": activity.to_dict()}), 201


@bp.route("/api/activity/pause", methods=["POST"])
def pause_activity():
    storage = get_storage()
    current = storage.get_current_activity()
    if not current:
        return jsonify({"error": _("No active activity")}), 400
    try:
        current.pause()
        storage.save_activity(current)
        _bump_revision()
        return jsonify({"activity": current.to_dict()})
    except ValueError as e:
        return jsonify({"error": str(e)}), 400


@bp.route("/api/activity/resume", methods=["POST"])
def resume_activity():
    storage = get_storage()
    current = storage.get_current_activity()
    if not current:
        return jsonify({"error": _("No activity to resume")}), 400
    try:
        current.resume()
        storage.save_activity(current)
        _bump_revision()
        return jsonify({"activity": current.to_dict()})
    except ValueError as e:
        return jsonify({"error": str(e)}), 400


@bp.route("/api/activity/stop", methods=["POST"])
def stop_activity():
    storage = get_storage()
    current = storage.get_current_activity()
    if not current:
        return jsonify({"error": _("No active activity")}), 400
    try:
        current.stop()
        storage.save_activity(current)
        _bump_revision()
        return jsonify({"activity": current.to_dict()})
    except ValueError as e:
        return jsonify({"error": str(e)}), 400


# ── Activity Edit / Delete ─────────────────────────────────────────────


@bp.route("/api/activity/<activity_id>", methods=["PUT"])
def update_activity(activity_id):
    storage = get_storage()
    activity = storage.find_activity(activity_id)
    if not activity:
        return jsonify({"error": _("Activity not found")}), 404

    data = _get_json_body()
    if data is None:
        return jsonify({"error": _("Invalid request body")}), 400

    if "description" in data:
        desc = str(data["description"]).strip()
        if not desc:
            return jsonify({"error": _("Description is required")}), 400
        if len(desc) > MAX_DESCRIPTION_LEN:
            return jsonify(
                {
                    "error": _(
                        "Description too long (max %(max)d characters)",
                        max=MAX_DESCRIPTION_LEN,
                    )
                }
            ), 400
        activity.description = desc

    if "start_time" in data:
        if not _validate_time(data["start_time"]):
            return jsonify({"error": _("Invalid start time (HH:MM)")}), 400
        dt = datetime.fromisoformat(activity.started_at)
        h, m = int(data["start_time"][:2]), int(data["start_time"][3:])
        activity.started_at = dt.replace(hour=h, minute=m, second=0, microsecond=0).isoformat()

    if "end_time" in data and activity.ended_at:
        if not _validate_time(data["end_time"]):
            return jsonify({"error": _("Invalid end time (HH:MM)")}), 400
        dt = datetime.fromisoformat(activity.ended_at)
        h, m = int(data["end_time"][:2]), int(data["end_time"][3:])
        activity.ended_at = dt.replace(hour=h, minute=m, second=0, microsecond=0).isoformat()

    storage.save_activity(activity)
    _bump_revision()
    return jsonify(
        {
            "activity": activity.to_dict(),
            "effective_duration": activity.effective_duration_formatted(),
            "effective_seconds": activity.effective_duration_seconds(),
        }
    )


@bp.route("/api/activity/<activity_id>", methods=["DELETE"])
def delete_activity_api(activity_id):
    storage = get_storage()
    if not storage.find_activity(activity_id):
        return jsonify({"error": _("Activity not found")}), 404
    storage.delete_activity(activity_id)
    _bump_revision()
    return jsonify({"ok": True})


# ── Phrases (micro-recompensa em pausar/finalizar) ────────────────────

_PHRASES_DIR = Path(__file__).parent / "data"
_phrases_cache: dict[str, dict] = {}


def _load_phrases(locale: str) -> dict:
    name = "phrases_en.json" if locale.startswith("en") else "phrases_pt_br.json"
    if name not in _phrases_cache:
        with (_PHRASES_DIR / name).open(encoding="utf-8") as f:
            _phrases_cache[name] = json.load(f)
    return _phrases_cache[name]


@bp.route("/api/phrase/<category>")
def get_phrase(category):
    if not get_config().get("phrases_enabled", True):
        return jsonify({"phrase": None})
    locale = str(get_locale()) if get_locale() else "pt_BR"
    phrases = _load_phrases(locale).get(category, [])
    if not phrases:
        return jsonify({"phrase": None})
    return jsonify({"phrase": random.choice(phrases)})


# ── Language switch ────────────────────────────────────────────────────


@bp.post("/api/lang")
def set_lang():
    body = request.get_json(silent=True) or {}
    lang = body.get("lang")
    if lang not in SUPPORTED_LOCALES:
        return jsonify({"error": _("Unsupported language")}), 400
    resp = make_response("", 204)
    resp.set_cookie("jt-lang", lang, max_age=60 * 60 * 24 * 365, samesite="Lax")
    return resp


# ── Revision (for cross-client sync) ──────────────────────────────────


@bp.route("/api/revision")
def get_revision():
    return jsonify({"rev": _state_revision})


# ── Activities list ────────────────────────────────────────────────────


@bp.route("/api/activities")
def list_activities():
    date_str = request.args.get("date")
    from_str = request.args.get("from")
    to_str = request.args.get("to")

    storage = get_storage()

    if date_str:
        dt = _parse_date(date_str)
        if not dt:
            return jsonify({"error": _("Invalid date")}), 400
        activities = storage.get_activities_for_date(dt)
    elif from_str and to_str:
        from_date = _parse_date(from_str)
        to_date = _parse_date(to_str)
        if not from_date or not to_date:
            return jsonify({"error": _("Invalid dates")}), 400
        activities = storage.get_activities_range(from_date, to_date)
    else:
        activities = storage.get_activities_for_date(date.today())

    return jsonify(
        {
            "activities": [
                {
                    **a.to_dict(),
                    "effective_duration": a.effective_duration_formatted(),
                    "effective_seconds": a.effective_duration_seconds(),
                }
                for a in activities
            ]
        }
    )


# ── Dashboard data ─────────────────────────────────────────────────────


@bp.route("/api/dashboard")
def dashboard_data():
    date_str = request.args.get("date", date.today().isoformat())
    dt = _parse_date(date_str)
    if not dt:
        return jsonify({"error": _("Invalid date")}), 400

    storage = get_storage()
    config = get_config()

    activities = storage.get_activities_for_date(dt)

    day_name = dt.strftime("%A").lower()
    shifts = config.get("shifts", {}).get(day_name, [])

    # Calculate shift time using minutes to avoid timezone issues
    now = datetime.now()
    today = date.today()
    now_minutes = now.hour * 60 + now.minute

    total_shift_seconds = 0
    elapsed_shift_seconds = 0

    for shift in shifts:
        sp = shift["start"].split(":")
        ep = shift["end"].split(":")
        shift_start_min = int(sp[0]) * 60 + int(sp[1])
        shift_end_min = int(ep[0]) * 60 + int(ep[1])
        shift_duration = (shift_end_min - shift_start_min) * 60

        total_shift_seconds += shift_duration

        if dt == today:
            if now_minutes >= shift_end_min:
                elapsed_shift_seconds += shift_duration
            elif now_minutes >= shift_start_min:
                elapsed_shift_seconds += (now_minutes - shift_start_min) * 60
        elif dt < today:
            elapsed_shift_seconds += shift_duration

    tracked_seconds = sum(a.effective_duration_seconds() for a in activities)

    percentage = (tracked_seconds / elapsed_shift_seconds * 100) if elapsed_shift_seconds > 0 else 0
    target = config.get("target_percentage", 90)

    return jsonify(
        {
            "date": dt.isoformat(),
            "day_name": day_name,
            "activities": [
                {
                    **a.to_dict(),
                    "effective_duration": a.effective_duration_formatted(),
                    "effective_seconds": a.effective_duration_seconds(),
                }
                for a in activities
            ],
            "shifts": shifts,
            "total_shift_seconds": total_shift_seconds,
            "elapsed_shift_seconds": elapsed_shift_seconds,
            "tracked_seconds": tracked_seconds,
            "percentage": round(percentage, 1),
            "target_percentage": target,
        }
    )


# ── Export ──────────────────────────────────────────────────────────────


@bp.route("/api/export")
def export():
    from_str = request.args.get("from")
    to_str = request.args.get("to")
    fmt = request.args.get("format", "csv")

    if not from_str or not to_str:
        return jsonify({"error": _("Parameters 'from' and 'to' are required")}), 400

    from_date = _parse_date(from_str)
    to_date = _parse_date(to_str)
    if not from_date or not to_date:
        return jsonify({"error": _("Invalid dates")}), 400
    if (to_date - from_date).days > 366:
        return jsonify({"error": _("Maximum export range: 1 year")}), 400
    if fmt not in ("csv", "tsv"):
        return jsonify({"error": _("Invalid format (csv or tsv)")}), 400

    storage = get_storage()
    activities = storage.get_activities_range(from_date, to_date)

    content, mimetype, filename = export_activities(activities, fmt, from_date, to_date)

    return send_file(
        io.BytesIO(content.encode("utf-8")),
        mimetype=mimetype,
        as_attachment=True,
        download_name=filename,
    )


# ── Config API ─────────────────────────────────────────────────────────


@bp.route("/api/config", methods=["GET"])
def get_config_api():
    return jsonify(get_config())


@bp.route("/api/config", methods=["PUT"])
def update_config():
    data = _get_json_body()
    if data is None:
        return jsonify({"error": _("Invalid request body")}), 400

    config = get_config()
    allowed = {"user_name", "target_percentage", "port", "phrases_enabled", "theme"}

    for key in data:
        if key not in allowed:
            continue
        val = data[key]
        if key == "user_name":
            val = str(val).strip()[:MAX_USERNAME_LEN]
        elif key == "target_percentage":
            try:
                val = max(0, min(100, int(val)))
            except (ValueError, TypeError):
                return jsonify({"error": _("Invalid target percentage")}), 400
        elif key == "port":
            try:
                val = int(val)
                if not (1024 <= val <= 65535):
                    return jsonify({"error": _("Invalid port (1024-65535)")}), 400
            except (ValueError, TypeError):
                return jsonify({"error": _("Invalid port")}), 400
        elif key == "phrases_enabled":
            val = bool(val)
        elif key == "theme" and val not in ("auto", "light", "dark"):
            return jsonify({"error": _("Invalid theme")}), 400
        config[key] = val

    save_config(config, current_app.config["CONFIG_PATH"])
    current_app.config["APP_CONFIG"] = config
    return jsonify(config)


@bp.route("/api/shifts", methods=["GET"])
def get_shifts():
    config = get_config()
    return jsonify(config.get("shifts", {}))


@bp.route("/api/shifts", methods=["PUT"])
def update_shifts():
    data = _get_json_body()
    if not isinstance(data, dict):
        return jsonify({"error": _("Invalid request body")}), 400

    validated = {}
    for day in _VALID_DAYS:
        shifts = data.get(day, [])
        if not isinstance(shifts, list) or len(shifts) > MAX_SHIFTS_PER_DAY:
            return jsonify({"error": _("Invalid shifts for %(day)s", day=day)}), 400
        day_shifts = []
        for s in shifts:
            if not isinstance(s, dict):
                return jsonify({"error": _("Invalid shift in %(day)s", day=day)}), 400
            start = s.get("start", "")
            end = s.get("end", "")
            if not _validate_time(start) or not _validate_time(end):
                return jsonify({"error": _("Invalid time in %(day)s", day=day)}), 400
            day_shifts.append({"start": start, "end": end})
        validated[day] = day_shifts

    config = get_config()
    config["shifts"] = validated
    save_config(config, current_app.config["CONFIG_PATH"])
    current_app.config["APP_CONFIG"] = config
    return jsonify(config["shifts"])
