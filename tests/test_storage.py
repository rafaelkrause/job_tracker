"""Tests for the monthly-JSON Storage layer."""

from __future__ import annotations

import json
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import pytest

from app.models import Activity
from app.storage import Storage


@pytest.fixture
def data_dir(tmp_path: Path) -> Path:
    d = tmp_path / "data"
    d.mkdir()
    return d


def _make_activity(description: str = "task", started_at: str | None = None) -> Activity:
    a = Activity.create(description)
    if started_at:
        a.started_at = started_at
    return a


def test_save_and_reload_activity(data_dir: Path):
    storage = Storage(data_dir)
    a = _make_activity("round-trip")
    storage.save_activity(a)

    other = Storage(data_dir)
    found = other.find_activity(a.id)
    assert found is not None
    assert found.description == "round-trip"
    assert found.id == a.id


def test_atomic_write_leaves_original_intact_on_failure(
    data_dir: Path, monkeypatch: pytest.MonkeyPatch
):
    storage = Storage(data_dir)
    a = _make_activity("original")
    storage.save_activity(a)

    original_path = data_dir / f"{datetime.fromisoformat(a.started_at).strftime('%Y-%m')}.json"
    original_bytes = original_path.read_bytes()

    import app.storage as storage_mod

    def boom(*args, **kwargs):
        raise OSError("disk full")

    monkeypatch.setattr(storage_mod.os, "replace", boom)

    a.description = "corrupted"
    with pytest.raises(OSError):
        storage.save_activity(a)

    assert original_path.read_bytes() == original_bytes
    leftover = list(data_dir.glob("*.tmp"))
    assert leftover == []


def test_corrupted_json_is_quarantined(data_dir: Path):
    bad = data_dir / "2026-01.json"
    bad.write_text("{not valid json", encoding="utf-8")

    storage = Storage(data_dir)
    result = storage._load_file(bad)

    assert result == []
    assert (data_dir / "2026-01.corrupted").exists()


def test_get_current_activity_returns_non_completed(data_dir: Path):
    storage = Storage(data_dir)
    done = _make_activity("done")
    done.stop()
    storage.save_activity(done)

    running = _make_activity("running")
    storage.save_activity(running)

    current = storage.get_current_activity()
    assert current is not None
    assert current.id == running.id


def test_get_current_activity_returns_none_when_all_done(data_dir: Path):
    storage = Storage(data_dir)
    a = _make_activity()
    a.stop()
    storage.save_activity(a)
    assert storage.get_current_activity() is None


def test_find_activity_returns_none_for_unknown(data_dir: Path):
    storage = Storage(data_dir)
    assert storage.find_activity("nope") is None


def test_delete_activity_removes_entry(data_dir: Path):
    storage = Storage(data_dir)
    a = _make_activity("to-delete")
    storage.save_activity(a)
    assert storage.delete_activity(a.id) is True
    assert storage.find_activity(a.id) is None


def test_delete_returns_false_when_missing(data_dir: Path):
    storage = Storage(data_dir)
    assert storage.delete_activity("missing") is False


def test_activity_is_filed_by_start_month(data_dir: Path):
    storage = Storage(data_dir)
    started = datetime(2026, 3, 15, 10, 0, 0, tzinfo=timezone.utc).isoformat()
    a = _make_activity("march-activity", started_at=started)
    storage.save_activity(a)

    march_file = data_dir / "2026-03.json"
    assert march_file.exists()
    payload = json.loads(march_file.read_text(encoding="utf-8"))
    assert payload["activities"][0]["id"] == a.id


def test_cleanup_removes_old_files_only(data_dir: Path):
    old = data_dir / "2020-01.json"
    old.write_text(json.dumps({"activities": []}), encoding="utf-8")
    recent_dt = date.today() - timedelta(days=10)
    recent = data_dir / f"{recent_dt.strftime('%Y-%m')}.json"
    recent.write_text(json.dumps({"activities": []}), encoding="utf-8")

    Storage(data_dir).cleanup_old_data(months_to_keep=12)
    assert not old.exists()
    assert recent.exists()


def test_activities_range_inclusive_of_endpoints(data_dir: Path):
    storage = Storage(data_dir)
    for day in (5, 10, 15):
        started = datetime(2026, 3, day, 9, 0, 0, tzinfo=timezone.utc).isoformat()
        a = _make_activity(f"day-{day}", started_at=started)
        a.stop()
        storage.save_activity(a)

    result = storage.get_activities_range(date(2026, 3, 5), date(2026, 3, 15))
    descriptions = {a.description for a in result}
    assert descriptions == {"day-5", "day-10", "day-15"}
