# CHAMP AI Control Center — X-Agent Edition

A Windows PowerShell control center for your local AI development stack. Manages Ollama, Open WebUI, Docker, and a full suite of development tools through a menu-driven interface with X-Men-inspired AI agents, voice responses, wake word activation, voice command dispatch, full conversation mode, sound alerts, Wolverine recovery, DevOps integrations, and an Intelligence Hub.

---

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\champ-ai-control-center-xagents.ps1
```

Or double-click `Launch-CHAMP-AI-Control-Center.bat`.

On every launch CEREBRO greets you by name with a time-aware greeting:

- **Morning** (5 AM–noon): *"Good morning, Carnell. CEREBRO is online. Today is Monday, May 12. Your X-Agent team is standing by."*
- **Afternoon** (noon–5 PM): *"Good afternoon, Carnell..."*
- **Evening** (5 PM–9 PM): *"Good evening, Carnell..."*
- **Night** (9 PM–5 AM): *"Welcome back, Carnell..."*

---

## Voice System

CEREBRO has three voice layers:

### 1. Voice Output (always on)

Every CEREBRO message, agent response, and status update is spoken aloud using the Windows Speech Synthesis engine. Toggle with option **16**.

### 2. CEREBRO Conversation Mode (option 22)

Full back-and-forth conversation with any of the 34 agents. CEREBRO speaks every response. You can type or speak.

**In-conversation commands:**

| Command | Action |
| --- | --- |
| `exit` / `bye` | End the conversation |
| `switch` | Change to a different agent mid-conversation |
| `voice on` | Enable microphone input |
| `voice off` | Back to typing |
| `clear` | Wipe conversation memory for this agent |

### 3. Wake Word — "Hey CEREBRO" (option 22 → item 8)

A background listener watches your microphone at all times. Say any of these phrases:

- **"Hey CEREBRO"**
- **"CEREBRO"**
- **"CEREBRO wake up"**

CEREBRO chimes, says *"Yes, Carnell. What would you like me to do?"* and listens for a command.

Wake word status is shown on the main menu status line: `Wake Word: ACTIVE — say 'Hey CEREBRO'`

### 4. Voice Command Dispatcher

After the wake word, speak a command and CEREBRO executes it directly — no menu navigation required.

**System & Services:**

| Voice Command | Action |
| --- | --- |
| "System status" / "Check status" | CEREBRO system health check |
| "Start Ollama" / "Launch Ollama" | Start Ollama runtime |
| "Stop Ollama" | Stop Ollama |
| "Start WebUI" / "Start Open WebUI" | Start Open WebUI container |
| "Stop WebUI" | Stop Open WebUI |
| "Restart WebUI" | Restart Open WebUI container |
| "Open dashboard" | Open Open WebUI in browser |
| "Show Docker containers" | List Docker containers |
| "List models" / "Show models" | List Ollama models |
| "Activity log" / "Show log" | Open activity log |
| "Live dashboard" / "War room" | Launch live dashboard |
| "Open VS Code" / "Open VS Code" | Launch VS Code |
| "Wolverine health scan" | Run Wolverine health check |
| "Pull all models" | Download all agent models |
| "Register agents" | Register agents in Open WebUI |
| "Network scan" | Open Network Scanner |
| "Event log" / "Windows errors" | Open Event Log Watcher |
| "Git tools" / "Git status" | Open Git Tools |
| "DevOps" / "Proxmox" / "Terraform" | Open DevOps Control Panel |
| "AI tools" / "Dev tools" | Open AI Development Tools |
| "Agent map" / "Show roster" | Display full agent roster |
| "Clipboard AI" | Send clipboard to an agent |

**Agent Commands:**

| Voice Command | Action |
| --- | --- |
| "Launch Forge" / "Activate Forge" | Activate Forge agent |
| "Use Cyclops" / "Start Cyclops" | Activate Cyclops |
| "Chat with Beast" / "Talk to Beast" | Open voice conversation with Beast |
| "Speak to Gambit" | Open voice conversation with Gambit |
| *(any agent name + action verb)* | Routes to that agent |

**Fallback:** Any unrecognised phrase is sent to Professor-X who answers it verbally and saves it to conversation history.

---

## 34-Agent Roster

Each agent is named after an X-Men character whose Marvel abilities mirror their AI function. The agent launcher (option 3) organises them into six tiers by RAM requirement.

### RAM Requirements at a Glance

| Tier | RAM Needed | Agents |
| --- | --- | --- |
| Lightning Fast | 8 GB | Dazzler, Jubilee, Nightcrawler |
| Core Team | 16 GB+ | Professor-X, Forge, Cyclops, Wolverine, Magneto, Beast, Storm, Psylocke, Havok, Bishop, Sage, Cypher, Moira, Cannonball, Scout |
| Enhanced | 24–32 GB | Gambit, Cable, Sunfire, Banshee, Mr. Sinister, Iceman, Shadowcat |
| Vision | 8–16 GB | Scout, Rogue, Longshot |
| Heavy Hitters | 48 GB+ | Legion, Emma Frost, Colossus, Phoenix, Stryfe |
| Titans | 96 GB+ | Onslaught, Apocalypse |

---

### Tier 1 — Lightning Fast

#### Dazzler

**Model:** `llama3.2:1b` (~1 GB) | **Function:** Absolute Fastest

1B parameters. Instant answers for trivial lookups. Use on low-RAM machines or when speed is everything.

#### Jubilee

**Model:** `llama3.2:3b` (~2 GB) | **Function:** Ultra-Fast Lightweight

The youngest X-Man — snappy, energetic, and instant. Use when even Nightcrawler feels slow. Ideal for one-liners and minimal-RAM environments.

#### Nightcrawler

**Model:** `phi3:mini` (~2.2 GB) | **Function:** Fast Lightweight Queries

The fastest X-Man — teleports instantly. Quick answers, short explanations, definitions, and summaries without waiting for a heavier model.

---

### Tier 2 — Core Team (16 GB+)

#### Professor-X

**Model:** `llama3.1:8b` | **Function:** Strategy & Planning

The team's leader and most powerful mind. High-level reasoning, architecture decisions, project planning, and anything that needs careful thought before action.

#### Forge

**Model:** `qwen2.5-coder:7b` | **Function:** Coding & Infrastructure

The X-Men's tech genius. Writing code, debugging, scripting in Python or PowerShell, Docker configuration, API design, and all infrastructure tasks.

#### Cyclops

**Model:** `mistral:7b` | **Function:** Cybersecurity & Analysis

Laser-focused, disciplined tactician. Security analysis, reviewing logs, triaging threats, IOC investigation, and any task requiring precision and methodical thinking.

#### Wolverine

**Model:** `phi3:mini` | **Function:** Recovery & Resilience

Near-indestructible with a rapid healing factor. Monitors and heals the local AI stack — restarting Ollama, recovering Open WebUI, running health scans, and acting as the emergency watchdog.

#### Magneto

**Model:** `codellama:7b` | **Function:** Experimental Engineering

Powerful, unpredictable, bends the rules. Advanced code generation, experimental builds, low-level logic, and the slot for dropping in larger or specialist models.

#### Beast

**Model:** `deepseek-r1:7b` | **Function:** Scientific Step-by-Step Reasoning

The X-Men's brilliant scientist. Thinks before answering, shows the reasoning chain, arrives at well-justified conclusions. Use for research, multi-step logic, and hypothesis testing.

#### Storm

**Model:** `gemma2:9b` | **Function:** Creative Writing & Long-Form Content

The X-Men's most powerful and versatile presence. Creative writing, drafting emails, reports, blog posts, documentation, and any task requiring eloquent long-form output.

#### Psylocke

**Model:** `qwen2.5:7b` | **Function:** Multilingual & Structured Output

The X-Men's telepathic ninja — precise, multilingual, lethal at structured tasks. Translations, JSON/YAML generation, data extraction, parsing, and cross-language work.

#### Havok

**Model:** `openchat:7b` | **Function:** Natural Conversation

Fine-tuned for human-friendly dialogue. Use Havok for warm, approachable responses and casual conversation.

#### Bishop

**Model:** `solar:10.7b` | **Function:** Balanced All-Rounder

Upstage's reliable general model. Steady and competent for everyday tasks that don't need a specialist.

#### Sage

**Model:** `mathstral:7b` | **Function:** Mathematics Specialist

The living computer. Equations, calculus, statistics, proofs, and any STEM problem requiring exact numerical work.

#### Cypher

**Model:** `sqlcoder:7b` | **Function:** SQL & Data

Trained to understand the language of databases. SQL queries, schema design, and data analysis.

#### Moira

**Model:** `meditron:7b` | **Function:** Medical & Health AI

The X-Men's chief scientist and physician. Medical questions, biology, clinical topics, and health information. *(Always consult a real doctor for serious decisions.)*

#### Cannonball

**Model:** `granite3.1-dense:8b` | **Function:** IBM Enterprise

IBM's Granite model — built for business, technical writing, and enterprise tasks.

#### Scout

**Model:** `llava:7b` | **Function:** Vision Agent

Vision specialist. Describe images, convert screenshots to UI code, analyse diagrams. The base vision agent.

---

### Tier 3 — Enhanced (24–32 GB)

#### Gambit

**Model:** `mistral-nemo:12b` | **Function:** Long Context Conversation

The X-Men's charming Cajun with a longer memory. Deep conversations, brainstorming, complex multi-turn discussions, and elaborate explanations.

#### Cable

**Model:** `nous-hermes2:10.7b` | **Function:** Instruction Following

Battle-hardened and precise. Multi-step procedures followed exactly — no drifting, no improvising.

#### Sunfire

**Model:** `gemma3:12b` | **Function:** Google Gemma 3 Latest

Google's latest generation model. Strong across languages including Japanese, versatile reasoning, and current training.

#### Banshee

**Model:** `phi4:14b` | **Function:** Microsoft Phi-4 Precision

Microsoft's Phi-4 — compact 14B package with high-precision reasoning that punches above its weight class.

#### Mr. Sinister

**Model:** `deepseek-r1:14b` | **Function:** Deep Analytical Reasoning

Larger DeepSeek R1 reasoning model. Use when Beast's 7B reasoning isn't deep enough.

#### Iceman

**Model:** `starcoder2:15b` | **Function:** Pure Code — 80+ Languages

Trained exclusively on code across 80+ programming languages. Rust, Go, Swift, Kotlin, Haskell, and 75 more.

#### Shadowcat

**Model:** `codestral:22b` | **Function:** Mistral Code Specialist

Mistral's dedicated code model. Phases through any codebase with surgical precision. Stronger than Forge or Iceman on multi-file real-world code reviews.

---

### Tier 4 — Vision Agents

#### Scout

**Model:** `llava:7b` (~4.7 GB) | **Function:** Standard Vision

Base vision agent. Screenshots, images, and diagrams converted to descriptions or code.

#### Rogue

**Model:** `llava:13b` (~8 GB) | **Function:** Enhanced Vision

Absorbs more detail than Scout. Complex screenshots, intricate diagrams, and images where the 7B model misses fine details.

#### Longshot

**Model:** `llama3.2-vision:11b` (~8 GB) | **Function:** Multimodal Llama

Combines image understanding with text reasoning. Better visual-text integration than llava-based agents.

---

### Tier 5 — Heavy Hitters (48 GB+ RAM)

#### Legion

**Model:** `mixtral:8x7b` (~26 GB) | **Function:** Mixture of Experts

Eight specialized sub-models working together. Stronger than a single 7B on most tasks, especially diverse topics in a single prompt.

#### Emma Frost

**Model:** `command-r:35b` (~20 GB) | **Function:** 128K Context — Long Documents

The White Queen with a 128K context window. Reads entire files, full codebases, or massive documents in a single pass.

#### Colossus

**Model:** `llama3.1:70b` (~40 GB) | **Function:** Maximum General Power

The X-Men's strongest member. Comprehensive document analysis, full code reviews, multi-step reasoning chains.

#### Phoenix

**Model:** `llama3.3:70b` (~40 GB) | **Function:** Latest 70B Powerhouse

The most powerful general model — Llama 3.3 at 70B. Use Phoenix when you want the latest and most capable generation.

#### Stryfe

**Model:** `deepseek-r1:70b` (~40 GB) | **Function:** Massive Reasoning

DeepSeek R1 at 70B scale. Extreme reasoning depth for the hardest analytical problems.

---

### Tier 6 — Titans (96 GB+ RAM — post-upgrade)

#### Onslaught

**Model:** `mixtral:8x22b` (~80 GB) | **Function:** Largest Mixture of Experts

The merged unstoppable force — 8 experts of 22B each. The most powerful MoE model available.

#### Apocalypse

**Model:** `command-r-plus:104b` (~60 GB) | **Function:** 104B Ultimate Context

Ancient and immeasurable power. 104B parameters, longest context window, most comprehensive analysis possible.

---

### CEREBRO

**Model:** PowerShell system layer | **Function:** Orchestration & Control

Professor X's machine that amplifies his reach to the entire world. CEREBRO runs the menus, speaks the voice responses, monitors system health, dispatches voice commands, and connects every agent.

---

## Smart Agent Router

Type any task in plain English — CEREBRO scores keyword matches and picks the best agent automatically.

| Agent | Trigger Keywords |
| --- | --- |
| Professor-X | plan, strategy, architect, design, roadmap, advise, recommend, think |
| Forge | code, debug, script, python, powershell, docker, build, deploy, bug, api, implement |
| Cyclops | security, threat, malware, ioc, vulnerability, audit, log, triage, scan, breach |
| Nightcrawler | quick, fast, explain, summarize, define, tldr, brief, simple |
| Wolverine | recover, restart, broken, crashed, health, watchdog, restore, failed |
| Magneto | experiment, advanced, optimize, benchmark, compile, performance, prototype |
| Beast | reason, research, analyse, hypothesis, scientific, step by step, logic, proof, deduce |
| Storm | write, creative, story, draft, email, report, blog, essay, document, content, compose |
| Psylocke | translate, multilingual, japanese, chinese, french, json output, yaml, format, parse, extract |
| Gambit | conversation, chat, long, context, discuss, elaborate, brainstorm, walk me through |
| Colossus | complex, difficult, large, massive, maximum, full analysis, comprehensive, complete |
| Jubilee | instant, tiny, smallest, 3b, snap, flash |
| Dazzler | 1b, absolute fastest, minimum, lightest, one line |
| Emma Frost | long document, entire file, 128k, full codebase, rag, retrieval |
| Iceman | rust, go, swift, kotlin, haskell, scala, typescript, ruby, php, c++, c# |
| Rogue | detailed image, high detail, complex screenshot, 13b vision |
| Shadowcat | codestral, entire repo, codebase review, full file, deep code |
| Cable | instruction, follow steps, multi-step, precise, procedure, protocol |
| Havok | friendly, natural, casual, dialogue, approachable |
| Sunfire | gemma3, google latest, japanese, multilingual latest |
| Bishop | balanced, reliable, general, everyday, solar |
| Sage | math, calculate, equation, calculus, statistics, proof, formula |
| Cypher | sql, database, query, select, join, schema, postgres |
| Banshee | phi4, microsoft latest, compact powerful, 14b precise |
| Mr. Sinister | deep reasoning, 14b reason, hard problem, obsessive analysis |
| Legion | mixtral, mixture of experts, moe, 8x7, multi-expert |
| Cannonball | granite, ibm, enterprise, business, corporate |
| Moira | medical, health, disease, symptom, diagnosis, clinical |
| Longshot | llama vision, multimodal, image and text, 11b vision |
| Phoenix | llama3.3, latest llama, newest 70b |
| Stryfe | deepseek 70b, massive reasoning, r1 70b |
| Apocalypse | 104b, command-r-plus, ultimate, largest context |
| Onslaught | 8x22b, largest mixtral, massive moe, unstoppable |

---

## Main Menu

| # | Option |
| --- | --- |
| 1 | CEREBRO System Status — RAM, disk, services, loaded models |
| 2 | Start Ollama |
| 2S | Stop Ollama |
| 3 | X-Agent Launcher (6 tiers, 34 agents) |
| 4 | Show X-Agent Model Map |
| 5 | Pull / Update Single X-Agent Model |
| 6 | Pull All X-Agent Models |
| 6R | **Register Agents in Open WebUI** — creates named models with system prompts so agents appear by name in the model selector |
| 6D | Remove Named Agent Models |
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
| 22 | **CEREBRO Chat / Voice Conversation** |
| 23 | Exit |

Status line shows: `Voice: ON/OFF` | `Sounds: ON/OFF` | `Wake Word: ACTIVE / OFF`

---

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
| 9 | Jupyter Launcher | Start Jupyter Notebook (uses local venv if present), open browser to `localhost:8888` |
| 10 | Docker Compose Generator | Generate a `docker-compose.yml` for any combination of Ollama, Open WebUI, n8n, Flowise, LiteLLM, SearXNG, Qdrant, Redis — with optional immediate launch |
| 11 | Windows Terminal Profile | Auto-install a CHAMP AI tab in Windows Terminal with correct launch command and colour scheme |

### Models & APIs

| # | Tool | Description |
| --- | --- | --- |
| 12 | Ollama Model Search | Browse ollama.com/library by keyword, pull a model directly from results |
| 13 | Model Disk Manager | List all installed models with sizes, delete to free disk space |
| 14 | RAM / VRAM Advisor | Check compatibility of common models against your free RAM/VRAM before pulling |
| 15 | Ollama REST API Tester | Direct `Invoke-RestMethod` to `localhost:11434` — list models, version, `/api/generate`, model info |
| 16 | AI Services Port Dashboard | Live port scan for Ollama, Open WebUI, Jupyter, FastAPI, Gradio, Streamlit, LiteLLM, AnythingLLM |
| 17 | API Key Manager | Read/write `.env` for `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `HF_TOKEN`, etc.; input masked |

