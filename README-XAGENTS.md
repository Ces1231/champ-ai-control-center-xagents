# CHAMP AI Control Center - X-Agent Edition

A Windows PowerShell menu system for managing your local AI development stack with X-Men-inspired agent roles, voice responses, sound alerts, Wolverine recovery, and a full AI Dev Tools suite.

## Agents

Each agent is named after an X-Men character whose Marvel abilities mirror their AI function.

### Professor X

**Model:** `llama3.1:8b` | **Main Function:** Strategy & Planning

The team's leader and most powerful mind. Use Professor X for high-level reasoning, architecture decisions, project planning, and anything that needs careful thought before action.

### Forge

**Model:** `qwen2.5-coder:7b` | **Main Function:** Coding & Infrastructure

The X-Men's tech genius who can build or fix anything. Use Forge for writing code, debugging, scripting in Python or PowerShell, Docker configuration, and all infrastructure tasks.

### Cyclops

**Model:** `mistral:7b` | **Main Function:** Cybersecurity & Analysis

Laser-focused, disciplined tactician. Use Cyclops for security analysis, reviewing logs, triaging threats, IOC investigation, and any task that needs precision and methodical thinking.

### Nightcrawler

**Model:** `phi3:mini` | **Main Function:** Fast Lightweight Queries

The fastest X-Man — teleports instantly. Use Nightcrawler when you need a quick answer, a short explanation, a definition, or a summary without waiting for a heavier model to load.

### Wolverine

**Model:** `phi3:mini` | **Main Function:** Recovery & Resilience

Near-indestructible with a rapid healing factor. Wolverine monitors and heals the local AI stack — restarting Ollama, recovering Open WebUI, running health scans, and acting as the emergency watchdog.

### Magneto

**Model:** `codellama:7b` | **Main Function:** Experimental Engineering

Powerful, unpredictable, bends the rules. Use Magneto for advanced code generation, experimental builds, low-level logic, and as the slot for dropping in larger or specialist models.

### CEREBRO

**Model:** PowerShell system layer | **Main Function:** Orchestration & Control

Professor X's machine that amplifies his reach to the entire world. CEREBRO is the control center itself — it runs the menus, speaks the voice responses, monitors system health, and connects every agent.

---

### Smart Agent Router

Type any task in plain English and CEREBRO automatically picks the best agent by scoring keyword matches.

| Agent | Trigger keywords |
| --- | --- |
| Professor X | plan, strategy, architect, design, roadmap, advise, recommend, think |
| Forge | code, debug, script, python, powershell, docker, build, deploy, bug, api, implement |
| Cyclops | security, threat, malware, ioc, vulnerability, audit, log, triage, scan, breach |
| Nightcrawler | quick, fast, explain, summarize, define, tldr, brief, simple |
| Wolverine | recover, restart, broken, crashed, health, watchdog, restore, failed |
| Magneto | experiment, advanced, optimize, benchmark, compile, performance, prototype |

## Run

```powershell
powershell -ExecutionPolicy Bypass -File .\champ-ai-control-center-xagents.ps1
```

Or double-click `Launch-CHAMP-AI-Control-Center.bat`.

## Main Menu Options

| # | Option |
| --- | --- |
| 1 | CEREBRO System Status (RAM, disk, services, loaded models) |
| 2 | Start Ollama |
| 2S | Stop Ollama |
| 3 | X-Agent Launcher |
| 4 | Show X-Agent Model Map |
| 5 | Pull / Update Single X-Agent Model |
| 6 | Pull All X-Agent Models |
| 7 | List Ollama Models |
| 8 | Start Open WebUI |
| 9 | Stop Open WebUI |
| 10 | Restart Open WebUI |
| 11 | Update Open WebUI Manually |
| 12 | Open Open WebUI Dashboard |
| 13 | Show Docker Containers |
| 14 | Open VS Code Project Folder |
| 15 | Wolverine Recovery Center |
| 16 | Toggle Voice Responses |
| 17 | Toggle Sound Alerts |
| 18 | View Activity Log |
| 19 | **AI Development Tools** |
| 20 | **DevOps Control Panel** |
| 21 | **Intelligence Hub** |
| 22 | Exit |

## AI Development Tools (option 19)

### Core Tools

