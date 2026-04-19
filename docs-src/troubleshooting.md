# Solução de problemas

Erros comuns e como resolvê-los.

## Instalação

### `ModuleNotFoundError: No module named 'flask'`

Você provavelmente está fora do ambiente virtual.

```bash
# Linux / macOS
source .venv/bin/activate

# Windows (PowerShell)
.venv\Scripts\Activate.ps1
```

### `python3: command not found` (Linux/macOS)

Instale Python 3.10+:

```bash
# Ubuntu/Debian
sudo apt install python3 python3-venv python3-pip

# macOS (Homebrew)
brew install python@3.11
```

### `install.sh: Permission denied`

Dê permissão de execução:

```bash
chmod +x install.sh job-tracker.sh
```

### SmartScreen bloqueia o instalador Windows

O `.exe` não é assinado digitalmente. Clique em **Mais informações → Executar assim mesmo**. É seguro — o código é aberto e pode ser verificado no repositório.

## Execução

### Porta 5000 em uso

Mensagem típica: `OSError: [Errno 98] Address already in use`.

Altere a porta em `config.json`:

```json
{ "port": 5050 }
```

Ou identifique e encerre o processo:

```bash
# Linux / macOS
lsof -i :5000
kill <PID>

# Windows (PowerShell)
Get-NetTCPConnection -LocalPort 5000
Stop-Process -Id <PID>
```

### O navegador não abre automaticamente

Navegue manualmente para `http://localhost:5000`. Para desativar a abertura automática:

```bash
python3 run.py --no-browser
```

### Ícone da bandeja não aparece

1. Confirme que `pystray` e `Pillow` estão instalados no venv:

    ```bash
    pip install pystray Pillow
    ```

2. Em **GNOME puro** (Ubuntu 22.04+), instale a extensão **AppIndicator and KStatusNotifierItem Support**.
3. Em Windows, verifique se o ícone não está em "ícones ocultos" na bandeja.

## Dados

### JSON corrompido

Se um arquivo `data/YYYY-MM.json` estiver corrompido, o app o renomeia para `.corrupted` e continua com estado vazio para aquele mês. Para recuperar:

1. Feche o servidor.
2. Inspecione o `.corrupted` com um editor.
3. Corrija manualmente e renomeie de volta para `.json`.
4. Reinicie o servidor.

### Arquivo não é atualizado

Escritas são atômicas e usam `os.replace()`. Se mesmo assim o arquivo não mudar:

- Verifique permissões da pasta `data/`.
- Verifique se você tem espaço em disco.
- Confira os logs do servidor (stdout) para erros de I/O.

### Perdi `config.json`

Sem problema — é regenerado com valores padrão na próxima inicialização. Seus dados históricos em `data/` continuam intactos.

## Bandeja / serviço

### Serviço systemd não inicia

```bash
systemctl --user status job-tracker.service
journalctl --user -u job-tracker.service -n 50
```

Causas comuns:

- Caminho absoluto errado em `WorkingDirectory` / `ExecStart`.
- Falta executar `systemctl --user daemon-reload` após editar o arquivo.
- venv fora do caminho esperado.

### Serviço Windows não inicia

No gerenciador de serviços (`services.msc`), confira o status do serviço "Job Tracker". Se usar NSSM, rode:

```powershell
nssm status JobTracker
nssm edit JobTracker
```

e ajuste o caminho do executável.

## Exportação

### O CSV está "quebrado" no Excel brasileiro

Excel pt-BR espera `;` como separador. Prefira **TSV** e cole diretamente na célula:

```
/api/export?format=tsv
```

### iClips não aceita a colagem

Verifique se selecionou o intervalo de células correto antes de colar. Se preciso, abra o TSV em uma planilha e copie de lá.

## Ainda com problemas?

- Abra uma issue: [github.com/rafaelkrause/job_tracker/issues](https://github.com/rafaelkrause/job_tracker/issues)
- Inclua: sistema operacional, versão do Python, trecho dos logs do servidor e passos para reproduzir.