### Data & Scheduling

| # | Tool | Description |
| --- | --- | --- |
| 18 | Backup & Restore | Backs up `.env`, prompts, Modelfiles, activity log, and Open WebUI Docker volume to `CHAMP-Backups\`; full restore from any snapshot |
| 19 | Scheduled Agent Queries | Create Windows Task Scheduler jobs that run a prompt against any agent on a daily/hourly/logon schedule; output auto-saved to `CHAMP-Sessions\` |

### UI Generation

| # | Tool | Description |
| --- | --- | --- |
| 20 | UI Code Generator | Generate HTML, React, or Vue UI components using Forge with framework-specific system prompts |
| 21 | Live Preview Server | HttpListener on port 9090 serves generated UI with JS auto-refresh on every regeneration |
| 22 | Iterative Refinement Loop | Feed Forge's last output back as context for incremental UI improvements |
| 23 | Scout Vision Agent | Send a screenshot or image to Scout (llava:7b) to describe it or convert to UI code |

---

## DevOps Control Panel (option 20)

### Proxmox VE

| # | Action |
| --- | --- |
| 1 | Dashboard — node status, CPU, RAM, storage |
| 2 | List VMs |
| 3 | Start / Stop / Reboot a VM |
| 4 | Snapshot Manager — list, create, rollback |
| 5 | AI Infrastructure Review (Professor-X analyses node health) |
| 6 | Configure connection (host, token ID, secret) |

### GitHub

| # | Action |
| --- | --- |
| 1 | List repos |
| 2 | Create issue (AI-assisted body via Professor-X) |
| 3 | List open PRs |
| 4 | Create PR (AI-assisted description via Professor-X) |
| 5 | AI code review of latest diff (Forge) |
| 6 | Trigger a GitHub Actions workflow |
| 7 | Configure default repo |

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
| 1 | `terraform init` |
| 2 | `terraform plan` — Professor-X reviews before apply |
| 3 | `terraform apply` |
| 4 | `terraform destroy` — requires typing `DESTROY` to confirm |
| 5 | `terraform state list` |
| 6 | List / switch workspaces |
| 7 | AI `.tf` file generator (Forge) |
| 8 | Configure working directory |

### Packer

| # | Action |
| --- | --- |
| 1 | `packer validate` |
| 2 | `packer build` |
| 3 | AI HCL template generator (Forge) |
| 4 | Cyclops security audit of a template |
| 5 | Configure template path |

### Ansible

| # | Action |
| --- | --- |
| 1 | Run a playbook — Professor-X reviews before execution |
| 2 | Ad-hoc command |
| 3 | List inventory |
| 4 | `ansible-galaxy` install a role |
| 5 | AI playbook generator (Forge) |
| 6 | Cyclops security audit of a playbook |
| 7 | Configure inventory path |

> Ansible runs natively if `ansible` is on PATH, or falls back to `wsl ansible` for WSL installations.

All DevOps settings are stored in `.devops-config.json`. Secrets live in `.env`. Run the **Configure** option inside each tool's submenu to set connection details.

---

## Intelligence Hub (option 21)

| # | Tool | Description |
| --- | --- | --- |
| 1 | Conversation History | Persistent per-agent memory — each agent remembers your last 100 exchanges across sessions, stored in `CHAMP-History\` |
| 2 | Cloud API Fallback | Route any prompt to OpenAI (gpt-4o-mini, gpt-4o) or Claude (Haiku, Sonnet) using keys from `.env`; side-by-side local vs cloud comparison |
| 3 | Clipboard AI | Grab whatever is on the clipboard and fire it at any agent instantly, with an optional instruction prefix |
| 4 | WSL Manager | List distros, launch a shell, run commands, start/stop/set-default, Linux system info, Forge bash script generator |
| 5 | Live Dashboard | Auto-refreshing war-room view — CPU, RAM, disk, Ollama, Docker, loaded models, port health, recent activity |
| 6 | Windows Event Log Watcher | Browse System / Application / Security logs; Cyclops AI analysis of recent errors; keyword search |
| 7 | Network Scanner | Ping, traceroute, DNS lookup, common port scan, /24 ping sweep, local network info, Cyclops analysis |
| 8 | File & Code Analyzer | Drop any file path — Forge explains and reviews, Cyclops security-audits, Nightcrawler summarises logs, Forge generates unit tests, Professor-X analyses folder architecture |
| 9 | Git Tools | `git status/log/diff/stash/branch` in any local repo; Forge commit messages and diff reviews; Cyclops security scan of uncommitted changes |
| 10 | LM Studio | Connect to LM Studio's OpenAI-compatible API on port 1234; list models, chat, code tasks, security analysis, side-by-side vs Forge |

---

## CEREBRO Chat / Voice Conversation (option 22)

| # | Option |
| --- | --- |
| 1 | Chat with Professor-X (text) |
| 2 | Chat with Forge (text) |
| 3 | Chat with Gambit (text — long context) |
| 4 | Chat with Nightcrawler (text — quick) |
| 5 | Chat with any agent (choose from full roster) |
| 6 | VOICE conversation with Professor-X (microphone) |
| 7 | VOICE conversation — choose any agent |
| 8 | Start / Stop wake word listener |

Conversation history is saved per-agent in `CHAMP-History\<agent>.json` and carried across sessions. Long responses are spoken up to 600 characters; full text displays on screen.

---

## Recommended First Run Order

1. **Option 1** — CEREBRO System Status: verify RAM, Docker, Ollama
2. **Option 2** — Start Ollama
3. **Option 6** — Pull All X-Agent Models (start with the Core Team tier)
4. **Option 6R** — Register agents in Open WebUI (agents appear by name in model selector)
5. **Option 8** — Start Open WebUI
6. **Option 12** — Open Open WebUI Dashboard — create admin account at `http://localhost:3000`
7. **Option 22 → 8** — Start wake word listener and say *"Hey CEREBRO"*

