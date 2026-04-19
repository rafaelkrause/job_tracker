#!/usr/bin/env python3
"""Entry point for the Job Tracker application."""

import sys
import threading
import webbrowser

from app import create_app, get_user_data_dir
from app.config import load_config


def main():
    config_path = get_user_data_dir() / "config.json"
    config = load_config(str(config_path))
    app = create_app(config)
    port = config.get("port", 5000)
    host = "127.0.0.1"
    url = f"http://{host}:{port}"

    # Check tray availability before starting anything
    tray_available = False
    try:
        import pystray  # noqa: F401
        from PIL import Image  # noqa: F401

        tray_available = True
    except ImportError:
        pass

    if tray_available:
        from app.tray import start_tray

        # Flask in background thread, tray owns the main thread
        web_thread = threading.Thread(
            target=lambda: app.run(host=host, port=port, debug=False, use_reloader=False),
            daemon=True,
        )
        web_thread.start()
        print(f"Job Tracker running at {url}")
        start_tray(url, app)
    else:
        print(f"Job Tracker running at {url}")
        print("(Install pystray and Pillow for system tray support)")
        if "--no-browser" not in sys.argv:
            webbrowser.open(url)
        app.run(host=host, port=port, debug=False)


if __name__ == "__main__":
    main()
