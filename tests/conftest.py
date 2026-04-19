"""Shared pytest fixtures.

Key invariant: tests must never write to the real user data directory.
`JOBTRACKER_DATA_DIR` is honored by `app.get_user_data_dir`, so we point it
at a tmp dir for every test that touches storage or config.
"""

from __future__ import annotations

import copy
import json
from collections.abc import Iterator
from pathlib import Path

import pytest
from flask import Flask


@pytest.fixture
def isolated_data_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """Point JOBTRACKER_DATA_DIR at a tmp dir so tests are hermetic."""
    data_dir = tmp_path / "jobtracker"
    data_dir.mkdir()
    monkeypatch.setenv("JOBTRACKER_DATA_DIR", str(data_dir))
    return data_dir


@pytest.fixture
def app(isolated_data_dir: Path) -> Iterator[Flask]:
    """Flask app bound to an isolated data dir. Testing mode enabled."""
    from app import create_app
    from app.config import DEFAULT_CONFIG

    config = copy.deepcopy(DEFAULT_CONFIG)
    config["phrases_enabled"] = False
    flask_app = create_app(config)
    flask_app.config.update(TESTING=True)
    yield flask_app


@pytest.fixture
def client(app: Flask):
    return app.test_client()


@pytest.fixture
def sample_config(isolated_data_dir: Path) -> dict:
    """Write a minimal config.json into the isolated data dir."""
    cfg = {
        "shifts": {
            "monday": [{"start": "09:00", "end": "18:00"}],
            "tuesday": [{"start": "09:00", "end": "18:00"}],
            "wednesday": [{"start": "09:00", "end": "18:00"}],
            "thursday": [{"start": "09:00", "end": "18:00"}],
            "friday": [{"start": "09:00", "end": "18:00"}],
            "saturday": [],
            "sunday": [],
        },
        "theme": "auto",
        "port": 5000,
        "target_percentage": 90,
        "user_name": "Tester",
        "phrases_enabled": False,
    }
    (isolated_data_dir / "config.json").write_text(json.dumps(cfg), encoding="utf-8")
    return cfg
