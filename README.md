# CHAMP AI Control Center — X-Agent Edition

> **Windows PowerShell AI control center with 34 X-Men-themed local AI agents, wake word activation, voice command dispatch, full conversation mode, DevOps integrations, and an Intelligence Hub. Runs fully local on bare metal — no cloud required.**

![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue?style=flat-square)
![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blueviolet?style=flat-square)
![Ollama](https://img.shields.io/badge/Ollama-local%20LLM-orange?style=flat-square)
![Agents](https://img.shields.io/badge/agents-34%20X--Men-red?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

---

## What is CHAMP AI?

CHAMP AI Control Center is a single PowerShell script that turns your Windows workstation into a fully-featured local AI command center. It manages your entire local AI stack — Ollama models, Open WebUI, Docker containers, and developer tools — through an interactive menu system with voice control.

Every AI agent is named after an X-Men character whose Marvel ability matches their AI role. Say **"Hey CEREBRO"** and your AI team is one voice command away.

---

## Features at a Glance

| Category | What's included |
| --- | --- |
| **34 AI Agents** | X-Men-themed agents from 1B (Dazzler) to 104B (Apocalypse), covering coding, security, reasoning, vision, math, SQL, medical, multilingual, and more |
| **Voice System** | Wake word ("Hey CEREBRO"), voice command dispatch, full voice conversation mode with any agent |
| **CEREBRO Chat** | Persistent back-and-forth conversation with any agent — text or voice — with memory across sessions |
| **Smart Router** | Describe your task in plain English, CEREBRO picks the best agent automatically |
| **Open WebUI** | Start, stop, restart, update, and open Open WebUI; register all agents by name so they appear in the model selector |
| **AI Dev Tools** | 23 tools: GPU monitor, Modelfile Creator, benchmark, prompt library, agent chain, multi-model compare, session export, Python env wizard, Jupyter, Docker Compose generator, port dashboard, API key manager, backup/restore, scheduler, UI code generator, live preview server, and more |
| **DevOps Panel** | Proxmox VE, GitHub, Docker Enhanced, Terraform, Packer, Ansible — each with AI-assisted operations |
| **Intelligence Hub** | Persistent history, cloud API fallback (OpenAI/Claude), Clipboard AI, WSL Manager, Live Dashboard, Event Log Watcher, Network Scanner, File Analyzer, Git Tools, LM Studio |
| **Wolverine Recovery** | Health scan, service recovery, emergency restart watchdog |
| **Voice Greeting** | Time-aware greeting on every launch — Good morning / afternoon / evening by name |

---

## Quick Start

```powershell
# 1. Allow PowerShell scripts (run once as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 2. Launch
powershell -ExecutionPolicy Bypass -File .\champ-ai-control-center-xagents.ps1
```

Or double-click `Launch-CHAMP-AI-Control-Center.bat`.

See [`DEPLOY.md`](DEPLOY.md) for permanent installation, desktop shortcut, and taskbar pinning.

---

## Voice Control

### Wake Word
Say **"Hey CEREBRO"**, **"CEREBRO"**, or **"CEREBRO wake up"** — CEREBRO chimes and asks what you need.

### Voice Commands (examples)

```
"Launch Forge"              → Activates Forge agent
"Open VS Code"              → Launches VS Code
"Start Ollama"              → Starts Ollama runtime
"System status"             → Runs CEREBRO health check
"Chat with Beast"           → Opens voice conversation with Beast
"Open dashboard"            → Opens Open WebUI in browser
"Wolverine health scan"     → Runs system health check
"Show Docker containers"    → Lists running containers
"Git tools"                 → Opens Git Tools menu
"DevOps"                    → Opens DevOps Control Panel
```

Any unrecognised phrase is answered by Professor-X verbally.

---

## The 34-Agent Roster

Agents are organised into six tiers by RAM requirement.

### Tier 1 — Lightning Fast (8 GB RAM)

| Agent | Model | Size | Role |
| --- | --- | --- | --- |
| Dazzler | `llama3.2:1b` | ~1 GB | Absolute fastest — trivial lookups |
| Jubilee | `llama3.2:3b` | ~2 GB | Ultra-fast lightweight assistant |
| Nightcrawler | `phi3:mini` | ~2.2 GB | Fast answers and quick summaries |

### Tier 2 — Core Team (16 GB+ RAM)

| Agent | Model | Size | Role |
| --- | --- | --- | --- |
| Professor-X | `llama3.1:8b` | ~4.7 GB | Strategy, planning, architecture |
| Forge | `qwen2.5-coder:7b` | ~4.4 GB | Coding, debugging, infrastructure |
| Cyclops | `mistral:7b` | ~4.1 GB | Cybersecurity, logs, threat analysis |
| Wolverine | `phi3:mini` | ~2.2 GB | Recovery, resilience, watchdog |
| Magneto | `codellama:7b` | ~3.8 GB | Experimental engineering |
| Beast | `deepseek-r1:7b` | ~4.7 GB | Scientific step-by-step reasoning |
| Storm | `gemma2:9b` | ~5.4 GB | Creative writing, long-form content |
| Psylocke | `qwen2.5:7b` | ~4.4 GB | Multilingual, structured output |
| Havok | `openchat:7b` | ~4.1 GB | Natural friendly conversation |
| Bishop | `solar:10.7b` | ~6.1 GB | Balanced all-purpose model |
| Sage | `mathstral:7b` | ~4.4 GB | Mathematics and STEM specialist |
| Cypher | `sqlcoder:7b` | ~4.1 GB | SQL and database specialist |
| Moira | `meditron:7b` | ~4.1 GB | Medical and health AI |
| Cannonball | `granite3.1-dense:8b` | ~5 GB | IBM enterprise model |
| Scout | `llava:7b` | ~4.7 GB | Vision — images, screenshots, diagrams |

### Tier 3 — Enhanced (24–32 GB RAM)

| Agent | Model | Size | Role |
| --- | --- | --- | --- |
| Gambit | `mistral-nemo:12b` | ~7.1 GB | Long context conversation |
| Cable | `nous-hermes2:10.7b` | ~6.1 GB | Precise instruction following |
| Sunfire | `gemma3:12b` | ~8 GB | Google Gemma 3 latest |
| Banshee | `phi4:14b` | ~9 GB | Microsoft Phi-4 precision |
| Mr. Sinister | `deepseek-r1:14b` | ~9 GB | Deep analytical reasoning |
| Iceman | `starcoder2:15b` | ~9 GB | Pure code — 80+ languages |
| Shadowcat | `codestral:22b` | ~13 GB | Mistral code specialist |

### Tier 4 — Vision Agents (8–16 GB RAM)

| Agent | Model | Size | Role |
| --- | --- | --- | --- |
| Scout | `llava:7b` | ~4.7 GB | Standard vision agent |
| Rogue | `llava:13b` | ~8 GB | Enhanced vision — more detail |
| Longshot | `llama3.2-vision:11b` | ~8 GB | Multimodal Llama |

### Tier 5 — Heavy Hitters (48 GB+ RAM)

| Agent | Model | Size | Role |
| --- | --- | --- | --- |
| Legion | `mixtral:8x7b` | ~26 GB | Mixture of 8 expert models |
| Emma Frost | `command-r:35b` | ~20 GB | 128K context window |
| Colossus | `llama3.1:70b` | ~40 GB | Maximum general power |
| Phoenix | `llama3.3:70b` | ~40 GB | Latest 70B powerhouse |
| Stryfe | `deepseek-r1:70b` | ~40 GB | Massive reasoning depth |

### Tier 6 — Titans (96 GB+ RAM — future upgrade)

| Agent | Model | Size | Role |
| --- | --- | --- | --- |
| Onslaught | `mixtral:8x22b` | ~80 GB | Largest mixture of experts |
| Apocalypse | `command-r-plus:104b` | ~60 GB | 104B — ultimate context |

---

## Main Menu

```
1.  CEREBRO System Status
2.  Start Ollama          2S. Stop Ollama
3.  X-Agent Launcher (6 tiers, 34 agents)
4.  Show X-Agent Model Map
5.  Pull / Update Single X-Agent Model
6.  Pull All X-Agent Models
6R. Register Agents in Open WebUI    6D. Remove Named Agent Models
7.  List Ollama Models
8.  Start Open WebUI      9. Stop    10. Restart    11. Update
12. Open Open WebUI Dashboard
13. Show Docker Containers
14. Open VS Code Project Folder
15. Wolverine Recovery Center
16. Toggle Voice Responses
17. Toggle Sound Alerts
18. View Activity Log
19. AI Development Tools  ──── 23 tools
20. DevOps Control Panel  ──── Proxmox · GitHub · Docker · Terraform · Packer · Ansible
21. Intelligence Hub      ──── 10 advanced tools
22. CEREBRO Chat / Voice Conversation
23. Exit
```

Status line: `Voice: ON/OFF` | `Sounds: ON/OFF` | `Wake Word: ACTIVE / OFF`

---

## AI Development Tools (option 19)

| # | Tool |
| --- | --- |
| 1 | GPU / Hardware Monitor |
| 2 | Modelfile Creator |
| 3 | Model Benchmark |
| 4 | Prompt Library |
| 5 | Agent Chain Pipeline |
| 6 | Multi-Model Comparison |
| 7 | Session Export |
| 8 | Python AI Env Wizard |
| 9 | Jupyter Launcher |
| 10 | Docker Compose Generator |
| 11 | Windows Terminal Profile |
| 12 | Ollama Model Search |
| 13 | Model Disk Manager |
| 14 | RAM / VRAM Advisor |
| 15 | Ollama REST API Tester |
| 16 | AI Services Port Dashboard |
| 17 | API Key Manager |
| 18 | Backup & Restore |
| 19 | Scheduled Agent Queries |
| 20 | UI Code Generator |
| 21 | Live Preview Server |
| 22 | Iterative Refinement Loop |
| 23 | Scout Vision Agent |

---

## DevOps Control Panel (option 20)

| Tool | AI Assist |
| --- | --- |
| **Proxmox VE** | Professor-X reviews node health |
| **GitHub** | Professor-X writes issue bodies and PR descriptions; Forge reviews diffs |
| **Docker Enhanced** | Cyclops analyses container logs; Forge generates Dockerfiles |
| **Terraform** | Professor-X reviews plan before apply; Forge generates `.tf` files |
| **Packer** | Forge generates HCL templates; Cyclops security-audits them |
| **Ansible** | Professor-X reviews playbooks before execution; Forge generates them |

---

## Intelligence Hub (option 21)

| # | Tool |
| --- | --- |
| 1 | Conversation History — persistent per-agent memory across sessions |
| 2 | Cloud API Fallback — OpenAI (gpt-4o) and Claude (Sonnet) via `.env` keys |
| 3 | Clipboard AI — send clipboard content to any agent instantly |
| 4 | WSL Manager — distro control, Linux commands, Forge bash generator |
| 5 | Live Dashboard — auto-refreshing war-room: CPU, RAM, services, ports |
| 6 | Windows Event Log Watcher — Cyclops AI analysis of system errors |
| 7 | Network Scanner — ping, port scan, sweep, Cyclops threat analysis |
| 8 | File & Code Analyzer — Forge review, Cyclops audit, unit test generation |
| 9 | Git Tools — local repo ops, Forge commit messages, Cyclops diff audit |
| 10 | LM Studio — second local backend on port 1234, side-by-side vs Ollama |

---

## Prerequisites

| Tool | Required |
| --- | --- |
| [PowerShell 7+](https://aka.ms/powershell) | Yes |
| [Ollama](https://ollama.com/download) | Yes |
| [Docker Desktop](https://www.docker.com/products/docker-desktop) | Yes (for Open WebUI) |
| Microphone | For voice / wake word features |
| [VS Code](https://code.visualstudio.com) | Optional |
| NVIDIA GPU driver | Optional (for GPU monitor) |
| [GitHub CLI](https://cli.github.com) | Optional (for GitHub DevOps) |
| Terraform, Packer, Ansible | Optional (for DevOps integrations) |
| [LM Studio](https://lmstudio.ai) | Optional (second AI backend) |

---

## Runtime Files

| File / Folder | Purpose |
| --- | --- |
| `CHAMP-activity.log` | Timestamped event log |
| `CHAMP-prompts.json` | Saved prompt library |
| `.env` | API keys — input masked, never displayed |
| `.devops-config.json` | DevOps connection settings |
| `CHAMP-History\` | Per-agent conversation history |
| `CHAMP-Sessions\` | Exported responses and comparisons |
| `CHAMP-Backups\` | Timestamped backup snapshots |
| `Modelfile-<name>` | Custom agent Modelfiles |
| `champ-ai-env\` | Python virtual environment |

---

## First Run

```
1. Option 1  — CEREBRO System Status (verify RAM, Docker, Ollama)
2. Option 2  — Start Ollama
3. Option 6  — Pull All X-Agent Models (Core Team tier first)
4. Option 6R — Register agents in Open WebUI
5. Option 8  — Start Open WebUI
6. Option 12 — Open dashboard → create admin account at http://localhost:3000
7. Option 22 → item 8 — Start wake word listener → say "Hey CEREBRO"
```

---

## Deployment

See [`DEPLOY.md`](DEPLOY.md) for:

- Moving out of Downloads to a permanent location
- Setting PowerShell execution policy
- Creating a Desktop shortcut
- Pinning to the taskbar
- Auto-starting Ollama on login
- Uninstall instructions

---

## Full Documentation

See [`README-XAGENTS.md`](README-XAGENTS.md) for the complete reference covering every feature, all 34 agents, all voice commands, every menu option, and all runtime files.

---

## License

MIT — free to use, modify, and distribute.
