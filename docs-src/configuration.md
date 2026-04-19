# Configuração

Referência completa das opções configuráveis do Job Tracker.

## Localização do `config.json`

| Plataforma | Caminho |
|---|---|
| Linux / macOS | `config.json` na raiz do projeto |
| Windows (instalador) | `%APPDATA%\JobTracker\config.json` |

Gerado automaticamente na primeira execução. Pode ser editado direto no arquivo ou via **Configurações** na UI.

## Estrutura completa

```json
{
  "shifts": {
    "monday":    [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "tuesday":   [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "wednesday": [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "thursday":  [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "friday":    [{"start": "09:00", "end": "12:00"}, {"start": "13:00", "end": "18:00"}],
    "saturday":  [],
    "sunday":    []
  },
  "theme": "auto",
  "port": 5000,
  "target_percentage": 90,
  "user_name": "",
  "phrases_enabled": true
}
```

## Referência

### `shifts` (objeto)

Turnos por dia da semana. Chaves em inglês minúsculas: `monday`, `tuesday`, …, `sunday`.

Cada dia é uma **lista** de blocos, cada bloco com:

| Campo | Tipo | Formato |
|---|---|---|
| `start` | string | `HH:MM` (24h) |
| `end` | string | `HH:MM` (24h), maior que `start` |

- Uma lista vazia `[]` significa dia livre (sem meta).
- Múltiplos blocos permitem modelar intervalo de almoço.
- Máximo de 10 blocos por dia.
- Horários são validados no servidor; valores inválidos são rejeitados.

### `theme` (string)

Um entre: `"light"`, `"dark"`, `"auto"`.

- `auto` segue a preferência do sistema operacional via `prefers-color-scheme`.
- A UI também persiste a escolha corrente em `localStorage` (chave `jt-theme`).

### `port` (número)

Porta HTTP local. Padrão `5000`. Intervalo válido: `1024–65535`.

Após alterar, reinicie o servidor.

### `target_percentage` (número, 0–100)

Meta de apontamento como porcentagem do turno do dia. Padrão `90`.
Utilizado pela barra de progresso e indicador de meta do dashboard.

### `user_name` (string)

Nome exibido em mensagens de saudação. Até 100 caracteres. Padrão vazio.

### `phrases_enabled` (booleano)

Habilita/desabilita o carrossel de micro-frases motivacionais exibidas ao iniciar/pausar atividades. Padrão `true`.

## Validação e segurança

- Chaves desconhecidas são ignoradas silenciosamente.
- Valores fora dos tipos esperados são rejeitados (400).
- Gravação é **atômica**: arquivo temporário → `fsync` → `os.replace()`. No Linux, o diretório também é sincronizado para garantir a persistência.
- Tamanho máximo do corpo de requisição: 64 KB.

## Editar via API

```bash
curl -X PUT http://localhost:5000/api/config \
     -H "Content-Type: application/json" \
     -d '{"theme": "dark", "target_percentage": 95}'
```

```bash
curl -X PUT http://localhost:5000/api/shifts \
     -H "Content-Type: application/json" \
     -d @meus-turnos.json
```

## Resetar para os padrões

Basta apagar `config.json` e reiniciar. O arquivo será regenerado com valores padrão na próxima inicialização.

```bash
rm config.json
python3 run.py
```

!!! warning "Atenção"
    Isso **não** apaga seus dados em `data/`. Apenas a configuração.
