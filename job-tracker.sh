#!/usr/bin/env bash
cd "/home/leise/Documents/Projects/job_tracker"
source "/home/leise/Documents/Projects/job_tracker/.venv/bin/activate"
exec python3 run.py "$@"
