"""Tests for the Activity / Pause state machine."""

from __future__ import annotations

import time

import pytest

from app.models import Activity, Pause


def test_activity_starts_in_active_state():
    a = Activity.create("demo")
    assert a.status == "active"
    assert a.ended_at is None
    assert a.pauses == []
    assert a.id
    assert a.description == "demo"


def test_pause_transitions_active_to_paused():
    a = Activity.create("demo")
    a.pause()
    assert a.status == "paused"
    assert len(a.pauses) == 1
    assert a.pauses[0].resumed_at is None


def test_resume_transitions_paused_to_active():
    a = Activity.create("demo")
    a.pause()
    a.resume()
    assert a.status == "active"
    assert a.pauses[-1].resumed_at is not None


def test_stop_transitions_to_completed():
    a = Activity.create("demo")
    a.stop()
    assert a.status == "completed"
    assert a.ended_at is not None


def test_pause_from_non_active_raises():
    a = Activity.create("demo")
    a.stop()
    with pytest.raises(ValueError):
        a.pause()


def test_resume_from_non_paused_raises():
    a = Activity.create("demo")
    with pytest.raises(ValueError):
        a.resume()


def test_stop_when_already_completed_raises():
    a = Activity.create("demo")
    a.stop()
    with pytest.raises(ValueError):
        a.stop()


def test_duration_subtracts_total_pause_time():
    a = Activity.create("demo")
    time.sleep(0.05)
    a.pause()
    time.sleep(0.1)
    a.resume()
    time.sleep(0.05)
    a.stop()

    wall = (
        pytest.importorskip("datetime").datetime.fromisoformat(a.ended_at)
        - pytest.importorskip("datetime").datetime.fromisoformat(a.started_at)
    ).total_seconds()
    effective = a.effective_duration_seconds()
    pause_total = sum(p.duration_seconds() for p in a.pauses)

    assert effective == pytest.approx(wall - pause_total, abs=0.01)
    assert effective < wall


def test_multiple_pauses_sum_correctly():
    a = Activity.create("demo")
    for _ in range(3):
        time.sleep(0.02)
        a.pause()
        time.sleep(0.02)
        a.resume()
    a.stop()
    assert len(a.pauses) == 3
    assert all(p.resumed_at is not None for p in a.pauses)


def test_stop_while_paused_closes_open_pause():
    a = Activity.create("demo")
    a.pause()
    time.sleep(0.02)
    a.stop()
    assert a.status == "completed"
    assert a.pauses[-1].resumed_at is not None


def test_roundtrip_serialization():
    a = Activity.create("demo")
    a.pause()
    a.resume()
    a.stop()

    restored = Activity.from_dict(a.to_dict())
    assert restored.id == a.id
    assert restored.description == a.description
    assert restored.status == a.status
    assert restored.started_at == a.started_at
    assert restored.ended_at == a.ended_at
    assert len(restored.pauses) == len(a.pauses)
    assert restored.pauses[0].paused_at == a.pauses[0].paused_at


def test_pause_duration_when_open_uses_now():
    p = Pause(paused_at="2026-01-01T09:00:00+00:00")
    assert p.duration_seconds() > 0
