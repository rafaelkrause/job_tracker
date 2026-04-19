"""Tests for config loading/saving and whitelist validation in PUT /api/config."""

from __future__ import annotations

from pathlib import Path

from app.config import DEFAULT_CONFIG, load_config, save_config


def test_defaults_when_file_missing(tmp_path: Path):
    cfg_path = tmp_path / "config.json"
    cfg = load_config(cfg_path)
    assert cfg["theme"] == "auto"
    assert cfg["port"] == 5000
    assert cfg["target_percentage"] == 90
    assert set(cfg["shifts"].keys()) == set(DEFAULT_CONFIG["shifts"].keys())
    assert cfg_path.exists()


def test_persistence_roundtrip(tmp_path: Path):
    cfg_path = tmp_path / "config.json"
    cfg = {"theme": "dark", "port": 8080, "user_name": "alice"}
    save_config(cfg, cfg_path)
    loaded = load_config(cfg_path)
    assert loaded["theme"] == "dark"
    assert loaded["port"] == 8080
    assert loaded["user_name"] == "alice"


def test_corrupted_config_falls_back_to_defaults(tmp_path: Path):
    cfg_path = tmp_path / "config.json"
    cfg_path.write_text("{nope", encoding="utf-8")
    cfg = load_config(cfg_path)
    assert cfg["port"] == 5000


def test_api_config_accepts_whitelisted_keys(client, sample_config):
    resp = client.put("/api/config", json={"user_name": "alice", "theme": "dark"})
    assert resp.status_code == 200
    data = resp.get_json()
    assert data["user_name"] == "alice"
    assert data["theme"] == "dark"


def test_api_config_rejects_invalid_theme(client, sample_config):
    resp = client.put("/api/config", json={"theme": "neon"})
    assert resp.status_code == 400


def test_api_config_rejects_out_of_range_port(client, sample_config):
    resp = client.put("/api/config", json={"port": 80})
    assert resp.status_code == 400
    resp = client.put("/api/config", json={"port": 99999})
    assert resp.status_code == 400


def test_api_config_clamps_target_percentage(client, sample_config):
    resp = client.put("/api/config", json={"target_percentage": 150})
    assert resp.status_code == 200
    assert resp.get_json()["target_percentage"] == 100

    resp = client.put("/api/config", json={"target_percentage": -5})
    assert resp.status_code == 200
    assert resp.get_json()["target_percentage"] == 0


def test_api_config_rejects_non_numeric_target(client, sample_config):
    resp = client.put("/api/config", json={"target_percentage": "abc"})
    assert resp.status_code == 400


def test_api_config_ignores_unknown_keys(client, sample_config):
    resp = client.put("/api/config", json={"evil_key": "ignored", "user_name": "bob"})
    assert resp.status_code == 200
    data = resp.get_json()
    assert "evil_key" not in data
    assert data["user_name"] == "bob"


def test_api_config_truncates_long_user_name(client, sample_config):
    resp = client.put("/api/config", json={"user_name": "x" * 500})
    assert resp.status_code == 200
    assert len(resp.get_json()["user_name"]) == 100


def test_api_shifts_rejects_too_many_entries_per_day(client, sample_config):
    shifts = {
        "monday": [{"start": "09:00", "end": "10:00"}] * 11,
        "tuesday": [],
        "wednesday": [],
        "thursday": [],
        "friday": [],
        "saturday": [],
        "sunday": [],
    }
    resp = client.put("/api/shifts", json=shifts)
    assert resp.status_code == 400


def test_api_shifts_rejects_invalid_time(client, sample_config):
    shifts = {
        "monday": [{"start": "25:00", "end": "18:00"}],
        "tuesday": [],
        "wednesday": [],
        "thursday": [],
        "friday": [],
        "saturday": [],
        "sunday": [],
    }
    resp = client.put("/api/shifts", json=shifts)
    assert resp.status_code == 400


def test_api_shifts_rejects_malformed_time_string(client, sample_config):
    shifts = {
        "monday": [{"start": "9", "end": "18:00"}],
        "tuesday": [],
        "wednesday": [],
        "thursday": [],
        "friday": [],
        "saturday": [],
        "sunday": [],
    }
    resp = client.put("/api/shifts", json=shifts)
    assert resp.status_code == 400
