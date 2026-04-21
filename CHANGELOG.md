# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-04-21

### English

#### Fixed
- Remote installer (`install-remote.sh`) failed on Linux/macOS because the
  v0.1.0 wheel exposed the console script as `job-tracker` while the
  launcher invoked `timetrack`. The wheel now ships the `timetrack` entry
  point, and the installer creates a compatibility symlink when only the
  legacy name is present.

### Português

#### Corrigido
- O instalador remoto (`install-remote.sh`) falhava no Linux/macOS porque
  o wheel v0.1.0 expunha o console script como `job-tracker` enquanto o
  launcher chamava `timetrack`. O wheel agora traz o entry point
  `timetrack`, e o instalador cria um symlink de compatibilidade quando
  apenas o nome antigo está presente.

## [0.1.0] - 2026-04-19

### English

#### Added
- Activity state machine (start / pause / resume / stop) with effective duration
  computed from wall-clock minus pause intervals.
- Daily dashboard with shift-aware timeline, target percentage, and
  cross-client state synchronization via a monotonic `/api/revision` counter.
- Monthly JSON persistence (`data/YYYY-MM.json`) with atomic writes
  (temp file + fsync + `os.replace`) and on-load corruption isolation.
- CSV / TSV export for completed activities within a date range (max 1 year).
- Configurable weekly shifts, port, theme (auto / light / dark), target %,
  and optional motivational phrases.
- Optional `pystray` system tray integration with pause / resume / stop and
  a "focus existing tab" endpoint (`/focus`).
- Linux launcher scripts (`install.sh`, `timetrack.sh`) and a Windows NSIS
  installer with embedded Python runtime and optional NSSM-based service.
- Bilingual UI (English + Brazilian Portuguese) via Flask-Babel with a
  cookie-based language switcher and Accept-Language fallback.
- Localized micro-reward phrase catalogs (`phrases_en.json`, `phrases_pt_br.json`).
- Packaging: PEP 621 `pyproject.toml` (Hatchling build backend), `timetrack`
  console script, optional `[tray]` and `[dev]` extras.
- Quality tooling: `ruff` (lint + format), `mypy`, `pytest` + `pytest-cov`,
  `pre-commit` hooks, and a full unit-test suite covering models, storage,
  config, export, routes, and locale resolution.
- CI: test matrix (3 OS × 4 Python versions), CodeQL static analysis,
  Dependabot, and Windows-installer build pipeline.
- Bilingual documentation site built with MkDocs Material and
  `mkdocs-static-i18n`, deployed to GitHub Pages.
- Community files: `LICENSE` (MIT), bilingual `CONTRIBUTING` guides.

#### Security
- 64 KB request-body limit (`MAX_CONTENT_LENGTH`).
- Whitelisted config keys on `PUT /api/config` and strict per-field
  validation (description length, time format, port range, target range,
  theme enum, export range cap).

### Português

#### Adicionado
- Máquina de estados de atividade (iniciar / pausar / retomar / encerrar) com
  duração efetiva igual a tempo de parede menos intervalos de pausa.
- Dashboard diário com linha do tempo alinhada aos turnos, meta percentual e
  sincronização entre abas via contador monótono em `/api/revision`.
- Persistência em JSON mensal (`data/YYYY-MM.json`) com escrita atômica
  (arquivo temporário + fsync + `os.replace`) e isolamento de arquivos
  corrompidos no carregamento.
- Exportação CSV / TSV de atividades concluídas em um intervalo de datas
  (máx. 1 ano).
- Configuração de turnos semanais, porta, tema (auto / claro / escuro),
  meta percentual e frases motivacionais opcionais.
- Integração opcional com bandeja do sistema via `pystray` (pausar /
  retomar / encerrar) e endpoint `/focus` para refocar aba já aberta.
- Scripts de lançamento para Linux (`install.sh`, `timetrack.sh`) e
  instalador NSIS para Windows com runtime Python embutido e serviço
  opcional baseado em NSSM.
- UI bilíngue (inglês + português do Brasil) via Flask-Babel, com troca de
  idioma por cookie e fallback por Accept-Language.
- Catálogos localizados de frases de micro-recompensa (`phrases_en.json`,
  `phrases_pt_br.json`).
- Empacotamento: `pyproject.toml` PEP 621 (backend Hatchling), script de
  console `timetrack` e extras opcionais `[tray]` e `[dev]`.
- Ferramental de qualidade: `ruff` (lint + format), `mypy`, `pytest` +
  `pytest-cov`, hooks de `pre-commit` e suíte de testes unitários cobrindo
  models, storage, config, export, routes e resolução de locale.
- CI: matriz de testes (3 SOs × 4 versões de Python), análise estática com
  CodeQL, Dependabot e pipeline de build do instalador Windows.
- Site de documentação bilíngue em MkDocs Material com
  `mkdocs-static-i18n`, publicado no GitHub Pages.
- Arquivos de comunidade: `LICENSE` (MIT) e guias `CONTRIBUTING` bilíngues.

#### Segurança
- Limite de 64 KB no corpo das requisições (`MAX_CONTENT_LENGTH`).
- Whitelist de chaves de configuração em `PUT /api/config` e validação
  estrita por campo (tamanho de descrição, formato de horário, faixa de
  porta, faixa de meta, enum de tema, limite de intervalo de exportação).

[Unreleased]: https://github.com/rafaelkrause/TimeTrack/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/rafaelkrause/TimeTrack/releases/tag/v0.1.1
[0.1.0]: https://github.com/rafaelkrause/TimeTrack/releases/tag/v0.1.0
