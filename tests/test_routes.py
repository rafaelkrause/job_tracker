"""Smoke tests for Flask routes."""

from __future__ import annotations

from datetime import date


def test_start_activity_sets_current(client, sample_config):
    resp = client.post("/api/activity/start", json={"description": "write tests"})
    assert resp.status_code == 201
    assert resp.get_json()["activity"]["description"] == "write tests"

    current = client.get("/api/activity/current").get_json()
    assert current["activity"]["description"] == "write tests"


def test_start_activity_rejects_empty_description(client, sample_config):
    resp = client.post("/api/activity/start", json={"description": ""})
    assert resp.status_code == 400


def test_start_activity_rejects_missing_body(client, sample_config):
    resp = client.post("/api/activity/start", data="not json", content_type="application/json")
    assert resp.status_code == 400


def test_start_activity_rejects_long_description(client, sample_config):
    resp = client.post("/api/activity/start", json={"description": "x" * 501})
    assert resp.status_code == 400


def test_pause_resume_stop_cycle(client, sample_config):
    client.post("/api/activity/start", json={"description": "cycle"})

    resp = client.post("/api/activity/pause")
    assert resp.status_code == 200
    assert resp.get_json()["activity"]["status"] == "paused"

    resp = client.post("/api/activity/resume")
    assert resp.status_code == 200
    assert resp.get_json()["activity"]["status"] == "active"

    resp = client.post("/api/activity/stop")
    assert resp.status_code == 200
    assert resp.get_json()["activity"]["status"] == "completed"

    assert client.get("/api/activity/current").get_json()["activity"] is None


def test_pause_without_active_activity_returns_400(client, sample_config):
    resp = client.post("/api/activity/pause")
    assert resp.status_code == 400


def test_starting_new_activity_finalizes_previous(client, sample_config):
    client.post("/api/activity/start", json={"description": "first"})
    client.post("/api/activity/start", json={"description": "second"})

    current = client.get("/api/activity/current").get_json()
    assert current["activity"]["description"] == "second"


def test_current_returns_null_when_nothing_active(client, sample_config):
    resp = client.get("/api/activity/current")
    assert resp.status_code == 200
    assert resp.get_json()["activity"] is None


def test_activities_by_date_returns_list(client, sample_config):
    client.post("/api/activity/start", json={"description": "today"})
    client.post("/api/activity/stop")

    today = date.today().isoformat()
    resp = client.get(f"/api/activities?date={today}")
    assert resp.status_code == 200
    activities = resp.get_json()["activities"]
    assert len(activities) >= 1


def test_activities_invalid_date_returns_400(client, sample_config):
    resp = client.get("/api/activities?date=not-a-date")
    assert resp.status_code == 400


def test_activities_range_returns_list(client, sample_config):
    client.post("/api/activity/start", json={"description": "range"})
    client.post("/api/activity/stop")

    today = date.today().isoformat()
    resp = client.get(f"/api/activities?from={today}&to={today}")
    assert resp.status_code == 200


def test_update_activity_description(client, sample_config):
    r = client.post("/api/activity/start", json={"description": "old"})
    activity_id = r.get_json()["activity"]["id"]

    resp = client.put(f"/api/activity/{activity_id}", json={"description": "new"})
    assert resp.status_code == 200
    assert resp.get_json()["activity"]["description"] == "new"


def test_update_activity_rejects_invalid_time(client, sample_config):
    r = client.post("/api/activity/start", json={"description": "edit"})
    activity_id = r.get_json()["activity"]["id"]

    resp = client.put(f"/api/activity/{activity_id}", json={"start_time": "25:00"})
    assert resp.status_code == 400


def test_update_activity_404_for_unknown(client, sample_config):
    resp = client.put("/api/activity/does-not-exist", json={"description": "x"})
    assert resp.status_code == 404


def test_delete_activity_removes_it(client, sample_config):
    r = client.post("/api/activity/start", json={"description": "delete-me"})
    activity_id = r.get_json()["activity"]["id"]

    resp = client.delete(f"/api/activity/{activity_id}")
    assert resp.status_code == 200

    resp = client.delete(f"/api/activity/{activity_id}")
    assert resp.status_code == 404


def test_dashboard_returns_expected_structure(client, sample_config):
    today = date.today().isoformat()
    resp = client.get(f"/api/dashboard?date={today}")
    assert resp.status_code == 200
    data = resp.get_json()
    for key in (
        "date",
        "day_name",
        "activities",
        "shifts",
        "total_shift_seconds",
        "elapsed_shift_seconds",
        "tracked_seconds",
        "percentage",
        "target_percentage",
    ):
        assert key in data


def test_dashboard_rejects_bad_date(client, sample_config):
    resp = client.get("/api/dashboard?date=invalid")
    assert resp.status_code == 400


def test_config_get(client, sample_config):
    resp = client.get("/api/config")
    assert resp.status_code == 200
    assert "theme" in resp.get_json()


def test_shifts_get_and_put(client, sample_config):
    resp = client.get("/api/shifts")
    assert resp.status_code == 200

    new_shifts = {
        "monday": [{"start": "10:00", "end": "16:00"}],
        "tuesday": [],
        "wednesday": [],
        "thursday": [],
        "friday": [],
        "saturday": [],
        "sunday": [],
    }
    resp = client.put("/api/shifts", json=new_shifts)
    assert resp.status_code == 200
    assert resp.get_json()["monday"] == [{"start": "10:00", "end": "16:00"}]


def test_revision_increments_on_state_change(client, sample_config):
    before = client.get("/api/revision").get_json()["rev"]
    client.post("/api/activity/start", json={"description": "bump-rev"})
    after = client.get("/api/revision").get_json()["rev"]
    assert after > before


def test_phrase_returns_null_when_disabled(client, sample_config):
    resp = client.get("/api/phrase/pause")
    assert resp.status_code == 200
    assert resp.get_json()["phrase"] is None


def test_focus_page_returns_html(client, sample_config):
    resp = client.get("/focus")
    assert resp.status_code == 200
    assert b"<html" in resp.data.lower() or b"<!doctype" in resp.data.lower()


def test_dashboard_page_returns_html(client, sample_config):
    resp = client.get("/")
    assert resp.status_code == 200


def test_settings_page_returns_html(client, sample_config):
    resp = client.get("/settings")
    assert resp.status_code == 200


def test_oversized_body_rejected(client, sample_config):
    huge = {"description": "x" * (70 * 1024)}
    resp = client.post("/api/activity/start", json=huge)
    assert resp.status_code == 413
