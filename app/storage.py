import json
import os
import sys
import tempfile
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Optional

from app.models import Activity


def _atomic_write_json(path: Path, data: dict):
    """Write JSON atomically: temp file + fsync + rename.

    Safe against crashes and power loss on both Linux and Windows.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=path.parent, suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_path, path)
        # Fsync directory to persist the rename (Linux only)
        if sys.platform != "win32":
            dir_fd = os.open(str(path.parent), os.O_RDONLY)
            try:
                os.fsync(dir_fd)
            finally:
                os.close(dir_fd)
    except BaseException:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


class Storage:
    def __init__(self, data_dir: Path):
        self.data_dir = data_dir
        self.data_dir.mkdir(exist_ok=True)

    def _file_for_date(self, dt: date) -> Path:
        return self.data_dir / f"{dt.strftime('%Y-%m')}.json"

    def _load_file(self, path: Path) -> list[dict]:
        if not path.exists():
            return []
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
            if not isinstance(data, dict):
                print(f"AVISO: formato inesperado em {path}", file=sys.stderr)
                return []
            return data.get("activities", [])
        except (json.JSONDecodeError, UnicodeDecodeError, OSError) as e:
            print(f"AVISO: arquivo corrompido {path}: {e}", file=sys.stderr)
            backup = path.with_suffix(".corrupted")
            try:
                if not backup.exists():
                    path.rename(backup)
                    print(f"  Backup salvo em {backup}", file=sys.stderr)
            except OSError:
                pass
            return []

    def _save_file(self, path: Path, activities: list[dict]):
        _atomic_write_json(path, {"activities": activities})

    def save_activity(self, activity: Activity):
        started = datetime.fromisoformat(activity.started_at).date()
        path = self._file_for_date(started)
        activities = self._load_file(path)
        for i, a in enumerate(activities):
            if a["id"] == activity.id:
                activities[i] = activity.to_dict()
                break
        else:
            activities.append(activity.to_dict())
        self._save_file(path, activities)

    def get_current_activity(self) -> Optional[Activity]:
        """Find any active or paused activity in recent months."""
        today = date.today()
        for month_offset in range(3):
            year = today.year
            month = today.month - month_offset
            if month <= 0:
                month += 12
                year -= 1
            path = self._file_for_date(date(year, month, 1))
            activities = self._load_file(path)
            for a in activities:
                if a["status"] in ("active", "paused"):
                    return Activity.from_dict(a)
        return None

    def find_activity(self, activity_id: str) -> Optional[Activity]:
        """Find an activity by ID across all monthly files."""
        for path in sorted(self.data_dir.glob("*.json"), reverse=True):
            for a in self._load_file(path):
                if a["id"] == activity_id:
                    return Activity.from_dict(a)
        return None

    def delete_activity(self, activity_id: str) -> bool:
        """Delete an activity by ID. Returns True if found and deleted."""
        for path in self.data_dir.glob("*.json"):
            activities = self._load_file(path)
            for i, a in enumerate(activities):
                if a["id"] == activity_id:
                    activities.pop(i)
                    self._save_file(path, activities)
                    return True
        return False

    def get_activities_for_date(self, dt: date) -> list[Activity]:
        path = self._file_for_date(dt)
        activities = self._load_file(path)
        result = []
        for a in activities:
            started = datetime.fromisoformat(a["started_at"]).date()
            if started == dt:
                result.append(Activity.from_dict(a))
        return result

    def get_activities_range(self, from_date: date, to_date: date) -> list[Activity]:
        result = []
        months_seen = set()
        current = from_date
        while current <= to_date:
            month_key = (current.year, current.month)
            if month_key not in months_seen:
                months_seen.add(month_key)
                path = self._file_for_date(current)
                activities = self._load_file(path)
                for a in activities:
                    started = datetime.fromisoformat(a["started_at"]).date()
                    if from_date <= started <= to_date:
                        result.append(Activity.from_dict(a))
            current += timedelta(days=1)
        result.sort(key=lambda a: a.started_at)
        return result

    def cleanup_old_data(self, months_to_keep: int = 12):
        """Remove data files older than months_to_keep months."""
        today = date.today()
        cutoff_year = today.year
        cutoff_month = today.month - months_to_keep + 1
        while cutoff_month <= 0:
            cutoff_month += 12
            cutoff_year -= 1
        cutoff = date(cutoff_year, cutoff_month, 1)

        for path in self.data_dir.glob("*.json"):
            try:
                file_date = date.fromisoformat(f"{path.stem}-01")
                if file_date < cutoff:
                    path.unlink()
            except (ValueError, OSError):
                pass  # skip non-standard filenames
