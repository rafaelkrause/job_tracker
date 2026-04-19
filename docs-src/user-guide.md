# Guia do usuário

Este guia cobre o fluxo completo do Job Tracker: conceitos, atividades, dashboard, turnos, exportação e API.

## Primeiro acesso

1. Inicie o servidor: `python3 run.py` (ou `./job-tracker.sh`).
2. O navegador abre em `http://localhost:5000`.
3. Na primeira execução um `config.json` é criado com defaults (turno 09–12 / 13–18 de seg a sex, tema automático, porta 5000, meta 90%).
4. Ajuste turnos e preferências em **Configurações**.

## Conceitos

| Conceito | Descrição |
|---|---|
| **Atividade** | Um bloco de trabalho com descrição, início, pausas e fim. |
| **Pausa** | Intervalo dentro de uma atividade. Tempo em pausa é subtraído da duração. |
| **Turno** | Faixa esperada de trabalho por dia da semana, com múltiplos blocos possíveis. |
| **Meta (target %)** | Quanto do turno você pretende apontar como atividade produtiva. |
| **Estado** | Máquina de estados: `active → paused → active → completed`. |

## Atividades

### Iniciar

Digite a descrição e clique em **Iniciar**. Se já houver uma atividade em curso, ela é finalizada automaticamente — sem prompt bloqueante. Trocar de tarefa é um gesto único.

### Pausar / Retomar

Use **Pausar** e **Retomar**. O cronômetro para/segue o relógio; a duração total é sempre tempo decorrido menos tempo em pausa.

### Finalizar

Clique em **Parar**. A atividade vira `completed` e entra no histórico do dia, disponível para exportação.

### Editar / Remover

Pela UI ou via `PUT /api/activity/<id>` (descrição, horário de início/fim) e `DELETE /api/activity/<id>`.

### Limites

- Descrição: até 500 caracteres
- Corpo de requisição: até 64 KB
- Horários: formato `HH:MM` (24h), validado no servidor

## Dashboard diário

O dashboard mostra:

- **Timeline do dia** — cada atividade posicionada no horário real de início/fim. A faixa exibida é derivada do turno + 30 min de padding em cada extremo.
- **Atividade atual** — descrição e cronômetro. O front-end incrementa o contador localmente entre polls (30s) para parecer instantâneo.
- **Barra de progresso do turno** — só conta horas já passadas no dia corrente. Horas futuras não puxam o progresso pra baixo.
- **Meta** — quanto da sua meta (% do turno) já foi apontada.
- **Resumo do dia** — total apontado e lista cronológica de atividades finalizadas.

Use o seletor de data para navegar dias anteriores.

## Turnos

Cada dia da semana pode ter zero, um ou mais blocos. Exemplo padrão:

```json
{
  "monday":    [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
  "tuesday":   [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
  "wednesday": [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
  "thursday":  [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
  "friday":    [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
  "saturday":  [],
  "sunday":    []
}
```

Edite pela UI em **Configurações → Turnos** ou direto no `config.json`.

## Bandeja do sistema

Com `pystray` e `Pillow` instalados, um ícone aparece na bandeja com:

- Pausar / Retomar
- Parar
- Abrir no navegador
- Sair

As ações conversam com o Flask via HTTP local — é a mesma API da UI.

Em instalações Linux com GNOME puro, é preciso a extensão **AppIndicator**.

## Exportação para iClips

O iClips não tem API pública. A exportação é formatada para **colar manualmente** no campo correto.

- **UI**: página **Exportar** → escolha intervalo de datas + formato CSV/TSV → Download.
- **API**: `GET /api/export?from=YYYY-MM-DD&to=YYYY-MM-DD&format=tsv`.
- Só atividades **finalizadas** são exportadas. Em andamento ou pausadas ficam de fora.
- Intervalo máximo: 1 ano.

## Onde ficam os dados

| Plataforma | Caminho |
|---|---|
| Linux / macOS | `data/YYYY-MM.json` na pasta do projeto |
| Windows (instalador) | `%APPDATA%\JobTracker\data\YYYY-MM.json` |

Um arquivo por mês mantém cada JSON pequeno e fácil de inspecionar à mão. Arquivos com mais de 12 meses são podados automaticamente ao iniciar.

Se um JSON estiver corrompido ao carregar, o app renomeia para `.corrupted` e continua com o mês vazio — você pode recuperar manualmente.

Escritas são **atômicas**: arquivo temporário → `fsync` → `os.replace()`. Seguras contra crashes e queda de energia.

## Dicas

- Deixe uma aba do navegador aberta no dashboard.
- Use a bandeja para pausar rapidamente sem trocar de janela.
- Descrições curtas e consistentes facilitam o apontamento semanal no iClips.
- Configure um atalho de teclado do sistema para focar a aba do Job Tracker.
- Ao rodar como serviço (`systemd` / NSSM), use `--no-browser`.
- Para backup, copie periodicamente a pasta `data/`. É só JSON.