---

## Files Created at Runtime

| File / Folder | Purpose |
| --- | --- |
| `CHAMP-activity.log` | Timestamped log of every agent activation, query, and event |
| `CHAMP-prompts.json` | Saved prompt library entries |
| `.env` | API keys (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `HF_TOKEN`, etc.) — input masked |
| `.devops-config.json` | DevOps connection settings (Proxmox host, GitHub repo, Terraform path, etc.) |
| `Modelfile-<name>` | Custom agent Modelfiles built by Modelfile Creator or agent registration |
| `champ-ai-env\` | Python virtual environment created by the AI Env Wizard |
| `CHAMP-Sessions\` | Exported agent responses, UI previews, and model comparison Markdowns |
| `CHAMP-Backups\` | Timestamped backup snapshots (configs, prompts, Docker volume) |
| `CHAMP-History\<agent>.json` | Per-agent conversation history (up to 100 exchanges per agent) |
| `docker-compose.yml` | Generated full-stack compose file from Docker Compose Generator |
| `sched-CHAMP-<name>.ps1` | Wrapper scripts for scheduled Task Scheduler agent queries |
| `.wake-trigger` | Temporary flag file used by wake word background listener (auto-deleted) |

---

## Prerequisites

| Tool | Required | Notes |
| --- | --- | --- |
| PowerShell 7+ | Yes | `https://aka.ms/powershell` — not Windows PowerShell 5 |
| Ollama | Yes | `https://ollama.com/download` |
| Docker Desktop | Yes (for WebUI) | `https://www.docker.com/products/docker-desktop` |
| Microphone | For voice features | Any Windows-recognised mic works |
| VS Code | Optional | For project folder integration |
| NVIDIA GPU Driver | Optional | For GPU hardware monitor (`nvidia-smi`) |
| GitHub CLI (`gh`) | Optional | For GitHub DevOps integration |
| Terraform CLI | Optional | For Terraform DevOps integration |
| Packer CLI | Optional | For Packer DevOps integration |
| Ansible / WSL | Optional | For Ansible DevOps integration |
| LM Studio | Optional | For LM Studio backend on port 1234 |

---

## Safe Update Design

Open WebUI does not auto-update on launch. Use **Update Open WebUI Manually** (option 11) only when ready — it preserves the `open-webui` data volume.

See `DEPLOY.md` for permanent installation, desktop shortcut creation, and taskbar pinning instructions.
