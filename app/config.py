import json
import sys
from pathlib import Path

from app.storage import _atomic_write_json

DEFAULT_SHIFTS = {
    "monday": [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "tuesday": [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "wednesday": [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "thursday": [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "friday": [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "saturday": [],
    "sunday": [],
}

DEFAULT_CONFIG = {
    "shifts": DEFAULT_SHIFTS,
    "theme": "auto",
    "port": 5000,
    "target_percentage": 90,
    "user_name": "",
    "phrases_enabled": True,
}


def load_config(path: str | Path | None = None) -> dict:
    config_path = Path(path) if path else Path("config.json")
    if config_path.exists():
        try:
            with open(config_path, encoding="utf-8") as f:
                user_config = json.load(f)
            if isinstance(user_config, dict):
                return {**DEFAULT_CONFIG, **user_config}
            print(f"AVISO: formato inesperado em {config_path}, usando padrões", file=sys.stderr)
        except (json.JSONDecodeError, UnicodeDecodeError, OSError) as e:
            print(f"AVISO: config corrompido {config_path}: {e}", file=sys.stderr)
    config = DEFAULT_CONFIG.copy()
    config["shifts"] = DEFAULT_SHIFTS.copy()
    save_config(config, config_path)
    return config


def save_config(config: dict, path: str | Path | None = None):
    config_path = Path(path) if path else Path("config.json")
    _atomic_write_json(config_path, config)
