"""System tray integration (optional — requires pystray and Pillow)."""

import json
import os
import sys
import threading
import urllib.request


def start_tray(url: str, app):
    import pystray
    from PIL import Image, ImageDraw

    def create_icon():
        img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        draw.ellipse([4, 4, 60, 60], outline="white", width=3)
        draw.line([32, 32, 32, 14], fill="white", width=2)
        draw.line([32, 32, 46, 32], fill="white", width=2)
        return img

    def open_browser(icon, item):
        import webbrowser

        webbrowser.open(f"{url}/focus")

    def _api_post(endpoint):
        """Run HTTP POST in a thread so the tray menu doesn't block."""

        def _do():
            try:
                req = urllib.request.Request(
                    f"{url}/api/activity/{endpoint}",
                    data=json.dumps({}).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                resp = urllib.request.urlopen(req, timeout=5)
                resp.read()
                resp.close()
            except Exception as e:
                print(f"[tray] erro em /{endpoint}: {e}", file=sys.stderr, flush=True)

        threading.Thread(target=_do, daemon=True).start()

    def pause_activity(icon, item):
        _api_post("pause")

    def resume_activity(icon, item):
        _api_post("resume")

    def stop_activity(icon, item):
        _api_post("stop")

    def on_quit(icon, item):
        icon.stop()
        os._exit(0)

    menu = pystray.Menu(
        pystray.MenuItem("Abrir", open_browser, default=True),
        pystray.MenuItem("Pausar", pause_activity),
        pystray.MenuItem("Retomar", resume_activity),
        pystray.MenuItem("Finalizar", stop_activity),
        pystray.MenuItem("Sair", on_quit),
    )

    icon = pystray.Icon("job-tracker", create_icon(), "Job Tracker", menu=menu)
    icon.run()
