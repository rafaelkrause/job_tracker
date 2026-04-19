# Política de idioma

O Job Tracker é um projeto **bilíngue por design**: a UI e a documentação têm versões em inglês e português do Brasil, com **pt-BR como padrão**.

## Por que bilíngue?

- O projeto nasceu para uma agência de marketing brasileira — pt-BR é a língua do dia-a-dia.
- A exportação é formatada para o iClips (plataforma brasileira).
- Mas o projeto é open source e queremos que contribuidores internacionais possam ler e contribuir sem barreira.

## Como a UI resolve o idioma

Ordem de precedência:

1. Cookie `jt-lang` (definido pelo próprio usuário via dropdown ou pela API `POST /api/lang`).
2. Cabeçalho `Accept-Language` do navegador.
3. Fallback: `pt_BR`.

Para trocar de idioma na interface:

- Use o dropdown de idioma no topo de qualquer página; ou
- Envie `POST /api/lang` com `{"lang": "pt_BR"}` ou `{"lang": "en"}`.

O cookie é persistente (1 ano) e amigável ao `SameSite=Lax`.

## Código vs. UI vs. docs

| Camada | Idioma |
|---|---|
| Código-fonte (identificadores, comentários, docstrings, logs, testes) | **Inglês apenas** |
| Strings da UI | Inglês + pt-BR via Flask-Babel |
| Documentação (este site) | Inglês + pt-BR via mkdocs-static-i18n |
| Wiki externa / issues / PRs | Qualquer uma — o maintainer responde em ambas |

## Contribuindo com traduções

Veja o [guia de contribuição](contributing.md) para o workflow completo. Em resumo:

```bash
pybabel extract -F app/i18n/babel.cfg -o app/i18n/messages.pot .
pybabel update -i app/i18n/messages.pot -d app/i18n
# edite app/i18n/<locale>/LC_MESSAGES/messages.po
pybabel compile -d app/i18n
```

Para adicionar um **novo idioma** (além de EN e pt-BR):

```bash
pybabel init -i app/i18n/messages.pot -d app/i18n -l <code>   # ex.: fr, es, de
```

Abra um PR com o `.po` traduzido (não commite o `.mo` — ele é gerado no build).

## Documentação

Arquivos sob `docs-src/`:

- `page.md` → versão padrão (pt-BR).
- `page.en.md` → versão em inglês.

O plugin `mkdocs-static-i18n` publica `https://rafaelkrause.github.io/job_tracker/` (pt-BR) e `https://rafaelkrause.github.io/job_tracker/en/` (EN). Links internos relativos funcionam em ambos os idiomas — o plugin cuida da tradução do caminho.

## Status

- ✅ UI: 100% traduzida (EN + pt-BR).
- ✅ Docs: páginas principais traduzidas.
- ⏳ Outros idiomas: aceitamos PRs.
