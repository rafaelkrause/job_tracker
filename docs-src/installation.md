# Instalação

Guia completo de instalação do Job Tracker no Linux, macOS e Windows.

## Pré-requisitos

| Sistema | Requisitos |
|---|---|
| Linux / macOS | Python 3.10+, `pip`, `git`, `bash` |
| Windows (instalador) | Nenhum — Python embutido |
| Windows (manual) | Python 3.10+ |
| Opcional | `pystray` + `Pillow` para ícone na bandeja |

## Linux / macOS — com script

A forma recomendada é rodar `install.sh`:

```bash
git clone https://github.com/rafaelkrause/job_tracker.git
cd job_tracker
./install.sh
```

O script:

1. Verifica se Python 3.10+ está disponível.
2. Cria um ambiente virtual em `.venv/`.
3. Instala dependências do `requirements.txt`.
4. Opcionalmente instala `pystray` + `Pillow`.
5. Cria um atalho `.desktop` se ambiente gráfico for detectado.

Depois, execute:

```bash
./job-tracker.sh
# ou
python3 run.py
```

## Linux / macOS — manual

```bash
git clone https://github.com/rafaelkrause/job_tracker.git
cd job_tracker

python3 -m venv .venv
source .venv/bin/activate

pip install -r requirements.txt

# opcional: suporte a bandeja
pip install pystray Pillow

python3 run.py
```

Use `python3 run.py --no-browser` para não abrir o navegador automaticamente.

## Windows — instalador NSIS

1. Baixe `JobTracker-Setup-X.Y.Z.exe` da [página de releases](https://github.com/rafaelkrause/job_tracker/releases).
2. Execute o `.exe`. Se o SmartScreen bloquear, clique em **Mais informações → Executar assim mesmo** (instalador não assinado).
3. O assistente permite escolher:
    - Atalho na área de trabalho
    - Entrada no menu Iniciar
    - Componente opcional de serviço do Windows (NSSM)

### Detalhes

- **Instalação por usuário**, sem UAC. Destino padrão: `%LOCALAPPDATA%\Programs\JobTracker`
- **Python embutido**: nenhum Python é instalado globalmente
- **Dados**: ficam em `%APPDATA%\JobTracker` (preservados entre atualizações)

## Windows — manual

1. Instale [Python 3.10+](https://www.python.org/downloads/windows/). Marque **Add Python to PATH**.
2. Baixe o código (ZIP da release ou `git clone`).
3. Abra o PowerShell na pasta do projeto:

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python run.py
```

## Gerar o instalador do zero

Só necessário se você quer customizar o instalador Windows. Roda em host Linux:

```bash
sudo apt install nsis
./installer/build_installer.sh 1.0.0
# saída: installer/JobTracker-Setup-1.0.0.exe
```

O workflow `.github/workflows/build-installer.yml` faz isso automaticamente quando uma tag `v*` é publicada.

## Iniciar automaticamente

### Linux — systemd (unidade de usuário)

Crie `~/.config/systemd/user/job-tracker.service`:

```ini
[Unit]
Description=Job Tracker
After=network.target

[Service]
Type=simple
WorkingDirectory=%h/job_tracker
ExecStart=%h/job_tracker/.venv/bin/python run.py --no-browser
Restart=on-failure

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now job-tracker.service
```

### macOS — launchd

Crie `~/Library/LaunchAgents/com.user.jobtracker.plist` com `<ProgramArguments>` apontando para `python` e `run.py`. Carregue com `launchctl load`.

### Windows — serviço via NSSM

O instalador oficial oferece a opção. Para instalação manual, use [NSSM](https://nssm.cc/):

```powershell
nssm install JobTracker "C:\caminho\job_tracker\.venv\Scripts\python.exe" run.py --no-browser
nssm start JobTracker
```

## Atualizar

### Linux / macOS

```bash
cd job_tracker
git pull
source .venv/bin/activate
pip install -r requirements.txt --upgrade
```

### Windows

Execute o novo `JobTracker-Setup-X.Y.Z.exe`. Dados e configuração em `%APPDATA%\JobTracker` são preservados.

## Desinstalar

- **Linux/macOS**: `rm -rf job_tracker/`. Se aplicável: `systemctl --user disable --now job-tracker.service`.
- **Windows**: Painel de Controle → Programas → Job Tracker → Desinstalar.
- Para remover dados históricos: apague `data/` (Linux) ou `%APPDATA%\JobTracker` (Windows).
