# Referência da API

Endpoints HTTP expostos pelo servidor local. Todos relativos a `http://localhost:5000` (ou a porta configurada em `config.json`).

## Convenções

- Content type: `application/json` (exceto export em CSV/TSV).
- Datas: `YYYY-MM-DD` (ISO 8601 apenas data).
- Horários: `HH:MM` (24h).
- Timestamps internos: ISO 8601 com offset de fuso (`2026-04-19T14:32:10-03:00`).
- Tamanho máximo do corpo: **64 KB** (`MAX_CONTENT_LENGTH`).
- Erros retornam JSON `{"error": "descrição"}` com um dos códigos listados ao final.

## Páginas HTML

| Rota | Descrição |
|---|---|
| `GET /` | Dashboard principal. |
| `GET /focus` | Página acionada pela bandeja para trazer a aba existente em foco (em vez de abrir uma nova). |
| `GET /settings` | Página de configurações (turnos, tema, meta, etc). |

## Atividades

### `POST /api/activity/start`

Inicia uma nova atividade. Se houver outra em curso (ativa ou pausada), ela é **finalizada automaticamente** antes.

**Body**

```json
{ "description": "Reunião com cliente XYZ" }
```

**Validação**

- `description` obrigatório, string, até 500 caracteres.

**Resposta `201`**

```json
{
  "id": "a1b2c3",
  "description": "Reunião com cliente XYZ",
  "start": "2026-04-19T09:00:00-03:00",
  "state": "active",
  "pauses": []
}
```

### `POST /api/activity/pause`

Pausa a atividade atual. Sem body. `404` se não houver atividade ativa.

### `POST /api/activity/resume`

Retoma uma atividade pausada. Sem body. `404` se não houver atividade em pausa.

### `POST /api/activity/stop`

Finaliza a atividade atual (ativa ou pausada). Sem body.

### `GET /api/activity/current`

Retorna a atividade em andamento (`active` ou `paused`), ou `null` se não houver.

```json
{
  "id": "a1b2c3",
  "description": "Reunião com cliente XYZ",
  "start": "2026-04-19T09:00:00-03:00",
  "state": "active",
  "pauses": [
    {"start": "2026-04-19T09:10:00-03:00", "end": "2026-04-19T09:15:00-03:00"}
  ],
  "duration_minutes": 25
}
```

!!! note
    `duration_minutes` = tempo decorrido (até agora) menos tempo em pausa.

### `PUT /api/activity/<id>`

Edita uma atividade existente. Campos aceitos no body: `description`, `start_time`, `end_time`.

```json
{
  "description": "Reunião com cliente ABC",
  "start_time": "09:15",
  "end_time": "10:30"
}
```

- `start_time` / `end_time` em formato `HH:MM`; aplicados ao mesmo dia da atividade.
- `404` se o id não existir.

### `DELETE /api/activity/<id>`

Remove a atividade do histórico. Resposta `204` sem corpo.

## Listagens

### `GET /api/activities`

Parâmetros:

- `date=YYYY-MM-DD` — atividades de um dia específico.
- `from=YYYY-MM-DD&to=YYYY-MM-DD` — intervalo (inclusivo). Máximo 1 ano.

Retorna array de atividades (ordem cronológica).

### `GET /api/dashboard?date=YYYY-MM-DD[&period=day|week|month]`

Dados agregados para um dia, semana ou mês. Defaults: `date` = hoje, `period` = `day`.

Parâmetros:

- `date` — data-âncora (ISO `YYYY-MM-DD`). Em `week` e `month` serve apenas para identificar qual semana/mês.
- `period` — granularidade da agregação:
    - `day` (padrão): apenas o dia.
    - `week`: segunda a domingo (ISO) contendo `date`.
    - `month`: mês calendário de `date`.

Regra de `elapsed_shift_seconds`: dias passados contam o turno inteiro; o dia atual conta até `now`; dias futuros contam zero. `shifts` e `day_name` só são preenchidos no modo `day` (a timeline horária é renderizada apenas nesse modo).

```json
{
  "date": "2026-04-20",
  "period": "week",
  "from_date": "2026-04-20",
  "to_date": "2026-04-26",
  "day_name": null,
  "activities": [ /* atividades do intervalo (ordem cronológica) */ ],
  "shifts": [],
  "total_shift_seconds": 104400,
  "elapsed_shift_seconds": 21780,
  "tracked_seconds": 14400,
  "percentage": 66.1,
  "target_percentage": 90
}
```

## Exportação

### `GET /api/export?from=YYYY-MM-DD&to=YYYY-MM-DD&format=csv|tsv`

Exporta atividades **finalizadas** no intervalo, no formato pedido (`csv` ou `tsv`). Intervalo máximo: **1 ano**.

Resposta `200` com:

- `Content-Type: text/csv` ou `text/tab-separated-values`
- `Content-Disposition: attachment; filename="jobtracker_YYYY-MM-DD_YYYY-MM-DD.csv"`

Campos: data, descrição, início, fim, duração (em minutos).

## Configuração

### `GET /api/config`

Retorna o objeto de configuração atual (inclui `user_name`, `target_percentage`, `port`, `phrases_enabled`, `theme`).

### `PUT /api/config`

Atualiza campos. Chaves permitidas:

- `user_name` (string, ≤ 100 chars)
- `target_percentage` (0–100)
- `port` (1024–65535)
- `phrases_enabled` (boolean)
- `theme` (`auto` | `light` | `dark`)

Chaves desconhecidas são ignoradas.

### `GET /api/shifts`

Retorna o objeto `shifts` atual.

### `PUT /api/shifts`

Substitui todos os turnos. Body deve conter o objeto `shifts` completo (7 dias, até 10 blocos por dia).

## Utilitários

### `GET /api/phrase/<category>`

Retorna uma micro-frase aleatória para exibição no dashboard. Categorias conforme `app/data/phrases.*.json` (ex.: `start`, `pause`, `resume`, `stop`).

Retorna `{"phrase": null}` se `phrases_enabled` estiver desativado.

### `POST /api/lang`

Troca o idioma da UI. Body:

```json
{ "lang": "pt_BR" }
```

ou

```json
{ "lang": "en" }
```

Define o cookie `jt-lang`. A próxima renderização usa o idioma escolhido.

### `GET /api/revision`

Contador monotônico incrementado a cada mudança de estado (start/pause/resume/stop/edit/delete). Clientes polam este endpoint para detectar mudanças feitas por outra aba ou pela bandeja sem fazer full-refresh.

```json
{ "revision": 42 }
```

## Códigos de erro

| Código | Significado |
|---|---|
| `400` | Body inválido, data/horário malformados, campo ausente |
| `404` | Atividade não encontrada no estado esperado |
| `413` | Body maior que 64 KB |
| `500` | Erro interno (veja os logs do servidor) |

## Exemplos com `curl`

```bash
# Iniciar
curl -X POST http://localhost:5000/api/activity/start \
     -H "Content-Type: application/json" \
     -d '{"description": "Email do cliente"}'

# Pausar
curl -X POST http://localhost:5000/api/activity/pause

# Atividade atual
curl http://localhost:5000/api/activity/current

# Dashboard do dia
curl "http://localhost:5000/api/dashboard?date=2026-04-19"

# Exportar semana em TSV
curl "http://localhost:5000/api/export?from=2026-04-14&to=2026-04-19&format=tsv" \
     -o semana.tsv

# Trocar idioma
curl -X POST http://localhost:5000/api/lang \
     -H "Content-Type: application/json" \
     -d '{"lang": "en"}' -c cookies.txt
```
