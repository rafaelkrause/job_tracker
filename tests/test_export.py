"""Tests for CSV/TSV export."""

from __future__ import annotations

from datetime import date

from app.export import export_activities
from app.models import Activity


def _completed(description: str = "task") -> Activity:
    a = Activity.create(description)
    a.stop()
    return a


def test_csv_header_row():
    content, mimetype, filename = export_activities([], "csv", date(2026, 1, 1), date(2026, 1, 2))
    first_line = content.splitlines()[0]
    assert "Data" in first_line
    assert "Descri" in first_line  # Descrição (unicode safe)
    assert mimetype == "text/csv"
    assert filename.endswith(".csv")


def test_tsv_uses_tab_separator():
    a = _completed("with tab export")
    content, mimetype, filename = export_activities([a], "tsv", date(2026, 1, 1), date(2026, 1, 2))
    assert "\t" in content.splitlines()[0]
    assert mimetype == "text/tab-separated-values"
    assert filename.endswith(".tsv")


def test_only_completed_activities_are_exported():
    completed_a = _completed("done")
    running = Activity.create("running")
    paused = Activity.create("paused")
    paused.pause()

    content, _, _ = export_activities(
        [completed_a, running, paused], "csv", date(2026, 1, 1), date(2026, 1, 2)
    )
    assert "done" in content
    assert "running" not in content
    assert "paused" not in content


def test_csv_escapes_commas_and_quotes_in_description():
    a = _completed('has, a comma and "quotes"')
    content, _, _ = export_activities([a], "csv", date(2026, 1, 1), date(2026, 1, 2))
    lines = content.splitlines()
    # csv module quotes the field when it contains the delimiter or quote char
    assert any('"has, a comma and ""quotes""' in line for line in lines)


def test_export_range_rejected_by_route_when_over_one_year(client, sample_config):
    resp = client.get("/api/export?from=2024-01-01&to=2026-01-02&format=csv")
    assert resp.status_code == 400


def test_export_route_returns_csv(client, sample_config):
    resp = client.get("/api/export?from=2026-01-01&to=2026-01-07&format=csv")
    assert resp.status_code == 200
    assert resp.mimetype == "text/csv"


def test_export_route_returns_tsv(client, sample_config):
    resp = client.get("/api/export?from=2026-01-01&to=2026-01-07&format=tsv")
    assert resp.status_code == 200
    assert resp.mimetype == "text/tab-separated-values"


def test_export_route_rejects_invalid_format(client, sample_config):
    resp = client.get("/api/export?from=2026-01-01&to=2026-01-07&format=xml")
    assert resp.status_code == 400


def test_export_route_requires_from_and_to(client, sample_config):
    resp = client.get("/api/export?format=csv")
    assert resp.status_code == 400


def test_export_route_rejects_invalid_dates(client, sample_config):
    resp = client.get("/api/export?from=not-a-date&to=2026-01-07&format=csv")
    assert resp.status_code == 400
