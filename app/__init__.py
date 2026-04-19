import os
from pathlib import Path

from flask import Flask, request
from flask_babel import Babel, get_locale

SUPPORTED_LOCALES = ("pt_BR", "en")
DEFAULT_LOCALE = "pt_BR"


def get_user_data_dir() -> Path:
    """Resolve the directory holding config.json and data/.

    Priority:
      1. $JOBTRACKER_DATA_DIR (set by the Windows installer / service wrapper)
      2. ./ (project root) — dev mode
    """
    override = os.environ.get("JOBTRACKER_DATA_DIR")
    if override:
        return Path(override).expanduser()
    return Path(__file__).parent.parent


def _select_locale() -> str:
    """Resolve the active locale for the current request.

    Precedence:
      1. `jt-lang` cookie (set by the language toggle).
      2. Accept-Language header best match.
      3. DEFAULT_LOCALE.
    """
    cookie = request.cookies.get("jt-lang")
    if cookie and cookie in SUPPORTED_LOCALES:
        return cookie
    match = request.accept_languages.best_match(SUPPORTED_LOCALES)
    return match or DEFAULT_LOCALE


def create_app(config: dict | None = None):
    app = Flask(__name__)

    user_dir = get_user_data_dir()
    user_dir.mkdir(parents=True, exist_ok=True)

    app.config["APP_CONFIG"] = config or {}
    app.config["DATA_DIR"] = user_dir / "data"
    app.config["CONFIG_PATH"] = user_dir / "config.json"

    app.config["DATA_DIR"].mkdir(exist_ok=True)
    app.config["MAX_CONTENT_LENGTH"] = 64 * 1024  # 64 KB max request body

    app.config["BABEL_DEFAULT_LOCALE"] = DEFAULT_LOCALE
    app.config["BABEL_TRANSLATION_DIRECTORIES"] = str(Path(__file__).parent / "i18n")
    Babel(app, locale_selector=_select_locale)

    @app.context_processor
    def inject_i18n() -> dict:
        current = str(get_locale()) if get_locale() else DEFAULT_LOCALE
        return {
            "current_lang": current.replace("_", "-").lower(),
            "current_locale": current,
            "supported_locales": SUPPORTED_LOCALES,
        }

    # Cleanup data files older than 12 months
    from app.storage import Storage

    Storage(app.config["DATA_DIR"]).cleanup_old_data()

    from app.routes import bp

    app.register_blueprint(bp)

    return app