| # | Tool | Description |
| --- | --- | --- |
| 1 | GPU / Hardware Monitor | CPU load, RAM %, disk per drive, NVIDIA VRAM and temp via `nvidia-smi` |
| 2 | Modelfile Creator | Build a custom Ollama agent with a system prompt and temperature, then `ollama create` it |
| 3 | Model Benchmark | Time a response end-to-end, estimate tokens/sec, logged to activity log |
| 4 | Prompt Library | Save, browse, and fire reusable prompts at any agent (`CHAMP-prompts.json`) |
| 5 | Agent Chain Pipeline | Pipe Agent A's full response as context into Agent B |
| 6 | Multi-Model Comparison | Send the same prompt to 2–3 agents simultaneously, compare with timing summary, save to Markdown |
| 7 | Session Export | Run a prompt and save the full response to a timestamped `.md` or `.txt` file |

### Environment

| # | Tool | Description |
| --- | --- | --- |
| 8 | Python AI Env Wizard | Create a venv and install bundle groups: torch/transformers, LangChain, LlamaIndex, Ollama SDK, data science, FastAPI, Jupyter |
| 9 | Jupyter Launcher | Start Jupyter Notebook (uses local venv if present), open browser to localhost:8888 |
| 10 | Docker Compose Generator | Generate a `docker-compose.yml` for any combination of Ollama, Open WebUI, n8n, Flowise, LiteLLM, SearXNG, Qdrant, Redis — with optional immediate launch |
| 11 | Windows Terminal Profile | Auto-install a CHAMP AI tab in Windows Terminal with correct launch command and color scheme |

### Models & APIs

| # | Tool | Description |
| --- | --- | --- |
| 12 | Ollama Model Search | Browse ollama.com/library by keyword, pull a model directly from results |
| 13 | Model Disk Manager | List all installed models with sizes, delete to free disk space |
| 14 | RAM / VRAM Advisor | Check compatibility of 13 common models against your free RAM/VRAM before pulling; heuristic estimate for custom model names |
| 15 | Ollama REST API Tester | Direct `Invoke-RestMethod` to localhost:11434 — list models, version, `/api/generate`, model info |
| 16 | AI Services Port Dashboard | Live port scan for Ollama, Open WebUI, Jupyter, FastAPI, Gradio, Streamlit, LiteLLM, AnythingLLM |
| 17 | API Key Manager | Read/write `.env` for OPENAI_API_KEY, HF_TOKEN, etc.; input via `-AsSecureString`, masked display |

### Data & Scheduling

