# Contributing

Thanks for considering a contribution to `job_tracker`! This page summarizes the essentials; the full guide lives in [CONTRIBUTING.md](https://github.com/rafaelkrause/job_tracker/blob/main/CONTRIBUTING.md) in the repo.

## Quick setup

```bash
git clone https://github.com/rafaelkrause/job_tracker.git
cd job_tracker

python3 -m venv .venv
source .venv/bin/activate

pip install -e ".[dev,tray]"
pre-commit install
```

## Run tests and checks

```bash
pytest --cov=app --cov-report=term-missing
ruff check .
ruff format .
mypy app
```

Coverage must stay **≥ 70%**. Add/update tests for any behavior you change.

## Conventions

- **Code language**: English (identifiers, comments, docstrings, logs, tests).
- **UI and docs language**: bilingual (EN + pt-BR, default pt-BR).
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`, `test:`, etc).
- **Lint + format**: [ruff](https://docs.astral.sh/ruff/).
- **Types**: [mypy](https://mypy.readthedocs.io/) (progressive — type what you touch, no need to retrofit the whole repo).

`pre-commit` runs lint and format on every commit.

## Translations

Flask-Babel workflow:

```bash
pybabel extract -F app/i18n/babel.cfg -o app/i18n/messages.pot .
pybabel update -i app/i18n/messages.pot -d app/i18n
pybabel compile -d app/i18n
```

To add a new language:

```bash
pybabel init -i app/i18n/messages.pot -d app/i18n -l <code>
```

`.mo` files are generated (not committed) and must be compiled before packaging or running the app.

## Opening a PR

1. Create a branch off `main`.
2. Make small, focused commits following the commit convention.
3. Ensure `pytest`, `ruff`, `mypy` are green locally.
4. Open a PR using the template.
5. Wait for CI (matrix of 3 OS × 4 Python versions + CodeQL).

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](https://github.com/rafaelkrause/job_tracker/blob/main/CODE_OF_CONDUCT.md). By participating you agree to keep the community respectful and welcoming.
