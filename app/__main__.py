"""CLI entry point. Delegates to run.py's main() so `python -m app` and the
`job-tracker` script both work identically to `python run.py`."""

from __future__ import annotations

import sys
from pathlib import Path


def main() -> None:
    # Ensure project root is on sys.path so `run.py` can be imported when
    # launched via the installed console script.
    project_root = Path(__file__).resolve().parent.parent
    if str(project_root) not in sys.path:
        sys.path.insert(0, str(project_root))

    from run import main as run_main

    run_main()


if __name__ == "__main__":
    main()
