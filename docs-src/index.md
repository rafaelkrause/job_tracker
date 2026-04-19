# Job Tracker

Ferramenta leve e local de rastreamento de horas, pensada para profissionais de agência. Roda como servidor web em `localhost:5000`, sem banco de dados, com armazenamento em arquivos JSON por mês.

!!! note "Idioma"
    A UI é em pt-BR por padrão. A documentação é bilíngue: use o seletor de idioma no topo para alternar entre **Português (Brasil)** e **English**.

## Visão geral

| Recurso | Descrição |
|---|---|
| [Instalação](installation.md) | Instalação no Linux, macOS e Windows (script, manual, instalador NSIS). |
| [Guia de uso](user-guide.md) | Atividades, turnos, dashboard, exportação e API. |
| [Configuração](configuration.md) | Referência completa do `config.json` e opções editáveis na UI. |
| [Referência da API](api.md) | Todos os endpoints HTTP (REST) do servidor local. |
| [Solução de problemas](troubleshooting.md) | Erros comuns de instalação e execução. |
| [Contribuindo](contributing.md) | Como propor mudanças e abrir PRs. |
| [Política de idioma](language.md) | Por que pt-BR + EN, e como contribuir com traduções. |

## Principais características

- Fluxo `active → paused → active → completed`; pausas são subtraídas do tempo total.
- Dashboard diário com timeline, progresso do turno e meta.
- Armazenamento em arquivos JSON mensais (sem ORM, sem banco).
- Turnos por dia da semana configuráveis, com múltiplos blocos (intervalo de almoço, por exemplo).
- Exportação CSV/TSV para colar no iClips.
- Bandeja do sistema opcional via `pystray`.
- Abre o navegador automaticamente ao iniciar (desativável com `--no-browser`).

## Links rápidos

- Código: [github.com/rafaelkrause/job_tracker](https://github.com/rafaelkrause/job_tracker)
- Releases: [GitHub Releases](https://github.com/rafaelkrause/job_tracker/releases)
- Licença: [MIT](https://github.com/rafaelkrause/job_tracker/blob/main/LICENSE)
