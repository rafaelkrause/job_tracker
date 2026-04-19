from __future__ import annotations


def test_default_locale_is_pt_br(client):
    resp = client.post("/api/activity/start", json={})
    assert resp.status_code == 400
    assert "obrigatória" in resp.get_json()["error"].lower()


def test_accept_language_en_returns_english_errors(client):
    resp = client.post(
        "/api/activity/start",
        json={},
        headers={"Accept-Language": "en"},
    )
    assert resp.status_code == 400
    assert "required" in resp.get_json()["error"].lower()


def test_lang_cookie_overrides_accept_language(client):
    client.set_cookie("jt-lang", "en", domain="localhost")
    resp = client.post(
        "/api/activity/start",
        json={},
        headers={"Accept-Language": "pt-BR"},
    )
    assert "required" in resp.get_json()["error"].lower()


def test_set_lang_endpoint_sets_cookie(client):
    resp = client.post("/api/lang", json={"lang": "en"})
    assert resp.status_code == 204
    set_cookie = resp.headers.get("Set-Cookie", "")
    assert "jt-lang=en" in set_cookie


def test_set_lang_rejects_unsupported(client):
    resp = client.post("/api/lang", json={"lang": "de"})
    assert resp.status_code == 400


def test_phrase_endpoint_returns_localized(client):
    client.put("/api/config", json={"phrases_enabled": True})

    resp_pt = client.get("/api/phrase/pause", headers={"Accept-Language": "pt-BR"})
    resp_en = client.get("/api/phrase/pause", headers={"Accept-Language": "en"})

    pt_phrase = resp_pt.get_json()["phrase"]
    en_phrase = resp_en.get_json()["phrase"]
    assert pt_phrase is not None
    assert en_phrase is not None


def test_dashboard_html_lang_attribute(client):
    resp = client.get("/")
    assert b'lang="pt-br"' in resp.data

    resp_en = client.get("/", headers={"Accept-Language": "en"})
    assert b'lang="en"' in resp_en.data


def test_dashboard_translates_labels(client):
    resp = client.get("/")
    assert "Configurações".encode() in resp.data

    resp_en = client.get("/", headers={"Accept-Language": "en"})
    assert b"Settings" in resp_en.data
