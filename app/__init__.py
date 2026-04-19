import os
from pathlib import Path

from flask import Flask


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


def create_app(config: dict | None = None):
    app = Flask(__name__)

    user_dir = get_user_data_dir()
    user_dir.mkdir(parents=True, exist_ok=True)

    app.config["APP_CONFIG"] = config or {}
    app.config["DATA_DIR"] = user_dir / "data"
    app.config["CONFIG_PATH"] = user_dir / "config.json"

    app.config["DATA_DIR"].mkdir(exist_ok=True)
    app.config["MAX_CONTENT_LENGTH"] = 64 * 1024  # 64 KB max request body

    # Cleanup data files older than 12 months
    from app.storage import Storage

    Storage(app.config["DATA_DIR"]).cleanup_old_data()

    from app.routes import bp

    app.register_blueprint(bp)

    return app
