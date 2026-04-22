#!/usr/bin/env python3
"""Legacy launcher kept for `python3 run.py` compatibility. Delegates to
`app.__main__.main`, which is also the target of the `timetrack` console
script defined in `pyproject.toml`."""

import os
import sys

# Python's embeddable distribution ships with a `._pth` file that replaces
# the normal sys.path construction — including the rule that adds the
# script's own directory. Without this bootstrap, running `pythonw.exe run.py`
# from the Windows installer fails with "ModuleNotFoundError: No module
# named 'app'". Harmless on standard Python (dedup'd by the interpreter).
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.__main__ import main

if __name__ == "__main__":
    main()
