# Language policy

Job Tracker is **bilingual by design**: UI and docs come in English and Brazilian Portuguese, with **pt-BR as the default**.

## Why bilingual?

- The project was born for a Brazilian marketing agency — pt-BR is the everyday language.
- Export is formatted for iClips (a Brazilian platform).
- But the project is open source, and we want international contributors to read and contribute without language friction.

## How the UI resolves the language

Precedence:

1. `jt-lang` cookie (set by the user via the dropdown or the `POST /api/lang` endpoint).
2. Browser `Accept-Language` header.
3. Fallback: `pt_BR`.

To switch languages in the UI:

- Use the language dropdown at the top of any page; or
- Send `POST /api/lang` with `{"lang": "pt_BR"}` or `{"lang": "en"}`.

The cookie persists for 1 year and is `SameSite=Lax`.

## Code vs. UI vs. docs

| Layer | Language |
|---|---|
| Source code (identifiers, comments, docstrings, logs, tests) | **English only** |
| UI strings | English + pt-BR via Flask-Babel |
| Documentation (this site) | English + pt-BR via mkdocs-static-i18n |
| External wiki / issues / PRs | Either — the maintainer replies in both |

## Contributing translations

See the [contributing guide](contributing.md) for the full workflow. In short:

```bash
pybabel extract -F app/i18n/babel.cfg -o app/i18n/messages.pot .
pybabel update -i app/i18n/messages.pot -d app/i18n
# edit app/i18n/<locale>/LC_MESSAGES/messages.po
pybabel compile -d app/i18n
```

To add a **new language** (beyond EN and pt-BR):

```bash
pybabel init -i app/i18n/messages.pot -d app/i18n -l <code>   # e.g. fr, es, de
```

Open a PR with the translated `.po` (do not commit `.mo` — it is generated at build time).

## Documentation

Files under `docs-src/`:

- `page.md` → default (pt-BR) version.
- `page.en.md` → English version.

The `mkdocs-static-i18n` plugin publishes `https://rafaelkrause.github.io/job_tracker/` (pt-BR) and `https://rafaelkrause.github.io/job_tracker/en/` (EN). Internal relative links work in both languages — the plugin handles path translation.

## Status

- ✅ UI: 100% translated (EN + pt-BR).
- ✅ Docs: main pages translated.
- ⏳ Other languages: PRs welcome.
