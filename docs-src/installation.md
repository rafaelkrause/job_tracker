# Instalação

Guia completo de instalação do Job Tracker no Linux, macOS e Windows.

## Pré-requisitos

| Sistema | Requisitos |
|---|---|
| Linux / macOS | Python 3.10+, `curl`, `bash` |
| Windows (instalador) | Nenhum — Python embutido |
| Windows (manual) | Python 3.10+ |
| Opcional | `pystray` + `Pillow` (ícone na bandeja, incluído por padrão no script remoto) |

## Linux / macOS — instalação rápida (remoto)

Recomendado para a maioria dos usuários. Baixa o `.whl` publicado no GitHub Releases, instala em um virtualenv isolado e cria um launcher `job-tracker` no `PATH`.

```bash
curl -fsSL https://raw.githubusercontent.com/rafaelkrause/job_tracker/main/install-remote.sh | bash
```

Depois:

```bash
job-tracker              # abre o navegador em http://localhost:5000
job-tracker --no-browser # só inicia o servidor
```

### O que é criado

| Caminho | Conteúdo |
|---|---|
| `~/.local/share/job-tracker/.venv/` | Ambiente Python isolado |
| `~/.local/share/job-tracker/user/` | `config.json` + `data/YYYY-MM.json` (seus dados) |
| `~/.local/bin/job-tracker` | Launcher no `PATH` |
| `~/.local/share/applications/job-tracker.desktop` | Entrada no menu de aplicações (Linux) |

Se `~/.local/bin` não estiver no `PATH`, o script avisa e sugere a linha a adicionar no `~/.bashrc` ou `~/.zshrc`.

### Opções via variáveis de ambiente

```bash
# Versão específica (default: última release)
JT_VERSION=0.1.0 curl -fsSL .../install-remote.sh | bash

# Sem suporte a bandeja (pystray + Pillow)
JT_NO_TRAY=1 curl -fsSL .../install-remote.sh | bash

# Local de instalação customizado
JT_PREFIX=/opt/job-tracker curl -fsSL .../install-remote.sh | bash
```

### Autostart (opcional)

A flag `--service` registra o serviço no padrão nativo do SO:

- **Linux:** unidade `systemd --user` em `~/.config/systemd/user/job-tracker.service`, habilitada automaticamente. Sobe no login.
- **macOS:** `LaunchAgent` em `~/Library/LaunchAgents/com.rafaelkrause.jobtracker.plist`, carregado via `launchctl`. Sobe no login.

```bash
curl -fsSL https://raw.githubusercontent.com/rafaelkrause/job_tracker/main/install-remote.sh | bash -s -- --service
```

Para rodar apenas a ativação do serviço depois de uma instalação sem `--service`, basta executar o comando acima novamente — o script detecta a instalação existente e só adiciona o serviço.

### Desinstalar

```bash
# Preserva os dados em ~/.local/share/job-tracker/user/
curl -fsSL https://raw.githubusercontent.com/rafaelkrause/job_tracker/main/install-remote.sh | bash -s -- --uninstall

# Remove também os dados (irreversível)
curl -fsSL https://raw.githubusercontent.com/rafaelkrause/job_tracker/main/install-remote.sh | bash -s -- --uninstall --purge-data
```

O desinstalador para e remove o serviço (se existir), apaga launcher, entrada do menu e virtualenv. Se você baixou o script em vez de usar `curl | bash`, a execução interativa (`bash install-remote.sh --uninstall`) pergunta antes de apagar os dados.

### Nota sobre macOS (v0.1.0)

O Windows tem instalador `.exe` com experiência double-click para usuário comum; no macOS, entregar o mesmo nível exige:

- Empacotar como `.app` via `py2app` ou PyInstaller.
- **Conta Apple Developer (US$99/ano)** para assinar o código.
- Passar pelo processo de **notarização** da Apple — sem isso, o Gatekeeper bloqueia a abertura com "unidentified developer".

Sem esse investimento, qualquer `.app` caseiro emite avisos assustadores. Por isso o v0.1.0 usa o caminho `curl | bash` descrito acima, que funciona com o que o macOS já oferece (Python via Homebrew ou oficial, `launchd` para autostart). É a mesma experiência que ferramentas como Homebrew, oh-my-zsh e Rust/rustup oferecem.

## Linux / macOS — a partir do código-fonte (contribuidores)

Para desenvolver ou modificar o projeto:

```bash
git clone https://github.com/rafaelkrause/job_tracker.git
cd job_tracker
./install.sh            # cria .venv e instala dependências
./job-tracker.sh        # inicia
```

Alternativa manual:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev,tray]"   # editable install + ferramentas de dev
python3 run.py
```

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

## Gerar o instalador Windows do zero

Só necessário para customizar o instalador. Roda em host Linux:

```bash
sudo apt install nsis
./installer/build_installer.sh 1.0.0
# saída: installer/JobTracker-Setup-1.0.0.exe
```

O workflow `.github/workflows/build-installer.yml` faz isso automaticamente quando uma tag `v*` é publicada.

## Atualizar

### Linux / macOS — via script remoto

Reexecute o `install-remote.sh`: ele detecta o virtualenv existente, baixa a versão nova, reinstala o wheel e preserva seus dados em `~/.local/share/job-tracker/user/`.

### Linux / macOS — a partir do código-fonte

```bash
cd job_tracker
git pull
source .venv/bin/activate
pip install -r requirements.txt --upgrade
```

### Windows

Execute o novo `JobTracker-Setup-X.Y.Z.exe`. Dados e configuração em `%APPDATA%\JobTracker` são preservados.

## Desinstalar

- **Linux/macOS (instalação remota):** veja [Desinstalar](#desinstalar) acima.
- **Linux/macOS (a partir do código):** `rm -rf job_tracker/`. Se aplicável, `systemctl --user disable --now job-tracker.service`.
- **Windows:** Painel de Controle → Programas → Job Tracker → Desinstalar.
