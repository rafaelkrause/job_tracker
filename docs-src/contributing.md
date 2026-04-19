# Contribuindo

Obrigado por considerar contribuir com o `job_tracker`! Este site resume o essencial; o guia completo fica no [CONTRIBUTING.pt-BR.md](https://github.com/rafaelkrause/job_tracker/blob/main/CONTRIBUTING.pt-BR.md) no repositório.

## Setup rápido

```bash
git clone https://github.com/rafaelkrause/job_tracker.git
cd job_tracker

python3 -m venv .venv
source .venv/bin/activate

pip install -e ".[dev,tray]"
pre-commit install
```

## Rodar testes e checks

```bash
pytest --cov=app --cov-report=term-missing
ruff check .
ruff format .
mypy app
```

Cobertura deve permanecer **≥ 70%**. Adicione/atualize testes para qualquer comportamento que você mude.

## Convenções

- **Idioma do código**: inglês (identificadores, comentários, docstrings, logs, testes).
- **Idioma da UI e docs**: bilíngue (EN + pt-BR, padrão pt-BR).
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`, `test:`, etc).
- **Lint + format**: [ruff](https://docs.astral.sh/ruff/).
- **Tipos**: [mypy](https://mypy.readthedocs.io/) progressivo — tipe o que você toca, sem obrigação de retrofit geral.

O `pre-commit` roda lint e format em todo commit.

## Traduções

Workflow com Flask-Babel:

```bash
pybabel extract -F app/i18n/babel.cfg -o app/i18n/messages.pot .
pybabel update -i app/i18n/messages.pot -d app/i18n
pybabel compile -d app/i18n
```

Para adicionar um novo idioma:

```bash
pybabel init -i app/i18n/messages.pot -d app/i18n -l <code>
```

Os arquivos `.mo` são gerados (não commitados) e precisam ser compilados antes de empacotar ou rodar o app.

## Abrindo um PR

1. Crie uma branch a partir de `main`.
2. Faça commits pequenos e coesos, seguindo o padrão de commits.
3. Garanta que `pytest`, `ruff`, `mypy` estejam verdes localmente.
4. Abra o PR preenchendo o template.
5. Espere o CI ficar verde (matriz 3 SO × 4 versões Python + CodeQL).

## Código de conduta

Este projeto segue o [Contributor Covenant Code of Conduct](https://github.com/rafaelkrause/job_tracker/blob/main/CODE_OF_CONDUCT.md). Participando, você concorda em manter a comunidade respeitosa e acolhedora.