| # | Tool | Description |
| --- | --- | --- |
| 18 | Backup & Restore | Backs up `.env`, prompts, Modelfiles, activity log, and Open WebUI Docker volume to `CHAMP-Backups\`; full restore from any snapshot |
| 19 | Scheduled Agent Queries | Create Windows Task Scheduler jobs that run a prompt against any agent on a daily/hourly/logon schedule; output auto-saved to `CHAMP-Sessions\` |

## DevOps Control Panel (option 20)

A full DevOps integration layer inside CHAMP AI. Each tool gets its own submenu with raw CLI commands and AI-assisted operations powered by the X-Agent team.

### Proxmox VE

| # | Action |
| --- | --- |
| 1 | Dashboard — node status, CPU, RAM, storage |
| 2 | List VMs |
| 3 | Start / Stop / Reboot a VM |
| 4 | Snapshot Manager — list, create, rollback |
| 5 | AI Infrastructure Review (Professor X analyses your node health) |
| 6 | Configure Proxmox connection (host, token ID, secret) |

### GitHub

| # | Action |
| --- | --- |
| 1 | List repos |
| 2 | Create issue (AI-assisted body via Professor X) |
| 3 | List open PRs |
| 4 | Create PR (AI-assisted description via Professor X) |
| 5 | AI code review of latest diff (Forge) |
| 6 | Trigger a GitHub Actions workflow |
| 7 | Configure GitHub (default repo) |

### Docker Enhanced

| # | Action |
| --- | --- |
| 1 | List containers (all) |
| 2 | Start / Stop / Remove a container |
| 3 | View container logs + Cyclops AI analysis |
| 4 | Live container stats |
| 5 | AI Dockerfile generator (Forge) |
| 6 | Build an image from a Dockerfile |
| 7 | List volumes |
| 8 | List networks |

### Terraform

| # | Action |
| --- | --- |
| 1 | terraform init |
| 2 | terraform plan (Professor X reviews before apply) |
| 3 | terraform apply |
| 4 | terraform destroy (requires typing DESTROY to confirm) |
| 5 | terraform state list |
| 6 | List / switch workspaces |
| 7 | AI .tf file generator (Forge) |
| 8 | Configure working directory |

### Packer

| # | Action |
| --- | --- |
| 1 | packer validate |
| 2 | packer build |
| 3 | AI HCL template generator (Forge) |
| 4 | Cyclops security audit of a template |
| 5 | Configure template path |

### Ansible

| # | Action |
| --- | --- |
| 1 | Run a playbook (Professor X reviews before execution) |
| 2 | Ad-hoc command |
| 3 | List inventory |
| 4 | ansible-galaxy install a role |
| 5 | AI playbook generator (Forge) |
| 6 | Cyclops security audit of a playbook |
| 7 | Configure inventory path |

> Ansible runs natively if `ansible` is on PATH, or falls back to `wsl ansible` for WSL installations.

### DevOps Config

All DevOps settings are stored in `.devops-config.json` in the script folder. Secrets (Proxmox token secret, API keys) are read from `.env`. Run the **Configure** option inside each tool's submenu to set up connection details.

---

## Intelligence Hub (option 21)

New capability layer exposing 10 advanced tools accessible from a single submenu.

| # | Tool | Description |
| --- | --- | --- |
| 1 | Conversation History | Persistent per-agent memory — each agent remembers your last 100 exchanges across sessions, stored in `CHAMP-History\` |
| 2 | Cloud API Fallback | Route any prompt to OpenAI (gpt-4o-mini, gpt-4o) or Claude (Haiku, Sonnet) using keys from `.env`; includes side-by-side local vs cloud comparison |
| 3 | Clipboard AI | Grab whatever is on the clipboard and fire it at any agent instantly, with an optional instruction prefix |
| 4 | WSL Manager | List distros, launch a shell, run commands, start/stop/set-default distros, check Linux system info, Forge bash script generator |
| 5 | Live Dashboard | Auto-refreshing war-room view — CPU, RAM, disk, Ollama status, Docker, loaded models, port health, recent activity log |
| 6 | Windows Event Log Watcher | Browse System / Application / Security event logs; Cyclops AI analysis of recent errors; keyword search |
| 7 | Network Scanner | Ping, traceroute, DNS lookup, common port scan, /24 ping sweep, local network info, Cyclops analysis of results |
| 8 | File & Code Analyzer | Drop any file path — Forge explains and reviews code, Cyclops security-audits it, Nightcrawler summarises logs, Forge generates unit tests, Professor X analyses folder architecture |
| 9 | Git Tools | `git status/log/diff/stash/branch` in any local repo; Forge generates commit messages and reviews diffs; Cyclops security-scans uncommitted changes |
| 10 | LM Studio | Connect to LM Studio's OpenAI-compatible API on port 1234; list models, chat, code tasks, security analysis, side-by-side vs Forge |

### New Runtime Files

| File / Folder | Purpose |
| --- | --- |
| `CHAMP-History\<agent>.json` | Per-agent conversation history (up to 100 exchanges) |

---

## Recommended First Run Order

1. CEREBRO System Status — verify RAM, Docker, Ollama
2. Start Ollama
3. Pull All X-Agent Models
4. Start Open WebUI
5. Open Open WebUI Dashboard
6. AI Dev Tools → Python AI Env Wizard (if using Python)

## Files Created at Runtime

| File / Folder | Purpose |
| --- | --- |
| `CHAMP-activity.log` | Timestamped log of every agent activation, query, and event |
| `CHAMP-prompts.json` | Saved prompt library entries |
| `.env` | API keys (OPENAI_API_KEY, HF_TOKEN, etc.) — input masked, never shown |
| `Modelfile-<name>` | Custom agent Modelfiles built by the Modelfile Creator |
| `champ-ai-env\` | Python virtual environment created by the AI Env Wizard |
| `CHAMP-Sessions\` | Exported agent responses and model comparison Markdowns |
| `CHAMP-Backups\` | Timestamped backup snapshots (configs, prompts, Docker volume) |
| `docker-compose.yml` | Generated full-stack compose file from Docker Compose Generator |
| `sched-CHAMP-<name>.ps1` | Wrapper scripts for scheduled Task Scheduler queries |

## Safe Update Design

Open WebUI does not auto-update on launch. Use **Update Open WebUI Manually** (option 11) only when ready — it preserves the `open-webui` data volume.
