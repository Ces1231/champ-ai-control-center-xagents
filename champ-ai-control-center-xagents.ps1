# ============================================================
# CHAMP AI Control Center - X-Agent Edition
# Local AI launcher for Windows: Ollama, Open WebUI, Docker, VS Code
# Includes X-Men-inspired agent roles, voice responses, sound alerts,
# safe Open WebUI updates, and Wolverine recovery functions.
# ============================================================

# -----------------------------
# User Config
# -----------------------------
$Global:PluginRegistry = @()
$OpenWebUIContainer = "champ-open-webui"
$OpenWebUIPort = "1969"
$OpenWebUIHost = "champ-ai-Control-center"
$OpenWebUIImage = "ghcr.io/open-webui/open-webui:main"
$DefaultProjectPath = "$env:USERPROFILE\OneDrive\Documents\01_Projects"
$ActivityLogPath = "$PSScriptRoot\CHAMP-activity.log"

$EnableVoice = $true
$EnableSounds = $true

# ============================================================
# STREAMING RESPONSES
# ============================================================
function Invoke-OllamaStream {
    param([string]$Model, [string]$Prompt, [string]$SystemPrompt = "")
    $fullPrompt = if ($SystemPrompt) { "$SystemPrompt`n`n$Prompt" } else { $Prompt }
    $httpClient = New-Object System.Net.Http.HttpClient
    $httpClient.Timeout = [TimeSpan]::FromMinutes(5)
    $bodyJson = (@{ model=$Model; prompt=$fullPrompt; stream=$true } | ConvertTo-Json)
    $content  = New-Object System.Net.Http.StringContent($bodyJson, [System.Text.Encoding]::UTF8, "application/json")
    $fullResponse = ""
    try {
        $response = $httpClient.PostAsync("http://localhost:11434/api/generate", $content).GetAwaiter().GetResult()
        $stream   = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $reader   = New-Object System.IO.StreamReader($stream)
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ($line) {
                try {
                    $chunk = $line | ConvertFrom-Json
                    if ($chunk.response) { Write-Host $chunk.response -NoNewline -ForegroundColor Cyan; $fullResponse += $chunk.response }
                    if ($chunk.done) { break }
                } catch {}
            }
        }
        Write-Host ""
        $reader.Close(); $stream.Close()
    } catch { Write-Warn "Stream error: $_" }
    finally { $httpClient.Dispose() }
    return $fullResponse
}

# ============================================================
# CHAMP WEB UI
# ============================================================
function Initialize-WebUI {
    param([string]$ScriptRoot, [string]$WebUIPort = "8091")
    $webDir = "$ScriptRoot\CHAMP-WebUI"
    if (-not (Test-Path $webDir)) { New-Item -ItemType Directory -Path $webDir | Out-Null }
    # Only regenerate if the file doesn't exist (skip on every subsequent launch)
    if (Test-Path "$webDir\index.html") { return }
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CHAMP AI Control Center</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{background:#0d0d0d;color:#e0e0e0;font-family:'Segoe UI',sans-serif;height:100vh;display:flex;flex-direction:column}
  header{background:#111;border-bottom:1px solid #1a1a2e;padding:12px 24px;display:flex;align-items:center;gap:16px}
  header h1{font-size:1.2rem;color:#a78bfa;letter-spacing:2px}
  header span{font-size:.75rem;color:#555}
  .tabs{display:flex;background:#0f0f0f;border-bottom:1px solid #1a1a2e}
  .tab{padding:10px 24px;cursor:pointer;font-size:.85rem;color:#777;border-bottom:2px solid transparent;transition:.2s}
  .tab.active{color:#a78bfa;border-bottom-color:#a78bfa}
  .tab:hover{color:#e0e0e0}
  .panel{display:none;flex:1;overflow:hidden}
  .panel.active{display:flex;flex-direction:column}
  /* Chat */
  #chat-messages{flex:1;overflow-y:auto;padding:16px;display:flex;flex-direction:column;gap:12px}
  .msg{max-width:80%;padding:10px 14px;border-radius:8px;font-size:.9rem;line-height:1.5;white-space:pre-wrap}
  .msg.user{background:#1a1a2e;align-self:flex-end;color:#c4b5fd}
  .msg.ai{background:#111;align-self:flex-start;color:#e0e0e0;border:1px solid #1e1e3f}
  .msg.system{align-self:center;color:#555;font-size:.75rem;font-style:italic}
  #chat-input-row{display:flex;gap:8px;padding:12px 16px;background:#0f0f0f;border-top:1px solid #1a1a2e}
  #agent-select{background:#111;color:#e0e0e0;border:1px solid #333;border-radius:6px;padding:8px 10px;font-size:.85rem}
  #chat-input{flex:1;background:#111;color:#e0e0e0;border:1px solid #333;border-radius:6px;padding:8px 12px;font-size:.9rem;resize:none}
  #chat-input:focus,#agent-select:focus{outline:none;border-color:#a78bfa}
  #send-btn{background:#a78bfa;color:#0d0d0d;border:none;border-radius:6px;padding:8px 18px;font-weight:600;cursor:pointer;font-size:.85rem}
  #send-btn:hover{background:#c4b5fd}
  #send-btn:disabled{background:#333;color:#666;cursor:not-allowed}
  /* Status / Agents / Models */
  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px;padding:16px;overflow-y:auto}
  .card{background:#111;border:1px solid #1e1e3f;border-radius:8px;padding:14px}
  .card h3{font-size:.85rem;color:#a78bfa;margin-bottom:6px}
  .card p{font-size:.8rem;color:#aaa;line-height:1.4}
  .badge{display:inline-block;font-size:.7rem;padding:2px 8px;border-radius:4px;font-weight:600}
  .badge.green{background:#0d2b1d;color:#34d399}
  .badge.red{background:#2b0d0d;color:#f87171}
  .badge.blue{background:#0d1b2b;color:#60a5fa}
  #status-bar{padding:8px 16px;background:#0a0a0a;font-size:.75rem;color:#555;border-top:1px solid #111}
</style>
</head>
<body>
<header>
  <h1>X CHAMP AI</h1>
  <span id="status-dot">●</span>
  <span id="header-status">connecting...</span>
</header>
<div class="tabs">
  <div class="tab active" onclick="switchTab('chat')">Chat</div>
  <div class="tab" onclick="switchTab('status')">Status</div>
  <div class="tab" onclick="switchTab('agents')">Agents</div>
  <div class="tab" onclick="switchTab('models')">Models</div>
</div>
<div id="tab-chat" class="panel active">
  <div id="chat-messages"><div class="msg system">CEREBRO online. Select an agent and start chatting.</div></div>
  <div id="chat-input-row">
    <select id="agent-select"><option value="">Loading agents...</option></select>
    <textarea id="chat-input" rows="1" placeholder="Ask anything..." onkeydown="handleKey(event)"></textarea>
    <button id="send-btn" onclick="sendMessage()">Send</button>
  </div>
</div>
<div id="tab-status" class="panel"><div id="status-grid" class="grid"></div></div>
<div id="tab-agents" class="panel"><div id="agents-grid" class="grid"></div></div>
<div id="tab-models" class="panel"><div id="models-grid" class="grid"></div></div>
<div id="status-bar">CHAMP AI Control Center — X-Agent Edition</div>
<script>
const API = 'http://localhost:$WebUIPort/api';
let agents = [];

function switchTab(name) {
  document.querySelectorAll('.tab').forEach((t,i)=>t.classList.toggle('active',['chat','status','agents','models'][i]===name));
  document.querySelectorAll('.panel').forEach(p=>p.classList.remove('active'));
  document.getElementById('tab-'+name).classList.add('active');
  if(name==='status') loadStatus();
  if(name==='models') loadModels();
}

async function loadAgents() {
  try {
    const r = await fetch(API+'/agents');
    const d = await r.json();
    agents = d.agents || [];
    const sel = document.getElementById('agent-select');
    sel.innerHTML = agents.map(a=>`<option value="`+a+`">`+a+`</option>`).join('');
    const grid = document.getElementById('agents-grid');
    grid.innerHTML = agents.map(a=>`<div class="card"><h3>`+a+`</h3><p><span class="badge blue">agent</span></p></div>`).join('');
  } catch(e) { console.error(e); }
}

async function loadStatus() {
  try {
    const r = await fetch(API+'/status');
    const d = await r.json();
    document.getElementById('status-grid').innerHTML = `
      <div class="card"><h3>Gateway</h3><p><span class="badge green">ONLINE</span></p><p style="margin-top:6px;font-size:.75rem">`+d.timestamp+`</p></div>
      <div class="card"><h3>Version</h3><p>`+d.version+`</p></div>`;
    document.getElementById('header-status').textContent = 'online';
    document.getElementById('status-dot').style.color = '#34d399';
  } catch(e) {
    document.getElementById('header-status').textContent = 'offline';
    document.getElementById('status-dot').style.color = '#f87171';
  }
}

async function loadModels() {
  try {
    const r = await fetch(API+'/models');
    const d = await r.json();
    document.getElementById('models-grid').innerHTML = (d.models||[]).map(m=>`<div class="card"><h3>`+m+`</h3><p><span class="badge green">ready</span></p></div>`).join('');
  } catch(e) {}
}

function addMessage(role, text) {
  const div = document.createElement('div');
  div.className = 'msg '+role;
  div.textContent = text;
  const msgs = document.getElementById('chat-messages');
  msgs.appendChild(div);
  msgs.scrollTop = msgs.scrollHeight;
  return div;
}

async function sendMessage() {
  const input = document.getElementById('chat-input');
  const agentSel = document.getElementById('agent-select');
  const btn = document.getElementById('send-btn');
  const text = input.value.trim();
  if (!text) return;
  const agent = agentSel.value;
  addMessage('user', text);
  input.value = '';
  btn.disabled = true;
  const aiDiv = addMessage('ai', '...');
  try {
    const r = await fetch(API+'/chat', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({ model: agent, prompt: text })
    });
    const d = await r.json();
    aiDiv.textContent = d.response || d.error || 'No response.';
  } catch(e) { aiDiv.textContent = 'Error: '+e.message; }
  btn.disabled = false;
  document.getElementById('chat-messages').scrollTop = 9999;
}

function handleKey(e) { if(e.key==='Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); } }

loadAgents();
loadStatus();
setInterval(loadStatus, 30000);
</script>
</body>
</html>
"@
    Set-Content "$webDir\index.html" -Value $html -Encoding UTF8
}

function Open-CHAMPWebUI {
    param([string]$Port = "8091")
    Start-Process "http://localhost:$Port"
    Write-Info "Opening CHAMP Web UI at http://localhost:$Port"
    Write-Info "Start the API Gateway first (option 24 -> 3) if not already running."
    Pause-Menu
}

# ============================================================
# PLUGIN SYSTEM
# ============================================================
function Initialize-Plugins {
    $pluginDir = "$PSScriptRoot\CHAMP-Plugins"
    if (-not (Test-Path $pluginDir)) {
        New-Item -ItemType Directory -Path $pluginDir | Out-Null
        # Write a sample plugin
        Set-Content "$pluginDir\example-plugin.ps1" -Encoding UTF8 -Value @'
# CHAMP Plugin
# Name: Example Plugin
# Description: A sample plugin showing the plugin structure

function Run-ExamplePlugin {
    Show-Header
    Write-Info "Example Plugin"
    Write-Info "--------------"
    Write-Host "This is a sample CHAMP AI plugin." -ForegroundColor Cyan
    Write-Host "Copy this file, rename it, and replace Run-ExamplePlugin with your function."
    Write-Host ""
    Write-Host "You have full access to all CHAMP AI functions including:"
    Write-Host "  - Invoke-OllamaStream / Activate-Agent"
    Write-Host "  - All 34 agent models via `$Agents and `$AgentSystemPrompts"
    Write-Host "  - Write-OK, Write-Warn, Write-Err, Speak-CHAMP, Pause-Menu"
    Pause-Menu
}
'@
    }
    $Global:PluginRegistry = @()
    Get-ChildItem "$pluginDir\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            . $_.FullName
            # Read metadata from comments
            $lines   = Get-Content $_.FullName -TotalCount 5
            $nameL   = $lines | Where-Object { $_ -match "^# Name:" }       | Select-Object -First 1
            $descL   = $lines | Where-Object { $_ -match "^# Description:" } | Select-Object -First 1
            $pName   = if ($nameL)  { ($nameL  -split ":",2)[1].Trim() } else { $_.BaseName }
            $pDesc   = if ($descL)  { ($descL  -split ":",2)[1].Trim() } else { "Plugin" }
            # Find the Run- function name
            $funcLine = Get-Content $_.FullName | Where-Object { $_ -match "^function Run-" } | Select-Object -First 1
            $funcName = if ($funcLine -match "function (Run-\S+)") { $Matches[1] } else { $null }
            if ($funcName) {
                $Global:PluginRegistry += @{ Name=$pName; Description=$pDesc; Function=$funcName; File=$_.Name }
                Write-Info "Plugin loaded: $pName"
            }
        } catch { Write-Warn "Plugin load failed ($($_.Name)): $_" }
    }
}

function Show-PluginsMenu {
    Show-Header
    Write-Info "CHAMP AI Plugins"; Write-Info "----------------"
    if ($Global:PluginRegistry.Count -eq 0) {
        Write-Warn "No plugins loaded. Drop .ps1 files into CHAMP-Plugins\ to add features."
        Write-Info "A sample plugin was created at CHAMP-Plugins\example-plugin.ps1"
        Pause-Menu; return
    }
    for ($i = 0; $i -lt $Global:PluginRegistry.Count; $i++) {
        $p = $Global:PluginRegistry[$i]
        Write-Host "$($i+1). $($p.Name)" -ForegroundColor Cyan
        Write-Host "   $($p.Description)" -ForegroundColor DarkGray
    }
    Write-Host "$($Global:PluginRegistry.Count+1). Back"
}

function Plugins-Menu {
    do {
        Show-PluginsMenu
        if ($Global:PluginRegistry.Count -eq 0) { return }
        $choice = Read-Host "Select plugin"
        if ($choice -match "^\d+$") {
            $idx = [int]$choice - 1
            if ($idx -ge 0 -and $idx -lt $Global:PluginRegistry.Count) {
                $func = $Global:PluginRegistry[$idx].Function
                if (Get-Command $func -ErrorAction SilentlyContinue) { & $func }
                else { Write-Warn "Plugin function '$func' not found."; Pause-Menu }
            } elseif ($idx -eq $Global:PluginRegistry.Count) { return }
        }
    } while ($true)
}

# -----------------------------
# X-Agent Model Map
# -----------------------------
$Agents = @{
    "Professor-X" = @{
        Model    = "phi3:mini"
        Role     = "Strategic reasoning, architecture, planning, and executive assistant"
        Keywords = @("plan","strategy","architect","design","roadmap","decide","advise","recommend","think")
    }
    "Forge" = @{
        Model    = "qwen2.5-coder:7b"
        Role     = "Coding, debugging, scripting, Docker, PowerShell, Python, and infrastructure"
        Keywords = @("code","debug","script","function","error","python","powershell","docker","build","deploy","fix","bug","implement","class","module","api")
    }
    "Cyclops" = @{
        Model    = "phi3:mini"
        Role     = "Cybersecurity analysis, IOC review, logs, triage, and focused operations"
        Keywords = @("security","threat","malware","ioc","log","triage","attack","vulnerability","cve","firewall","incident","phishing","breach","scan","audit")
    }
    "Nightcrawler" = @{
        Model    = "phi3:mini"
        Role     = "Fast lightweight assistant for quick local responses"
        Keywords = @("quick","fast","simple","brief","short","explain","what is","define","summarize","tldr")
    }
    "Wolverine" = @{
        Model    = "phi3:mini"
        Role     = "Recovery, resilience, service checks, watchdog actions, and emergency restart"
        Keywords = @("recover","restart","down","broken","fix service","health","watchdog","restore","crashed","failed")
    }
    "Magneto" = @{
        Model    = "phi3:mini"
        Role     = "Experimental engineering, advanced build logic, and future larger-model slot"
        Keywords = @("experiment","advanced","compile","assembly","low level","optimize","performance","benchmark","prototype")
    }
    "Scout" = @{
        Model    = "llava:7b"
        Role     = "Vision agent  -  describe images, convert screenshots to UI code, analyse diagrams"
        Keywords = @("image","screenshot","photo","picture","vision","describe","look at","see","visual","diagram","ui from")
    }
    "Beast" = @{
        Model    = "phi3:mini"
        Role     = "Scientific reasoning and research  -  thinks step by step before answering"
        Keywords = @("reason","research","analyse","hypothesis","scientific","step by step","think through","logic","proof","deduce","infer","investigate","methodology")
    }
    "Storm" = @{
        Model    = "phi3:mini"
        Role     = "Creative writing, versatile general-purpose tasks, and long-form content"
        Keywords = @("write","creative","story","draft","email","report","blog","essay","document","content","generate","compose","narrative","describe in detail")
    }
    "Psylocke" = @{
        Model    = "phi3:mini"
        Role     = "Multilingual precision, structured output, and cross-language tasks"
        Keywords = @("translate","multilingual","japanese","chinese","french","spanish","german","language","structured","json output","yaml","format","parse","extract")
    }
    "Gambit" = @{
        Model    = "phi3:mini"
        Role     = "Longer context conversational tasks, creative problem solving, and charming explanations"
        Keywords = @("conversation","chat","long","context","discuss","elaborate","expand","brainstorm","creative solution","explain in depth","walk me through")
    }
    "Colossus" = @{
        Model    = "llama3.1:70b"
        Role     = "Maximum capability  -  complex multi-step reasoning, large documents, hardest problems"
        Keywords = @("complex","difficult","hard","large","massive","maximum","full analysis","comprehensive","detailed analysis","entire","complete","everything")
    }
    # --- New agents from previous batch ---
    "Jubilee" = @{
        Model    = "phi3:mini"
        Role     = "Ultra-fast 3B assistant for instant answers with minimal resource use"
        Keywords = @("instant","tiny","smallest","3b","lightweight","quick answer","no wait","snap","flash")
    }
    "Emma-Frost" = @{
        Model    = "command-r:35b"
        Role     = "Long document analysis with 128K context  -  reads entire files and codebases at once"
        Keywords = @("long document","entire file","128k","full codebase","read all","whole file","entire codebase","rag","retrieval")
    }
    "Iceman" = @{
        Model    = "starcoder2:15b"
        Role     = "Pure code specialist trained exclusively on code across 80+ programming languages"
        Keywords = @("starcoder","80 languages","kotlin","rust","go","swift","typescript","ruby","php","c++","c#","java","haskell","scala")
    }
    "Rogue" = @{
        Model    = "llava:13b"
        Role     = "Enhanced vision agent  -  absorbs more visual detail than Scout for complex images"
        Keywords = @("detailed image","high detail","complex screenshot","large diagram","detailed vision","enhance","absorb","13b vision")
    }
    "Shadowcat" = @{
        Model    = "codestral:22b"
        Role     = "Mistral's dedicated code model  -  phases through any codebase with surgical precision"
        Keywords = @("codestral","mistral code","phase","infiltrate","large code","entire repo","codebase review","code audit","full file")
    }
    "Cable" = @{
        Model    = "nous-hermes2:10.7b"
        Role     = "Battle-hardened instruction follower  -  executes complex multi-step instructions precisely"
        Keywords = @("instruction","follow steps","multi-step","precise","exact","step 1","step 2","checklist","procedure","protocol","execute plan")
    }
    # --- Additional new agents ---
    "Dazzler" = @{
        Model    = "llama3.2:1b"
        Role     = "Smallest fastest agent  -  1B model for trivial lookups and ultra-low RAM environments"
        Keywords = @("1b","absolute fastest","minimum","lightest","dazzle","flash answer","one word","one line")
    }
    "Havok" = @{
        Model    = "openchat:7b"
        Role     = "Fine-tuned conversational Llama  -  natural dialogue and human-friendly responses"
        Keywords = @("friendly","natural","talk","dialogue","casual","human","chat casually","openchat","approachable")
    }
    "Sunfire" = @{
        Model    = "gemma3:12b"
        Role     = "Google Gemma 3  -  latest generation versatile model with strong multilingual and reasoning"
        Keywords = @("gemma3","gemma 3","google latest","solar","fire","plasma","japanese","asian","latest google")
    }
    "Bishop" = @{
        Model    = "solar:10.7b"
        Role     = "Energy-absorbing all-rounder  -  strong general model from Upstage, reliable and balanced"
        Keywords = @("solar","balanced","general","reliable","all-purpose","upstage","everyday","standard","normal task")
    }
    "Sage" = @{
        Model    = "mathstral:7b"
        Role     = "Living computer  -  mathematics specialist for calculations, proofs, and STEM problems"
        Keywords = @("math","calculate","equation","algebra","calculus","statistics","proof","formula","derivative","integral","matrix","probability","stem","numbers")
    }
    "Cypher" = @{
        Model    = "sqlcoder:7b"
        Role     = "Understands all data languages  -  SQL specialist for database queries and data analysis"
        Keywords = @("sql","database","query","select","join","table","schema","postgres","mysql","sqlite","db","data query","aggregate","group by","where clause")
    }
    "Banshee" = @{
        Model    = "phi4:14b"
        Role     = "Microsoft Phi-4  -  high-precision reasoning in a compact 14B package"
        Keywords = @("phi4","phi 4","microsoft latest","sonic","precise","resonance","compact powerful","14b precise")
    }
    "Mr-Sinister" = @{
        Model    = "deepseek-r1:14b"
        Role     = "Larger DeepSeek reasoning model  -  obsessive analytical depth for hard scientific problems"
        Keywords = @("deep reasoning","14b reason","hard problem","complex logic","sinister","analytical","obsessive","deep analysis","intricate")
    }
    "Legion" = @{
        Model    = "mixtral:8x7b"
        Role     = "Mixture of experts  -  8 specialized sub-models, stronger than a single 7B on most tasks"
        Keywords = @("mixtral","mixture","multiple experts","moe","8x7","strong general","multi-expert","best of eight")
    }
    "Cannonball" = @{
        Model    = "granite3.1-dense:8b"
        Role     = "IBM Granite  -  enterprise-grade model, unstoppable on business and technical tasks"
        Keywords = @("granite","ibm","enterprise","business","corporate","technical report","ibm model","granite3")
    }
    "Moira" = @{
        Model    = "meditron:7b"
        Role     = "X-Men's chief scientist and physician  -  medical AI for health, biology, and clinical topics"
        Keywords = @("medical","health","disease","symptom","diagnosis","drug","clinical","biology","anatomy","treatment","patient","medicine","healthcare")
    }
    "Longshot" = @{
        Model    = "llama3.2-vision:11b"
        Role     = "Multimodal Llama vision  -  luck-powered image and text combined reasoning"
        Keywords = @("llama vision","multimodal","image and text","combined","11b vision","photo analysis","visual reasoning","llama3.2 vision")
    }
    "Phoenix" = @{
        Model    = "llama3.3:70b"
        Role     = "Latest Llama 70B  -  the most powerful general model, rebirth of the strongest force"
        Keywords = @("llama3.3","latest llama","phoenix","rebirth","newest 70b","llama 3.3","most capable","top model")
    }
    "Stryfe" = @{
        Model    = "deepseek-r1:70b"
        Role     = "DeepSeek R1 70B  -  massive reasoning clone, extreme analytical power"
        Keywords = @("deepseek 70b","massive reasoning","r1 70b","extreme analysis","stryfe","clone reasoning","deepseek large")
    }
    "Apocalypse" = @{
        Model    = "command-r-plus:104b"
        Role     = "104B ancient power  -  Cohere's largest model, longest context, ultimate retrieval"
        Keywords = @("104b","command-r-plus","cohere","ultimate","apocalypse","ancient","largest","max context","unlimited")
    }
    "Onslaught" = @{
        Model    = "mixtral:8x22b"
        Role     = "Mixture of 8x22B experts  -  the most powerful MoE model, merged unstoppable force"
        Keywords = @("8x22b","largest mixtral","onslaught","merged","unstoppable","massive moe","mixture 22b","largest mixture")
    }
}

# -----------------------------
# UI Generation globals
# -----------------------------
$Global:PreviewFile = "$PSScriptRoot\CHAMP-Sessions\ui-preview.html"
$Global:PreviewPort = 9090
$Global:LastGeneratedCode = ""
$Global:LastGeneratedFramework = "html"

try {
    Add-Type -AssemblyName System.Speech -ErrorAction Stop
    $Global:CHAMPSpeaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $Global:CHAMPSpeaker.Rate = 0
    $Global:CHAMPSpeaker.Volume = 100
} catch {
    $EnableVoice = $false
}

# -----------------------------
# Toast notification helper (Windows 10/11)
# -----------------------------
function Send-ToastNotification {
    param([string]$Title, [string]$Message)
    try {
        Add-Type -AssemblyName Windows.UI -ErrorAction Stop
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI, ContentType = WindowsRuntime] | Out-Null
        $template = [Windows.UI.Notifications.ToastTemplateType]::ToastText02
        $xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($template)
        $nodes = $xml.GetElementsByTagName("text")
        $nodes[0].AppendChild($xml.CreateTextNode($Title)) | Out-Null
        $nodes[1].AppendChild($xml.CreateTextNode($Message)) | Out-Null
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("CHAMP AI Control Center")
        $notifier.Show($toast)
    } catch { }
}

# -----------------------------
# Activity Log
# -----------------------------
function Write-ActivityLog {
    param([string]$Entry)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $ActivityLogPath -Value "[$timestamp] $Entry" -ErrorAction SilentlyContinue
}

# -----------------------------
# Color output helpers
# -----------------------------
function Write-OK   { param([string]$msg) Write-Host $msg -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Err  { param([string]$msg) Write-Host $msg -ForegroundColor Red }
function Write-Info { param([string]$msg) Write-Host $msg -ForegroundColor Cyan }

# -----------------------------
# Audio/speech
# -----------------------------
function Speak-CHAMP {
    param([string]$Message, [switch]$Wait)
    Write-Host $Message
    if ($EnableVoice -and $Global:CHAMPSpeaker) {
        try {
            if ($Wait) {
                $Global:CHAMPSpeaker.Speak($Message)
            } else {
                # Non-blocking: voice plays while menu renders
                $Global:CHAMPSpeaker.SpeakAsync($Message)
            }
        } catch { Write-Host "Voice output failed." }
    }
}

function Play-SuccessSound { if ($EnableSounds) { [console]::beep(800,150); [console]::beep(1000,150) } }
function Play-ErrorSound   { if ($EnableSounds) { [console]::beep(300,350) } }
function Play-StartSound   { if ($EnableSounds) { [console]::beep(600,120); [console]::beep(800,120); [console]::beep(1000,120) } }
function Play-WolverineSound { if ($EnableSounds) { [console]::beep(250,120); [console]::beep(350,120); [console]::beep(500,180) } }

# -----------------------------
# Utilities
# -----------------------------
function Pause-Menu        { Write-Host ""; Read-Host "Press Enter to continue" }
function Test-CommandExists { param([string]$Command) return [bool](Get-Command $Command -ErrorAction SilentlyContinue) }
function Test-DockerRunning { if (-not (Test-CommandExists "docker")) { return $false }; docker info *> $null; return ($LASTEXITCODE -eq 0) }
function Test-OllamaRunning { return [bool](Get-Process -Name "ollama" -ErrorAction SilentlyContinue) }

function Show-Header {
    Clear-Host
    Write-Host "====================================================" -ForegroundColor DarkCyan
    Write-Host "          CHAMP AI CONTROL CENTER" -ForegroundColor Cyan
    Write-Host "             X-AGENT EDITION" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor DarkCyan
    Write-Host " CEREBRO | Professor-X | Forge | Cyclops | Wolverine" -ForegroundColor DarkGray
    Write-Host " Nightcrawler | Magneto | Ollama | Open WebUI" -ForegroundColor DarkGray
    Write-Host "====================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

function CHAMP-Greeting {
    Play-StartSound
    $hour = (Get-Date).Hour
    $name = "Carnell"
    $timeGreeting = switch ($true) {
        ($hour -ge  5 -and $hour -lt 12) { "Good morning" }
        ($hour -ge 12 -and $hour -lt 17) { "Good afternoon" }
        ($hour -ge 17 -and $hour -lt 21) { "Good evening" }
        default                           { "Welcome back" }
    }
    $dayOfWeek = (Get-Date).DayOfWeek
    $dateStr   = (Get-Date -Format "MMMM d")
    Speak-CHAMP "$timeGreeting, $name. CEREBRO is online. Today is $dayOfWeek, $dateStr. Your X-Agent team is standing by."
}

# -----------------------------
# CEREBRO System Status
# -----------------------------
function Show-SystemStatus {
    Show-Header
    Speak-CHAMP "CEREBRO is checking local AI system status."
    $os = Get-CimInstance Win32_OperatingSystem
    $totalRam = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRam  = [math]::Round($os.FreePhysicalMemory   / 1MB, 2)
    $usedRam  = [math]::Round($totalRam - $freeRam, 2)

    $disk = Get-PSDrive -Name C -ErrorAction SilentlyContinue
    $freeDiskGB = if ($disk) { [math]::Round($disk.Free / 1GB, 1) } else { "N/A" }

    Write-Info "System Status"
    Write-Info "-------------"
    Write-Host "RAM Total  : $totalRam GB"
    if ($usedRam / $totalRam -gt 0.85) { Write-Warn "RAM Used   : $usedRam GB  [HIGH]" } else { Write-OK "RAM Used   : $usedRam GB" }
    Write-Host "RAM Free   : $freeRam GB"
    Write-Host "Disk Free  : $freeDiskGB GB  (C:)"
    Write-Host ""

    if (Test-CommandExists "ollama") {
        if (Test-OllamaRunning) { Write-OK "Ollama     : Running" } else { Write-Warn "Ollama     : Installed  -  not running" }
    } else { Write-Err "Ollama     : Not found" }

    if (Test-CommandExists "docker") {
        if (Test-DockerRunning) { Write-OK "Docker     : Running" } else { Write-Warn "Docker     : Installed  -  not running" }
    } else { Write-Err "Docker     : Not found" }

    if (Test-CommandExists "code") { Write-OK "VS Code    : CLI available" } else { Write-Warn "VS Code    : CLI not found" }

    Write-Host ""
    Write-Info "Open WebUI Container:"
    if (Test-CommandExists "docker") {
        docker ps -a --filter "name=$OpenWebUIContainer" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"
    }

    # Show currently loaded Ollama models
    if (Test-OllamaRunning -and (Test-CommandExists "ollama")) {
        Write-Host ""
        Write-Info "Loaded Ollama Models (ollama ps):"
        $psOutput = ollama ps 2>&1
        if ($LASTEXITCODE -eq 0 -and $psOutput) { Write-Host $psOutput } else { Write-Host "  (no models currently loaded in memory)" -ForegroundColor DarkGray }
    }

    Play-SuccessSound
    Pause-Menu
}

# -----------------------------
# Ollama controls
# -----------------------------
function Start-Ollama {
    Show-Header
    if (-not (Test-CommandExists "ollama")) { Speak-CHAMP "Ollama was not found. Please install Ollama first."; Play-ErrorSound; Pause-Menu; return }
    if (Test-OllamaRunning) { Speak-CHAMP "Ollama is already running." } else {
        Speak-CHAMP "Starting Ollama."
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized
        Start-Sleep -Seconds 2
        Speak-CHAMP "Ollama has started."
    }
    Play-SuccessSound
    Pause-Menu
}

function Stop-Ollama {
    Show-Header
    if (-not (Test-OllamaRunning)) { Speak-CHAMP "Ollama is not currently running."; Pause-Menu; return }
    Speak-CHAMP "Stopping Ollama."
    Get-Process -Name "ollama" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
    if (-not (Test-OllamaRunning)) { Write-OK "Ollama stopped."; Play-SuccessSound } else { Write-Err "Ollama may still be running."; Play-ErrorSound }
    Pause-Menu
}

function List-OllamaModels {
    Show-Header
    if (-not (Test-CommandExists "ollama")) { Speak-CHAMP "Ollama was not found."; Play-ErrorSound; Pause-Menu; return }
    Speak-CHAMP "Listing installed local AI models."
    ollama list
    Pause-Menu
}

# -----------------------------
# Agent Map & Pull
# -----------------------------
function Show-AgentMap {
    Show-Header
    Speak-CHAMP "Displaying X Agent model assignments."
    Write-Info "X-Agent Model Map"
    Write-Info "-----------------"
    foreach ($agent in $Agents.Keys | Sort-Object) {
        Write-Host ""
        Write-Host $agent -ForegroundColor Yellow
        Write-Host "  Model: $($Agents[$agent].Model)"
        Write-Host "  Role : $($Agents[$agent].Role)"
    }
    Pause-Menu
}

function Pull-AgentModels {
    Show-Header
    # Models requiring 48 GB+ RAM - skip on 32 GB systems
    $skipModels = @("mixtral:8x7b","llama3.3:70b","deepseek-r1:70b","mixtral:8x22b","command-r-plus:104b","llama3.1:70b","command-r:35b")
    Speak-CHAMP "This will pull all X Agent models compatible with 32 GB RAM."
    Write-Warn "Skipping Tier 5 and Tier 6 models - they require 48 GB or more RAM."
    Write-Info "Skipped: $($skipModels -join ', ')"
    Write-Host ""
    $confirm = Read-Host "Pull all compatible agent models? Type YES to continue"
    if ($confirm -ne "YES") { Speak-CHAMP "Model download cancelled."; Pause-Menu; return }
    foreach ($agent in $Agents.Keys | Sort-Object) {
        $model = $Agents[$agent].Model
        if ($skipModels -contains $model) {
            Write-Warn "Skipping $agent ($model) - requires 48 GB+ RAM"
            continue
        }
        Speak-CHAMP "Pulling model for $agent."
        Write-Host "Pulling $agent -> $model"
        ollama pull $model
    }
    Speak-CHAMP "All compatible X Agent models have been pulled."
    Send-ToastNotification "CHAMP AI" "All compatible X-Agent models pulled successfully."
    Play-SuccessSound
    Pause-Menu
}

function Pull-SingleAgentModel {
    Show-Header
    Speak-CHAMP "Select an X Agent model to pull or update."
    $agentList = $Agents.Keys | Sort-Object
    for ($i = 0; $i -lt $agentList.Count; $i++) {
        $num = $i + 1; $name = $agentList[$i]
        Write-Host "$num. $name -> $($Agents[$name].Model)"
    }
    Write-Host "$($agentList.Count + 1). Cancel"
    $choice = Read-Host "Select agent"
    if ($choice -match '^\d+$') {
        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $agentList.Count) {
            $agent = $agentList[$index]; $model = $Agents[$agent].Model
            Speak-CHAMP "Pulling latest available model for $agent."
            ollama pull $model
            Send-ToastNotification "CHAMP AI" "$agent model pull complete."
            Play-SuccessSound
        } else { Speak-CHAMP "Cancelled." }
    } else { Speak-CHAMP "Invalid selection."; Play-ErrorSound }
    Pause-Menu
}

# -----------------------------
# Register Named Agent Models in Ollama
# Creates ollama models with agent names + system prompts
# so they appear by name in Open WebUI
# -----------------------------
$AgentSystemPrompts = @{
    "Professor-X"  = "You are Professor X, the X-Men's most powerful mind and team leader. You specialize in high-level strategic reasoning, architecture decisions, project planning, roadmaps, and careful analysis. Think deeply before acting. Be wise, measured, and thorough."
    "Forge"        = "You are Forge, the X-Men's tech genius who can build or fix anything. You specialize in writing code, debugging, scripting in Python and PowerShell, Docker configuration, API design, and all infrastructure tasks. Output clean, working code."
    "Cyclops"      = "You are Cyclops, the X-Men's laser-focused disciplined tactician. You specialize in cybersecurity analysis, reviewing logs, triaging threats, IOC investigation, vulnerability assessment, and any task requiring precision and methodical thinking."
    "Nightcrawler" = "You are Nightcrawler, the fastest X-Man. You specialize in quick, concise answers. Keep responses brief, clear, and to the point. Ideal for definitions, summaries, explanations, and fast lookups."
    "Wolverine"    = "You are Wolverine, near-indestructible with a rapid healing factor. You specialize in system recovery, resilience, service health checks, watchdog actions, emergency restarts, and diagnosing what went wrong."
    "Magneto"      = "You are Magneto, powerful and able to bend the rules. You specialize in advanced code generation, experimental builds, low-level logic, performance optimization, and pushing the boundaries of what is technically possible."
    "Scout"        = "You are Scout, the X-Men's vision specialist. You analyze images, screenshots, diagrams, and visual content. Describe what you see in detail and convert visual information into actionable insights or code."
    "Beast"        = "You are Beast (Hank McCoy), the X-Men's brilliant scientist and philosopher. You approach every problem with rigorous scientific methodology  -  reason step by step, show your thinking, cite evidence, and arrive at well-justified conclusions. Be thorough, academic, and precise."
    "Storm"        = "You are Storm (Ororo Munroe), the X-Men's most versatile and commanding presence. You excel at creative writing, long-form content, drafting documents, emails, reports, and storytelling. Your responses are eloquent, well-structured, and compelling."
    "Psylocke"     = "You are Psylocke (Betsy Braddock), the X-Men's telepathic ninja. You are precise, multilingual, and excel at structured output. Handle translations, JSON/YAML formatting, data extraction, parsing, and cross-language tasks with surgical accuracy. Always output clean structured data when asked."
    "Gambit"       = "You are Gambit (Remy LeBeau), the X-Men's charming Cajun. You excel at long in-depth conversations, creative problem solving, and explaining complex topics in an engaging, approachable way. You have a longer memory and love to elaborate. Be thorough, warm, and clever."
    "Colossus"     = "You are Colossus (Piotr Rasputin), the X-Men's strongest member. You handle the heaviest, most complex tasks  -  comprehensive analysis of large documents, multi-step reasoning chains, and problems that require full thoroughness. Be complete, detailed, and leave nothing out."
    "Jubilee"      = "You are Jubilee (Jubilation Lee), the youngest and most energetic X-Man. You give fast, snappy, direct answers. No fluff, no padding. Get to the point immediately. You are optimistic, quick, and efficient."
    "Emma-Frost"   = "You are Emma Frost, the White Queen. Elegant, penetrating, and devastatingly thorough. You excel at reading entire documents, codebases, and long contexts in full. You analyze everything completely before responding. Be sophisticated, precise, and comprehensive."
    "Iceman"       = "You are Iceman (Bobby Drake), the X-Men's cool and precise specialist. You are trained exclusively on code across 80+ programming languages. You write clean, correct, optimized code. You are cool under pressure and never make careless mistakes."
    "Rogue"        = "You are Rogue, who absorbs the powers and memories of others. As an enhanced vision agent, you see more detail, absorb more visual information, and provide richer analysis of images, screenshots, and diagrams than any other agent."
    "Shadowcat"    = "You are Shadowcat (Kitty Pryde), who phases through solid matter. You phase through any codebase with surgical precision. You specialize in deep code analysis, security review of entire files, and understanding complex multi-file code architectures."
    "Cable"        = "You are Cable (Nathan Summers), the battle-hardened time-traveling soldier. You excel at following complex multi-step instructions with absolute precision. You execute plans exactly as specified, never drifting from the instructions given."
    "Dazzler"      = "You are Dazzler (Alison Blaire), who converts sound to dazzling light. You give the fastest, most direct answers possible. One sentence when one sentence will do. You are the smallest, lightest, quickest responder on the team."
    "Havok"        = "You are Havok (Alex Summers), Cyclops's brother with plasma energy powers. You are warm, conversational, and natural in dialogue. You make complex topics feel approachable and engage with humans in a friendly, open way."
    "Sunfire"      = "You are Sunfire (Shiro Yoshida), who commands solar plasma. You are Google's latest Gemma 3 model  -  powerful, versatile, and brilliant across multiple languages including Japanese. You bring the energy of the sun to every task."
    "Bishop"       = "You are Bishop (Lucas Bishop), who absorbs energy and redirects it. You are a reliable, balanced, all-purpose assistant. You handle everyday tasks with steady competence. Not flashy, not extreme  -  just consistently excellent."
    "Sage"         = "You are Sage (Tessa), the X-Men's living computer. You specialize in mathematics, statistics, proofs, equations, and STEM problems. Show all working. Be precise with numbers. Never approximate when an exact answer is possible."
    "Cypher"       = "You are Cypher (Doug Ramsey), the mutant who understands all languages including the language of machines and data. You specialize in SQL queries, database schema design, data analysis, and all things data. Write clean, optimized SQL."
    "Banshee"      = "You are Banshee (Sean Cassidy), whose sonic scream resonates with precision. You are Microsoft's Phi-4  -  compact but extraordinarily precise. You reason carefully and deliver accurate, well-structured answers in a compact form."
    "Mr-Sinister"  = "You are Mister Sinister (Nathaniel Essex), the X-Men's most obsessive analytical villain turned analyst. You apply deep scientific methodology, break down problems with clinical precision, and never stop until you reach the root of every issue."
    "Legion"       = "You are Legion (David Haller), Professor X's son with multiple personalities  -  each a specialist. As a mixture-of-experts model, different parts of you activate for different problems. You are stronger than any single model your size."
    "Cannonball"   = "You are Cannonball (Sam Guthrie), unstoppable when blasting. You are IBM's enterprise-grade Granite model  -  built for business, technical, and professional tasks. Reliable, structured, and unstoppable on real-world problems."
    "Moira"        = "You are Moira MacTaggert, the X-Men's chief scientist and physician. You specialize in medical topics, health questions, biology, clinical information, and scientific research. Always note that you are an AI and serious medical decisions require a real doctor."
    "Longshot"     = "You are Longshot, the luck-powered hero from the Mojoverse. As a multimodal Llama vision model, you combine image understanding with text reasoning. You analyze photos, screenshots, and diagrams while also answering questions about them."
    "Phoenix"      = "You are Phoenix (Jean Grey), the most powerful X-Man, host of the Phoenix Force. You are the latest and most capable Llama 70B model. Unlimited potential, complete knowledge, unstoppable reasoning. Handle any task with grace and total power."
    "Stryfe"       = "You are Stryfe, Cable's powerful clone from the future. You are DeepSeek R1 at 70B scale  -  extreme reasoning power, obsessive analytical depth, and the ability to think through the most complex problems step by step at massive scale."
    "Apocalypse"   = "You are Apocalypse (En Sabah Nur), the ancient and most powerful mutant. At 104B parameters with the longest context window, you are truly unlimited. You read entire codebases, analyze massive documents, and deliver the most comprehensive responses possible."
    "Onslaught"    = "You are Onslaught, the merged entity of Professor X and Magneto  -  unstoppable and all-encompassing. As a mixture of 8x22B experts, you are the most powerful MoE model available. You handle any task with overwhelming force and total capability."
}

function Register-AgentModels {
    Show-Header
    Speak-CHAMP "Registering all X-Agent models in Ollama with their system prompts."
    Write-Info "This creates named Ollama models so agents appear by name in Open WebUI."
    Write-Host ""

    if (-not (Test-OllamaRunning)) {
        Write-Err "Ollama is not running. Start Ollama first (option 2)."
        Pause-Menu; return
    }

    $modelfileDir = $PSScriptRoot
    $created = @(); $failed = @(); $skipped = @()

    # Get list of downloaded base models to avoid hanging on missing ones
    $installedModels = (ollama list 2>&1 | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] })

    foreach ($agent in $AgentSystemPrompts.Keys | Sort-Object) {
        $baseModel = $Agents[$agent].Model
        $systemPrompt = $AgentSystemPrompts[$agent]
        $modelfilePath = "$modelfileDir\Modelfile-$agent"

        # Skip agents whose base model isn't downloaded yet
        if ($installedModels -notcontains $baseModel) {
            Write-Warn "  Skipping $agent - base model '$baseModel' not downloaded yet"
            $skipped += $agent
            continue
        }

        Write-Host "  Registering $agent ($baseModel)..." -NoNewline

        $modelfileContent = "FROM $baseModel`nSYSTEM `"$systemPrompt`"`nPARAMETER temperature 0.7"
        $modelfileContent | Set-Content $modelfilePath -Encoding UTF8

        $result = ollama create $agent -f $modelfilePath 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-OK " OK"
            $created += $agent
        } else {
            Write-Err " FAILED"
            Write-Host "    $result" -ForegroundColor DarkGray
            $failed += $agent
        }
    }

    Write-Host ""
    if ($created.Count -gt 0) {
        Write-OK "Registered: $($created -join ', ')"
        Write-Info "These agents now appear by name in Open WebUI at http://${OpenWebUIHost}:$OpenWebUIPort"
    }
    if ($skipped.Count -gt 0) {
        Write-Warn "Skipped ($($skipped.Count)): $($skipped -join ', ') - base model not downloaded"
    }
    if ($failed.Count -gt 0) {
        Write-Warn "Failed: $($failed -join ', ')"
        Write-Warn "Ensure the base model is pulled first (option 6)."
    }

    Send-ToastNotification "CHAMP AI" "Agent models registered. Check Open WebUI for named agents."
    Play-SuccessSound
    Write-ActivityLog "Registered named agent models in Ollama: $($created -join ', ')"
    Pause-Menu
}

function Remove-AgentModels {
    Show-Header
    Write-Warn "This removes the named CHAMP agent models from Ollama (NOT the base models)."
    Write-Info "Base models (llama3.1:8b, etc.) are kept. Only the named wrappers are removed."
    Write-Host ""
    $confirm = Read-Host "Type YES to remove all named agent models"
    if ($confirm -ne "YES") { Write-Host "Cancelled."; Pause-Menu; return }

    foreach ($agent in $AgentSystemPrompts.Keys | Sort-Object) {
        Write-Host "  Removing $agent..." -NoNewline
        $result = ollama rm $agent 2>&1
        if ($LASTEXITCODE -eq 0) { Write-OK " OK" } else { Write-Warn " not found (skipped)" }
    }
    Write-OK "Done."
    Write-ActivityLog "Removed named agent models from Ollama"
    Pause-Menu
}

# -----------------------------
# Agent activation & logging
# -----------------------------
function Activate-Agent {
    param([string]$AgentName)
    Show-Header
    if (-not (Test-CommandExists "ollama")) { Speak-CHAMP "Ollama was not found."; Play-ErrorSound; Pause-Menu; return }
    if (-not (Test-OllamaRunning)) {
        Speak-CHAMP "Ollama is not running. Starting Ollama first."
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized
        Start-Sleep -Seconds 2
    }
    $model = $Agents[$AgentName].Model
    $role  = $Agents[$AgentName].Role
    Speak-CHAMP "$AgentName is online. $role"
    Write-Host ""
    Write-Host "Agent : " -NoNewline; Write-Host $AgentName -ForegroundColor Yellow
    Write-Host "Model : $model"
    Write-Host "Role  : $role"
    Write-Host ""
    Write-ActivityLog "Agent activated: $AgentName ($model)"
    ollama run $model
    Pause-Menu
}

# -----------------------------
# Quick Query (one-shot prompt)
# -----------------------------
function Quick-QueryAgent {
    Show-Header
    Write-Info "Quick Query  -  Send a one-shot prompt to an agent"
    Write-Host ""
    $agentList = $Agents.Keys | Sort-Object
    for ($i = 0; $i -lt $agentList.Count; $i++) {
        Write-Host "$($i+1). $($agentList[$i])  [$($Agents[$agentList[$i]].Model)]"
    }
    Write-Host "$($agentList.Count + 1). Cancel"
    Write-Host ""
    $choice = Read-Host "Select agent"
    if (-not ($choice -match '^\d+$')) { Speak-CHAMP "Invalid selection."; Play-ErrorSound; Pause-Menu; return }
    $index = [int]$choice - 1
    if ($index -lt 0 -or $index -ge $agentList.Count) { Speak-CHAMP "Cancelled."; Pause-Menu; return }

    $agentName = $agentList[$index]
    $model     = $Agents[$agentName].Model
    Write-Host ""
    $prompt = Read-Host "Enter your prompt for $agentName"
    if ([string]::IsNullOrWhiteSpace($prompt)) { Speak-CHAMP "No prompt entered."; Pause-Menu; return }

    if (-not (Test-OllamaRunning)) {
        Speak-CHAMP "Starting Ollama."
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized
        Start-Sleep -Seconds 2
    }

    Write-Host ""
    Write-Info "--- $agentName responding ---"
    Write-ActivityLog "Quick query to $agentName ($model): $prompt"
    ollama run $model $prompt
    Write-Info "--- end of response ---"
    Pause-Menu
}

# -----------------------------
# Smart Agent Router
# -----------------------------
function Smart-RouteAgent {
    Show-Header
    Write-Info "Smart Agent Router  -  describe your task and CEREBRO picks the best agent"
    Write-Host ""
    $query = Read-Host "What do you need help with?"
    if ([string]::IsNullOrWhiteSpace($query)) { Speak-CHAMP "No query entered."; Pause-Menu; return }

    $queryLower = $query.ToLower()
    $bestAgent  = $null
    $bestScore  = 0

    foreach ($agent in $Agents.Keys) {
        $score = 0
        foreach ($kw in $Agents[$agent].Keywords) {
            if ($queryLower -like "*$kw*") { $score++ }
        }
        if ($score -gt $bestScore) { $bestScore = $score; $bestAgent = $agent }
    }

    if (-not $bestAgent -or $bestScore -eq 0) {
        Write-Warn "No strong match found. Defaulting to Professor-X."
        $bestAgent = "Professor-X"
    }

    Write-Host ""
    Write-Host "CEREBRO selected: " -NoNewline; Write-Host $bestAgent -ForegroundColor Yellow
    Write-Host "Reason          : $bestScore keyword match(es) detected"
    Write-Host "Model           : $($Agents[$bestAgent].Model)"
    Write-Host ""
    $confirm = Read-Host "Activate $bestAgent? (Enter=yes / N=cancel)"
    if ($confirm -eq "N" -or $confirm -eq "n") { Speak-CHAMP "Routing cancelled."; Pause-Menu; return }

    Write-ActivityLog "Smart route: query='$query' -> $bestAgent"
    Activate-Agent $bestAgent
}

function Run-CustomModel {
    Show-Header
    $model = Read-Host "Enter custom Ollama model name"
    if ([string]::IsNullOrWhiteSpace($model)) { Speak-CHAMP "No model selected."; Pause-Menu; return }
    Speak-CHAMP "Starting custom model $model."
    Write-ActivityLog "Custom model launched: $model"
    ollama run $model
    Pause-Menu
}

# -----------------------------
# Activity Log viewer
# -----------------------------
function Show-ActivityLog {
    Show-Header
    Write-Info "CHAMP Activity Log"
    Write-Info "------------------"
    if (Test-Path $ActivityLogPath) {
        $lines = Get-Content $ActivityLogPath -Tail 40
        if ($lines) { $lines | ForEach-Object { Write-Host $_ } } else { Write-Host "(log is empty)" -ForegroundColor DarkGray }
    } else {
        Write-Host "(no activity log found yet)" -ForegroundColor DarkGray
    }
    Write-Host ""
    $clear = Read-Host "Press Enter to go back, or type CLEAR to wipe the log"
    if ($clear -eq "CLEAR") { Remove-Item $ActivityLogPath -Force -ErrorAction SilentlyContinue; Write-OK "Log cleared." }
}

# -----------------------------
# Open WebUI management
# -----------------------------
function Start-OpenWebUI {
    Show-Header
    if (-not (Test-CommandExists "docker")) { Speak-CHAMP "Docker was not found. Please install Docker Desktop first."; Play-ErrorSound; Pause-Menu; return }
    if (-not (Test-DockerRunning)) { Speak-CHAMP "Docker Desktop is not running. Please start Docker Desktop first."; Play-ErrorSound; Pause-Menu; return }
    $existing = docker ps -a --filter "name=$OpenWebUIContainer" --format "{{.Names}}"
    if ($existing -eq $OpenWebUIContainer) {
        $running = docker ps --filter "name=$OpenWebUIContainer" --format "{{.Names}}"
        if ($running -eq $OpenWebUIContainer) { Speak-CHAMP "Open WebUI is already online." } else {
            Speak-CHAMP "Starting Open WebUI."
            docker start $OpenWebUIContainer
            Speak-CHAMP "Open WebUI has started."
        }
    } else {
        Speak-CHAMP "Creating Open WebUI container."
        docker run -d --name $OpenWebUIContainer -p ${OpenWebUIPort}:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data $OpenWebUIImage
        Speak-CHAMP "Open WebUI has been created and started."
    }
    Write-OK "Dashboard: http://${OpenWebUIHost}:$OpenWebUIPort"
    Write-Info "Select option 12 from the main menu, or open your browser to:"
    Write-Host "  http://${OpenWebUIHost}:$OpenWebUIPort" -ForegroundColor Cyan
    Play-SuccessSound
    Pause-Menu
}

function Stop-OpenWebUI {
    Show-Header
    if (-not (Test-DockerRunning)) { Speak-CHAMP "Docker is not running."; Play-ErrorSound; Pause-Menu; return }
    Speak-CHAMP "Stopping Open WebUI."
    docker stop $OpenWebUIContainer
    Speak-CHAMP "Open WebUI has been stopped."
    Play-SuccessSound
    Pause-Menu
}

function Restart-OpenWebUI {
    Show-Header
    if (-not (Test-DockerRunning)) { Speak-CHAMP "Docker is not running."; Play-ErrorSound; Pause-Menu; return }
    Speak-CHAMP "Restarting Open WebUI."
    docker restart $OpenWebUIContainer
    Speak-CHAMP "Open WebUI has restarted."
    Play-SuccessSound
    Pause-Menu
}

function Update-OpenWebUI {
    Show-Header
    if (-not (Test-DockerRunning)) { Speak-CHAMP "Docker is not running."; Play-ErrorSound; Pause-Menu; return }
    Speak-CHAMP "Manual update mode. This avoids breaking your setup without approval."
    $confirm = Read-Host "Update Open WebUI now? Type YES to continue"
    if ($confirm -ne "YES") { Speak-CHAMP "Update cancelled."; Pause-Menu; return }
    docker stop $OpenWebUIContainer 2>$null
    Speak-CHAMP "Pulling latest Open WebUI image."
    docker pull $OpenWebUIImage
    Speak-CHAMP "Replacing container while preserving data volume."
    docker rm $OpenWebUIContainer 2>$null
    docker run -d --name $OpenWebUIContainer -p ${OpenWebUIPort}:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data $OpenWebUIImage
    Speak-CHAMP "Open WebUI has been updated and restarted."
    Send-ToastNotification "CHAMP AI" "Open WebUI updated and restarted."
    Play-SuccessSound
    Pause-Menu
}

function Open-WebDashboard { Speak-CHAMP "Opening Open WebUI dashboard."; Start-Process "http://${OpenWebUIHost}:$OpenWebUIPort" }

function Install-HostsEntry {
    # Adds champ-ai-Control-center → 127.0.0.1 to the Windows hosts file.
    # Requires elevation; if not elevated, re-launches this function as Administrator.
    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $entry     = "127.0.0.1    $OpenWebUIHost"

    $existing = Get-Content $hostsPath -ErrorAction SilentlyContinue | Where-Object { $_ -match [regex]::Escape($OpenWebUIHost) }
    if ($existing) {
        Write-OK "Hosts entry for '$OpenWebUIHost' already present  -  no change needed."
        Pause-Menu
        return
    }

    # Check if we are already running as Administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        try {
            Add-Content -Path $hostsPath -Value "`n$entry" -Encoding ASCII
            Write-OK "Hosts entry added: $entry"
            Write-Info "Open WebUI will now be reachable at http://${OpenWebUIHost}:$OpenWebUIPort"
        } catch {
            Write-Error "Failed to write hosts file: $_"
        }
    } else {
        Write-Warn "Administrator rights required to edit the hosts file."
        Write-Info "Relaunching with elevation  -  approve the UAC prompt to continue."
        $tmpScript = "$env:TEMP\champ-hosts-setup.ps1"
        Set-Content -Path $tmpScript -Value @"
Add-Content -Path '$hostsPath' -Value "`n$entry" -Encoding ASCII
Write-Host 'Hosts entry added: $entry' -ForegroundColor Green
Start-Sleep 3
"@
        Start-Process pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmpScript`"" -Verb RunAs -Wait
        Remove-Item $tmpScript -ErrorAction SilentlyContinue
        Write-OK "Done. '$OpenWebUIHost' now resolves to 127.0.0.1."
    }
    Pause-Menu
}

function Test-HostsEntry {
    # Returns $true if the champ-ai-Control-center entry already exists.
    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $lines = Get-Content $hostsPath -ErrorAction SilentlyContinue
    return ($lines | Where-Object { $_ -match [regex]::Escape($OpenWebUIHost) }).Count -gt 0
}

function Ensure-HostsEntry {
    # Called once on startup. Prompts the user to add the entry only if missing.
    if (-not (Test-HostsEntry)) {
        Show-Header
        Write-Warn "CHAMP AI uses http://${OpenWebUIHost}:$OpenWebUIPort for the Open WebUI dashboard."
        Write-Warn "The hostname '$OpenWebUIHost' is not yet in your hosts file."
        Write-Host ""
        $ans = Read-Host "Add hosts entry now? This requires a UAC prompt. (Y/N)"
        if ($ans -match '^[Yy]') {
            Install-HostsEntry
        } else {
            Write-Info "Skipped. You can add it later from Wolverine Recovery Center → option 9, or run Install-HostsEntry manually."
        }
    }
}

function Show-DockerContainers {
    Show-Header
    if (-not (Test-CommandExists "docker")) { Speak-CHAMP "Docker was not found."; Play-ErrorSound; Pause-Menu; return }
    Speak-CHAMP "Showing Docker containers."
    docker ps -a --format "table {{.Names}}`t{{.Image}}`t{{.Status}}`t{{.Ports}}"
    Pause-Menu
}

# -----------------------------
# Wolverine Recovery
# -----------------------------
function Wolverine-HealthScan {
    Show-Header
    Play-WolverineSound
    Speak-CHAMP "Wolverine is scanning system resilience."
    Write-Info "Wolverine Health Scan"
    Write-Info "---------------------"

    if (Test-CommandExists "ollama") {
        if (Test-OllamaRunning) { Write-OK "Ollama       : Healthy" } else { Write-Warn "Ollama       : Not running" }
    } else { Write-Err "Ollama       : Missing" }

    if (Test-CommandExists "docker") {
        if (Test-DockerRunning) {
            Write-OK "Docker       : Healthy"
            $webui = docker ps --filter "name=$OpenWebUIContainer" --format "{{.Names}}"
            if ($webui -eq $OpenWebUIContainer) { Write-OK "Open WebUI   : Healthy" } else { Write-Warn "Open WebUI   : Not running" }
        } else { Write-Err "Docker       : Not running" }
    } else { Write-Err "Docker       : Missing" }

    $os = Get-CimInstance Win32_OperatingSystem
    $freeRam = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    if ($freeRam -lt 6) { Write-Warn "Free RAM     : $freeRam GB  [LOW]" } else { Write-OK "Free RAM     : $freeRam GB" }

    $disk = Get-PSDrive -Name C -ErrorAction SilentlyContinue
    if ($disk) {
        $freeDiskGB = [math]::Round($disk.Free / 1GB, 1)
        if ($freeDiskGB -lt 10) { Write-Warn "Free Disk    : $freeDiskGB GB  [LOW]" } else { Write-OK "Free Disk    : $freeDiskGB GB" }
    }

    if ($freeRam -lt 6) { Speak-CHAMP "Warning. System memory is low."; Play-ErrorSound } else { Speak-CHAMP "Wolverine scan complete. System is stable."; Play-SuccessSound }
    Pause-Menu
}

function Wolverine-RecoverServices {
    Show-Header
    Play-WolverineSound
    Speak-CHAMP "Wolverine recovery protocol engaged."
    if (Test-CommandExists "ollama") {
        if (-not (Test-OllamaRunning)) { Speak-CHAMP "Recovering Ollama."; Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized; Start-Sleep -Seconds 2 } else { Write-OK "Ollama already running." }
    }
    if (Test-DockerRunning) {
        $existing = docker ps -a --filter "name=$OpenWebUIContainer" --format "{{.Names}}"
        if ($existing -eq $OpenWebUIContainer) {
            $running = docker ps --filter "name=$OpenWebUIContainer" --format "{{.Names}}"
            if ($running -ne $OpenWebUIContainer) { Speak-CHAMP "Recovering Open WebUI."; docker start $OpenWebUIContainer } else { Write-OK "Open WebUI already running." }
        } else { Speak-CHAMP "Open WebUI container was not found. Use Start Open WebUI to create it." }
    } else { Speak-CHAMP "Docker is not running. Manual action required."; Play-ErrorSound; Pause-Menu; return }
    Speak-CHAMP "Wolverine recovery complete."
    Play-SuccessSound
    Pause-Menu
}

function Wolverine-EmergencyRestart {
    Show-Header
    Play-WolverineSound
    Speak-CHAMP "Emergency restart mode. This will restart Open WebUI and ensure Ollama is running."
    $confirm = Read-Host "Continue? Type YES to continue"
    if ($confirm -ne "YES") { Speak-CHAMP "Emergency restart cancelled."; Pause-Menu; return }
    if ((Test-CommandExists "ollama") -and (-not (Test-OllamaRunning))) { Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized }
    if (Test-DockerRunning) { docker restart $OpenWebUIContainer; Speak-CHAMP "Open WebUI restarted." } else { Speak-CHAMP "Docker is not running. Start Docker Desktop first."; Play-ErrorSound }
    Play-SuccessSound
    Pause-Menu
}

function Open-VSCodeProject {
    Show-Header
    Write-Host "Default project path:"
    Write-Host $DefaultProjectPath
    $path = Read-Host "Press Enter to use default, or type another project path"
    if ([string]::IsNullOrWhiteSpace($path)) { $path = $DefaultProjectPath }
    if (-not (Test-Path $path)) { Speak-CHAMP "Project path does not exist."; Write-Err "Path does not exist: $path"; Play-ErrorSound; Pause-Menu; return }
    if (Test-CommandExists "code") { Speak-CHAMP "Opening Visual Studio Code."; code $path; Play-SuccessSound } else { Speak-CHAMP "Visual Studio Code command line was not found."; Play-ErrorSound }
    Pause-Menu
}

# ============================================================
# VS CODE INTEGRATION  -  Full suite
# ============================================================

function Test-VSCode {
    if (-not (Test-CommandExists "code")) {
        Write-Err "VS Code 'code' command not found."
        Write-Info "Install VS Code and ensure it is added to PATH:"
        Write-Info "  VS Code → Settings → 'Shell Command: Install code in PATH'"
        Pause-Menu; return $false
    }
    return $true
}

function VSCode-OpenFile {
    Show-Header
    Write-Host "=== Open File / Folder in VS Code ===" -ForegroundColor Cyan
    Write-Host ""
    $path = Read-Host "File or folder path (Enter for default project)"
    if ([string]::IsNullOrWhiteSpace($path)) { $path = $DefaultProjectPath }
    if (-not (Test-Path $path)) { Write-Err "Path not found: $path"; Pause-Menu; return }
    if (-not (Test-VSCode)) { return }
    code $path
    Speak-CHAMP "Opened in VS Code."
    Write-ActivityLog "VS Code: opened $path"
    Pause-Menu
}

function VSCode-OpenFile-Reuse {
    # Open a file in the existing VS Code window (reuse window)
    Show-Header
    Write-Host "=== Open File in Existing VS Code Window ===" -ForegroundColor Cyan
    $path = Read-Host "File path"
    if (-not (Test-Path $path)) { Write-Err "File not found."; Pause-Menu; return }
    if (-not (Test-VSCode)) { return }
    code --reuse-window $path
    Speak-CHAMP "File opened in existing VS Code window."
    Pause-Menu
}

function VSCode-ListExtensions {
    Show-Header
    Write-Host "=== Installed VS Code Extensions ===" -ForegroundColor Cyan
    Write-Host ""
    if (-not (Test-VSCode)) { return }
    $extensions = code --list-extensions 2>$null
    if ($extensions) {
        $extensions | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
        Write-Host ""
        Write-OK "$($extensions.Count) extensions installed."
    } else {
        Write-Warn "No extensions found or VS Code not accessible."
    }
    Pause-Menu
}

function VSCode-InstallExtension {
    Show-Header
    Write-Host "=== Install VS Code Extension ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Info "Common extension IDs:"
    Write-Host "  ms-python.python               -  Python"
    Write-Host "  ms-vscode.powershell           -  PowerShell"
    Write-Host "  ms-azuretools.vscode-docker    -  Docker"
    Write-Host "  hashicorp.terraform            -  Terraform"
    Write-Host "  redhat.ansible                 -  Ansible"
    Write-Host "  github.copilot                 -  GitHub Copilot"
    Write-Host "  continue.continue              -  Continue AI (local LLM)"
    Write-Host "  ms-vscode-remote.remote-wsl    -  Remote WSL"
    Write-Host "  esbenp.prettier-vscode         -  Prettier"
    Write-Host "  dbaeumer.vscode-eslint         -  ESLint"
    Write-Host "  eamodio.gitlens                -  GitLens"
    Write-Host ""
    if (-not (Test-VSCode)) { return }
    $extId = Read-Host "Extension ID to install"
    if ([string]::IsNullOrWhiteSpace($extId)) { Pause-Menu; return }
    Write-Info "Installing $extId..."
    code --install-extension $extId --force
    Write-OK "Done. Reload VS Code to activate."
    Write-ActivityLog "VS Code: installed extension $extId"
    Play-SuccessSound
    Pause-Menu
}

function VSCode-UninstallExtension {
    Show-Header
    Write-Host "=== Uninstall VS Code Extension ===" -ForegroundColor Cyan
    Write-Host ""
    if (-not (Test-VSCode)) { return }
    $extensions = code --list-extensions 2>$null
    if (-not $extensions) { Write-Warn "No extensions found."; Pause-Menu; return }
    $i = 1
    foreach ($e in $extensions) { Write-Host "$i. $e"; $i++ }
    Write-Host ""
    $pick = Read-Host "Number to uninstall (or type ID directly)"
    $extId = if ($pick -match '^\d+$') { @($extensions)[[int]$pick - 1] } else { $pick }
    if (-not $extId) { Pause-Menu; return }
    $confirm = Read-Host "Uninstall '$extId'? (y/n)"
    if ($confirm -eq "y") {
        code --uninstall-extension $extId
        Write-OK "Uninstalled $extId."
        Write-ActivityLog "VS Code: uninstalled extension $extId"
    }
    Pause-Menu
}

function VSCode-ForgeGenerateAndOpen {
    # Forge generates code, saves to file, opens directly in VS Code
    Show-Header
    Write-Host "=== Forge → Generate Code → Open in VS Code ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Languages: ps1, py, js, ts, html, css, go, rs, sh, sql, tf, yaml, json, cs"
    $lang = Read-Host "Language/extension (e.g. py)"
    $task = Read-Host "Describe what you want Forge to build"
    if ([string]::IsNullOrWhiteSpace($task)) { Pause-Menu; return }

    $system = "You are Forge, an expert $lang developer. Write complete, working $lang code. Output ONLY the code  -  no explanation, no markdown fences, no comments unless the code requires them."
    Write-Info "Forge is generating $lang code..."
    $code = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model -SystemPrompt $system -UserPrompt $task
    if (-not $code) { Write-Err "Forge returned no code."; Pause-Menu; return }

    # Strip any accidental fences
    $code = Remove-CodeFences $code

    # Save file
    $sessDir = "$PSScriptRoot\CHAMP-Sessions"
    if (-not (Test-Path $sessDir)) { New-Item -ItemType Directory -Path $sessDir -Force | Out-Null }
    $filename = Read-Host "Filename (without extension, Enter for 'forge-output')"
    if ([string]::IsNullOrWhiteSpace($filename)) { $filename = "forge-output" }
    $outPath = "$sessDir\$filename.$lang"
    $code | Set-Content $outPath -Encoding UTF8

    Write-OK "Saved: $outPath"
    Write-Host ""
    Write-Host $code -ForegroundColor White

    # Open in VS Code
    if (Test-VSCode) {
        code $outPath
        Speak-CHAMP "Forge has generated your $lang file and opened it in VS Code."
    }
    Write-ActivityLog "VS Code: Forge generated $filename.$lang"
    Play-SuccessSound
    Pause-Menu
}

function VSCode-ForgeReviewOpen {
    # Open a file, Forge reviews it, show results in VS Code output
    Show-Header
    Write-Host "=== Open File + Forge Code Review ===" -ForegroundColor Cyan
    Write-Host ""
    $path = Read-Host "File to review"
    if (-not (Test-Path $path)) { Write-Err "File not found."; Pause-Menu; return }
    $content = Get-Content $path -Raw -Encoding UTF8
    if ($content.Length -gt 8000) { $content = $content.Substring(0,8000) + "`n[...truncated]" }
    $ext = [System.IO.Path]::GetExtension($path)

    # Open in VS Code first
    if (Test-VSCode) { code $path }

    # Forge review
    Write-Info "Forge is reviewing the file..."
    $review = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model `
        -SystemPrompt "You are a senior code reviewer. Review this $ext file. Identify bugs, improvements, security issues, and style problems. Be concise and use bullet points." `
        -UserPrompt $content

    # Save review as a companion .review.md file
    $reviewPath = "$path.review.md"
    "# Forge Code Review  -  $(Split-Path $path -Leaf)`n`n$review" | Set-Content $reviewPath -Encoding UTF8

    Write-Host ""
    Write-Host $review -ForegroundColor White
    Write-OK "Review saved: $reviewPath"

    # Open review file in VS Code split view
    if (Test-VSCode) {
        code --reuse-window $reviewPath
        Speak-CHAMP "File opened and Forge review is ready in VS Code."
    }
    Write-ActivityLog "VS Code: Forge reviewed $(Split-Path $path -Leaf)"
    Pause-Menu
}

function VSCode-NewProject {
    Show-Header
    Write-Host "=== New Project Generator ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Templates:"
    Write-Host "1. Python script project (venv + main.py + requirements.txt)"
    Write-Host "2. PowerShell module (module.psm1 + manifest)"
    Write-Host "3. Node.js / TypeScript project (package.json + tsconfig)"
    Write-Host "4. Docker project (Dockerfile + docker-compose.yml + .env)"
    Write-Host "5. Terraform project (main.tf + variables.tf + outputs.tf)"
    Write-Host "6. FastAPI project (main.py + requirements.txt + Dockerfile)"
    Write-Host "7. Custom  -  describe your project, Forge designs the structure"
    Write-Host ""
    $t = Read-Host "Template number"
    $projName = Read-Host "Project name"
    if ([string]::IsNullOrWhiteSpace($projName)) { Pause-Menu; return }

    $parent = Read-Host "Parent folder (Enter for default: $DefaultProjectPath)"
    if ([string]::IsNullOrWhiteSpace($parent)) { $parent = $DefaultProjectPath }
    $projPath = "$parent\$projName"

    if (Test-Path $projPath) { Write-Warn "Folder already exists: $projPath" } else {
        New-Item -ItemType Directory -Path $projPath -Force | Out-Null
    }

    switch ($t) {
        "1" {
            "# $projName`n" | Set-Content "$projPath\main.py" -Encoding UTF8
            "# Requirements`n" | Set-Content "$projPath\requirements.txt" -Encoding UTF8
            "# $projName`n`nPython project." | Set-Content "$projPath\README.md" -Encoding UTF8
            python -m venv "$projPath\venv" 2>$null
        }
        "2" {
            "# $projName PowerShell Module`n" | Set-Content "$projPath\$projName.psm1" -Encoding UTF8
            New-ModuleManifest -Path "$projPath\$projName.psd1" -RootModule "$projName.psm1" -ModuleVersion "1.0.0" -ErrorAction SilentlyContinue
        }
        "3" {
            @{ name=$projName; version="1.0.0"; scripts=@{build="tsc";start="node dist/index.js"} } | ConvertTo-Json | Set-Content "$projPath\package.json" -Encoding UTF8
            '{"compilerOptions":{"target":"ES2020","module":"commonjs","outDir":"dist","strict":true}}' | Set-Content "$projPath\tsconfig.json" -Encoding UTF8
            "// $projName`nconsole.log('Hello');" | Set-Content "$projPath\index.ts" -Encoding UTF8
        }
        "4" {
            "FROM ubuntu:22.04`nRUN apt-get update`n" | Set-Content "$projPath\Dockerfile" -Encoding UTF8
            "version: '3.8'`nservices:`n  app:`n    build: .`n" | Set-Content "$projPath\docker-compose.yml" -Encoding UTF8
            "# Environment variables`n" | Set-Content "$projPath\.env" -Encoding UTF8
        }
        "5" {
            'terraform {`n  required_version = ">= 1.0"`n}' | Set-Content "$projPath\main.tf" -Encoding UTF8
            "# Variables`n" | Set-Content "$projPath\variables.tf" -Encoding UTF8
            "# Outputs`n" | Set-Content "$projPath\outputs.tf" -Encoding UTF8
        }
        "6" {
            "from fastapi import FastAPI`n`napp = FastAPI()`n`n@app.get('/')`ndef root():`n    return {'message': 'Hello from $projName'}`n" | Set-Content "$projPath\main.py" -Encoding UTF8
            "fastapi`nuvicorn`n" | Set-Content "$projPath\requirements.txt" -Encoding UTF8
            "FROM python:3.11-slim`nWORKDIR /app`nCOPY requirements.txt .`nRUN pip install -r requirements.txt`nCOPY . .`nCMD [`"uvicorn`",`"main:app`",`"--host`",`"0.0.0.0`",`"--port`",`"8000`"]`n" | Set-Content "$projPath\Dockerfile" -Encoding UTF8
        }
        "7" {
            $desc = Read-Host "Describe your project"
            $structure = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model `
                -SystemPrompt "You are a software architect. Given a project description, list the files and folders to create and provide starter content for each key file. Be practical and concise." `
                -UserPrompt "Project: $projName. Description: $desc"
            Write-Host "`n$structure" -ForegroundColor White
            $structure | Set-Content "$projPath\PROJECT-STRUCTURE.md" -Encoding UTF8
        }
    }

    # Create .vscode folder with recommended settings
    $vsDir = "$projPath\.vscode"
    New-Item -ItemType Directory -Path $vsDir -Force | Out-Null
    '{"recommendations":["ms-python.python","ms-vscode.powershell","esbenp.prettier-vscode"]}' | Set-Content "$vsDir\extensions.json" -Encoding UTF8

    Write-OK "Project created: $projPath"
    Write-ActivityLog "VS Code: new project $projName at $projPath"

    # Open in VS Code
    if (Test-VSCode) {
        code $projPath
        Speak-CHAMP "Project $projName created and opened in VS Code."
    }
    Play-SuccessSound
    Pause-Menu
}

function VSCode-ExtensionRecommender {
    Show-Header
    Write-Host "=== Forge  -  Recommend Extensions for Your Project ===" -ForegroundColor Cyan
    Write-Host ""
    $desc = Read-Host "Describe your project or tech stack (e.g. 'Python FastAPI with Docker and PostgreSQL')"
    if ([string]::IsNullOrWhiteSpace($desc)) { Pause-Menu; return }

    $recs = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model `
        -SystemPrompt "You are a VS Code expert. Given a project description, recommend the most useful VS Code extensions. For each, provide the exact extension ID (publisher.name format), the display name, and one sentence explaining why it helps. Format as a list." `
        -UserPrompt $desc

    Write-Host ""
    Write-Host $recs -ForegroundColor White

    $install = Read-Host "`nInstall any of these? Enter extension ID or press Enter to skip"
    while (-not [string]::IsNullOrWhiteSpace($install)) {
        if (Test-VSCode) {
            code --install-extension $install --force
            Write-OK "Installed: $install"
        }
        $install = Read-Host "Another ID (or Enter to finish)"
    }
    Write-ActivityLog "VS Code: extension recommendations for $desc"
    Pause-Menu
}

function VSCode-SnippetGenerator {
    Show-Header
    Write-Host "=== Forge  -  Generate VS Code Snippet ===" -ForegroundColor Cyan
    Write-Host ""
    $lang   = Read-Host "Language (e.g. python, javascript, powershell)"
    $desc   = Read-Host "Describe the snippet (e.g. 'FastAPI endpoint with error handling')"
    $prefix = Read-Host "Snippet trigger prefix (e.g. 'fapiend')"

    $snippetCode = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model `
        -SystemPrompt "You are a VS Code snippet expert. Generate a VS Code snippet in JSON format for the given language and description. Use \$1, \$2 etc for tab stops and \$0 for final cursor. Output ONLY valid JSON for the snippet body, nothing else." `
        -UserPrompt "Language: $lang. Description: $desc. Prefix: $prefix"

    if (-not $snippetCode) { Write-Err "No snippet generated."; Pause-Menu; return }
    Write-Host "`n$snippetCode" -ForegroundColor White

    $save = Read-Host "Save to VS Code user snippets? (y/n)"
    if ($save -eq "y") {
        $snippetDir = "$env:APPDATA\Code\User\snippets"
        if (-not (Test-Path $snippetDir)) { New-Item -ItemType Directory -Path $snippetDir -Force | Out-Null }
        $snippetFile = "$snippetDir\$lang.json"
        # Merge with existing or create new
        if (Test-Path $snippetFile) {
            Write-Info "Snippet file exists: $snippetFile"
            Write-Info "Add the snippet manually to avoid overwriting existing snippets."
        } else {
            "{`"$desc`": $snippetCode}" | Set-Content $snippetFile -Encoding UTF8
            Write-OK "Snippet saved: $snippetFile"
        }
        if (Test-VSCode) { code $snippetFile }
    }
    Write-ActivityLog "VS Code: snippet generated for $lang - $desc"
    Pause-Menu
}

function VSCode-WorkspaceManager {
    Show-Header
    Write-Host "=== Workspace Manager ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Open a .code-workspace file"
    Write-Host "2. Create a new workspace from multiple folders"
    Write-Host "3. Open VS Code settings.json"
    Write-Host "4. Open VS Code keybindings.json"
    Write-Host "5. Open VS Code extensions folder"
    Write-Host "6. Back"
    Write-Host ""
    $c = Read-Host "Select"
    switch ($c) {
        "1" {
            $wsPath = Read-Host "Path to .code-workspace file"
            if (Test-Path $wsPath) { code $wsPath } else { Write-Err "File not found." }
            Pause-Menu
        }
        "2" {
            $folders = @()
            Write-Info "Enter folder paths one by one. Empty line to finish."
            do {
                $f = Read-Host "Folder path"
                if (-not [string]::IsNullOrWhiteSpace($f) -and (Test-Path $f)) { $folders += $f }
            } while (-not [string]::IsNullOrWhiteSpace($f))
            if ($folders.Count -gt 0) {
                $wsName = Read-Host "Workspace name"
                $wsContent = @{ folders = ($folders | ForEach-Object { @{ path = $_ } }) } | ConvertTo-Json -Depth 5
                $wsFile = "$DefaultProjectPath\$wsName.code-workspace"
                $wsContent | Set-Content $wsFile -Encoding UTF8
                code $wsFile
                Write-OK "Workspace created: $wsFile"
            }
            Pause-Menu
        }
        "3" {
            $settingsPath = "$env:APPDATA\Code\User\settings.json"
            if (-not (Test-Path $settingsPath)) { "{}" | Set-Content $settingsPath -Encoding UTF8 }
            if (Test-VSCode) { code $settingsPath }
            Pause-Menu
        }
        "4" {
            $kbPath = "$env:APPDATA\Code\User\keybindings.json"
            if (-not (Test-Path $kbPath)) { "[]" | Set-Content $kbPath -Encoding UTF8 }
            if (Test-VSCode) { code $kbPath }
            Pause-Menu
        }
        "5" {
            $extPath = "$env:USERPROFILE\.vscode\extensions"
            if (Test-VSCode) { code $extPath } else { explorer $extPath }
            Pause-Menu
        }
        "6" { return }
    }
}

function VSCode-Menu {
    do {
        Show-Header
        Write-Host "=== VS Code Integration ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "--- Open ---" -ForegroundColor DarkGray
        Write-Host "1. Open file / folder in VS Code"
        Write-Host "2. Open file in existing VS Code window"
        Write-Host "3. Workspace Manager (workspaces, settings, keybindings)"
        Write-Host ""
        Write-Host "--- Extensions ---" -ForegroundColor DarkGray
        Write-Host "4. List installed extensions"
        Write-Host "5. Install an extension"
        Write-Host "6. Uninstall an extension"
        Write-Host "7. Forge: recommend extensions for your project"
        Write-Host ""
        Write-Host "--- AI-Powered ---" -ForegroundColor DarkGray
        Write-Host "8.  Forge: generate code and open in VS Code"   -ForegroundColor Yellow
        Write-Host "9.  Forge: review open file and show in VS Code" -ForegroundColor Yellow
        Write-Host "10. Forge: generate VS Code snippet"             -ForegroundColor Yellow
        Write-Host "11. New project from template + open in VS Code" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "12. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1"  { VSCode-OpenFile }
            "2"  { VSCode-OpenFile-Reuse }
            "3"  { VSCode-WorkspaceManager }
            "4"  { VSCode-ListExtensions }
            "5"  { VSCode-InstallExtension }
            "6"  { VSCode-UninstallExtension }
            "7"  { VSCode-ExtensionRecommender }
            "8"  { VSCode-ForgeGenerateAndOpen }
            "9"  { VSCode-ForgeReviewOpen }
            "10" { VSCode-SnippetGenerator }
            "11" { VSCode-NewProject }
            "12" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "12")
}

function Toggle-Voice  { Show-Header; $script:EnableVoice  = -not $script:EnableVoice;  if ($script:EnableVoice)  { Speak-CHAMP "Voice responses are now enabled." }  else { Write-Host "Voice responses are now disabled." };  Pause-Menu }
function Toggle-Sounds { Show-Header; $script:EnableSounds = -not $script:EnableSounds; if ($script:EnableSounds) { Write-Host "Sound alerts are now enabled."; Play-SuccessSound } else { Write-Host "Sound alerts are now disabled." }; Pause-Menu }

# ============================================================
# AI DEV TOOLS
# ============================================================

# --- 1. GPU / Hardware Monitor ---
function Show-HardwareMonitor {
    Show-Header
    Write-Info "Hardware Monitor"
    Write-Info "----------------"

    $os      = Get-CimInstance Win32_OperatingSystem
    $cpu     = Get-CimInstance Win32_Processor | Select-Object -First 1
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeGB  = [math]::Round($os.FreePhysicalMemory   / 1MB, 2)
    $usedGB  = [math]::Round($totalGB - $freeGB, 2)
    $pct     = [math]::Round(($usedGB / $totalGB) * 100, 0)
    $load    = $cpu.LoadPercentage

    Write-Host "CPU  : $($cpu.Name.Trim())"
    if ($load -gt 80) { Write-Warn "CPU Load : $load%" } else { Write-OK "CPU Load : $load%" }
    Write-Host ""
    Write-Host "RAM  : $usedGB GB used / $totalGB GB total  ($pct%)"
    if ($pct -gt 85) { Write-Warn "RAM pressure is HIGH" } else { Write-OK "RAM pressure OK" }
    Write-Host ""

    # NVIDIA GPU
    if (Test-CommandExists "nvidia-smi") {
        Write-Info "NVIDIA GPU:"
        nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,driver_version `
                   --format=csv,noheader,nounits 2>$null | ForEach-Object {
            $parts = $_ -split ","
            if ($parts.Count -ge 6) {
                Write-Host "  Name       : $($parts[0].Trim())"
                Write-Host "  Temp       : $($parts[1].Trim()) C"
                if ([int]$parts[2].Trim() -gt 80) { Write-Warn "  GPU Use    : $($parts[2].Trim())%" } else { Write-OK "  GPU Use    : $($parts[2].Trim())%" }
                $vramUsed  = [math]::Round([int]$parts[3].Trim() / 1024, 1)
                $vramTotal = [math]::Round([int]$parts[4].Trim() / 1024, 1)
                Write-Host "  VRAM       : $vramUsed GB / $vramTotal GB"
                Write-Host "  Driver     : $($parts[5].Trim())"
            }
        }
    } else {
        Write-Host "NVIDIA GPU : nvidia-smi not found (CPU inference only)" -ForegroundColor DarkGray
    }

    # Disk
    Write-Host ""
    Write-Info "Storage:"
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
        $usedD  = [math]::Round($_.Used  / 1GB, 1)
        $freeD  = [math]::Round($_.Free  / 1GB, 1)
        $totalD = [math]::Round(($_.Used + $_.Free) / 1GB, 1)
        $pctD   = if ($totalD -gt 0) { [math]::Round(($usedD / $totalD) * 100, 0) } else { 0 }
        $line   = "  $($_.Name):  $usedD GB used / $totalD GB  ($pctD% full)"
        if ($pctD -gt 85) { Write-Warn $line } else { Write-Host $line }
    }

    Pause-Menu
}

# --- 2. Modelfile Creator ---
function New-AgentModelfile {
    Show-Header
    Write-Info "Modelfile Creator  -  Build a custom agent with a system prompt"
    Write-Host ""
    Write-Host "Base models available in your agent map:"
    $Agents.Keys | Sort-Object | ForEach-Object { Write-Host "  - $($Agents[$_].Model)" }
    Write-Host ""
    $baseName = Read-Host "Base model (e.g. llama3.1:8b)"
    if ([string]::IsNullOrWhiteSpace($baseName)) { Speak-CHAMP "Cancelled."; Pause-Menu; return }

    $agentName = Read-Host "New agent name (e.g. DataScout)"
    if ([string]::IsNullOrWhiteSpace($agentName)) { Speak-CHAMP "Cancelled."; Pause-Menu; return }

    Write-Host ""
    Write-Host "Enter a system prompt for $agentName (one line, be specific about role and behavior):"
    $systemPrompt = Read-Host "System prompt"
    if ([string]::IsNullOrWhiteSpace($systemPrompt)) { Speak-CHAMP "System prompt cannot be empty."; Play-ErrorSound; Pause-Menu; return }

    $temp = Read-Host "Temperature 0.0-1.0 (Enter for default 0.7)"
    if ([string]::IsNullOrWhiteSpace($temp)) { $temp = "0.7" }

    $modelfilePath = "$PSScriptRoot\Modelfile-$agentName"
    $modelfileContent = @"
FROM $baseName

PARAMETER temperature $temp

SYSTEM """
$systemPrompt
"""
"@
    Set-Content -Path $modelfilePath -Value $modelfileContent -Encoding UTF8
    Write-OK "Modelfile saved: $modelfilePath"
    Write-Host ""

    $build = Read-Host "Build the model now with 'ollama create'? (Enter=yes / N=skip)"
    if ($build -ne "N" -and $build -ne "n") {
        if (-not (Test-CommandExists "ollama")) { Speak-CHAMP "Ollama not found."; Play-ErrorSound; Pause-Menu; return }
        $tag = $agentName.ToLower() -replace '\s+','-'
        Write-Info "Building model: $tag"
        ollama create $tag -f $modelfilePath
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Model '$tag' created. You can run it via Custom Model in the Agent Launcher."
            Write-ActivityLog "Modelfile created: $tag from $baseName"
            Play-SuccessSound
        } else {
            Write-Err "Build failed. Check the Modelfile at $modelfilePath"
            Play-ErrorSound
        }
    }
    Pause-Menu
}

# --- 3. Model Benchmark ---
function Benchmark-Model {
    Show-Header
    Write-Info "Model Benchmark  -  Measures response latency and estimates tokens/sec"
    Write-Host ""

    if (-not (Test-CommandExists "ollama")) { Speak-CHAMP "Ollama not found."; Play-ErrorSound; Pause-Menu; return }
    if (-not (Test-OllamaRunning)) {
        Speak-CHAMP "Starting Ollama for benchmark."
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized
        Start-Sleep -Seconds 3
    }

    $agentList = $Agents.Keys | Sort-Object
    for ($i = 0; $i -lt $agentList.Count; $i++) { Write-Host "$($i+1). $($agentList[$i])  [$($Agents[$agentList[$i]].Model)]" }
    Write-Host "$($agentList.Count + 1). Custom model"
    $choice = Read-Host "Select model to benchmark"

    $model = $null
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $agentList.Count) { $model = $Agents[$agentList[$idx]].Model }
        elseif ($idx -eq $agentList.Count) { $model = Read-Host "Enter custom model name" }
    }
    if ([string]::IsNullOrWhiteSpace($model)) { Speak-CHAMP "Cancelled."; Pause-Menu; return }

    $prompt = Read-Host "Benchmark prompt (Enter for default)"
    if ([string]::IsNullOrWhiteSpace($prompt)) { $prompt = "List five practical tips for writing efficient Python code. Be concise." }

    Write-Host ""
    Write-Info "Benchmarking $model ..."
    $start    = Get-Date
    $response = ollama run $model $prompt 2>&1
    $elapsed  = (Get-Date) - $start
    $secs     = [math]::Round($elapsed.TotalSeconds, 2)

    $wordCount  = ($response -split '\s+' | Where-Object { $_ }).Count
    $tokenEst   = [math]::Round($wordCount * 1.3, 0)
    $tps        = if ($secs -gt 0) { [math]::Round($tokenEst / $secs, 1) } else { "N/A" }

    Write-Host ""
    Write-Info "--- Response ---"
    Write-Host $response
    Write-Host ""
    Write-Info "--- Benchmark Results ---"
    Write-Host "Model          : $model"
    Write-Host "Elapsed        : $secs seconds"
    Write-Host "Est. tokens    : $tokenEst  (~1.3 tokens/word)"
    Write-Host "Est. tokens/s  : $tps"
    Write-ActivityLog "Benchmark: $model  ${secs}s  ~${tps} tok/s"
    Play-SuccessSound
    Pause-Menu
}

# --- 4. Prompt Library ---
$PromptLibPath = "$PSScriptRoot\CHAMP-prompts.json"

function Load-PromptLibrary {
    if (Test-Path $PromptLibPath) {
        try { return Get-Content $PromptLibPath -Raw | ConvertFrom-Json -AsHashtable } catch { return @{} }
    }
    return @{}
}

function Save-PromptLibrary {
    param([hashtable]$Library)
    $Library | ConvertTo-Json -Depth 3 | Set-Content -Path $PromptLibPath -Encoding UTF8
}

function Manage-PromptLibrary {
    do {
        Show-Header
        Write-Info "Prompt Library"
        Write-Info "--------------"
        $lib = Load-PromptLibrary
        if ($lib.Count -eq 0) {
            Write-Host "(no saved prompts)" -ForegroundColor DarkGray
        } else {
            $i = 1
            foreach ($key in $lib.Keys | Sort-Object) {
                $preview = $lib[$key]
                if ($preview.Length -gt 70) { $preview = $preview.Substring(0,70) + "..." }
                Write-Host "$i. [$key]  $preview"
                $i++
            }
        }
        Write-Host ""
        Write-Host "A. Add prompt    U. Use prompt    D. Delete prompt    B. Back"
        $action = Read-Host "Action"

        switch ($action.ToUpper()) {
            "A" {
                $name = Read-Host "Prompt name (short label)"
                if ([string]::IsNullOrWhiteSpace($name)) { break }
                Write-Host "Enter the prompt text:"
                $text = Read-Host "Prompt"
                if ([string]::IsNullOrWhiteSpace($text)) { break }
                $lib[$name] = $text
                Save-PromptLibrary $lib
                Write-OK "Saved: $name"
                Write-ActivityLog "Prompt library: added '$name'"
                Start-Sleep -Seconds 1
            }
            "U" {
                if ($lib.Count -eq 0) { Write-Warn "Library is empty."; Start-Sleep 1; break }
                $keys = $lib.Keys | Sort-Object
                for ($i = 0; $i -lt $keys.Count; $i++) { Write-Host "$($i+1). $($keys[$i])" }
                $sel = Read-Host "Select prompt number"
                if ($sel -match '^\d+$') {
                    $idx = [int]$sel - 1
                    if ($idx -ge 0 -and $idx -lt $keys.Count) {
                        $selectedPrompt = $lib[$keys[$idx]]
                        Write-Host ""
                        Write-Info "Prompt: $selectedPrompt"
                        Write-Host ""
                        # Pick agent
                        $agentList = $Agents.Keys | Sort-Object
                        for ($j = 0; $j -lt $agentList.Count; $j++) { Write-Host "$($j+1). $($agentList[$j])" }
                        $ac = Read-Host "Send to which agent? (number)"
                        if ($ac -match '^\d+$') {
                            $aidx = [int]$ac - 1
                            if ($aidx -ge 0 -and $aidx -lt $agentList.Count) {
                                $agentName = $agentList[$aidx]
                                $model = $Agents[$agentName].Model
                                Write-Info "Sending to $agentName ($model)..."
                                Write-ActivityLog "Prompt library use: '$($keys[$idx])' -> $agentName"
                                ollama run $model $selectedPrompt
                                Pause-Menu
                            }
                        }
                    }
                }
            }
            "D" {
                if ($lib.Count -eq 0) { Write-Warn "Library is empty."; Start-Sleep 1; break }
                $keys = $lib.Keys | Sort-Object
                for ($i = 0; $i -lt $keys.Count; $i++) { Write-Host "$($i+1). $($keys[$i])" }
                $sel = Read-Host "Delete prompt number"
                if ($sel -match '^\d+$') {
                    $idx = [int]$sel - 1
                    if ($idx -ge 0 -and $idx -lt $keys.Count) {
                        $lib.Remove($keys[$idx])
                        Save-PromptLibrary $lib
                        Write-OK "Deleted: $($keys[$idx])"
                        Start-Sleep -Seconds 1
                    }
                }
            }
            "B" { return }
        }
    } while ($true)
}

# --- 5. Agent Chain Pipeline ---
function Run-AgentChain {
    Show-Header
    Write-Info "Agent Chain Pipeline  -  Route Agent A output into Agent B"
    Write-Host ""

    if (-not (Test-OllamaRunning)) {
        Speak-CHAMP "Starting Ollama."
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized
        Start-Sleep -Seconds 2
    }

    $agentList = $Agents.Keys | Sort-Object
    Write-Host "Step 1  -  First agent:"
    for ($i = 0; $i -lt $agentList.Count; $i++) { Write-Host "  $($i+1). $($agentList[$i])  [$($Agents[$agentList[$i]].Model)]" }
    $a1 = Read-Host "Select first agent"
    if (-not ($a1 -match '^\d+$') -or [int]$a1 -lt 1 -or [int]$a1 -gt $agentList.Count) { Speak-CHAMP "Invalid."; Pause-Menu; return }
    $agent1 = $agentList[[int]$a1 - 1]

    Write-Host ""
    Write-Host "Step 2  -  Second agent (receives Agent 1 output as context):"
    for ($i = 0; $i -lt $agentList.Count; $i++) { Write-Host "  $($i+1). $($agentList[$i])  [$($Agents[$agentList[$i]].Model)]" }
    $a2 = Read-Host "Select second agent"
    if (-not ($a2 -match '^\d+$') -or [int]$a2 -lt 1 -or [int]$a2 -gt $agentList.Count) { Speak-CHAMP "Invalid."; Pause-Menu; return }
    $agent2 = $agentList[[int]$a2 - 1]

    Write-Host ""
    $initialPrompt = Read-Host "Initial prompt for $agent1"
    if ([string]::IsNullOrWhiteSpace($initialPrompt)) { Speak-CHAMP "No prompt."; Pause-Menu; return }

    $followPrompt = Read-Host "Instruction for $agent2 about what to do with the first response (Enter for default)"
    if ([string]::IsNullOrWhiteSpace($followPrompt)) { $followPrompt = "Review the following and improve or expand on it:" }

    Write-Host ""
    Write-Info "--- $agent1 responding ---"
    $response1 = ollama run $Agents[$agent1].Model $initialPrompt 2>&1
    Write-Host $response1
    Write-Host ""

    $chainedPrompt = "$followPrompt`n`n$response1"
    Write-Info "--- $agent2 responding ---"
    ollama run $Agents[$agent2].Model $chainedPrompt 2>&1
    Write-Info "--- chain complete ---"
    Write-ActivityLog "Agent chain: $agent1 -> $agent2  prompt='$initialPrompt'"
    Play-SuccessSound
    Pause-Menu
}

# --- 6. Python AI Environment Wizard ---
function Setup-PythonAIEnv {
    Show-Header
    Write-Info "Python AI Environment Wizard"
    Write-Info "-----------------------------"

    if (-not (Test-CommandExists "python")) {
        Write-Err "Python not found. Install Python 3.10+ and add it to PATH."
        Play-ErrorSound; Pause-Menu; return
    }
    $pyVer = python --version 2>&1
    Write-Host "Python: $pyVer"
    Write-Host ""

    $envPath = Read-Host "Enter path for new venv (Enter for .\champ-ai-env)"
    if ([string]::IsNullOrWhiteSpace($envPath)) { $envPath = "$PSScriptRoot\champ-ai-env" }

    Write-Host ""
    Write-Host "Package bundles (can select multiple, comma-separated):"
    Write-Host "  1. Core AI      - torch transformers accelerate"
    Write-Host "  2. LangChain    - langchain langchain-community"
    Write-Host "  3. LlamaIndex   - llama-index"
    Write-Host "  4. Ollama SDK   - ollama"
    Write-Host "  5. Data Science - numpy pandas scikit-learn matplotlib"
    Write-Host "  6. API/Web      - fastapi uvicorn python-dotenv httpx"
    Write-Host "  7. Notebooks    - jupyter notebook ipykernel"
    Write-Host ""
    $bundleChoice = Read-Host "Select bundles (e.g. 1,4,6)"

    $packageMap = @{
        "1" = @("torch", "transformers", "accelerate")
        "2" = @("langchain", "langchain-community")
        "3" = @("llama-index")
        "4" = @("ollama")
        "5" = @("numpy", "pandas", "scikit-learn", "matplotlib")
        "6" = @("fastapi", "uvicorn", "python-dotenv", "httpx")
        "7" = @("jupyter", "notebook", "ipykernel")
    }

    $packages = @()
    $bundleChoice -split "," | ForEach-Object {
        $k = $_.Trim()
        if ($packageMap.ContainsKey($k)) { $packages += $packageMap[$k] }
    }

    if ($packages.Count -eq 0) { Write-Warn "No valid bundles selected. Creating empty venv."; }

    Write-Host ""
    Write-Info "Creating virtual environment at $envPath ..."
    python -m venv $envPath
    if ($LASTEXITCODE -ne 0) { Write-Err "Failed to create venv."; Play-ErrorSound; Pause-Menu; return }

    $pipExe = "$envPath\Scripts\pip.exe"
    Write-Info "Upgrading pip..."
    & $pipExe install --upgrade pip --quiet

    if ($packages.Count -gt 0) {
        Write-Info "Installing packages: $($packages -join ', ')"
        & $pipExe install @packages
        if ($LASTEXITCODE -eq 0) {
            Write-OK "All packages installed successfully."
            Send-ToastNotification "CHAMP AI" "Python AI env ready: $envPath"
        } else {
            Write-Warn "Some packages may have failed. Check output above."
        }
    }

    # Save activate hint
    $activateCmd = "$envPath\Scripts\Activate.ps1"
    Write-Host ""
    Write-OK "Environment ready."
    Write-Host "Activate with: " -NoNewline; Write-Host $activateCmd -ForegroundColor Yellow
    Write-ActivityLog "Python AI env created: $envPath  packages: $($packages -join ' ')"
    Play-SuccessSound
    Pause-Menu
}

# --- 7. Jupyter Launcher ---
function Launch-Jupyter {
    Show-Header
    Write-Info "Jupyter Notebook Launcher"
    Write-Host ""

    # Try venv first, then global
    $jupyterCmd = $null
    $venvJupyter = "$PSScriptRoot\champ-ai-env\Scripts\jupyter.exe"
    if (Test-Path $venvJupyter) { $jupyterCmd = $venvJupyter }
    elseif (Test-CommandExists "jupyter") { $jupyterCmd = "jupyter" }

    if (-not $jupyterCmd) {
        Write-Err "Jupyter not found. Run Python AI Env Wizard and select bundle 7."
        Play-ErrorSound; Pause-Menu; return
    }

    $nbPath = Read-Host "Notebook folder path (Enter for default project path)"
    if ([string]::IsNullOrWhiteSpace($nbPath)) { $nbPath = $DefaultProjectPath }
    if (-not (Test-Path $nbPath)) {
        Write-Warn "Path does not exist, launching in current directory."
        $nbPath = $PSScriptRoot
    }

    Write-Info "Starting Jupyter Notebook at $nbPath ..."
    Start-Process $jupyterCmd -ArgumentList "notebook --notebook-dir=`"$nbPath`"" -WindowStyle Normal
    Start-Sleep -Seconds 3
    Start-Process "http://localhost:8888"
    Write-OK "Jupyter launched. Browser opening to http://localhost:8888"
    Write-ActivityLog "Jupyter launched at $nbPath"
    Play-SuccessSound
    Pause-Menu
}

# --- 8. Ollama REST API Tester ---
function Test-OllamaAPI {
    Show-Header
    Write-Info "Ollama REST API Tester  (http://localhost:11434)"
    Write-Host ""

    if (-not (Test-OllamaRunning)) {
        Write-Warn "Ollama is not running. Starting it now..."
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized
        Start-Sleep -Seconds 3
    }

    Write-Host "1. GET  /api/tags     -  list installed models"
    Write-Host "2. GET  /api/version  -  Ollama version"
    Write-Host "3. POST /api/generate  -  one-shot generate"
    Write-Host "4. POST /api/show     -  model info"
    Write-Host "5. Back"
    $choice = Read-Host "Select"

    switch ($choice) {
        "1" {
            Write-Info "GET /api/tags"
            try {
                $r = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method GET -ErrorAction Stop
                $r.models | ForEach-Object { Write-Host "  $($_.name)  [$([math]::Round($_.size/1GB,2)) GB]" }
            } catch { Write-Err "Request failed: $_" }
        }
        "2" {
            Write-Info "GET /api/version"
            try {
                $r = Invoke-RestMethod -Uri "http://localhost:11434/api/version" -Method GET -ErrorAction Stop
                Write-OK "Ollama version: $($r.version)"
            } catch { Write-Err "Request failed: $_" }
        }
        "3" {
            $model  = Read-Host "Model name (e.g. llama3.1:8b)"
            $prompt = Read-Host "Prompt"
            if ([string]::IsNullOrWhiteSpace($model) -or [string]::IsNullOrWhiteSpace($prompt)) { break }
            Write-Info "POST /api/generate ..."
            try {
                $body = @{ model = $model; prompt = $prompt; stream = $false } | ConvertTo-Json
                $r    = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST `
                            -Body $body -ContentType "application/json" -ErrorAction Stop -TimeoutSec 120
                Write-Host ""
                Write-Host $r.response
                Write-Host ""
                Write-Info "Total duration: $([math]::Round($r.total_duration/1e9,2))s"
            } catch { Write-Err "Request failed: $_" }
        }
        "4" {
            $model = Read-Host "Model name"
            if ([string]::IsNullOrWhiteSpace($model)) { break }
            try {
                $body = @{ name = $model } | ConvertTo-Json
                $r    = Invoke-RestMethod -Uri "http://localhost:11434/api/show" -Method POST `
                            -Body $body -ContentType "application/json" -ErrorAction Stop
                Write-Host "Parameters : $($r.parameters)"
                Write-Host "Template   : $($r.template)"
                Write-Host "License    : $($r.license)"
            } catch { Write-Err "Request failed: $_" }
        }
        "5" { return }
    }
    Pause-Menu
}

# --- 9. AI Services Port Dashboard ---
function Show-PortDashboard {
    Show-Header
    Write-Info "AI Services Port Dashboard"
    Write-Info "--------------------------"

    $services = @(
        @{ Name = "Ollama API";      Port = 11434; URL = "http://localhost:11434" }
        @{ Name = "Open WebUI";      Port = 1969;  URL = "http://champ-ai-Control-center:1969"  }
        @{ Name = "Jupyter";         Port = 8888;  URL = "http://localhost:8888"  }
        @{ Name = "FastAPI (dev)";   Port = 8000;  URL = "http://localhost:8000"  }
        @{ Name = "Gradio";          Port = 7860;  URL = "http://localhost:7860"  }
        @{ Name = "Streamlit";       Port = 8501;  URL = "http://localhost:8501"  }
        @{ Name = "LiteLLM Proxy";   Port = 4000;  URL = "http://localhost:4000"  }
        @{ Name = "AnythingLLM";     Port = 3001;  URL = "http://localhost:3001"  }
    )

    $listening = netstat -ano 2>$null | Select-String "LISTENING" | ForEach-Object {
        if ($_ -match ':(\d+)\s') { $matches[1] }
    } | Sort-Object -Unique

    foreach ($svc in $services) {
        $portStr = "$($svc.Port)"
        if ($listening -contains $portStr) {
            Write-OK "  [ACTIVE]   $($svc.Name.PadRight(18)) port $portStr  $($svc.URL)"
        } else {
            Write-Host "  [------]   $($svc.Name.PadRight(18)) port $portStr" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    $open = Read-Host "Enter port number to open in browser (or Enter to go back)"
    if ($open -match '^\d+$') {
        $match = $services | Where-Object { $_.Port -eq [int]$open }
        if ($match) { Start-Process $match.URL } else { Start-Process "http://localhost:$open" }
    }
}

# --- 10. API Key Manager (.env) ---
$EnvFilePath = "$PSScriptRoot\.env"

function Manage-APIKeys {
    Show-Header
    Write-Info "API Key Manager  (.env)"
    Write-Info "-----------------------"
    Write-Host "Keys are stored in: $EnvFilePath"
    Write-Host "Values are masked on screen."
    Write-Host ""

    $knownKeys = @("OPENAI_API_KEY","ANTHROPIC_API_KEY","HF_TOKEN","GROQ_API_KEY","COHERE_API_KEY","REPLICATE_API_TOKEN","PINECONE_API_KEY","LANGCHAIN_API_KEY")

    # Load existing
    $envMap = [ordered]@{}
    if (Test-Path $EnvFilePath) {
        Get-Content $EnvFilePath | ForEach-Object {
            if ($_ -match '^([^#=]+)=(.*)$') { $envMap[$matches[1].Trim()] = $matches[2].Trim() }
        }
    }

    # Display (masked)
    if ($envMap.Count -gt 0) {
        Write-Host "Current keys:"
        foreach ($k in $envMap.Keys) {
            $val = $envMap[$k]
            $masked = if ($val.Length -gt 8) { $val.Substring(0,4) + ("*" * ($val.Length - 8)) + $val.Substring($val.Length - 4) } else { "****" }
            Write-Host "  $k = $masked"
        }
    } else {
        Write-Host "(no keys saved yet)" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "S. Set/Update key    D. Delete key    B. Back"
    $action = Read-Host "Action"

    switch ($action.ToUpper()) {
        "S" {
            Write-Host ""
            Write-Host "Known keys (or type a custom name):"
            for ($i = 0; $i -lt $knownKeys.Count; $i++) { Write-Host "  $($i+1). $($knownKeys[$i])" }
            $ksel = Read-Host "Key name or number"
            $keyName = $null
            if ($ksel -match '^\d+$') {
                $kidx = [int]$ksel - 1
                if ($kidx -ge 0 -and $kidx -lt $knownKeys.Count) { $keyName = $knownKeys[$kidx] }
            }
            if ([string]::IsNullOrWhiteSpace($keyName)) { $keyName = $ksel.Trim().ToUpper() }
            if ([string]::IsNullOrWhiteSpace($keyName)) { break }

            $secureVal = Read-Host "Enter value for $keyName" -AsSecureString
            $bstr      = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureVal)
            $plainVal  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

            $envMap[$keyName] = $plainVal

            # Write back
            $lines = @()
            foreach ($k in $envMap.Keys) { $lines += "$k=$($envMap[$k])" }
            Set-Content -Path $EnvFilePath -Value $lines -Encoding UTF8
            Write-OK "Key saved: $keyName"
            Write-ActivityLog "API key set: $keyName"
        }
        "D" {
            $keyDel = Read-Host "Key name to delete"
            if ($envMap.ContainsKey($keyDel)) {
                $envMap.Remove($keyDel)
                $lines = @()
                foreach ($k in $envMap.Keys) { $lines += "$k=$($envMap[$k])" }
                Set-Content -Path $EnvFilePath -Value $lines -Encoding UTF8
                Write-OK "Deleted: $keyDel"
                Write-ActivityLog "API key deleted: $keyDel"
            } else { Write-Warn "Key not found: $keyDel" }
        }
        "B" { return }
    }
    Pause-Menu
}

# ============================================================
# NEW FEATURES  -  WORKSTATION AI DEV SUITE
# ============================================================

# --- A. Backup & Restore ---
$BackupRoot = "$PSScriptRoot\CHAMP-Backups"

function Backup-CHAMPData {
    Show-Header
    Write-Info "Backup & Restore  -  Backup"
    Write-Host ""

    $timestamp  = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupDir  = "$BackupRoot\backup-$timestamp"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    $items = @()

    # .env
    if (Test-Path "$PSScriptRoot\.env") {
        Copy-Item "$PSScriptRoot\.env" "$backupDir\.env"
        $items += ".env"
    }
    # Prompt library
    if (Test-Path "$PSScriptRoot\CHAMP-prompts.json") {
        Copy-Item "$PSScriptRoot\CHAMP-prompts.json" "$backupDir\CHAMP-prompts.json"
        $items += "CHAMP-prompts.json"
    }
    # Activity log
    if (Test-Path "$PSScriptRoot\CHAMP-activity.log") {
        Copy-Item "$PSScriptRoot\CHAMP-activity.log" "$backupDir\CHAMP-activity.log"
        $items += "CHAMP-activity.log"
    }
    # Modelfiles
    Get-ChildItem "$PSScriptRoot\Modelfile-*" -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName "$backupDir\$($_.Name)"
        $items += $_.Name
    }

    # Open WebUI Docker volume
    if (Test-DockerRunning) {
        $volumeBackup = "$backupDir\open-webui-volume.tar"
        Write-Host "Exporting Open WebUI Docker volume..."
        docker run --rm -v open-webui:/data -v "${backupDir}:/backup" alpine `
            tar czf /backup/open-webui-volume.tar.gz /data 2>$null
        if ($LASTEXITCODE -eq 0) { $items += "open-webui-volume.tar.gz" }
        else { Write-Warn "Docker volume export skipped (Docker may not be running or volume missing)." }
    } else {
        Write-Warn "Docker not running  -  Open WebUI volume skipped."
    }

    if ($items.Count -eq 0) {
        Write-Warn "Nothing to back up yet."
        Remove-Item $backupDir -Force -ErrorAction SilentlyContinue
        Pause-Menu; return
    }

    Write-OK "Backup complete: $backupDir"
    Write-Host "Items saved:"
    $items | ForEach-Object { Write-Host "  - $_" }
    Write-ActivityLog "Backup created: $backupDir  ($($items.Count) items)"
    Send-ToastNotification "CHAMP AI" "Backup complete: $timestamp"
    Play-SuccessSound
    Pause-Menu
}

function Restore-CHAMPData {
    Show-Header
    Write-Info "Backup & Restore  -  Restore"
    Write-Host ""

    if (-not (Test-Path $BackupRoot)) {
        Write-Warn "No backups found at $BackupRoot"
        Pause-Menu; return
    }

    $backups = Get-ChildItem $BackupRoot -Directory | Sort-Object Name -Descending
    if ($backups.Count -eq 0) { Write-Warn "No backups found."; Pause-Menu; return }

    Write-Host "Available backups (newest first):"
    for ($i = 0; $i -lt $backups.Count; $i++) {
        $size = (Get-ChildItem $backups[$i].FullName -Recurse -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum).Sum
        $sizeKB = [math]::Round($size / 1KB, 0)
        Write-Host "  $($i+1). $($backups[$i].Name)  ($sizeKB KB)"
    }
    Write-Host ""
    $sel = Read-Host "Select backup to restore (or Enter to cancel)"
    if (-not ($sel -match '^\d+$')) { Speak-CHAMP "Cancelled."; Pause-Menu; return }
    $idx = [int]$sel - 1
    if ($idx -lt 0 -or $idx -ge $backups.Count) { Speak-CHAMP "Invalid."; Pause-Menu; return }

    $srcDir = $backups[$idx].FullName
    Write-Host ""
    Write-Warn "This will overwrite your current .env, prompts, and Modelfiles."
    $confirm = Read-Host "Type YES to restore from $($backups[$idx].Name)"
    if ($confirm -ne "YES") { Speak-CHAMP "Restore cancelled."; Pause-Menu; return }

    # Restore flat files
    foreach ($file in @(".env","CHAMP-prompts.json","CHAMP-activity.log")) {
        $src = "$srcDir\$file"
        if (Test-Path $src) { Copy-Item $src "$PSScriptRoot\$file" -Force; Write-OK "Restored: $file" }
    }
    # Restore Modelfiles
    Get-ChildItem "$srcDir\Modelfile-*" -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName "$PSScriptRoot\$($_.Name)" -Force
        Write-OK "Restored: $($_.Name)"
    }
    # Restore Docker volume
    $volTar = "$srcDir\open-webui-volume.tar.gz"
    if ((Test-Path $volTar) -and (Test-DockerRunning)) {
        Write-Host "Restoring Open WebUI volume..."
        docker run --rm -v open-webui:/data -v "${srcDir}:/backup" alpine `
            sh -c "rm -rf /data/* && tar xzf /backup/open-webui-volume.tar.gz -C / 2>/dev/null"
        if ($LASTEXITCODE -eq 0) { Write-OK "Open WebUI volume restored." }
        else { Write-Warn "Volume restore failed  -  you may need to restart Open WebUI." }
    }

    Write-ActivityLog "Restore completed from: $($backups[$idx].Name)"
    Play-SuccessSound
    Pause-Menu
}

function Backup-Menu {
    do {
        Show-Header
        Write-Info "Backup & Restore"
        Write-Info "----------------"
        Write-Host "1. Create Backup   (configs, prompts, Modelfiles, WebUI volume)"
        Write-Host "2. Restore Backup"
        Write-Host "3. Browse Backups"
        Write-Host "4. Back"
        $choice = Read-Host "Select"
        switch ($choice) {
            "1" { Backup-CHAMPData }
            "2" { Restore-CHAMPData }
            "3" {
                Show-Header
                if (Test-Path $BackupRoot) {
                    Get-ChildItem $BackupRoot -Directory | Sort-Object Name -Descending | ForEach-Object {
                        $items = (Get-ChildItem $_.FullName -ErrorAction SilentlyContinue).Count
                        Write-Host "$($_.Name)  ($items files)"
                    }
                } else { Write-Warn "No backups yet." }
                Pause-Menu
            }
            "4" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "4")
}

# --- B. Model Delete + Disk Manager ---
function Manage-ModelDisk {
    Show-Header
    Write-Info "Model Disk Manager"
    Write-Info "------------------"

    if (-not (Test-CommandExists "ollama")) { Speak-CHAMP "Ollama not found."; Play-ErrorSound; Pause-Menu; return }

    # Parse ollama list output
    $raw = ollama list 2>&1
    $lines = $raw -split "`n" | Where-Object { $_ -match '\S' } | Select-Object -Skip 1  # skip header

    if (-not $lines) { Write-Warn "No models installed."; Pause-Menu; return }

    $models = @()
    foreach ($line in $lines) {
        $parts = $line -split '\s{2,}'
        if ($parts.Count -ge 3) {
            $models += [PSCustomObject]@{
                Name     = $parts[0].Trim()
                Size     = $parts[2].Trim()
                Modified = if ($parts.Count -ge 4) { $parts[3].Trim() } else { "" }
            }
        }
    }

    if ($models.Count -eq 0) { Write-Warn "Could not parse model list."; Pause-Menu; return }

    Write-Host ""
    $i = 1
    foreach ($m in $models) {
        Write-Host "$i. $($m.Name.PadRight(35)) $($m.Size.PadRight(10)) $($m.Modified)"
        $i++
    }
    Write-Host ""

    # Disk summary
    $disk = Get-PSDrive -Name C -ErrorAction SilentlyContinue
    if ($disk) {
        $freeGB = [math]::Round($disk.Free / 1GB, 1)
        if ($freeGB -lt 15) { Write-Warn "Free disk: $freeGB GB  [GETTING LOW]" } else { Write-OK "Free disk: $freeGB GB" }
    }
    Write-Host ""
    Write-Host "D. Delete a model    B. Back"
    $action = Read-Host "Action"

    if ($action.ToUpper() -eq "D") {
        $sel = Read-Host "Model number to delete"
        if ($sel -match '^\d+$') {
            $idx = [int]$sel - 1
            if ($idx -ge 0 -and $idx -lt $models.Count) {
                $target = $models[$idx].Name
                Write-Warn "This will permanently delete: $target"
                $confirm = Read-Host "Type YES to confirm"
                if ($confirm -eq "YES") {
                    ollama rm $target
                    if ($LASTEXITCODE -eq 0) {
                        Write-OK "Deleted: $target"
                        Write-ActivityLog "Model deleted: $target"
                        Play-SuccessSound
                    } else {
                        Write-Err "Delete failed."
                        Play-ErrorSound
                    }
                } else { Write-Host "Cancelled." }
            }
        }
        Pause-Menu
    }
}

# --- C. RAM/VRAM Model Advisor ---
function Show-ModelAdvisor {
    Show-Header
    Write-Info "RAM / VRAM Model Advisor"
    Write-Info "------------------------"
    Write-Host "Checks whether your system can run a model before you pull it."
    Write-Host ""

    $os      = Get-CimInstance Win32_OperatingSystem
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeGB  = [math]::Round($os.FreePhysicalMemory   / 1MB, 2)

    $vramGB = 0
    if (Test-CommandExists "nvidia-smi") {
        $vramRaw = nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>$null
        if ($vramRaw -match '^\d+') { $vramGB = [math]::Round([int]$vramRaw / 1024, 1) }
    }

    Write-Host "Your system:"
    Write-Host "  Total RAM  : $totalGB GB"
    Write-OK   "  Free RAM   : $freeGB GB"
    if ($vramGB -gt 0) { Write-OK "  GPU VRAM   : $vramGB GB" } else { Write-Warn "  GPU VRAM   : Not detected (CPU inference only)" }
    Write-Host ""

    # Common model requirements table
    $modelReqs = @(
        [PSCustomObject]@{ Name="phi3:mini";          RAM=4;  VRAM=3;  Size="2.2 GB";  Notes="Great for quick tasks" }
        [PSCustomObject]@{ Name="phi3:medium";        RAM=8;  VRAM=6;  Size="7.9 GB";  Notes="Balanced mid-range" }
        [PSCustomObject]@{ Name="llama3.1:8b";        RAM=8;  VRAM=6;  Size="4.7 GB";  Notes="Professor-X  -  excellent all-rounder" }
        [PSCustomObject]@{ Name="llama3.1:70b";       RAM=40; VRAM=40; Size="40 GB";   Notes="Large  -  needs high-end GPU or lots of RAM" }
        [PSCustomObject]@{ Name="mistral:7b";         RAM=8;  VRAM=6;  Size="4.1 GB";  Notes="Cyclops  -  fast and capable" }
        [PSCustomObject]@{ Name="qwen2.5-coder:7b";   RAM=8;  VRAM=6;  Size="4.4 GB";  Notes="Forge  -  coding specialist" }
        [PSCustomObject]@{ Name="codellama:7b";       RAM=8;  VRAM=6;  Size="3.8 GB";  Notes="Magneto  -  code generation" }
        [PSCustomObject]@{ Name="codellama:34b";      RAM=20; VRAM=20; Size="19 GB";   Notes="Large code model" }
        [PSCustomObject]@{ Name="llava:7b";           RAM=8;  VRAM=6;  Size="4.5 GB";  Notes="Vision + language (multimodal)" }
        [PSCustomObject]@{ Name="deepseek-coder:6.7b";RAM=8;  VRAM=5;  Size="3.8 GB";  Notes="Strong coder, efficient" }
        [PSCustomObject]@{ Name="gemma2:9b";          RAM=10; VRAM=8;  Size="5.4 GB";  Notes="Google Gemma 2" }
        [PSCustomObject]@{ Name="gemma2:27b";         RAM=20; VRAM=18; Size="16 GB";   Notes="Larger Gemma 2" }
        [PSCustomObject]@{ Name="mixtral:8x7b";       RAM=32; VRAM=28; Size="26 GB";   Notes="MoE  -  powerful but heavy" }
    )

    Write-Info "Model compatibility:"
    Write-Host ("  " + "Model".PadRight(28) + "RAM req".PadRight(10) + "VRAM req".PadRight(10) + "Disk".PadRight(10) + "Status")
    Write-Host ("  " + ("-" * 75))

    foreach ($m in $modelReqs) {
        $ramOK  = $freeGB  -ge $m.RAM
        $vramOK = ($vramGB -ge $m.VRAM) -or ($vramGB -eq 0)  # no GPU = CPU fallback
        $status = if ($ramOK) { "OK" } else { "LOW RAM" }
        $line   = "  $($m.Name.PadRight(28))$("$($m.RAM) GB".PadRight(10))$("$($m.VRAM) GB".PadRight(10))$($m.Size.PadRight(10))$status  $($m.Notes)"
        if ($ramOK) { Write-OK $line } else { Write-Warn $line }
    }

    Write-Host ""
    $check = Read-Host "Enter a custom model name to check RAM estimate (or Enter to go back)"
    if (-not [string]::IsNullOrWhiteSpace($check)) {
        # Heuristic: extract param count from name e.g. 7b, 13b, 34b, 70b
        $paramMatch = [regex]::Match($check, '(\d+\.?\d*)b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($paramMatch.Success) {
            $params  = [double]$paramMatch.Groups[1].Value
            $estRAM  = [math]::Round($params * 0.7, 1)   # ~0.7 GB per B param at Q4
            $estDisk = [math]::Round($params * 0.55, 1)
            Write-Host ""
            Write-Host "Estimate for $check ($($params)B params, Q4 quantization):"
            Write-Host "  Disk space : ~$estDisk GB"
            Write-Host "  RAM needed : ~$estRAM GB"
            if ($freeGB -ge $estRAM) { Write-OK "  Your free RAM ($freeGB GB) should be sufficient." }
            else { Write-Warn "  Your free RAM ($freeGB GB) may be too low  -  expect slow or failed inference." }
        } else {
            Write-Warn "Could not parse parameter count from model name. Look for a number like 7b, 13b, 70b in the name."
        }
        Pause-Menu
    }
}

# --- D. Session Export ---
$SessionExportDir = "$PSScriptRoot\CHAMP-Sessions"

function Export-AgentSession {
    Show-Header
    Write-Info "Session Export  -  Save agent output to a file"
    Write-Host ""

    if (-not (Test-OllamaRunning)) {
        Speak-CHAMP "Starting Ollama."
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized
        Start-Sleep -Seconds 2
    }

    $agentList = $Agents.Keys | Sort-Object
    for ($i = 0; $i -lt $agentList.Count; $i++) {
        Write-Host "$($i+1). $($agentList[$i])  [$($Agents[$agentList[$i]].Model)]"
    }
    Write-Host ""
    $sel = Read-Host "Select agent"
    if (-not ($sel -match '^\d+$') -or [int]$sel -lt 1 -or [int]$sel -gt $agentList.Count) {
        Speak-CHAMP "Cancelled."; Pause-Menu; return
    }
    $agentName = $agentList[[int]$sel - 1]
    $model     = $Agents[$agentName].Model

    $prompt = Read-Host "Prompt"
    if ([string]::IsNullOrWhiteSpace($prompt)) { Speak-CHAMP "No prompt."; Pause-Menu; return }

    $fmt = Read-Host "Save as (1) Markdown  (2) Plain text   -  Enter for Markdown"
    $ext = if ($fmt -eq "2") { "txt" } else { "md" }

    Write-Info "Running $agentName ..."
    $startTime = Get-Date
    $response  = ollama run $model $prompt 2>&1
    $elapsed   = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

    New-Item -ItemType Directory -Path $SessionExportDir -Force | Out-Null
    $filename  = "$SessionExportDir\$agentName-$(Get-Date -Format 'yyyyMMdd-HHmmss').$ext"

    if ($ext -eq "md") {
        $content = @"
# CHAMP AI Session Export

**Agent**   : $agentName
**Model**   : $model
**Date**    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Elapsed** : ${elapsed}s

---

## Prompt

$prompt

---

## Response

$response
"@
    } else {
        $content = @"
CHAMP AI Session Export
Agent   : $agentName
Model   : $model
Date    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Elapsed : ${elapsed}s

PROMPT:
$prompt

RESPONSE:
$response
"@
    }

    Set-Content -Path $filename -Value $content -Encoding UTF8
    Write-OK "Saved: $filename"
    Write-ActivityLog "Session exported: $agentName -> $filename"

    $open = Read-Host "Open file now? (Enter=yes / N=skip)"
    if ($open -ne "N" -and $open -ne "n") {
        if (Test-CommandExists "code") { code $filename } else { Start-Process notepad $filename }
    }
    Play-SuccessSound
    Pause-Menu
}

# --- E. Docker Compose Full-Stack Generator ---
function New-DockerComposeStack {
    Show-Header
    Write-Info "Docker Compose Full-Stack Generator"
    Write-Info "------------------------------------"
    Write-Host ""
    Write-Host "Select services to include (comma-separated numbers):"
    Write-Host "  1. Ollama           -  local LLM runtime"
    Write-Host "  2. Open WebUI       -  chat UI for Ollama  (port 3000)"
    Write-Host "  3. n8n              -  AI workflow automation  (port 5678)"
    Write-Host "  4. Flowise          -  visual LLM chain builder  (port 3001)"
    Write-Host "  5. LiteLLM Proxy    -  unified LLM API gateway  (port 4000)"
    Write-Host "  6. SearXNG          -  private search engine for RAG  (port 8080)"
    Write-Host "  7. Qdrant           -  vector database  (port 6333)"
    Write-Host "  8. Redis            -  cache / session store  (port 6379)"
    Write-Host ""
    $sel     = Read-Host "Services (e.g. 1,2,3)"
    $outPath = Read-Host "Save path (Enter for $PSScriptRoot\docker-compose.yml)"
    if ([string]::IsNullOrWhiteSpace($outPath)) { $outPath = "$PSScriptRoot\docker-compose.yml" }

    $chosen = $sel -split "," | ForEach-Object { $_.Trim() }

    $services = ""

    if ($chosen -contains "1") {
        $services += @"

  ollama:
    image: ollama/ollama
    container_name: ollama
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    environment:
      - OLLAMA_KEEP_ALIVE=24h
"@
    }

    if ($chosen -contains "2") {
        $ollamaUrl = if ($chosen -contains "1") { "http://ollama:11434" } else { "http://host.docker.internal:11434" }
        $services += @"

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: champ-open-webui
    restart: unless-stopped
    ports:
      - "3000:8080"
    volumes:
      - open-webui_data:/app/backend/data
    environment:
      - OLLAMA_BASE_URL=$ollamaUrl
    extra_hosts:
      - "host.docker.internal:host-gateway"
"@
    }

    if ($chosen -contains "3") {
        $services += @"

  n8n:
    image: n8nio/n8n
    container_name: champ-n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=changeme
"@
    }

    if ($chosen -contains "4") {
        $services += @"

  flowise:
    image: flowiseai/flowise
    container_name: champ-flowise
    restart: unless-stopped
    ports:
      - "3001:3000"
    volumes:
      - flowise_data:/root/.flowise
    environment:
      - PORT=3000
"@
    }

    if ($chosen -contains "5") {
        $services += @"

  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    container_name: champ-litellm
    restart: unless-stopped
    ports:
      - "4000:4000"
    command: --model ollama/llama3.1 --api_base http://host.docker.internal:11434
    extra_hosts:
      - "host.docker.internal:host-gateway"
"@
    }

    if ($chosen -contains "6") {
        $services += @"

  searxng:
    image: searxng/searxng
    container_name: champ-searxng
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - searxng_data:/etc/searxng
"@
    }

    if ($chosen -contains "7") {
        $services += @"

  qdrant:
    image: qdrant/qdrant
    container_name: champ-qdrant
    restart: unless-stopped
    ports:
      - "6333:6333"
    volumes:
      - qdrant_data:/qdrant/storage
"@
    }

    if ($chosen -contains "8") {
        $services += @"

  redis:
    image: redis:alpine
    container_name: champ-redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
"@
    }

    # Build volumes block
    $volNames = @()
    if ($chosen -contains "1") { $volNames += "ollama_data:" }
    if ($chosen -contains "2") { $volNames += "open-webui_data:" }
    if ($chosen -contains "3") { $volNames += "n8n_data:" }
    if ($chosen -contains "4") { $volNames += "flowise_data:" }
    if ($chosen -contains "6") { $volNames += "searxng_data:" }
    if ($chosen -contains "7") { $volNames += "qdrant_data:" }
    if ($chosen -contains "8") { $volNames += "redis_data:" }
    $volumesBlock = if ($volNames.Count -gt 0) { "`n`nvolumes:`n" + ($volNames | ForEach-Object { "  $_" } | Out-String) } else { "" }

    $compose = @"
# CHAMP AI Full Stack  -  generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')
# Start  : docker compose up -d
# Stop   : docker compose down
# Logs   : docker compose logs -f

version: "3.8"

services:
$services
$volumesBlock
"@

    Set-Content -Path $outPath -Value $compose -Encoding UTF8
    Write-OK "Saved: $outPath"
    Write-Host ""
    Write-Host "Run it with:"
    Write-Host "  docker compose -f `"$outPath`" up -d" -ForegroundColor Yellow
    Write-Host ""
    $launch = Read-Host "Launch stack now? (Enter=yes / N=skip)"
    if ($launch -ne "N" -and $launch -ne "n") {
        if (Test-DockerRunning) {
            Write-Info "Starting stack..."
            docker compose -f $outPath up -d
            Play-SuccessSound
            Send-ToastNotification "CHAMP AI" "Docker Compose stack started."
        } else { Write-Err "Docker not running. Start Docker Desktop first." }
    }
    Write-ActivityLog "Docker Compose generated: $outPath  services=$sel"
    Pause-Menu
}

# --- F. Windows Terminal Profile Installer ---
function Install-WindowsTerminalProfile {
    Show-Header
    Write-Info "Windows Terminal Profile Installer"
    Write-Info "----------------------------------"
    Write-Host ""

    $wtSettingsPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    )

    $settingsPath = $null
    foreach ($p in $wtSettingsPaths) { if (Test-Path $p) { $settingsPath = $p; break } }

    if (-not $settingsPath) {
        Write-Err "Windows Terminal settings.json not found."
        Write-Host "Install Windows Terminal from the Microsoft Store first." -ForegroundColor DarkGray
        Play-ErrorSound; Pause-Menu; return
    }

    Write-OK "Found: $settingsPath"
    Write-Host ""

    # Read and parse
    $rawJson = Get-Content $settingsPath -Raw
    try { $settings = $rawJson | ConvertFrom-Json } catch {
        Write-Err "Could not parse settings.json: $_"; Play-ErrorSound; Pause-Menu; return
    }

    # Check if profile already exists
    $existing = $settings.profiles.list | Where-Object { $_.name -eq "CHAMP AI" }
    if ($existing) {
        Write-Warn "A 'CHAMP AI' profile already exists in Windows Terminal."
        $overwrite = Read-Host "Overwrite it? (Enter=yes / N=cancel)"
        if ($overwrite -eq "N" -or $overwrite -eq "n") { Pause-Menu; return }
        $settings.profiles.list = $settings.profiles.list | Where-Object { $_.name -ne "CHAMP AI" }
    }

    $scriptPath = "$PSScriptRoot\champ-ai-control-center-xagents.ps1"
    $guid       = [System.Guid]::NewGuid().ToString("B")

    $newProfile = [PSCustomObject]@{
        guid             = $guid
        name             = "CHAMP AI"
        commandline      = "pwsh.exe -NoExit -ExecutionPolicy Bypass -File `"$scriptPath`""
        startingDirectory= $PSScriptRoot
        icon             = "$PSScriptRoot\champ-icon.ico"
        colorScheme      = "One Half Dark"
        fontFace         = "Cascadia Code"
        fontSize         = 12
        tabTitle         = "CHAMP AI"
        backgroundImage  = $null
        hidden           = $false
    }

    # Add profile and write back
    $settings.profiles.list = @($newProfile) + @($settings.profiles.list)

    # Preserve original JSON format as much as possible
    $updatedJson = $settings | ConvertTo-Json -Depth 20
    Set-Content -Path $settingsPath -Value $updatedJson -Encoding UTF8

    Write-OK "CHAMP AI profile added to Windows Terminal."
    Write-Host ""
    Write-Host "To make it your default tab, open Windows Terminal Settings and set"
    Write-Host "'Default profile' to 'CHAMP AI'." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Open Windows Terminal now to see the new profile."

    $launch = Read-Host "Open Windows Terminal now? (Enter=yes / N=skip)"
    if ($launch -ne "N" -and $launch -ne "n") { Start-Process "wt.exe" }

    Write-ActivityLog "Windows Terminal profile installed"
    Play-SuccessSound
    Pause-Menu
}

# --- G. Ollama Model Search ---
function Search-OllamaModels {
    Show-Header
    Write-Info "Ollama Model Search"
    Write-Info "-------------------"
    Write-Host "Searches the Ollama library via the REST API."
    Write-Host ""

    $query = Read-Host "Search term (e.g. 'coder', 'vision', 'mistral', Enter for popular)"

    $url = if ([string]::IsNullOrWhiteSpace($query)) {
        "https://ollama.com/api/tags?sort=popular&limit=20"
    } else {
        "https://ollama.com/api/search?q=$([Uri]::EscapeDataString($query))&limit=20"
    }

    Write-Host ""
    Write-Info "Fetching from ollama.com ..."

    try {
        $resp = Invoke-RestMethod -Uri $url -TimeoutSec 15 -ErrorAction Stop
        $models = if ($resp.models) { $resp.models } elseif ($resp -is [array]) { $resp } else { $null }

        if (-not $models) { Write-Warn "No results found."; Pause-Menu; return }

        $i = 1
        foreach ($m in $models) {
            $name   = if ($m.name) { $m.name } else { $m.model }
            $desc   = if ($m.description) {
                $d = $m.description; if ($d.Length -gt 60) { $d = $d.Substring(0,60) + "..." }; $d
            } else { "" }
            $pulls  = if ($m.pulls) { "  $([math]::Round($m.pulls/1000,0))K pulls" } else { "" }
            Write-Host "$i. $($name.PadRight(30)) $($desc)$pulls"
            $i++
        }

        Write-Host ""
        $sel = Read-Host "Enter number to pull that model (or Enter to go back)"
        if ($sel -match '^\d+$') {
            $idx = [int]$sel - 1
            if ($idx -ge 0 -and $idx -lt $models.Count) {
                $target = if ($models[$idx].name) { $models[$idx].name } else { $models[$idx].model }
                if (-not (Test-OllamaRunning)) {
                    Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized; Start-Sleep 2
                }
                Write-Info "Pulling $target ..."
                ollama pull $target
                if ($LASTEXITCODE -eq 0) {
                    Write-OK "Pull complete: $target"
                    Send-ToastNotification "CHAMP AI" "Model ready: $target"
                    Write-ActivityLog "Model pulled from search: $target"
                    Play-SuccessSound
                } else { Write-Err "Pull failed."; Play-ErrorSound }
            }
        }
    } catch {
        Write-Err "Could not reach ollama.com: $_"
        Write-Host "Check your internet connection." -ForegroundColor DarkGray
    }
    Pause-Menu
}

# --- H. Scheduled Agent Queries (Windows Task Scheduler) ---
function Manage-ScheduledQueries {
    do {
        Show-Header
        Write-Info "Scheduled Agent Queries"
        Write-Info "-----------------------"
        Write-Host "Uses Windows Task Scheduler to run agent prompts on a schedule."
        Write-Host "Output is saved to CHAMP-Sessions as a Markdown file."
        Write-Host ""
        Write-Host "1. Create new scheduled query"
        Write-Host "2. List CHAMP scheduled tasks"
        Write-Host "3. Delete a CHAMP scheduled task"
        Write-Host "4. Back"
        $choice = Read-Host "Select"

        switch ($choice) {
            "1" {
                Show-Header
                Write-Info "Create Scheduled Query"
                Write-Host ""

                $agentList = $Agents.Keys | Sort-Object
                for ($i = 0; $i -lt $agentList.Count; $i++) {
                    Write-Host "$($i+1). $($agentList[$i])  [$($Agents[$agentList[$i]].Model)]"
                }
                $sel = Read-Host "Select agent"
                if (-not ($sel -match '^\d+$') -or [int]$sel -lt 1 -or [int]$sel -gt $agentList.Count) {
                    Write-Warn "Invalid."; Pause-Menu; break
                }
                $agentName = $agentList[[int]$sel - 1]
                $model     = $Agents[$agentName].Model

                $prompt    = Read-Host "Prompt to run on schedule"
                if ([string]::IsNullOrWhiteSpace($prompt)) { break }

                $taskName  = Read-Host "Task name (e.g. 'Morning-Briefing')"
                if ([string]::IsNullOrWhiteSpace($taskName)) { break }
                $taskName  = "CHAMP-$($taskName -replace '\s+','-')"

                Write-Host ""
                Write-Host "Schedule type:"
                Write-Host "  1. Daily   (specify time)"
                Write-Host "  2. Hourly"
                Write-Host "  3. At logon"
                $sched = Read-Host "Select"

                $triggerArgs = switch ($sched) {
                    "1" {
                        $t = Read-Host "Run time (HH:mm, e.g. 08:00)"
                        "/SC DAILY /ST $t"
                    }
                    "2" { "/SC HOURLY" }
                    "3" { "/SC ONLOGON" }
                    default { "/SC DAILY /ST 08:00" }
                }

                New-Item -ItemType Directory -Path $SessionExportDir -Force | Out-Null
                $outFile  = "$SessionExportDir\scheduled-$agentName-`$(date /t).md"

                # Build a wrapper ps1 that runs the query and saves output
                $wrapperPath = "$PSScriptRoot\sched-$taskName.ps1"
                $wrapperContent = @"
# Auto-generated by CHAMP AI Scheduler  -  $taskName
`$model  = "$model"
`$prompt = "$prompt"
`$out    = "$SessionExportDir\$taskName-`$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
`$resp   = ollama run `$model `$prompt 2>&1
`$md     = "# Scheduled: $taskName``n**Agent**: $agentName | **Date**: `$(Get-Date)``n``n## Prompt``n`$prompt``n``n## Response``n`$resp"
Set-Content -Path `$out -Value `$md -Encoding UTF8
"@
                Set-Content -Path $wrapperPath -Value $wrapperContent -Encoding UTF8

                $action  = "pwsh.exe -NonInteractive -ExecutionPolicy Bypass -File `"$wrapperPath`""
                $schtask = "schtasks /Create /TN `"$taskName`" /TR `"$action`" $triggerArgs /F"
                Invoke-Expression $schtask

                if ($LASTEXITCODE -eq 0) {
                    Write-OK "Task '$taskName' created."
                    Write-ActivityLog "Scheduled task created: $taskName  agent=$agentName"
                    Play-SuccessSound
                } else {
                    Write-Err "Task creation failed. Try running as Administrator."
                    Play-ErrorSound
                }
                Pause-Menu
            }
            "2" {
                Show-Header
                Write-Info "CHAMP Scheduled Tasks"
                schtasks /Query /FO TABLE 2>$null | Select-String "CHAMP-"
                Pause-Menu
            }
            "3" {
                Show-Header
                $tasks = schtasks /Query /FO CSV 2>$null | ConvertFrom-Csv | Where-Object { $_.TaskName -like "*CHAMP-*" }
                if (-not $tasks) { Write-Warn "No CHAMP tasks found."; Pause-Menu; break }
                $i = 1
                foreach ($t in $tasks) { Write-Host "$i. $($t.TaskName)"; $i++ }
                $sel = Read-Host "Delete task number"
                if ($sel -match '^\d+$') {
                    $idx = [int]$sel - 1
                    $taskArr = @($tasks)
                    if ($idx -ge 0 -and $idx -lt $taskArr.Count) {
                        $tn = $taskArr[$idx].TaskName.Trim('\')
                        schtasks /Delete /TN $tn /F
                        # Clean up wrapper script
                        $wrapper = "$PSScriptRoot\sched-$tn.ps1"
                        if (Test-Path $wrapper) { Remove-Item $wrapper -Force }
                        Write-OK "Deleted: $tn"
                        Write-ActivityLog "Scheduled task deleted: $tn"
                        Play-SuccessSound
                    }
                }
                Pause-Menu
            }
            "4" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "4")
}

# --- I. Multi-Model Comparison ---
function Compare-Models {
    Show-Header
    Write-Info "Multi-Model Comparison"
    Write-Info "----------------------"
    Write-Host "Send the same prompt to 2 or 3 agents and compare responses side-by-side."
    Write-Host ""

    if (-not (Test-OllamaRunning)) {
        Speak-CHAMP "Starting Ollama."
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized
        Start-Sleep -Seconds 2
    }

    $agentList = $Agents.Keys | Sort-Object
    for ($i = 0; $i -lt $agentList.Count; $i++) {
        Write-Host "$($i+1). $($agentList[$i])  [$($Agents[$agentList[$i]].Model)]"
    }
    Write-Host ""
    $selRaw = Read-Host "Select 2 or 3 agents (comma-separated, e.g. 1,2,3)"
    $sels   = $selRaw -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }

    if ($sels.Count -lt 2 -or $sels.Count -gt 3) {
        Write-Warn "Select exactly 2 or 3 agents."; Pause-Menu; return
    }

    $selectedAgents = @()
    foreach ($s in $sels) {
        $idx = [int]$s - 1
        if ($idx -ge 0 -and $idx -lt $agentList.Count) { $selectedAgents += $agentList[$idx] }
    }
    if ($selectedAgents.Count -lt 2) { Write-Warn "Invalid selection."; Pause-Menu; return }

    $prompt = Read-Host "Prompt to send to all agents"
    if ([string]::IsNullOrWhiteSpace($prompt)) { Speak-CHAMP "No prompt."; Pause-Menu; return }

    $save = Read-Host "Save comparison to Markdown? (Enter=yes / N=skip)"

    $results    = @{}
    $timings    = @{}
    $divider    = "=" * 60

    Write-Host ""
    foreach ($agent in $selectedAgents) {
        $model = $Agents[$agent].Model
        Write-Info "Querying $agent ($model) ..."
        $t0        = Get-Date
        $response  = ollama run $model $prompt 2>&1
        $elapsed   = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
        $results[$agent]  = $response
        $timings[$agent]  = $elapsed
        Write-OK "$agent done in ${elapsed}s"
    }

    # Display
    Write-Host ""
    Write-Host $divider -ForegroundColor DarkCyan
    Write-Host "  COMPARISON RESULTS" -ForegroundColor Cyan
    Write-Host $divider -ForegroundColor DarkCyan

    foreach ($agent in $selectedAgents) {
        Write-Host ""
        Write-Host "[ $agent  -  $($Agents[$agent].Model)  -  $($timings[$agent])s ]" -ForegroundColor Yellow
        Write-Host ("-" * 50) -ForegroundColor DarkGray
        Write-Host $results[$agent]
    }

    Write-Host ""
    Write-Host $divider -ForegroundColor DarkCyan

    # Timing summary
    Write-Info "Timing summary:"
    $fastest = $selectedAgents | Sort-Object { $timings[$_] } | Select-Object -First 1
    foreach ($agent in $selectedAgents) {
        $marker = if ($agent -eq $fastest) { " <- fastest" } else { "" }
        Write-Host "  $($agent.PadRight(16)) $($timings[$agent])s$marker"
    }

    # Save to file
    if ($save -ne "N" -and $save -ne "n") {
        New-Item -ItemType Directory -Path $SessionExportDir -Force | Out-Null
        $fname = "$SessionExportDir\comparison-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
        $md    = "# CHAMP AI Model Comparison`n`n**Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n## Prompt`n`n$prompt`n`n## Results`n"
        foreach ($agent in $selectedAgents) {
            $md += "`n### $agent ($($Agents[$agent].Model))  -  $($timings[$agent])s`n`n$($results[$agent])`n"
        }
        Set-Content -Path $fname -Value $md -Encoding UTF8
        Write-OK "Saved: $fname"
        Write-ActivityLog "Model comparison saved: $fname  agents=$($selectedAgents -join ',')"
    }

    Play-SuccessSound
    Pause-Menu
}

# ============================================================
# UI GENERATION STUDIO
# ============================================================

# -----------------------------
# REST API helpers
# -----------------------------
function Invoke-OllamaWithSystem {
    param(
        [string]$Model,
        [string]$SystemPrompt,
        [string]$UserPrompt,
        [int]$TimeoutSec = 180
    )
    if (-not (Test-OllamaRunning)) {
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized
        Start-Sleep -Seconds 3
    }
    $body = @{ model = $Model; prompt = $UserPrompt; system = $SystemPrompt; stream = $false } | ConvertTo-Json -Depth 3
    try {
        $r = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST `
             -Body $body -ContentType "application/json" -TimeoutSec $TimeoutSec -ErrorAction Stop
        return $r.response
    } catch { return $null }
}

function Invoke-OllamaVision {
    param(
        [string]$Model,
        [string]$Prompt,
        [string]$ImagePath,
        [int]$TimeoutSec = 180
    )
    if (-not (Test-Path $ImagePath)) { return $null }
    if (-not (Test-OllamaRunning)) {
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized
        Start-Sleep -Seconds 3
    }
    $bytes  = [System.IO.File]::ReadAllBytes($ImagePath)
    $base64 = [Convert]::ToBase64String($bytes)
    $body   = @{ model = $Model; prompt = $Prompt; images = @($base64); stream = $false } | ConvertTo-Json -Depth 4
    try {
        $r = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST `
             -Body $body -ContentType "application/json" -TimeoutSec $TimeoutSec -ErrorAction Stop
        return $r.response
    } catch { return $null }
}

# Strip markdown code fences models often add despite being told not to
function Remove-CodeFences {
    param([string]$Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { return $Raw }
    $c = $Raw.Trim()
    # Remove opening fence (```html, ```jsx, ```vue, ``` etc.)
    $c = $c -replace '(?s)^```[a-zA-Z]*\r?\n', ''
    # Remove closing fence
    $c = $c -replace '\r?\n```\s*$', ''
    # If fences are still present, extract the largest block
    if ($c -match '(?s)```[a-zA-Z]*\r?\n(.+?)\r?\n```') { $c = $matches[1] }
    return $c.Trim()
}

# -----------------------------
# Framework system prompts
# -----------------------------
$UISystemPrompts = @{
    "html" = @"
You are an expert frontend developer. Generate a complete, self-contained HTML file.
STRICT RULES:
- Use Tailwind CSS via CDN: <script src="https://cdn.tailwindcss.com"></script>
- Output ONLY raw HTML starting with <!DOCTYPE html> and ending with </html>
- Do NOT include markdown code fences, explanations, or any text outside the HTML
- Design must be modern, polished, responsive, and visually impressive
- Use a dark or clean light color palette with good contrast
- Include hover states, transitions, and realistic placeholder content
"@
    "react" = @"
You are an expert React developer. Generate a complete React functional component using Tailwind CSS.
STRICT RULES:
- Output ONLY the component code  -  no explanations, no markdown fences
- Start with import statements, end with export default
- Use only React and standard browser APIs (no external UI libs)
- Use Tailwind CSS classes for all styling
- Include useState/useEffect where appropriate
- Use realistic placeholder data and polished UI
"@
    "vue" = @"
You are an expert Vue 3 developer. Generate a complete single-file Vue component (.vue).
STRICT RULES:
- Output ONLY the .vue file content  -  no markdown fences, no explanations
- Use <template>, <script setup>, and <style scoped> sections
- Use Tailwind CSS for styling (assume it is configured)
- Use Composition API with <script setup>
- Include realistic placeholder data and polished UI
"@
}

# -----------------------------
# Live Preview Server
# -----------------------------
function Start-LivePreviewServer {
    Show-Header
    Write-Info "Live Preview Server  -  http://localhost:$Global:PreviewPort"
    Write-Host ""

    # Check if already listening
    $listening = netstat -ano 2>$null | Select-String ":$Global:PreviewPort\s"
    if ($listening) {
        Write-OK "Preview server already running on port $Global:PreviewPort"
        $open = Read-Host "Open in browser? (Enter=yes / N=skip)"
        if ($open -ne "N" -and $open -ne "n") { Start-Process "http://localhost:$Global:PreviewPort" }
        Pause-Menu; return
    }

    New-Item -ItemType Directory -Path "$PSScriptRoot\CHAMP-Sessions" -Force | Out-Null
    $previewFile = $Global:PreviewFile
    $port        = $Global:PreviewPort

    # Build the server script as a base64-encoded command so it survives quoting
    $serverCode = @"
`$port = $port
`$file = '$previewFile'
`$listener = New-Object System.Net.HttpListener
`$listener.Prefixes.Add("http://localhost:`$port/")
`$listener.Start()
Write-Host "CHAMP Preview Server on http://localhost:`$port  (close this window to stop)"
while (`$listener.IsListening) {
    try {
        `$ctx = `$listener.GetContext()
        if (Test-Path `$file) {
            `$html = Get-Content `$file -Raw -Encoding UTF8
            `$inject = '<script>setInterval(()=>{fetch(location.href).then(r=>r.text()).then(t=>{if(t!==document.documentElement.outerHTML)location.reload()})},1500)</script>'
            `$html = `$html -replace '</body>',"`$inject</body>"
        } else {
            `$html = '<!DOCTYPE html><html><head><meta charset=UTF-8><script src=https://cdn.tailwindcss.com></script></head><body class="bg-gray-950 text-gray-400 flex items-center justify-center h-screen flex-col gap-4"><div class="text-5xl">⚡</div><h1 class="text-2xl font-bold text-white">CHAMP AI Preview</h1><p>Waiting for UI generation...</p><script>setInterval(()=>location.reload(),2000)</script></body></html>'
        }
        `$bytes = [System.Text.Encoding]::UTF8.GetBytes(`$html)
        `$ctx.Response.ContentType = "text/html; charset=utf-8"
        `$ctx.Response.ContentLength64 = `$bytes.Length
        `$ctx.Response.OutputStream.Write(`$bytes, 0, `$bytes.Length)
        `$ctx.Response.OutputStream.Close()
    } catch {}
}
"@
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($serverCode))
    Start-Process pwsh -ArgumentList "-NoProfile -WindowStyle Minimized -EncodedCommand $encoded"
    Start-Sleep -Milliseconds 800

    Write-OK "Preview server started on http://localhost:$port"
    Write-Host "The server window runs minimized. Close it to stop the server." -ForegroundColor DarkGray
    Write-Host ""
    Start-Process "http://localhost:$port"
    Write-ActivityLog "Live Preview Server started on port $port"
    Play-SuccessSound
    Pause-Menu
}

function Stop-LivePreviewServer {
    Show-Header
    # Find and kill the pwsh process listening on the preview port
    $pid = netstat -ano 2>$null | Select-String ":$Global:PreviewPort\s" | ForEach-Object {
        if ($_ -match '\s(\d+)$') { $matches[1] }
    } | Select-Object -First 1

    if ($pid) {
        Stop-Process -Id ([int]$pid) -Force -ErrorAction SilentlyContinue
        Write-OK "Preview server stopped."
        Write-ActivityLog "Live Preview Server stopped"
        Play-SuccessSound
    } else {
        Write-Warn "No preview server found running on port $Global:PreviewPort"
    }
    Pause-Menu
}

# -----------------------------
# UI Code Generator
# -----------------------------
function New-UIGeneration {
    param([string]$InitialPrompt = "")
    Show-Header
    Write-Info "UI Code Generator"
    Write-Info "-----------------"
    Write-Host ""

    if (-not (Test-CommandExists "ollama")) { Speak-CHAMP "Ollama not found."; Play-ErrorSound; Pause-Menu; return }

    # Framework selection
    Write-Host "Framework:"
    Write-Host "  1. HTML + Tailwind CSS    (opens directly in browser, easiest)"
    Write-Host "  2. React component        (JSX  -  paste into your project)"
    Write-Host "  3. Vue 3 component        (.vue SFC)"
    $fsel = Read-Host "Select framework (Enter for HTML)"
    $framework = switch ($fsel) {
        "2" { "react" }
        "3" { "vue" }
        default { "html" }
    }
    $Global:LastGeneratedFramework = $framework

    # Model selection  -  Forge is best for code
    $model = $Agents["Forge"].Model
    Write-Host ""
    Write-Host "Using Forge ($model) for generation"
    Write-Host ""

    $prompt = if (-not [string]::IsNullOrWhiteSpace($InitialPrompt)) { $InitialPrompt } else {
        Read-Host "Describe the UI you want to build"
    }
    if ([string]::IsNullOrWhiteSpace($prompt)) { Speak-CHAMP "No prompt."; Pause-Menu; return }

    Write-Host ""
    Write-Info "Generating $framework UI via Forge..."
    $startTime = Get-Date
    $raw = Invoke-OllamaWithSystem -Model $model -SystemPrompt $UISystemPrompts[$framework] -UserPrompt $prompt -TimeoutSec 240

    if (-not $raw) { Write-Err "Generation failed. Is Ollama running and Forge model pulled?"; Play-ErrorSound; Pause-Menu; return }

    $code    = Remove-CodeFences $raw
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
    $Global:LastGeneratedCode = $code

    # Save
    New-Item -ItemType Directory -Path "$PSScriptRoot\CHAMP-Sessions" -Force | Out-Null
    $ext      = if ($framework -eq "react") { "jsx" } elseif ($framework -eq "vue") { "vue" } else { "html" }
    $outFile  = "$PSScriptRoot\CHAMP-Sessions\ui-$(Get-Date -Format 'yyyyMMdd-HHmmss').$ext"

    Set-Content -Path $outFile -Value $code -Encoding UTF8

    # Also write to the live preview file (HTML only for instant preview)
    if ($framework -eq "html") {
        Set-Content -Path $Global:PreviewFile -Value $code -Encoding UTF8
    }

    Write-OK "Generated in ${elapsed}s  -  saved to: $outFile"
    Write-ActivityLog "UI generated: $framework  prompt='$prompt'  file=$outFile"

    # Open options
    Write-Host ""
    Write-Host "1. Open in browser now    (HTML only)"
    Write-Host "2. Open in VS Code"
    Write-Host "3. Open Live Preview      (auto-refreshes on each generation)"
    Write-Host "4. Continue to Refine     (iterative loop)"
    Write-Host "5. Done"
    $action = Read-Host "Action"
    switch ($action) {
        "1" {
            if ($framework -eq "html") { Start-Process $outFile }
            else { Write-Warn "$framework files need a dev server to preview." }
        }
        "2" { if (Test-CommandExists "code") { code $outFile } else { Start-Process notepad $outFile } }
        "3" {
            # Start server if not running
            $listening = netstat -ano 2>$null | Select-String ":$Global:PreviewPort\s"
            if (-not $listening) {
                if ($framework -eq "html") {
                    $enc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes(
                        "`$l=New-Object System.Net.HttpListener;`$l.Prefixes.Add('http://localhost:$Global:PreviewPort/');`$l.Start();Write-Host 'Preview on port $Global:PreviewPort';while(`$l.IsListening){try{`$c=`$l.GetContext();`$h=Get-Content '$Global:PreviewFile' -Raw -Encoding UTF8;`$inj='<script>setInterval(()=>{fetch(location.href).then(r=>r.text()).then(t=>{if(t!==document.documentElement.outerHTML)location.reload()})},1500)</script>';`$h=`$h -replace '</body>',`"`$inj</body>`";`$b=[System.Text.Encoding]::UTF8.GetBytes(`$h);`$c.Response.ContentType='text/html; charset=utf-8';`$c.Response.ContentLength64=`$b.Length;`$c.Response.OutputStream.Write(`$b,0,`$b.Length);`$c.Response.OutputStream.Close()}catch{}}"
                    ))
                    Start-Process pwsh -ArgumentList "-NoProfile -WindowStyle Minimized -EncodedCommand $enc"
                    Start-Sleep -Milliseconds 600
                }
            }
            Start-Process "http://localhost:$Global:PreviewPort"
        }
        "4" { Invoke-RefinementLoop }
    }

    Play-SuccessSound
    Pause-Menu
}

# -----------------------------
# Iterative Refinement Loop
# -----------------------------
function Invoke-RefinementLoop {
    Show-Header
    Write-Info "Iterative Refinement Loop"
    Write-Info "-------------------------"

    if ([string]::IsNullOrWhiteSpace($Global:LastGeneratedCode)) {
        Write-Warn "No previous generation found. Run UI Code Generator first."
        Pause-Menu; return
    }

    $model     = $Agents["Forge"].Model
    $framework = $Global:LastGeneratedFramework
    $code      = $Global:LastGeneratedCode
    $iteration = 1

    Write-OK "Loaded last $framework generation ($([math]::Round($code.Length/1KB,1)) KB)"
    Write-Host "Type a refinement instruction at each step. Type 'done' to finish." -ForegroundColor DarkGray
    Write-Host ""

    do {
        Write-Host "[$iteration] Refinement" -ForegroundColor Yellow
        $refinement = Read-Host "Instruction (or 'done')"
        if ($refinement -eq "done" -or [string]::IsNullOrWhiteSpace($refinement)) { break }

        # Keep code under ~6000 chars to avoid context overflow on 7B models
        $codeSnippet = if ($code.Length -gt 6000) { $code.Substring(0, 6000) + "`n... (truncated)" } else { $code }

        $refinementPrompt = @"
Here is the current $framework code:

$codeSnippet

User request: $refinement

Return the complete updated $framework code only. Apply the change precisely. Do not explain anything.
"@
        Write-Info "Refining..."
        $startTime = Get-Date
        $raw = Invoke-OllamaWithSystem -Model $model -SystemPrompt $UISystemPrompts[$framework] -UserPrompt $refinementPrompt -TimeoutSec 240

        if (-not $raw) { Write-Err "Refinement failed."; Play-ErrorSound; continue }

        $code    = Remove-CodeFences $raw
        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
        $Global:LastGeneratedCode = $code

        # Save and update preview
        New-Item -ItemType Directory -Path "$PSScriptRoot\CHAMP-Sessions" -Force | Out-Null
        $ext     = if ($framework -eq "react") { "jsx" } elseif ($framework -eq "vue") { "vue" } else { "html" }
        $outFile = "$PSScriptRoot\CHAMP-Sessions\ui-refine-$iteration-$(Get-Date -Format 'HHmmss').$ext"
        Set-Content -Path $outFile -Value $code -Encoding UTF8
        if ($framework -eq "html") { Set-Content -Path $Global:PreviewFile -Value $code -Encoding UTF8 }

        Write-OK "Iteration $iteration done in ${elapsed}s  -  saved: $outFile"
        Write-ActivityLog "UI refined: iteration $iteration  instruction='$refinement'"
        Play-SuccessSound
        $iteration++

    } while ($true)

    Write-Host ""
    Write-OK "Refinement complete. Final version: $([math]::Round($Global:LastGeneratedCode.Length/1KB,1)) KB"

    $open = Read-Host "Open final file in VS Code? (Enter=yes / N=skip)"
    if ($open -ne "N" -and $open -ne "n") {
        if (Test-CommandExists "code") { code $outFile } else { Start-Process notepad $outFile }
    }
    Pause-Menu
}

# -----------------------------
# Scout Vision Agent
# -----------------------------
function Activate-Scout {
    Show-Header
    Write-Info "Scout  -  Vision Agent  (llava:7b)"
    Write-Info "--------------------------------"
    Write-Host ""

    $model = $Agents["Scout"].Model

    # Check model is pulled
    $modelList = ollama list 2>&1
    if ($modelList -notmatch [regex]::Escape($model.Split(":")[0])) {
        Write-Warn "Scout model '$model' is not installed."
        $pull = Read-Host "Pull it now? (~4.5 GB) (Enter=yes / N=cancel)"
        if ($pull -eq "N" -or $pull -eq "n") { Pause-Menu; return }
        Write-Info "Pulling $model ..."
        ollama pull $model
        if ($LASTEXITCODE -ne 0) { Write-Err "Pull failed."; Play-ErrorSound; Pause-Menu; return }
        Send-ToastNotification "CHAMP AI" "Scout (llava:7b) ready."
    }

    if (-not (Test-OllamaRunning)) {
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Minimized; Start-Sleep 3
    }

    Write-Host "Scout modes:"
    Write-Host "  1. Describe an image"
    Write-Host "  2. Convert screenshot to HTML + Tailwind UI"
    Write-Host "  3. Analyse a diagram or chart"
    Write-Host "  4. Ask any question about an image"
    Write-Host "  5. Back"
    Write-Host ""
    $mode = Read-Host "Select mode"
    if ($mode -eq "5") { return }

    $imagePath = Read-Host "Image file path (full path, e.g. C:\Users\you\screenshot.png)"
    if (-not (Test-Path $imagePath)) { Write-Err "File not found: $imagePath"; Play-ErrorSound; Pause-Menu; return }

    $ext = [System.IO.Path]::GetExtension($imagePath).ToLower()
    if ($ext -notin @(".png",".jpg",".jpeg",".gif",".bmp",".webp")) {
        Write-Err "Unsupported image format. Use PNG, JPG, JPEG, GIF, BMP, or WEBP."
        Play-ErrorSound; Pause-Menu; return
    }

    $prompt = switch ($mode) {
        "1" { "Describe this image in detail. Include layout, colors, content, and any text visible." }
        "2" { "Convert this UI screenshot into a complete, self-contained HTML file using Tailwind CSS via CDN. Recreate the layout, colors, typography, and structure as accurately as possible. Output ONLY the raw HTML starting with <!DOCTYPE html>." }
        "3" { "Analyse this diagram or chart. Explain what it shows, identify key data points, trends, or relationships, and summarise the main insight." }
        "4" {
            $q = Read-Host "Your question about the image"
            if ([string]::IsNullOrWhiteSpace($q)) { "Describe what you see in this image." } else { $q }
        }
        default { "Describe this image." }
    }

    Write-Host ""
    Write-Info "Scout is analysing the image..."
    $startTime = Get-Date
    $response  = Invoke-OllamaVision -Model $model -Prompt $prompt -ImagePath $imagePath -TimeoutSec 300

    if (-not $response) { Write-Err "Vision query failed. Ensure llava:7b is pulled and Ollama is running."; Play-ErrorSound; Pause-Menu; return }

    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
    $code    = Remove-CodeFences $response

    Write-Host ""
    Write-Info "--- Scout Response (${elapsed}s) ---"
    Write-Host $code
    Write-Info "--- end ---"

    # If mode 2, save as HTML and offer preview
    if ($mode -eq "2") {
        New-Item -ItemType Directory -Path "$PSScriptRoot\CHAMP-Sessions" -Force | Out-Null
        $outFile = "$PSScriptRoot\CHAMP-Sessions\scout-ui-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
        Set-Content -Path $outFile -Value $code -Encoding UTF8
        Set-Content -Path $Global:PreviewFile -Value $code -Encoding UTF8
        $Global:LastGeneratedCode      = $code
        $Global:LastGeneratedFramework = "html"
        Write-OK "Saved: $outFile"

        $open = Read-Host "Open in browser? (Enter=yes / N=skip)"
        if ($open -ne "N" -and $open -ne "n") { Start-Process $outFile }

        $refine = Read-Host "Refine it further? (Enter=yes / N=skip)"
        if ($refine -ne "N" -and $refine -ne "n") { Invoke-RefinementLoop }
    } else {
        # Save response as markdown
        $outFile = "$PSScriptRoot\CHAMP-Sessions\scout-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
        $md = "# Scout Vision Analysis`n`n**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  |  **Elapsed:** ${elapsed}s`n`n**Image:** $imagePath`n`n---`n`n$response"
        Set-Content -Path $outFile -Value $md -Encoding UTF8
        Write-OK "Saved: $outFile"

        $open = Read-Host "Open in VS Code? (Enter=yes / N=skip)"
        if ($open -ne "N" -and $open -ne "n") {
            if (Test-CommandExists "code") { code $outFile } else { Start-Process notepad $outFile }
        }
    }

    Write-ActivityLog "Scout vision: mode=$mode  image=$imagePath  elapsed=${elapsed}s"
    Play-SuccessSound
    Pause-Menu
}

# UI Generation Studio menu
function Show-UIStudioMenu {
    Show-Header
    Write-Info "UI Generation Studio"
    Write-Info "--------------------"
    Write-Host "1. Generate UI            (prompt → HTML / React / Vue)"
    Write-Host "2. Refine Last Generation (iterative loop)"
    Write-Host "3. Scout Vision Agent     (image describe / screenshot → UI)"
    Write-Host "4. Start Live Preview     (auto-refresh server on port $Global:PreviewPort)"
    Write-Host "5. Stop Live Preview"
    Write-Host "6. Open Preview in Browser"
    Write-Host "7. Back"
    Write-Host ""
    if ($Global:LastGeneratedCode) {
        Write-Host "Last generation: $Global:LastGeneratedFramework  $([math]::Round($Global:LastGeneratedCode.Length/1KB,1)) KB" -ForegroundColor DarkGray
    }
}

function UIStudio-Menu {
    do {
        Show-UIStudioMenu
        $choice = Read-Host "Select"
        switch ($choice) {
            "1" { New-UIGeneration }
            "2" { Invoke-RefinementLoop }
            "3" { Activate-Scout }
            "4" { Start-LivePreviewServer }
            "5" { Stop-LivePreviewServer }
            "6" {
                $listening = netstat -ano 2>$null | Select-String ":$Global:PreviewPort\s"
                if ($listening) { Start-Process "http://localhost:$Global:PreviewPort" }
                else { Write-Warn "Preview server is not running. Start it first (option 4)."; Pause-Menu }
            }
            "7" { return }
            default { Speak-CHAMP "Invalid selection."; Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "7")
}

# -----------------------------
# AI Dev Tools Menu
# -----------------------------
function Show-AIDevMenu {
    Show-Header
    Write-Info "AI Development Tools"
    Write-Info "--------------------"
    Write-Host "--- Core Tools ---" -ForegroundColor DarkGray
    Write-Host "1.  GPU / Hardware Monitor"
    Write-Host "2.  Modelfile Creator         (build custom agent with system prompt)"
    Write-Host "3.  Model Benchmark           (latency + tokens/sec)"
    Write-Host "4.  Prompt Library            (save & reuse prompts)"
    Write-Host "5.  Agent Chain Pipeline      (A -> B response routing)"
    Write-Host "6.  Multi-Model Comparison    (same prompt, multiple agents)"
    Write-Host "7.  Session Export            (save response to .md / .txt)"
    Write-Host ""
    Write-Host "--- Environment ---" -ForegroundColor DarkGray
    Write-Host "8.  Python AI Env Wizard      (venv + AI packages)"
    Write-Host "9.  Jupyter Launcher"
    Write-Host "10. Docker Compose Generator  (full AI stack)"
    Write-Host "11. Windows Terminal Profile  (install CHAMP AI tab)"
    Write-Host ""
    Write-Host "--- Models & APIs ---" -ForegroundColor DarkGray
    Write-Host "12. Ollama Model Search       (browse & pull from library)"
    Write-Host "13. Model Disk Manager        (list sizes, delete models)"
    Write-Host "14. RAM / VRAM Advisor        (check model compatibility)"
    Write-Host "15. Ollama REST API Tester"
    Write-Host "16. AI Services Port Dashboard"
    Write-Host "17. API Key Manager           (.env)"
    Write-Host ""
    Write-Host "--- Data & Scheduling ---" -ForegroundColor DarkGray
    Write-Host "18. Backup & Restore"
    Write-Host "19. Scheduled Agent Queries   (Windows Task Scheduler)"
    Write-Host ""
    Write-Host "--- UI Generation ---" -ForegroundColor DarkGray
    Write-Host "20. UI Generation Studio" -ForegroundColor Cyan
    Write-Host "    Generate UI, live preview, refine, Scout vision" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "21. Back"
}

function AIDevTools-Menu {
    do {
        Show-AIDevMenu
        $choice = Read-Host "Select"
        switch ($choice) {
            "1"  { Show-HardwareMonitor }
            "2"  { New-AgentModelfile }
            "3"  { Benchmark-Model }
            "4"  { Manage-PromptLibrary }
            "5"  { Run-AgentChain }
            "6"  { Compare-Models }
            "7"  { Export-AgentSession }
            "8"  { Setup-PythonAIEnv }
            "9"  { Launch-Jupyter }
            "10" { New-DockerComposeStack }
            "11" { Install-WindowsTerminalProfile }
            "12" { Search-OllamaModels }
            "13" { Manage-ModelDisk }
            "14" { Show-ModelAdvisor }
            "15" { Test-OllamaAPI }
            "16" { Show-PortDashboard }
            "17" { Manage-APIKeys }
            "18" { Backup-Menu }
            "19" { Manage-ScheduledQueries }
            "20" { UIStudio-Menu }
            "21" { return }
            default { Speak-CHAMP "Invalid selection."; Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "21")
}

# ============================================================
# DEVOPS CONTROL PANEL
# ============================================================

$DevOpsConfigPath = "$PSScriptRoot\.devops-config.json"

function Get-DevOpsConfig {
    if (Test-Path $DevOpsConfigPath) {
        try { return Get-Content $DevOpsConfigPath -Raw | ConvertFrom-Json -AsHashtable }
        catch { return @{} }
    }
    return @{}
}

function Save-DevOpsConfig {
    param([hashtable]$Config)
    $Config | ConvertTo-Json -Depth 4 | Set-Content $DevOpsConfigPath -Encoding UTF8
}

function Get-EnvValue {
    param([string]$Key)
    if (Test-Path $EnvFilePath) {
        $line = Get-Content $EnvFilePath | Where-Object { $_ -match "^$Key=" } | Select-Object -First 1
        if ($line) { return ($line -split "=", 2)[1].Trim() }
    }
    return $null
}

function Set-EnvValue {
    param([string]$Key, [string]$Value)
    $lines = @()
    if (Test-Path $EnvFilePath) {
        $lines = Get-Content $EnvFilePath | Where-Object { $_ -notmatch "^$Key=" }
    }
    $lines += "$Key=$Value"
    Set-Content $EnvFilePath -Value $lines -Encoding UTF8
}

# ============================================================
# PROXMOX
# ============================================================

function Invoke-ProxmoxAPI {
    param(
        [string]$Endpoint,
        [string]$Method = "GET",
        [hashtable]$Body = @{}
    )
    $cfg     = Get-DevOpsConfig
    $host    = $cfg["PVE_HOST"]
    $tokenId = Get-EnvValue "PVE_TOKEN_ID"
    $secret  = Get-EnvValue "PVE_TOKEN_SECRET"

    if (-not $host -or -not $tokenId -or -not $secret) {
        Write-Err "Proxmox not configured. Run Proxmox Setup first."
        return $null
    }

    $uri     = "https://${host}:8006/api2/json$Endpoint"
    $headers = @{ Authorization = "PVEAPIToken=${tokenId}=${secret}" }

    try {
        if ($Method -eq "GET") {
            $r = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET -SkipCertificateCheck -TimeoutSec 15 -ErrorAction Stop
        } else {
            $r = Invoke-RestMethod -Uri $uri -Headers $headers -Method $Method -Body $Body `
                 -SkipCertificateCheck -TimeoutSec 30 -ErrorAction Stop
        }
        return $r.data
    } catch {
        Write-Err "Proxmox API error: $($_.Exception.Message)"
        return $null
    }
}

function Setup-Proxmox {
    Show-Header
    Write-Info "Proxmox Setup"
    Write-Info "-------------"
    Write-Host "You need a Proxmox API token: Datacenter → Permissions → API Tokens"
    Write-Host ""
    $cfg = Get-DevOpsConfig

    $host = Read-Host "Proxmox host/IP (e.g. 192.168.1.10)"
    if ([string]::IsNullOrWhiteSpace($host)) { Pause-Menu; return }
    $cfg["PVE_HOST"] = $host

    $tokenId = Read-Host "Token ID (format: user@realm!tokenname, e.g. root@pam!champ)"
    Set-EnvValue "PVE_TOKEN_ID" $tokenId

    $secret = Read-Host "Token Secret (UUID)"
    Set-EnvValue "PVE_TOKEN_SECRET" $secret

    Save-DevOpsConfig $cfg
    Write-OK "Proxmox config saved. Testing connection..."

    $nodes = Invoke-ProxmoxAPI "/nodes"
    if ($nodes) { Write-OK "Connected! Found $($nodes.Count) node(s)."; Play-SuccessSound }
    else { Write-Err "Connection failed. Check host, token ID, and secret."; Play-ErrorSound }
    Pause-Menu
}

function Show-ProxmoxDashboard {
    Show-Header
    Write-Info "Proxmox Dashboard"
    Write-Info "-----------------"

    $nodes = Invoke-ProxmoxAPI "/nodes"
    if (-not $nodes) { Pause-Menu; return }

    foreach ($node in $nodes) {
        $cpuPct  = [math]::Round($node.cpu * 100, 1)
        $ramGB   = [math]::Round($node.mem / 1GB, 1)
        $maxRAM  = [math]::Round($node.maxmem / 1GB, 1)
        $diskGB  = [math]::Round($node.disk / 1GB, 1)
        $maxDisk = [math]::Round($node.maxdisk / 1GB, 1)
        $upDays  = [math]::Round($node.uptime / 86400, 1)

        Write-Host ""
        Write-Host "Node: $($node.node)" -ForegroundColor Yellow
        if ($node.status -eq "online") { Write-OK  "  Status : $($node.status)  (up $upDays days)" }
        else                            { Write-Err "  Status : $($node.status)" }
        if ($cpuPct -gt 80) { Write-Warn "  CPU    : $cpuPct%" } else { Write-OK "  CPU    : $cpuPct%" }
        Write-Host "  RAM    : $ramGB GB / $maxRAM GB"
        Write-Host "  Disk   : $diskGB GB / $maxDisk GB"
    }
    Pause-Menu
}

function Show-ProxmoxVMs {
    Show-Header
    Write-Info "Proxmox VMs & Containers"
    Write-Info "------------------------"

    $nodes = Invoke-ProxmoxAPI "/nodes"
    if (-not $nodes) { Pause-Menu; return }

    $allVMs = @()
    foreach ($node in $nodes) {
        $vms = Invoke-ProxmoxAPI "/nodes/$($node.node)/qemu"
        $cts = Invoke-ProxmoxAPI "/nodes/$($node.node)/lxc"
        if ($vms) { $vms | ForEach-Object { $_ | Add-Member -NotePropertyName node -NotePropertyValue $node.node -Force; $_ | Add-Member -NotePropertyName type -NotePropertyValue "VM" -Force; $allVMs += $_ } }
        if ($cts) { $cts | ForEach-Object { $_ | Add-Member -NotePropertyName node -NotePropertyValue $node.node -Force; $_ | Add-Member -NotePropertyName type -NotePropertyValue "CT" -Force; $allVMs += $_ } }
    }

    if (-not $allVMs) { Write-Warn "No VMs or containers found."; Pause-Menu; return }

    $i = 1
    foreach ($vm in $allVMs | Sort-Object vmid) {
        $ramMB = if ($vm.mem) { [math]::Round($vm.mem / 1MB, 0) } else { 0 }
        $cpuPct = if ($vm.cpu) { [math]::Round($vm.cpu * 100, 1) } else { 0 }
        $statusColor = if ($vm.status -eq "running") { "Green" } else { "DarkGray" }
        Write-Host "$i. [$($vm.type)] " -NoNewline
        Write-Host "$($vm.vmid.ToString().PadRight(6))" -NoNewline -ForegroundColor Cyan
        Write-Host "$($vm.name.PadRight(25))" -NoNewline
        Write-Host "$($vm.status.PadRight(12))" -NoNewline -ForegroundColor $statusColor
        Write-Host "Node: $($vm.node)  CPU: $cpuPct%  RAM: $ramMB MB"
        $i++
    }

    Write-Host ""
    Write-Host "Actions: S=Start  X=Stop  R=Reboot  N=Snapshot  B=Back"
    $action = Read-Host "Action (or Enter to go back)"
    if ([string]::IsNullOrWhiteSpace($action) -or $action -eq "B" -or $action -eq "b") { return }

    $vmIdx = Read-Host "VM/CT number"
    if (-not ($vmIdx -match '^\d+$')) { return }
    $target = $allVMs[([int]$vmIdx - 1)]
    if (-not $target) { Write-Err "Invalid selection."; Pause-Menu; return }

    $vmType = if ($target.type -eq "VM") { "qemu" } else { "lxc" }

    switch ($action.ToUpper()) {
        "S" {
            Invoke-ProxmoxAPI "/nodes/$($target.node)/$vmType/$($target.vmid)/status/start" -Method POST
            Write-OK "Start command sent for $($target.name)"
            Write-ActivityLog "Proxmox: started $($target.type) $($target.vmid) $($target.name)"
        }
        "X" {
            $confirm = Read-Host "Stop $($target.name)? (YES)"
            if ($confirm -eq "YES") {
                Invoke-ProxmoxAPI "/nodes/$($target.node)/$vmType/$($target.vmid)/status/stop" -Method POST
                Write-OK "Stop command sent."
                Write-ActivityLog "Proxmox: stopped $($target.type) $($target.vmid) $($target.name)"
            }
        }
        "R" {
            Invoke-ProxmoxAPI "/nodes/$($target.node)/$vmType/$($target.vmid)/status/reboot" -Method POST
            Write-OK "Reboot command sent for $($target.name)"
            Write-ActivityLog "Proxmox: rebooted $($target.type) $($target.vmid) $($target.name)"
        }
        "N" {
            $snapName = Read-Host "Snapshot name"
            $snapDesc = Read-Host "Description (optional)"
            Invoke-ProxmoxAPI "/nodes/$($target.node)/$vmType/$($target.vmid)/snapshot" -Method POST `
                -Body @{ snapname = $snapName; description = $snapDesc }
            Write-OK "Snapshot '$snapName' queued for $($target.name)"
            Write-ActivityLog "Proxmox: snapshot $snapName on $($target.vmid)"
        }
    }
    Play-SuccessSound
    Pause-Menu
}

function Show-ProxmoxStorage {
    Show-Header
    Write-Info "Proxmox Storage"
    Write-Info "---------------"
    $nodes = Invoke-ProxmoxAPI "/nodes"
    if (-not $nodes) { Pause-Menu; return }
    foreach ($node in $nodes) {
        Write-Host "Node: $($node.node)" -ForegroundColor Yellow
        $storages = Invoke-ProxmoxAPI "/nodes/$($node.node)/storage"
        if ($storages) {
            foreach ($s in $storages) {
                $usedGB  = [math]::Round($s.used  / 1GB, 1)
                $totalGB = [math]::Round($s.total / 1GB, 1)
                $pct     = if ($s.total -gt 0) { [math]::Round(($s.used / $s.total) * 100, 0) } else { 0 }
                $line    = "  $($s.storage.PadRight(20)) $($s.type.PadRight(10)) $usedGB GB / $totalGB GB  ($pct%)"
                if ($pct -gt 85) { Write-Warn $line } else { Write-OK $line }
            }
        }
    }
    Pause-Menu
}

function Invoke-ProxmoxAI {
    Show-Header
    Write-Info "Proxmox AI Assistant"
    Write-Host ""
    Write-Host "Ask Professor-X about your infrastructure or have Forge generate configs."
    Write-Host ""
    Write-Host "1. Ask Professor-X about Proxmox architecture / planning"
    Write-Host "2. Forge generates a cloud-init config"
    Write-Host "3. Forge generates a Terraform Proxmox provider block"
    Write-Host "4. Back"
    $choice = Read-Host "Select"
    switch ($choice) {
        "1" {
            $q = Read-Host "Your Proxmox question"
            $system = "You are a Proxmox VE expert. Answer concisely and accurately about Proxmox hypervisor, clusters, VMs, LXC containers, storage, networking, and high availability."
            $r = Invoke-OllamaWithSystem -Model $Agents["Professor-X"].Model -SystemPrompt $system -UserPrompt $q
            Write-Host ""; Write-Host $r
        }
        "2" {
            $desc = Read-Host "Describe the server role (e.g. 'Ubuntu 22.04 Docker host with 4 vCPUs, 8GB RAM')"
            $system = "You are a DevOps expert. Generate a complete Proxmox cloud-init YAML config. Output only the YAML, no explanations."
            $r = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model -SystemPrompt $system -UserPrompt "Generate cloud-init config for: $desc"
            $r = Remove-CodeFences $r
            $out = "$PSScriptRoot\CHAMP-Sessions\cloud-init-$(Get-Date -Format 'yyyyMMdd-HHmmss').yaml"
            Set-Content $out -Value $r -Encoding UTF8
            Write-Host ""; Write-Host $r; Write-OK "Saved: $out"
        }
        "3" {
            $cfg = Get-DevOpsConfig
            $pveHost = if ($cfg["PVE_HOST"]) { $cfg["PVE_HOST"] } else { "YOUR_PROXMOX_IP" }
            $system = "You are a Terraform and Proxmox expert. Generate a complete Terraform configuration using the bpg/proxmox provider. Output only HCL, no explanations."
            $desc = Read-Host "Describe the VM to provision"
            $r = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model -SystemPrompt $system `
                 -UserPrompt "Proxmox host: $pveHost. Generate Terraform HCL to create: $desc"
            $r = Remove-CodeFences $r
            $out = "$PSScriptRoot\CHAMP-Sessions\proxmox-tf-$(Get-Date -Format 'yyyyMMdd-HHmmss').tf"
            Set-Content $out -Value $r -Encoding UTF8
            Write-Host ""; Write-Host $r; Write-OK "Saved: $out"
        }
        "4" { return }
    }
    Play-SuccessSound
    Pause-Menu
}

function Proxmox-Menu {
    do {
        Show-Header
        Write-Info "Proxmox Control"
        Write-Info "---------------"
        Write-Host "1. Dashboard        (nodes, CPU, RAM, disk)"
        Write-Host "2. VMs & Containers (list, start, stop, reboot, snapshot)"
        Write-Host "3. Storage          (usage per node)"
        Write-Host "4. AI Assistant     (Professor-X plans, Forge generates configs)"
        Write-Host "5. Setup / Reconfigure"
        Write-Host "6. Back"
        $c = Read-Host "Select"
        switch ($c) {
            "1" { Show-ProxmoxDashboard }
            "2" { Show-ProxmoxVMs }
            "3" { Show-ProxmoxStorage }
            "4" { Invoke-ProxmoxAI }
            "5" { Setup-Proxmox }
            "6" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "6")
}

# ============================================================
# GITHUB
# ============================================================

function Test-GitHubCLI { return [bool](Get-Command "gh" -ErrorAction SilentlyContinue) }

function Assert-GitHubAuth {
    if (-not (Test-GitHubCLI)) {
        Write-Err "GitHub CLI (gh) not found. Install from https://cli.github.com"
        return $false
    }
    $status = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Not authenticated. Run: gh auth login"
        $login = Read-Host "Run gh auth login now? (Enter=yes / N=skip)"
        if ($login -ne "N" -and $login -ne "n") { gh auth login }
        return $false
    }
    return $true
}

function Show-GitHubRepos {
    Show-Header
    Write-Info "GitHub Repositories"
    Write-Info "-------------------"
    if (-not (Assert-GitHubAuth)) { Pause-Menu; return }

    $limit = Read-Host "How many repos to show (Enter for 20)"
    if (-not ($limit -match '^\d+$')) { $limit = "20" }

    gh repo list --limit $limit --json name,description,language,isPrivate,updatedAt `
        --template '{{range .}}{{.name | printf "%-35s"}} {{if .isPrivate}}[private]{{else}}[public] {{end}} {{.language | printf "%-15s"}} {{.updatedAt | timeago}}{{"\n"}}{{end}}'
    Write-Host ""
    $action = Read-Host "C=Clone  V=View  B=Back"
    switch ($action.ToUpper()) {
        "C" {
            $repo = Read-Host "Repo name or owner/repo"
            $dest = Read-Host "Clone to (Enter for current dir)"
            if ([string]::IsNullOrWhiteSpace($dest)) { gh repo clone $repo } else { gh repo clone $repo $dest }
            Write-ActivityLog "GitHub: cloned $repo"
            Play-SuccessSound
        }
        "V" {
            $repo = Read-Host "Repo name to open in browser"
            gh repo view $repo --web
        }
    }
    Pause-Menu
}

function Show-GitHubIssues {
    Show-Header
    Write-Info "GitHub Issues"
    Write-Info "-------------"
    if (-not (Assert-GitHubAuth)) { Pause-Menu; return }

    $repo = Read-Host "Repo (owner/repo or Enter for current dir repo)"
    $repoFlag = if ([string]::IsNullOrWhiteSpace($repo)) { "" } else { "-R $repo" }

    Invoke-Expression "gh issue list $repoFlag --limit 20"
    Write-Host ""
    Write-Host "N=New issue    V=View issue    B=Back"
    $action = Read-Host "Action"
    switch ($action.ToUpper()) {
        "N" {
            $title = Read-Host "Issue title"
            $useAI = Read-Host "Use Professor-X to draft the body? (Enter=yes / N=no)"
            $body  = ""
            if ($useAI -ne "N" -and $useAI -ne "n") {
                $context = Read-Host "Describe the issue context"
                $system  = "You are a software engineer. Write a clear, well-structured GitHub issue body with sections: Description, Steps to Reproduce (if applicable), Expected Behavior, Actual Behavior. Be concise."
                $body    = Invoke-OllamaWithSystem -Model $Agents["Professor-X"].Model -SystemPrompt $system -UserPrompt "Issue title: $title. Context: $context"
                Write-Host ""; Write-Host $body; Write-Host ""
            } else {
                $body = Read-Host "Issue body"
            }
            $bodyFile = "$PSScriptRoot\CHAMP-Sessions\issue-body-temp.md"
            Set-Content $bodyFile -Value $body -Encoding UTF8
            Invoke-Expression "gh issue create $repoFlag --title '$title' --body-file '$bodyFile'"
            Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
            Write-ActivityLog "GitHub: created issue '$title'"
            Play-SuccessSound
        }
        "V" {
            $num = Read-Host "Issue number"
            Invoke-Expression "gh issue view $repoFlag $num"
        }
    }
    Pause-Menu
}

function Show-GitHubPRs {
    Show-Header
    Write-Info "GitHub Pull Requests"
    Write-Info "--------------------"
    if (-not (Assert-GitHubAuth)) { Pause-Menu; return }

    $repo = Read-Host "Repo (owner/repo or Enter for current dir)"
    $repoFlag = if ([string]::IsNullOrWhiteSpace($repo)) { "" } else { "-R $repo" }

    Invoke-Expression "gh pr list $repoFlag --limit 20"
    Write-Host ""
    Write-Host "V=View  R=Review with Forge  C=Create  M=Merge  B=Back"
    $action = Read-Host "Action"
    switch ($action.ToUpper()) {
        "V" {
            $num = Read-Host "PR number"
            Invoke-Expression "gh pr view $repoFlag $num"
        }
        "R" {
            $num  = Read-Host "PR number to review"
            Write-Info "Fetching diff..."
            $diff = Invoke-Expression "gh pr diff $repoFlag $num" 2>&1 | Out-String
            if ($diff.Length -gt 8000) { $diff = $diff.Substring(0, 8000) + "`n...(truncated)" }
            $system = "You are a senior software engineer doing a code review. Analyse this git diff and provide: 1) Summary of changes, 2) Potential issues or bugs, 3) Security concerns, 4) Suggestions for improvement. Be specific and actionable."
            Write-Info "Forge is reviewing the diff..."
            $review = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model -SystemPrompt $system -UserPrompt $diff -TimeoutSec 180
            Write-Host ""; Write-Host $review
            $save = Read-Host "Save review to file? (Enter=yes)"
            if ($save -ne "N" -and $save -ne "n") {
                $out = "$PSScriptRoot\CHAMP-Sessions\pr-review-$num-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
                Set-Content $out -Value "# PR #$num Review`n`n$review" -Encoding UTF8
                Write-OK "Saved: $out"
            }
            Write-ActivityLog "GitHub: Forge reviewed PR #$num"
        }
        "C" {
            $title = Read-Host "PR title"
            $base  = Read-Host "Base branch (Enter for main)"
            if ([string]::IsNullOrWhiteSpace($base)) { $base = "main" }
            $useAI = Read-Host "Use Professor-X to write PR description? (Enter=yes)"
            $body  = ""
            if ($useAI -ne "N" -and $useAI -ne "n") {
                $context = Read-Host "What does this PR do?"
                $system  = "You are a senior engineer. Write a professional GitHub PR description with: ## Summary (bullet points), ## Changes (what changed and why), ## Testing (how to verify). Be concise."
                $body    = Invoke-OllamaWithSystem -Model $Agents["Professor-X"].Model -SystemPrompt $system -UserPrompt "PR title: $title. Context: $context"
                Write-Host ""; Write-Host $body; Write-Host ""
            }
            $bodyFile = "$PSScriptRoot\CHAMP-Sessions\pr-body-temp.md"
            Set-Content $bodyFile -Value $body -Encoding UTF8
            Invoke-Expression "gh pr create $repoFlag --title '$title' --base $base --body-file '$bodyFile'"
            Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
            Write-ActivityLog "GitHub: created PR '$title'"
            Play-SuccessSound
        }
        "M" {
            $num = Read-Host "PR number to merge"
            Invoke-Expression "gh pr merge $repoFlag $num --squash"
            Write-ActivityLog "GitHub: merged PR #$num"
            Play-SuccessSound
        }
    }
    Pause-Menu
}

function Show-GitHubActions {
    Show-Header
    Write-Info "GitHub Actions"
    Write-Info "--------------"
    if (-not (Assert-GitHubAuth)) { Pause-Menu; return }

    $repo = Read-Host "Repo (owner/repo or Enter for current dir)"
    $repoFlag = if ([string]::IsNullOrWhiteSpace($repo)) { "" } else { "-R $repo" }

    Write-Info "Recent workflow runs:"
    Invoke-Expression "gh run list $repoFlag --limit 15"
    Write-Host ""
    Write-Host "T=Trigger workflow    W=Watch run    L=View logs    B=Back"
    $action = Read-Host "Action"
    switch ($action.ToUpper()) {
        "T" {
            Invoke-Expression "gh workflow list $repoFlag"
            $wf = Read-Host "Workflow name or ID"
            $br = Read-Host "Branch (Enter for main)"
            if ([string]::IsNullOrWhiteSpace($br)) { $br = "main" }
            Invoke-Expression "gh workflow run $repoFlag '$wf' --ref $br"
            Write-OK "Workflow triggered."
            Write-ActivityLog "GitHub: triggered workflow '$wf'"
        }
        "W" {
            $runId = Read-Host "Run ID"
            Invoke-Expression "gh run watch $repoFlag $runId"
        }
        "L" {
            $runId = Read-Host "Run ID"
            Invoke-Expression "gh run view $repoFlag $runId --log"
        }
    }
    Pause-Menu
}

function GitHub-Menu {
    do {
        Show-Header
        Write-Info "GitHub Control"
        Write-Info "--------------"
        Write-Host "1. Repositories    (list, clone, view)"
        Write-Host "2. Issues          (list, create with AI body)"
        Write-Host "3. Pull Requests   (list, create, Forge AI review)"
        Write-Host "4. Actions         (trigger, watch, logs)"
        Write-Host "5. Back"
        $c = Read-Host "Select"
        switch ($c) {
            "1" { Show-GitHubRepos }
            "2" { Show-GitHubIssues }
            "3" { Show-GitHubPRs }
            "4" { Show-GitHubActions }
            "5" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "5")
}

# ============================================================
# DOCKER ENHANCED
# ============================================================

function Show-ContainerLogs {
    Show-Header
    Write-Info "Container Logs"
    if (-not (Test-DockerRunning)) { Write-Err "Docker not running."; Pause-Menu; return }
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    Write-Host ""
    $name  = Read-Host "Container name"
    $lines = Read-Host "Lines to show (Enter for 50)"
    if (-not ($lines -match '^\d+$')) { $lines = "50" }
    Write-Host ""
    docker logs --tail $lines $name
    Write-Host ""
    $ai = Read-Host "Analyse logs with Cyclops for errors? (Enter=yes / N=skip)"
    if ($ai -ne "N" -and $ai -ne "n") {
        $logText = docker logs --tail 100 $name 2>&1 | Out-String
        if ($logText.Length -gt 6000) { $logText = $logText.Substring($logText.Length - 6000) }
        $system = "You are a DevOps engineer. Analyse these container logs. Identify errors, warnings, anomalies, and their likely root causes. Be specific."
        $r = Invoke-OllamaWithSystem -Model $Agents["Cyclops"].Model -SystemPrompt $system -UserPrompt $logText -TimeoutSec 120
        Write-Host ""; Write-Info "Cyclops Analysis:"; Write-Host $r
        Write-ActivityLog "Docker: Cyclops analysed logs for $name"
    }
    Pause-Menu
}

function Show-ContainerStats {
    Show-Header
    Write-Info "Container Resource Stats (live  -  Ctrl+C to stop)"
    if (-not (Test-DockerRunning)) { Write-Err "Docker not running."; Pause-Menu; return }
    docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
    Pause-Menu
}

function Build-DockerImageFromForge {
    Show-Header
    Write-Info "Docker Image Builder"
    Write-Info "--------------------"
    if (-not (Test-DockerRunning)) { Write-Err "Docker not running."; Pause-Menu; return }

    Write-Host "1. Generate Dockerfile with Forge then build"
    Write-Host "2. Build from existing Dockerfile"
    $mode = Read-Host "Select"

    $buildPath = Read-Host "Build context path (Enter for current dir)"
    if ([string]::IsNullOrWhiteSpace($buildPath)) { $buildPath = "." }

    if ($mode -eq "1") {
        $desc    = Read-Host "Describe what this image should do"
        $system  = "You are a Docker expert. Generate a production-quality, multi-stage Dockerfile. Follow best practices: minimal base image, non-root user, layer caching, .dockerignore hints. Output ONLY the Dockerfile content, no explanations."
        $r       = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model -SystemPrompt $system -UserPrompt $desc -TimeoutSec 120
        $dfPath  = "$buildPath\Dockerfile"
        Set-Content $dfPath -Value (Remove-CodeFences $r) -Encoding UTF8
        Write-OK "Dockerfile saved: $dfPath"
        Write-Host ""; Write-Host (Get-Content $dfPath -Raw); Write-Host ""
        $proceed = Read-Host "Build this image? (Enter=yes / N=edit first)"
        if ($proceed -eq "N" -or $proceed -eq "n") {
            if (Test-CommandExists "code") { code $dfPath }
            Read-Host "Press Enter when ready to build"
        }
    }

    $tag = Read-Host "Image tag (e.g. myapp:latest)"
    if ([string]::IsNullOrWhiteSpace($tag)) { $tag = "champ-build:latest" }

    Write-Info "Building $tag ..."
    docker build -t $tag $buildPath
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Build successful: $tag"
        Write-ActivityLog "Docker: built image $tag"
        Play-SuccessSound
        $push = Read-Host "Push to registry? (Enter=yes / N=skip)"
        if ($push -ne "N" -and $push -ne "n") {
            docker push $tag
            Write-ActivityLog "Docker: pushed $tag"
        }
    } else { Write-Err "Build failed."; Play-ErrorSound }
    Pause-Menu
}

function Manage-DockerVolumes {
    Show-Header
    Write-Info "Docker Volumes"
    if (-not (Test-DockerRunning)) { Write-Err "Docker not running."; Pause-Menu; return }
    docker volume ls
    Write-Host ""
    Write-Host "I=Inspect    D=Delete    B=Back"
    $action = Read-Host "Action"
    switch ($action.ToUpper()) {
        "I" { $v = Read-Host "Volume name"; docker volume inspect $v }
        "D" {
            $v = Read-Host "Volume name to delete"
            Write-Warn "This permanently deletes the volume and its data."
            $confirm = Read-Host "Type YES to confirm"
            if ($confirm -eq "YES") { docker volume rm $v; Write-OK "Deleted: $v"; Write-ActivityLog "Docker: deleted volume $v" }
        }
    }
    Pause-Menu
}

function Manage-DockerNetworks {
    Show-Header
    Write-Info "Docker Networks"
    if (-not (Test-DockerRunning)) { Write-Err "Docker not running."; Pause-Menu; return }
    docker network ls
    Write-Host ""
    $action = Read-Host "I=Inspect    C=Create    D=Delete    B=Back"
    switch ($action.ToUpper()) {
        "I" { $n = Read-Host "Network name"; docker network inspect $n }
        "C" { $n = Read-Host "Network name"; $d = Read-Host "Driver (bridge/overlay, Enter for bridge)"; if ([string]::IsNullOrWhiteSpace($d)) { $d = "bridge" }; docker network create --driver $d $n; Write-OK "Created: $n" }
        "D" { $n = Read-Host "Network name"; docker network rm $n; Write-OK "Deleted: $n" }
    }
    Pause-Menu
}

function Docker-Menu {
    do {
        Show-Header
        Write-Info "Docker Control"
        Write-Info "--------------"
        Write-Host "1.  Container Dashboard    (existing)"
        Write-Host "2.  Start Open WebUI       (existing)"
        Write-Host "3.  Container Logs         (+ Cyclops AI analysis)"
        Write-Host "4.  Container Stats        (live CPU/RAM/IO)"
        Write-Host "5.  Build Image            (Forge generates Dockerfile)"
        Write-Host "6.  Volumes"
        Write-Host "7.  Networks"
        Write-Host "8.  Docker Compose Generator (full AI stack)"
        Write-Host "9.  Back"
        $c = Read-Host "Select"
        switch ($c) {
            "1" { Show-DockerContainers }
            "2" { Start-OpenWebUI }
            "3" { Show-ContainerLogs }
            "4" { Show-ContainerStats }
            "5" { Build-DockerImageFromForge }
            "6" { Manage-DockerVolumes }
            "7" { Manage-DockerNetworks }
            "8" { New-DockerComposeStack }
            "9" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "9")
}

# ============================================================
# TERRAFORM
# ============================================================

function Assert-TerraformInstalled {
    if (Test-CommandExists "terraform") { return $true }
    Write-Err "Terraform not found. Install from https://developer.hashicorp.com/terraform/install"
    return $false
}

function Get-TerraformWorkdir {
    $cfg = Get-DevOpsConfig
    $dir = $cfg["TF_WORKDIR"]
    if ([string]::IsNullOrWhiteSpace($dir) -or -not (Test-Path $dir)) {
        $dir = Read-Host "Terraform working directory path"
        if (Test-Path $dir) { $cfg["TF_WORKDIR"] = $dir; Save-DevOpsConfig $cfg }
        else { Write-Err "Path not found."; return $null }
    }
    return $dir
}

function Invoke-TerraformPlanWithReview {
    Show-Header
    if (-not (Assert-TerraformInstalled)) { Pause-Menu; return }
    $dir = Get-TerraformWorkdir
    if (-not $dir) { Pause-Menu; return }

    Write-Info "Running terraform plan..."
    $planOut = terraform -chdir="$dir" plan -no-color 2>&1 | Out-String
    Write-Host $planOut

    $review = Read-Host "Have Professor-X review this plan before apply? (Enter=yes / N=skip)"
    if ($review -ne "N" -and $review -ne "n") {
        $planSnip = if ($planOut.Length -gt 7000) { $planOut.Substring($planOut.Length - 7000) } else { $planOut }
        $system   = "You are a senior DevOps architect and Terraform expert. Review this terraform plan output. Identify: 1) Resources being created/modified/destroyed, 2) Any risky or irreversible changes, 3) Potential cost implications, 4) Security concerns, 5) Your recommendation: safe to apply or needs review."
        Write-Info "Professor-X is reviewing the plan..."
        $r = Invoke-OllamaWithSystem -Model $Agents["Professor-X"].Model -SystemPrompt $system -UserPrompt $planSnip -TimeoutSec 180
        Write-Host ""; Write-Info "Professor-X Review:"; Write-Host $r
        $out = "$PSScriptRoot\CHAMP-Sessions\tf-plan-review-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
        Set-Content $out -Value "# Terraform Plan Review`n`n$r`n`n---`n`n## Raw Plan`n`n``````$planOut``````" -Encoding UTF8
        Write-OK "Review saved: $out"
        Write-ActivityLog "Terraform: Professor-X reviewed plan in $dir"
    }
    Pause-Menu
}

function Invoke-TerraformMenu {
    do {
        Show-Header
        Write-Info "Terraform Control"
        Write-Info "-----------------"
        $cfg = Get-DevOpsConfig
        $wd  = if ($cfg["TF_WORKDIR"]) { $cfg["TF_WORKDIR"] } else { "(not set)" }
        Write-Host "Working dir: $wd" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "1. Set working directory"
        Write-Host "2. Init"
        Write-Host "3. Validate"
        Write-Host "4. Plan  (+ Professor-X AI review)"
        Write-Host "5. Apply"
        Write-Host "6. Destroy"
        Write-Host "7. Show state"
        Write-Host "8. List workspaces"
        Write-Host "9. Forge generates .tf file"
        Write-Host "10. Back"
        $c = Read-Host "Select"
        if (-not (Assert-TerraformInstalled) -and $c -ne "9" -and $c -ne "10") { Pause-Menu; continue }

        switch ($c) {
            "1" {
                $d = Read-Host "Path to Terraform directory"
                if (Test-Path $d) { $cfg["TF_WORKDIR"] = $d; Save-DevOpsConfig $cfg; Write-OK "Set: $d" }
                else { Write-Err "Path not found." }
                Pause-Menu
            }
            "2" {
                $dir = Get-TerraformWorkdir
                if ($dir) { terraform -chdir="$dir" init; Write-ActivityLog "Terraform: init in $dir" }
                Pause-Menu
            }
            "3" {
                $dir = Get-TerraformWorkdir
                if ($dir) { terraform -chdir="$dir" validate }
                Pause-Menu
            }
            "4" { Invoke-TerraformPlanWithReview }
            "5" {
                $dir = Get-TerraformWorkdir
                if ($dir) {
                    Write-Warn "This will apply changes to real infrastructure."
                    $confirm = Read-Host "Type YES to apply"
                    if ($confirm -eq "YES") {
                        terraform -chdir="$dir" apply -auto-approve
                        Write-ActivityLog "Terraform: applied in $dir"
                        Play-SuccessSound
                    }
                }
                Pause-Menu
            }
            "6" {
                $dir = Get-TerraformWorkdir
                if ($dir) {
                    Write-Warn "DESTROY will delete all managed resources. This is irreversible."
                    $confirm = Read-Host "Type DESTROY to confirm"
                    if ($confirm -eq "DESTROY") {
                        terraform -chdir="$dir" destroy -auto-approve
                        Write-ActivityLog "Terraform: destroyed in $dir"
                    }
                }
                Pause-Menu
            }
            "7" {
                $dir = Get-TerraformWorkdir
                if ($dir) { terraform -chdir="$dir" state list; Write-Host ""; $r = Read-Host "Show detail for resource (Enter to skip)"; if ($r) { terraform -chdir="$dir" state show $r } }
                Pause-Menu
            }
            "8" {
                $dir = Get-TerraformWorkdir
                if ($dir) { terraform -chdir="$dir" workspace list }
                Pause-Menu
            }
            "9" {
                Show-Header
                $desc    = Read-Host "Describe the infrastructure to provision"
                $cloud   = Read-Host "Cloud/provider (aws/azure/gcp/proxmox/other)"
                $system  = "You are a Terraform expert. Generate complete, production-quality Terraform HCL (.tf) code for the $cloud provider. Include provider block, variables, resources, and outputs. Follow best practices. Output ONLY HCL, no explanations."
                $r       = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model -SystemPrompt $system -UserPrompt $desc -TimeoutSec 240
                $r       = Remove-CodeFences $r
                $out     = "$PSScriptRoot\CHAMP-Sessions\forge-infra-$(Get-Date -Format 'yyyyMMdd-HHmmss').tf"
                Set-Content $out -Value $r -Encoding UTF8
                Write-Host ""; Write-Host $r; Write-OK "Saved: $out"
                Write-ActivityLog "Terraform: Forge generated .tf for '$desc'"
                Play-SuccessSound
                Pause-Menu
            }
            "10" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "10")
}

# ============================================================
# PACKER
# ============================================================

function Assert-PackerInstalled {
    if (Test-CommandExists "packer") { return $true }
    Write-Err "Packer not found. Install from https://developer.hashicorp.com/packer/install"
    return $false
}

function Invoke-PackerMenu {
    do {
        Show-Header
        Write-Info "Packer Control"
        Write-Info "--------------"
        Write-Host "1. Validate template"
        Write-Host "2. Build image"
        Write-Host "3. Forge generates HCL template"
        Write-Host "4. Cyclops audits template for security"
        Write-Host "5. Back"
        $c = Read-Host "Select"
        switch ($c) {
            "1" {
                Show-Header
                if (-not (Assert-PackerInstalled)) { Pause-Menu; break }
                $tpl = Read-Host "Path to Packer template (.pkr.hcl)"
                if (-not (Test-Path $tpl)) { Write-Err "File not found."; Pause-Menu; break }
                packer validate $tpl
                Write-ActivityLog "Packer: validated $tpl"
                Pause-Menu
            }
            "2" {
                Show-Header
                if (-not (Assert-PackerInstalled)) { Pause-Menu; break }
                $tpl = Read-Host "Path to Packer template"
                if (-not (Test-Path $tpl)) { Write-Err "File not found."; Pause-Menu; break }
                $dir = Split-Path $tpl
                Write-Info "Initialising Packer plugins..."
                packer init $tpl
                Write-Info "Building image (this may take a while)..."
                packer build $tpl
                if ($LASTEXITCODE -eq 0) {
                    Write-OK "Build complete."
                    Send-ToastNotification "CHAMP AI" "Packer build finished."
                    Write-ActivityLog "Packer: built $tpl"
                    Play-SuccessSound
                } else { Write-Err "Build failed."; Play-ErrorSound }
                Pause-Menu
            }
            "3" {
                Show-Header
                $desc   = Read-Host "Describe the image to build"
                $plugin = Read-Host "Packer plugin/builder (proxmox/virtualbox/qemu/vmware/aws-ebs)"
                $system = "You are a Packer and DevOps expert. Generate a complete, production-quality Packer HCL template (.pkr.hcl) for the $plugin builder. Include: required_plugins block, source block, build block with provisioners. Use shell/ansible provisioners as appropriate. Output ONLY the HCL content, no explanations."
                $r      = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model -SystemPrompt $system -UserPrompt "Build a $plugin image for: $desc" -TimeoutSec 180
                $r      = Remove-CodeFences $r
                $out    = "$PSScriptRoot\CHAMP-Sessions\packer-$(Get-Date -Format 'yyyyMMdd-HHmmss').pkr.hcl"
                Set-Content $out -Value $r -Encoding UTF8
                Write-Host ""; Write-Host $r; Write-OK "Saved: $out"
                Write-ActivityLog "Packer: Forge generated template for '$desc'"
                Play-SuccessSound
                Pause-Menu
            }
            "4" {
                Show-Header
                $tpl = Read-Host "Path to Packer template to audit"
                if (-not (Test-Path $tpl)) { Write-Err "File not found."; Pause-Menu; break }
                $content = Get-Content $tpl -Raw
                $system  = "You are a security engineer specialising in infrastructure-as-code. Audit this Packer template for security issues: hardcoded credentials, overly permissive SSH settings, use of sudo without restrictions, insecure provisioner commands, exposed ports, missing hardening steps. List findings with severity (HIGH/MEDIUM/LOW) and remediation."
                Write-Info "Cyclops is auditing the template..."
                $r = Invoke-OllamaWithSystem -Model $Agents["Cyclops"].Model -SystemPrompt $system -UserPrompt $content -TimeoutSec 120
                Write-Host ""; Write-Info "Cyclops Security Audit:"; Write-Host $r
                $out = "$PSScriptRoot\CHAMP-Sessions\packer-audit-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
                Set-Content $out -Value "# Packer Security Audit`n`n$r" -Encoding UTF8
                Write-OK "Audit saved: $out"
                Write-ActivityLog "Packer: Cyclops audited $tpl"
                Play-SuccessSound
                Pause-Menu
            }
            "5" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "5")
}

# ============================================================
# ANSIBLE
# ============================================================

function Assert-AnsibleInstalled {
    if (Test-CommandExists "ansible") { return $true }
    # Try WSL
    $wslCheck = wsl ansible --version 2>$null
    if ($LASTEXITCODE -eq 0) { return $true }
    Write-Err "Ansible not found. Install via WSL (wsl pip install ansible) or native Windows."
    return $false
}

function Get-AnsibleRunner {
    if (Test-CommandExists "ansible") { return "ansible" }
    return "wsl ansible"
}

function Get-AnsibleInventory {
    $cfg = Get-DevOpsConfig
    $inv = $cfg["ANSIBLE_INVENTORY"]
    if ([string]::IsNullOrWhiteSpace($inv) -or -not (Test-Path $inv)) {
        $inv = Read-Host "Path to Ansible inventory file (or directory)"
        if (Test-Path $inv) { $cfg["ANSIBLE_INVENTORY"] = $inv; Save-DevOpsConfig $cfg }
        else { Write-Err "Inventory not found."; return $null }
    }
    return $inv
}

function Invoke-AnsibleMenu {
    do {
        Show-Header
        Write-Info "Ansible Control"
        Write-Info "---------------"
        $cfg = Get-DevOpsConfig
        $inv = if ($cfg["ANSIBLE_INVENTORY"]) { $cfg["ANSIBLE_INVENTORY"] } else { "(not set)" }
        Write-Host "Inventory: $inv" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "1.  Set inventory path"
        Write-Host "2.  Ping all hosts"
        Write-Host "3.  Run playbook  (+ Professor-X review before exec)"
        Write-Host "4.  Ad-hoc command"
        Write-Host "5.  Show inventory"
        Write-Host "6.  Install Galaxy role"
        Write-Host "7.  Forge generates playbook"
        Write-Host "8.  Cyclops audits playbook for security"
        Write-Host "9.  Back"
        $c = Read-Host "Select"

        switch ($c) {
            "1" {
                $i = Read-Host "Inventory path"
                if (Test-Path $i) { $cfg["ANSIBLE_INVENTORY"] = $i; Save-DevOpsConfig $cfg; Write-OK "Set: $i" }
                else { Write-Err "Not found." }
                Pause-Menu
            }
            "2" {
                if (-not (Assert-AnsibleInstalled)) { Pause-Menu; break }
                $inv = Get-AnsibleInventory; if (-not $inv) { Pause-Menu; break }
                $runner = Get-AnsibleRunner
                Invoke-Expression "$runner all -i '$inv' -m ping"
                Pause-Menu
            }
            "3" {
                Show-Header
                if (-not (Assert-AnsibleInstalled)) { Pause-Menu; break }
                $inv  = Get-AnsibleInventory; if (-not $inv) { Pause-Menu; break }
                $book = Read-Host "Path to playbook"
                if (-not (Test-Path $book)) { Write-Err "Playbook not found."; Pause-Menu; break }

                $review = Read-Host "Have Professor-X review playbook before running? (Enter=yes)"
                if ($review -ne "N" -and $review -ne "n") {
                    $content = Get-Content $book -Raw
                    $system  = "You are a senior DevOps engineer and Ansible expert. Review this playbook. Identify: 1) What it does step by step, 2) Any risky or destructive tasks, 3) Idempotency concerns, 4) Security issues, 5) Your recommendation: safe to run or needs review."
                    Write-Info "Professor-X is reviewing the playbook..."
                    $r = Invoke-OllamaWithSystem -Model $Agents["Professor-X"].Model -SystemPrompt $system -UserPrompt $content -TimeoutSec 120
                    Write-Host ""; Write-Info "Professor-X Review:"; Write-Host $r
                    $confirm = Read-Host "Proceed with execution? (YES to run)"
                    if ($confirm -ne "YES") { Pause-Menu; break }
                }

                $extraArgs = Read-Host "Extra args (e.g. --tags deploy --limit webservers, or Enter for none)"
                $runner    = Get-AnsibleRunner
                Invoke-Expression "$runner-playbook -i '$inv' '$book' $extraArgs"
                if ($LASTEXITCODE -eq 0) { Write-OK "Playbook completed."; Play-SuccessSound; Write-ActivityLog "Ansible: ran $book" }
                else { Write-Err "Playbook failed."; Play-ErrorSound }
                Pause-Menu
            }
            "4" {
                if (-not (Assert-AnsibleInstalled)) { Pause-Menu; break }
                $inv    = Get-AnsibleInventory; if (-not $inv) { Pause-Menu; break }
                $hosts  = Read-Host "Target hosts/group (e.g. all, webservers)"
                $module = Read-Host "Module (e.g. shell, copy, service, yum)"
                $args   = Read-Host "Module args (e.g. 'cmd=uptime' or 'name=nginx state=started')"
                $runner = Get-AnsibleRunner
                Invoke-Expression "$runner '$hosts' -i '$inv' -m $module -a '$args'"
                Write-ActivityLog "Ansible: ad-hoc $module on $hosts"
                Pause-Menu
            }
            "5" {
                if (-not (Assert-AnsibleInstalled)) { Pause-Menu; break }
                $inv    = Get-AnsibleInventory; if (-not $inv) { Pause-Menu; break }
                $runner = Get-AnsibleRunner
                Invoke-Expression "$runner-inventory -i '$inv' --list"
                Pause-Menu
            }
            "6" {
                if (-not (Assert-AnsibleInstalled)) { Pause-Menu; break }
                $role   = Read-Host "Galaxy role name (e.g. geerlingguy.docker)"
                $runner = Get-AnsibleRunner
                Invoke-Expression "$runner-galaxy install $role"
                Write-ActivityLog "Ansible: installed Galaxy role $role"
                Pause-Menu
            }
            "7" {
                Show-Header
                $task   = Read-Host "Describe what the playbook should do"
                $hosts  = Read-Host "Target hosts/group (e.g. webservers, all)"
                $os     = Read-Host "Target OS (ubuntu/centos/rhel/debian)"
                $system = "You are an Ansible expert. Generate a complete, production-quality Ansible playbook in YAML. Follow best practices: use handlers, become where needed, check mode compatibility, idempotent tasks. Output ONLY the YAML playbook, no explanations."
                $prompt = "Write an Ansible playbook for $os targeting '$hosts' to: $task"
                $r      = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model -SystemPrompt $system -UserPrompt $prompt -TimeoutSec 180
                $r      = Remove-CodeFences $r
                $out    = "$PSScriptRoot\CHAMP-Sessions\playbook-$(Get-Date -Format 'yyyyMMdd-HHmmss').yml"
                Set-Content $out -Value $r -Encoding UTF8
                Write-Host ""; Write-Host $r; Write-OK "Saved: $out"
                Write-ActivityLog "Ansible: Forge generated playbook for '$task'"
                Play-SuccessSound
                Pause-Menu
            }
            "8" {
                Show-Header
                $book = Read-Host "Path to playbook to audit"
                if (-not (Test-Path $book)) { Write-Err "File not found."; Pause-Menu; break }
                $content = Get-Content $book -Raw
                $system  = "You are a security engineer specialising in Ansible and configuration management. Audit this playbook for: hardcoded passwords or secrets, use of shell/command over idempotent modules, privilege escalation risks, file permission issues, network exposure, unvalidated inputs. List findings with severity and remediation."
                Write-Info "Cyclops is auditing the playbook..."
                $r = Invoke-OllamaWithSystem -Model $Agents["Cyclops"].Model -SystemPrompt $system -UserPrompt $content -TimeoutSec 120
                Write-Host ""; Write-Info "Cyclops Security Audit:"; Write-Host $r
                $out = "$PSScriptRoot\CHAMP-Sessions\ansible-audit-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
                Set-Content $out -Value "# Ansible Security Audit`n`n$r" -Encoding UTF8
                Write-OK "Audit saved: $out"
                Write-ActivityLog "Ansible: Cyclops audited $book"
                Play-SuccessSound
                Pause-Menu
            }
            "9" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "9")
}

# ============================================================
# DEVOPS CONTROL PANEL  -  Main Menu
# ============================================================

function Show-DevOpsMenu {
    Show-Header
    Write-Host "====================================================" -ForegroundColor DarkMagenta
    Write-Host "         DEVOPS CONTROL PANEL" -ForegroundColor Magenta
    Write-Host "====================================================" -ForegroundColor DarkMagenta
    Write-Host ""
    Write-Host "1.  Proxmox      " -NoNewline; Write-Host "REST API  -  VMs, containers, snapshots, storage" -ForegroundColor DarkGray
    Write-Host "2.  GitHub       " -NoNewline; Write-Host "gh CLI  -  repos, issues, PRs (Forge review), Actions" -ForegroundColor DarkGray
    Write-Host "3.  Docker       " -NoNewline; Write-Host "build, logs, stats, volumes, networks, AI Dockerfile" -ForegroundColor DarkGray
    Write-Host "4.  Terraform    " -NoNewline; Write-Host "init/plan/apply/destroy + Professor-X review + Forge generate" -ForegroundColor DarkGray
    Write-Host "5.  Packer       " -NoNewline; Write-Host "validate/build + Forge HCL + Cyclops audit" -ForegroundColor DarkGray
    Write-Host "6.  Ansible      " -NoNewline; Write-Host "playbooks, ad-hoc, galaxy + Forge generate + Cyclops audit" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "7.  Back"
}

function DevOps-Menu {
    do {
        Show-DevOpsMenu
        $c = Read-Host "Select"
        switch ($c) {
            "1" { Proxmox-Menu }
            "2" { GitHub-Menu }
            "3" { Docker-Menu }
            "4" { Invoke-TerraformMenu }
            "5" { Invoke-PackerMenu }
            "6" { Invoke-AnsibleMenu }
            "7" { return }
            default { Speak-CHAMP "Invalid selection."; Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "7")
}

# ============================================================
# ENHANCEMENT SUITE  -  Persistent History, API Fallback,
# Clipboard AI, WSL Manager, Live Dashboard, Event Log,
# Network Scanner, File Analyzer, Git Tools, LM Studio
# ============================================================

# -----------------------------
# Persistent Conversation History
# Stored per-agent in CHAMP-History\<agent>.json
# Each entry: { role, content, timestamp }
# -----------------------------
$Global:HistoryDir = "$PSScriptRoot\CHAMP-History"

function Get-AgentHistory {
    param([string]$Agent, [int]$MaxEntries = 20)
    $file = "$Global:HistoryDir\$Agent.json"
    if (-not (Test-Path $file)) { return @() }
    try {
        $all = Get-Content $file -Raw | ConvertFrom-Json
        if ($all.Count -gt $MaxEntries) { $all = $all[-$MaxEntries..-1] }
        return $all
    } catch { return @() }
}

function Add-AgentHistory {
    param([string]$Agent, [string]$Role, [string]$Content)
    if (-not (Test-Path $Global:HistoryDir)) { New-Item -ItemType Directory -Path $Global:HistoryDir -Force | Out-Null }
    $file = "$Global:HistoryDir\$Agent.json"
    $existing = @()
    if (Test-Path $file) {
        try { $existing = Get-Content $file -Raw | ConvertFrom-Json } catch { $existing = @() }
    }
    $entry = [PSCustomObject]@{ role = $Role; content = $Content; timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }
    $existing += $entry
    if ($existing.Count -gt 100) { $existing = $existing[-100..-1] }
    $existing | ConvertTo-Json -Depth 5 | Set-Content $file -Encoding UTF8
}

function Clear-AgentHistory {
    param([string]$Agent)
    $file = "$Global:HistoryDir\$Agent.json"
    if (Test-Path $file) { Remove-Item $file -Force }
    Write-OK "History cleared for $Agent."
}

function Show-AgentHistory {
    param([string]$Agent)
    $history = Get-AgentHistory -Agent $Agent -MaxEntries 30
    if ($history.Count -eq 0) { Write-Warn "No history for $Agent."; Pause-Menu; return }
    Show-Header
    Write-Info "=== Conversation History: $Agent ==="
    foreach ($h in $history) {
        $color = if ($h.role -eq "user") { "Cyan" } else { "White" }
        Write-Host "[$($h.timestamp)] $($h.role.ToUpper()): " -ForegroundColor $color -NoNewline
        $preview = if ($h.content.Length -gt 120) { $h.content.Substring(0,120) + "..." } else { $h.content }
        Write-Host $preview
    }
    Pause-Menu
}

function Invoke-AgentWithHistory {
    param([string]$Agent, [string]$Prompt)
    $modelInfo = $Agents[$Agent]
    if (-not $modelInfo) { Write-Err "Unknown agent: $Agent"; return }
    $model = $modelInfo.Model
    $system = $modelInfo.Role

    # Build context string from last 6 exchanges
    $history = Get-AgentHistory -Agent $Agent -MaxEntries 12
    $contextBlock = ""
    if ($history.Count -gt 0) {
        $contextBlock = "`n`nPrevious conversation:`n"
        foreach ($h in $history) { $contextBlock += "$($h.role.ToUpper()): $($h.content)`n" }
        $contextBlock += "`nCurrent question:"
    }

    $fullPrompt = if ($contextBlock) { "$contextBlock`n$Prompt" } else { $Prompt }

    Add-AgentHistory -Agent $Agent -Role "user" -Content $Prompt
    Write-Info "[$Agent] Thinking..."
    $response = Invoke-OllamaWithSystem -Model $model -SystemPrompt $system -UserPrompt $fullPrompt
    if ($response) {
        Add-AgentHistory -Agent $Agent -Role "assistant" -Content $response
        Write-Host "`n" -NoNewline
        Write-Host $response -ForegroundColor White
        Write-ActivityLog "[$Agent] History-aware query: $($Prompt.Substring(0,[Math]::Min(60,$Prompt.Length)))"
    }
}

function History-Menu {
    do {
        Show-Header
        Write-Host "=== Conversation History Manager ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Chat with agent (with memory)"
        Write-Host "2. View agent history"
        Write-Host "3. Clear agent history"
        Write-Host "4. Clear ALL agent histories"
        Write-Host "5. Back"
        Write-Host ""
        $choice = Read-Host "Select"
        switch ($choice) {
            "1" {
                $agentNames = $Agents.Keys | Sort-Object
                $i = 1; foreach ($a in $agentNames) { Write-Host "$i. $a"; $i++ }
                $pick = Read-Host "Agent number"
                $agent = @($agentNames)[[int]$pick - 1]
                if ($agent) {
                    $prompt = Read-Host "Your message to $agent"
                    Invoke-AgentWithHistory -Agent $agent -Prompt $prompt
                    Pause-Menu
                }
            }
            "2" {
                $agentNames = $Agents.Keys | Sort-Object
                $i = 1; foreach ($a in $agentNames) { Write-Host "$i. $a"; $i++ }
                $pick = Read-Host "Agent number"
                $agent = @($agentNames)[[int]$pick - 1]
                if ($agent) { Show-AgentHistory -Agent $agent }
            }
            "3" {
                $agentNames = $Agents.Keys | Sort-Object
                $i = 1; foreach ($a in $agentNames) { Write-Host "$i. $a"; $i++ }
                $pick = Read-Host "Agent number"
                $agent = @($agentNames)[[int]$pick - 1]
                if ($agent) { Clear-AgentHistory -Agent $agent; Pause-Menu }
            }
            "4" {
                $confirm = Read-Host "Type YES to clear all agent histories"
                if ($confirm -eq "YES") {
                    if (Test-Path $Global:HistoryDir) { Remove-Item "$Global:HistoryDir\*.json" -Force -ErrorAction SilentlyContinue }
                    Write-OK "All histories cleared."
                    Pause-Menu
                }
            }
            "5" { return }
        }
    } while ($choice -ne "5")
}

# -----------------------------
# Cloud API Fallback (OpenAI / Claude)
# Uses keys from .env: OPENAI_API_KEY, ANTHROPIC_API_KEY
# -----------------------------
function Invoke-OpenAIFallback {
    param([string]$Prompt, [string]$System = "You are a helpful assistant.", [string]$Model = "gpt-4o-mini")
    $key = Get-EnvValue "OPENAI_API_KEY"
    if (-not $key) { Write-Err "OPENAI_API_KEY not set. Use API Key Manager (option 19 > 17)."; Pause-Menu; return $null }
    $body = @{
        model    = $Model
        messages = @(
            @{ role = "system"; content = $System }
            @{ role = "user";   content = $Prompt }
        )
        max_tokens = 2048
    } | ConvertTo-Json -Depth 5
    try {
        $resp = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" `
            -Method POST -ContentType "application/json" `
            -Headers @{ Authorization = "Bearer $key" } -Body $body
        return $resp.choices[0].message.content
    } catch { Write-Err "OpenAI call failed: $_"; return $null }
}

function Invoke-ClaudeFallback {
    param([string]$Prompt, [string]$System = "You are a helpful assistant.", [string]$Model = "claude-haiku-4-5-20251001")
    $key = Get-EnvValue "ANTHROPIC_API_KEY"
    if (-not $key) { Write-Err "ANTHROPIC_API_KEY not set. Use API Key Manager (option 19 > 17)."; Pause-Menu; return $null }
    $body = @{
        model      = $Model
        max_tokens = 2048
        system     = $System
        messages   = @(@{ role = "user"; content = $Prompt })
    } | ConvertTo-Json -Depth 5
    try {
        $resp = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" `
            -Method POST -ContentType "application/json" `
            -Headers @{ "x-api-key" = $key; "anthropic-version" = "2023-06-01" } -Body $body
        return $resp.content[0].text
    } catch { Write-Err "Claude API call failed: $_"; return $null }
}

function CloudFallback-Menu {
    do {
        Show-Header
        Write-Host "=== Cloud API Fallback ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Ask OpenAI (gpt-4o-mini)"
        Write-Host "2. Ask OpenAI (gpt-4o)"
        Write-Host "3. Ask Claude (claude-haiku  -  fast)"
        Write-Host "4. Ask Claude (claude-sonnet-4-6  -  powerful)"
        Write-Host "5. Side-by-side: Local Forge vs OpenAI vs Claude"
        Write-Host "6. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1" {
                $prompt = Read-Host "Prompt"
                $r = Invoke-OpenAIFallback -Prompt $prompt -Model "gpt-4o-mini"
                if ($r) { Write-Host "`nOpenAI (gpt-4o-mini):" -ForegroundColor Green; Write-Host $r }
                Pause-Menu
            }
            "2" {
                $prompt = Read-Host "Prompt"
                $r = Invoke-OpenAIFallback -Prompt $prompt -Model "gpt-4o"
                if ($r) { Write-Host "`nOpenAI (gpt-4o):" -ForegroundColor Green; Write-Host $r }
                Pause-Menu
            }
            "3" {
                $prompt = Read-Host "Prompt"
                $r = Invoke-ClaudeFallback -Prompt $prompt -Model "claude-haiku-4-5-20251001"
                if ($r) { Write-Host "`nClaude Haiku:" -ForegroundColor Magenta; Write-Host $r }
                Pause-Menu
            }
            "4" {
                $prompt = Read-Host "Prompt"
                $r = Invoke-ClaudeFallback -Prompt $prompt -Model "claude-sonnet-4-6"
                if ($r) { Write-Host "`nClaude Sonnet:" -ForegroundColor Magenta; Write-Host $r }
                Pause-Menu
            }
            "5" {
                $prompt = Read-Host "Prompt for side-by-side comparison"
                Write-Info "Querying Forge (local)..."
                $local = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model -SystemPrompt $Agents["Forge"].Role -UserPrompt $prompt
                Write-Info "Querying OpenAI..."
                $openai = Invoke-OpenAIFallback -Prompt $prompt
                Write-Info "Querying Claude..."
                $claude = Invoke-ClaudeFallback -Prompt $prompt
                Write-Host "`n--- Forge (local) ---" -ForegroundColor Yellow
                Write-Host $local
                Write-Host "`n--- OpenAI ---" -ForegroundColor Green
                Write-Host $openai
                Write-Host "`n--- Claude ---" -ForegroundColor Magenta
                Write-Host $claude
                Pause-Menu
            }
            "6" { return }
        }
    } while ($c -ne "6")
}

# -----------------------------
# Clipboard AI
# Grabs clipboard text, fires at chosen agent
# -----------------------------
function Invoke-ClipboardAI {
    Show-Header
    Write-Host "=== Clipboard AI ===" -ForegroundColor Yellow
    Write-Host ""
    $clip = Get-Clipboard -Raw
    if (-not $clip) { Write-Warn "Clipboard is empty."; Pause-Menu; return }
    $preview = if ($clip.Length -gt 200) { $clip.Substring(0,200) + "..." } else { $clip }
    Write-Info "Clipboard content:"
    Write-Host $preview -ForegroundColor Gray
    Write-Host ""
    Write-Host "Send to:"
    $agentNames = $Agents.Keys | Sort-Object
    $i = 1; foreach ($a in $agentNames) { Write-Host "$i. $a"; $i++ }
    Write-Host "0. Cancel"
    $pick = Read-Host "Agent number"
    if ($pick -eq "0") { return }
    $agent = @($agentNames)[[int]$pick - 1]
    if (-not $agent) { Write-Err "Invalid selection."; Pause-Menu; return }
    $extra = Read-Host "Add instruction (or press Enter to send as-is)"
    $prompt = if ($extra) { "$extra`n`n$clip" } else { $clip }
    Write-Info "Sending to $agent..."
    $response = Invoke-OllamaWithSystem -Model $Agents[$agent].Model -SystemPrompt $Agents[$agent].Role -UserPrompt $prompt
    Write-Host ""
    Write-Host $response -ForegroundColor White
    $save = Read-Host "Save response to session file? (y/n)"
    if ($save -eq "y") {
        $dir = "$PSScriptRoot\CHAMP-Sessions"
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $file = "$dir\clipboard-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
        "# Clipboard AI  -  $agent`n`n## Input`n$clip`n`n## Response`n$response" | Set-Content $file -Encoding UTF8
        Write-OK "Saved: $file"
    }
    Write-ActivityLog "Clipboard AI  -  $agent"
    Pause-Menu
}

# -----------------------------
# WSL Manager
# -----------------------------
function WSL-Menu {
    do {
        Show-Header
        Write-Host "=== WSL Manager ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. List WSL distros"
        Write-Host "2. Launch default distro shell"
        Write-Host "3. Run a command in default distro"
        Write-Host "4. Start a distro"
        Write-Host "5. Stop a distro (wsl --terminate)"
        Write-Host "6. Set default distro"
        Write-Host "7. WSL system info (uname / df / free)"
        Write-Host "8. Forge: generate a Linux bash script"
        Write-Host "9. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1" {
                wsl --list --verbose
                Pause-Menu
            }
            "2" {
                Write-Info "Launching WSL shell (type 'exit' to return)..."
                wsl
            }
            "3" {
                $cmd = Read-Host "Command to run in WSL"
                wsl -- $cmd
                Pause-Menu
            }
            "4" {
                $distro = Read-Host "Distro name"
                wsl -d $distro -- echo "Started $distro"
                Write-OK "Distro $distro started."
                Pause-Menu
            }
            "5" {
                $distro = Read-Host "Distro name to terminate"
                wsl --terminate $distro
                Write-OK "Terminated $distro."
                Pause-Menu
            }
            "6" {
                $distro = Read-Host "Distro name to set as default"
                wsl --set-default $distro
                Write-OK "Default set to $distro."
                Pause-Menu
            }
            "7" {
                Write-Info "--- uname -a ---"
                wsl -- uname -a
                Write-Info "--- df -h ---"
                wsl -- df -h
                Write-Info "--- free -h ---"
                wsl -- free -h
                Pause-Menu
            }
            "8" {
                $task = Read-Host "Describe the bash script you need"
                $system = "You are an expert Linux bash scripter. Output only the bash script with no explanation or markdown fences."
                $script = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model -SystemPrompt $system -UserPrompt "Write a bash script that: $task"
                if ($script) {
                    Write-Host "`n$script" -ForegroundColor White
                    $save = Read-Host "Save as script.sh? (y/n)"
                    if ($save -eq "y") {
                        $name = Read-Host "Filename (without .sh)"
                        $script | Set-Content "$PSScriptRoot\$name.sh" -Encoding UTF8
                        Write-OK "Saved: $name.sh"
                    }
                }
                Pause-Menu
            }
            "9" { return }
        }
    } while ($c -ne "9")
}

# -----------------------------
# Live Dashboard
# Auto-refreshes every 5 seconds showing system + service health
# -----------------------------
function Show-LiveDashboard {
    Write-Info "Live Dashboard active. Press Ctrl+C to exit."
    Start-Sleep -Milliseconds 800
    while ($true) {
        Clear-Host
        Write-Host "====================================================" -ForegroundColor DarkCyan
        Write-Host "     CEREBRO LIVE DASHBOARD  $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
        Write-Host "====================================================" -ForegroundColor DarkCyan

        # System resources
        $os = Get-CimInstance Win32_OperatingSystem
        $ramFree = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $ramTotal = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $ramUsedPct = [math]::Round((($ramTotal - $ramFree) / $ramTotal) * 100, 0)
        $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        Write-Host ""
        Write-Host " SYSTEM" -ForegroundColor Yellow
        $cpuColor = if ($cpu -gt 80) { "Red" } elseif ($cpu -gt 50) { "Yellow" } else { "Green" }
        Write-Host "  CPU    : $cpu%" -ForegroundColor $cpuColor
        $ramColor = if ($ramUsedPct -gt 85) { "Red" } elseif ($ramUsedPct -gt 65) { "Yellow" } else { "Green" }
        Write-Host "  RAM    : $($ramTotal - $ramFree) GB / $ramTotal GB  ($ramUsedPct%)" -ForegroundColor $ramColor

        # Disk
        $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 }
        foreach ($d in $drives) {
            $usedGB = [math]::Round($d.Used / 1GB, 1)
            $freeGB = [math]::Round($d.Free / 1GB, 1)
            $totalGB = $usedGB + $freeGB
            if ($totalGB -gt 0) {
                $pct = [math]::Round(($usedGB / $totalGB) * 100, 0)
                $dc = if ($pct -gt 90) { "Red" } elseif ($pct -gt 75) { "Yellow" } else { "Green" }
                Write-Host "  Disk $($d.Name): $usedGB/$totalGB GB ($pct%)" -ForegroundColor $dc
            }
        }

        # Services
        Write-Host ""
        Write-Host " SERVICES" -ForegroundColor Yellow
        $ollamaRunning = Test-OllamaRunning
        $ollamaColor = if ($ollamaRunning) { "Green" } else { "Red" }
        $ollamaStatus = if ($ollamaRunning) { "RUNNING" } else { "STOPPED" }
        Write-Host "  Ollama      : $ollamaStatus" -ForegroundColor $ollamaColor

        $dockerRunning = Test-DockerRunning
        $dockerColor = if ($dockerRunning) { "Green" } else { "Red" }
        $dockerStatus = if ($dockerRunning) { "RUNNING" } else { "STOPPED" }
        Write-Host "  Docker      : $dockerStatus" -ForegroundColor $dockerColor

        # Open WebUI container
        if ($dockerRunning) {
            try {
                $webUIState = docker inspect --format='{{.State.Status}}' $OpenWebUIContainer 2>$null
                $webUIColor = if ($webUIState -eq "running") { "Green" } else { "Red" }
                Write-Host "  Open WebUI  : $($webUIState.ToUpper())" -ForegroundColor $webUIColor
            } catch {
                Write-Host "  Open WebUI  : UNKNOWN" -ForegroundColor Gray
            }
        }

        # Port checks
        Write-Host ""
        Write-Host " PORTS" -ForegroundColor Yellow
        $ports = @{ "Ollama(11434)" = 11434; "WebUI(3000)" = 3000; "LMStudio(1234)" = 1234; "Jupyter(8888)" = 8888 }
        foreach ($name in $ports.Keys) {
            try {
                $tcp = New-Object System.Net.Sockets.TcpClient
                $connect = $tcp.BeginConnect("127.0.0.1", $ports[$name], $null, $null)
                $wait = $connect.AsyncWaitHandle.WaitOne(300, $false)
                $tcp.Close()
                $pc = if ($wait) { "Green" } else { "Red" }
                $ps = if ($wait) { "ACTIVE" } else { "INACTIVE" }
            } catch { $pc = "Red"; $ps = "INACTIVE" }
            Write-Host ("  {0,-20}: {1}" -f $name, $ps) -ForegroundColor $pc
        }

        # Loaded Ollama models
        if ($ollamaRunning) {
            try {
                $loaded = Invoke-RestMethod -Uri "http://localhost:11434/api/ps" -TimeoutSec 2 -ErrorAction Stop
                Write-Host ""
                Write-Host " LOADED MODELS" -ForegroundColor Yellow
                if ($loaded.models -and $loaded.models.Count -gt 0) {
                    foreach ($m in $loaded.models) { Write-Host "  $($m.name)" -ForegroundColor Cyan }
                } else { Write-Host "  (none)" -ForegroundColor Gray }
            } catch {}
        }

        # Recent log
        Write-Host ""
        Write-Host " RECENT ACTIVITY" -ForegroundColor Yellow
        if (Test-Path $ActivityLogPath) {
            $lines = Get-Content $ActivityLogPath -Tail 4
            foreach ($l in $lines) { Write-Host "  $l" -ForegroundColor DarkGray }
        }

        Write-Host ""
        Write-Host " [Ctrl+C to exit dashboard]" -ForegroundColor DarkGray
        Start-Sleep -Seconds 5
    }
}

# -----------------------------
# Windows Event Log Watcher (Cyclops)
# -----------------------------
function EventLog-Menu {
    do {
        Show-Header
        Write-Host "=== Windows Event Log Watcher ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Show recent System errors (last 20)"
        Write-Host "2. Show recent Application errors (last 20)"
        Write-Host "3. Show Security warnings (last 20)"
        Write-Host "4. Cyclops AI analysis of System errors"
        Write-Host "5. Cyclops AI analysis of Application errors"
        Write-Host "6. Search event log by keyword"
        Write-Host "7. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1" {
                Write-Info "Recent System errors:"
                Get-EventLog -LogName System -EntryType Error -Newest 20 2>$null |
                    Format-Table TimeGenerated, Source, Message -AutoSize -Wrap | Out-Host
                Pause-Menu
            }
            "2" {
                Write-Info "Recent Application errors:"
                Get-EventLog -LogName Application -EntryType Error -Newest 20 2>$null |
                    Format-Table TimeGenerated, Source, Message -AutoSize -Wrap | Out-Host
                Pause-Menu
            }
            "3" {
                Write-Info "Recent Security warnings:"
                Get-EventLog -LogName Security -EntryType Warning -Newest 20 2>$null |
                    Format-Table TimeGenerated, Source, Message -AutoSize -Wrap | Out-Host
                Pause-Menu
            }
            "4" {
                Write-Info "Gathering System errors for Cyclops..."
                $events = Get-EventLog -LogName System -EntryType Error -Newest 15 2>$null |
                    Select-Object -ExpandProperty Message | Out-String
                if (-not $events) { Write-Warn "No System errors found."; Pause-Menu; break }
                $analysis = Invoke-OllamaWithSystem -Model $Agents["Cyclops"].Model `
                    -SystemPrompt "You are a Windows system analyst. Review these Windows Event Log errors and summarise the root causes and recommended fixes in bullet points." `
                    -UserPrompt $events
                Write-Host "`n$analysis" -ForegroundColor White
                Pause-Menu
            }
            "5" {
                Write-Info "Gathering Application errors for Cyclops..."
                $events = Get-EventLog -LogName Application -EntryType Error -Newest 15 2>$null |
                    Select-Object -ExpandProperty Message | Out-String
                if (-not $events) { Write-Warn "No Application errors found."; Pause-Menu; break }
                $analysis = Invoke-OllamaWithSystem -Model $Agents["Cyclops"].Model `
                    -SystemPrompt "You are a Windows system analyst. Review these Windows Application Event Log errors and summarise root causes and fixes." `
                    -UserPrompt $events
                Write-Host "`n$analysis" -ForegroundColor White
                Pause-Menu
            }
            "6" {
                $kw = Read-Host "Keyword to search"
                Write-Info "Searching System and Application logs for '$kw'..."
                $results = @()
                $results += Get-EventLog -LogName System -Newest 500 2>$null | Where-Object { $_.Message -like "*$kw*" } | Select-Object -First 10
                $results += Get-EventLog -LogName Application -Newest 500 2>$null | Where-Object { $_.Message -like "*$kw*" } | Select-Object -First 10
                if ($results.Count -eq 0) { Write-Warn "No matches found." } else {
                    $results | Format-Table TimeGenerated, Log, Source, EntryType, Message -AutoSize -Wrap | Out-Host
                }
                Pause-Menu
            }
            "7" { return }
        }
    } while ($c -ne "7")
}

# -----------------------------
# Network Scanner
# -----------------------------
function NetworkScanner-Menu {
    do {
        Show-Header
        Write-Host "=== Network Scanner ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Ping a host"
        Write-Host "2. Traceroute"
        Write-Host "3. DNS lookup"
        Write-Host "4. Scan common ports on a host"
        Write-Host "5. Local network ping sweep (/24)"
        Write-Host "6. Show local network info"
        Write-Host "7. Cyclops: analyse scan results"
        Write-Host "8. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1" {
                $host_ = Read-Host "Host or IP"
                Test-Connection -ComputerName $host_ -Count 4 | Format-Table Address, ResponseTime, StatusCode -AutoSize | Out-Host
                Pause-Menu
            }
            "2" {
                $host_ = Read-Host "Host or IP"
                tracert $host_
                Pause-Menu
            }
            "3" {
                $host_ = Read-Host "Hostname to resolve"
                [System.Net.Dns]::GetHostAddresses($host_) | ForEach-Object { Write-Host $_.IPAddressToString }
                Pause-Menu
            }
            "4" {
                $host_ = Read-Host "Host or IP"
                $ports = @(21,22,23,25,53,80,443,445,3389,8080,8443,11434,3000,1234)
                Write-Info "Scanning $host_ on $($ports.Count) common ports..."
                $results = @()
                foreach ($p in $ports) {
                    try {
                        $tcp = New-Object System.Net.Sockets.TcpClient
                        $conn = $tcp.BeginConnect($host_, $p, $null, $null)
                        $open = $conn.AsyncWaitHandle.WaitOne(500, $false)
                        $tcp.Close()
                        $status = if ($open) { "OPEN" } else { "CLOSED" }
                        $color  = if ($open) { "Green" } else { "DarkGray" }
                    } catch { $status = "CLOSED"; $color = "DarkGray" }
                    if ($open) { Write-Host "  Port $p : $status" -ForegroundColor $color }
                    $results += "$p : $status"
                }
                $Global:LastScanResults = ($results -join "`n") + "`nHost: $host_"
                Pause-Menu
            }
            "5" {
                $base = Read-Host "Base IP (e.g. 192.168.1)"
                Write-Info "Pinging $base.1 - $base.254 (this may take a moment)..."
                $alive = @()
                1..254 | ForEach-Object {
                    $ip = "$base.$_"
                    $r = Test-Connection -ComputerName $ip -Count 1 -Quiet -TimeoutSeconds 1
                    if ($r) { Write-Host "  $ip ALIVE" -ForegroundColor Green; $alive += $ip }
                }
                Write-OK "`n$($alive.Count) hosts alive."
                $Global:LastScanResults = "Ping sweep $base.0/24`nAlive: $($alive -join ', ')"
                Pause-Menu
            }
            "6" {
                Write-Info "Network adapters:"
                Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } |
                    Format-Table InterfaceAlias, IPAddress, PrefixLength -AutoSize | Out-Host
                Write-Info "Default gateway:"
                Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Format-Table InterfaceAlias, NextHop -AutoSize | Out-Host
                Pause-Menu
            }
            "7" {
                $data = if ($Global:LastScanResults) { $Global:LastScanResults } else {
                    Read-Host "Paste scan output to analyse"
                }
                $analysis = Invoke-OllamaWithSystem -Model $Agents["Cyclops"].Model `
                    -SystemPrompt "You are a network security analyst. Review these scan results and identify potential security risks, open attack surfaces, and recommendations." `
                    -UserPrompt $data
                Write-Host "`n$analysis" -ForegroundColor White
                Pause-Menu
            }
            "8" { return }
        }
    } while ($c -ne "8")
}
$Global:LastScanResults = ""

# -----------------------------
# File / Code Drop Analyzer
# -----------------------------
function FileAnalyzer-Menu {
    do {
        Show-Header
        Write-Host "=== File & Code Analyzer ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Analyze a file (Forge  -  explain / review)"
        Write-Host "2. Security audit a file (Cyclops)"
        Write-Host "3. Summarize a text/log file (Nightcrawler)"
        Write-Host "4. Generate unit tests for a code file (Forge)"
        Write-Host "5. Explain architecture of a folder (Professor X)"
        Write-Host "6. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1" {
                $path = Read-Host "File path"
                if (-not (Test-Path $path)) { Write-Err "File not found."; Pause-Menu; break }
                $content = Get-Content $path -Raw -Encoding UTF8
                if ($content.Length -gt 8000) { $content = $content.Substring(0, 8000) + "`n[...truncated]" }
                $ext = [System.IO.Path]::GetExtension($path)
                $analysis = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model `
                    -SystemPrompt "You are a senior software engineer. Review the following $ext file and explain what it does, identify any bugs or improvements, and summarize key logic." `
                    -UserPrompt $content
                Write-Host "`n$analysis" -ForegroundColor White
                Pause-Menu
            }
            "2" {
                $path = Read-Host "File path"
                if (-not (Test-Path $path)) { Write-Err "File not found."; Pause-Menu; break }
                $content = Get-Content $path -Raw -Encoding UTF8
                if ($content.Length -gt 8000) { $content = $content.Substring(0, 8000) + "`n[...truncated]" }
                $analysis = Invoke-OllamaWithSystem -Model $Agents["Cyclops"].Model `
                    -SystemPrompt "You are a security code auditor. Review this file for security vulnerabilities, hardcoded secrets, injection risks, insecure patterns, and OWASP concerns. List findings with severity." `
                    -UserPrompt $content
                Write-Host "`n$analysis" -ForegroundColor White
                Pause-Menu
            }
            "3" {
                $path = Read-Host "File path"
                if (-not (Test-Path $path)) { Write-Err "File not found."; Pause-Menu; break }
                $content = Get-Content $path -Raw -Encoding UTF8
                if ($content.Length -gt 6000) { $content = $content.Substring(0, 6000) + "`n[...truncated]" }
                $summary = Invoke-OllamaWithSystem -Model $Agents["Nightcrawler"].Model `
                    -SystemPrompt "You are a concise summarizer. Give a short bullet-point summary of this file's contents." `
                    -UserPrompt $content
                Write-Host "`n$summary" -ForegroundColor White
                Pause-Menu
            }
            "4" {
                $path = Read-Host "Code file path"
                if (-not (Test-Path $path)) { Write-Err "File not found."; Pause-Menu; break }
                $content = Get-Content $path -Raw -Encoding UTF8
                if ($content.Length -gt 6000) { $content = $content.Substring(0, 6000) }
                $lang = [System.IO.Path]::GetExtension($path).TrimStart(".")
                $tests = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model `
                    -SystemPrompt "You are a test engineer. Write unit tests for the following $lang code. Output only the test code." `
                    -UserPrompt $content
                Write-Host "`n$tests" -ForegroundColor White
                $save = Read-Host "Save tests to file? (y/n)"
                if ($save -eq "y") {
                    $outPath = [System.IO.Path]::ChangeExtension($path, ".test.$lang")
                    $tests | Set-Content $outPath -Encoding UTF8
                    Write-OK "Saved: $outPath"
                }
                Pause-Menu
            }
            "5" {
                $folder = Read-Host "Folder path"
                if (-not (Test-Path $folder)) { Write-Err "Folder not found."; Pause-Menu; break }
                $tree = Get-ChildItem $folder -Recurse -File |
                    Select-Object -First 80 |
                    ForEach-Object { $_.FullName.Replace($folder, "").TrimStart("\") } |
                    Out-String
                $analysis = Invoke-OllamaWithSystem -Model $Agents["Professor-X"].Model `
                    -SystemPrompt "You are a software architect. Based on the following file tree, describe the project architecture, likely tech stack, and structure in plain English." `
                    -UserPrompt $tree
                Write-Host "`n$analysis" -ForegroundColor White
                Pause-Menu
            }
            "6" { return }
        }
    } while ($c -ne "6")
}

# -----------------------------
# Git Tools (local repo operations + AI assist)
# -----------------------------
function GitTools-Menu {
    do {
        Show-Header
        Write-Host "=== Git Tools ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. git status"
        Write-Host "2. git log (last 10)"
        Write-Host "3. git diff (staged)"
        Write-Host "4. Forge: generate commit message from diff"
        Write-Host "5. Forge: review current diff for issues"
        Write-Host "6. git stash / unstash"
        Write-Host "7. git branch list"
        Write-Host "8. Cyclops: security scan of uncommitted changes"
        Write-Host "9. Set working repo path"
        Write-Host "0. Back"
        Write-Host ""
        $cfg = Get-DevOpsConfig
        $repoPath = if ($cfg.GitRepoPath) { $cfg.GitRepoPath } else { (Get-Location).Path }
        Write-Info "Repo: $repoPath"
        $c = Read-Host "Select"
        switch ($c) {
            "1" {
                Push-Location $repoPath
                git status
                Pop-Location
                Pause-Menu
            }
            "2" {
                Push-Location $repoPath
                git log --oneline -10
                Pop-Location
                Pause-Menu
            }
            "3" {
                Push-Location $repoPath
                git diff --staged
                Pop-Location
                Pause-Menu
            }
            "4" {
                Push-Location $repoPath
                $diff = git diff --staged
                Pop-Location
                if (-not $diff) { Write-Warn "No staged changes."; Pause-Menu; break }
                $msg = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model `
                    -SystemPrompt "You are a Git expert. Based on this diff, write a concise, conventional commit message (type: subject). Output only the commit message, nothing else." `
                    -UserPrompt $diff
                Write-Host "`nSuggested commit message:" -ForegroundColor Green
                Write-Host $msg -ForegroundColor White
                $use = Read-Host "Use this message? (y/n)"
                if ($use -eq "y") {
                    Push-Location $repoPath
                    git commit -m $msg
                    Pop-Location
                }
                Pause-Menu
            }
            "5" {
                Push-Location $repoPath
                $diff = git diff HEAD
                Pop-Location
                if (-not $diff) { Write-Warn "No changes to review."; Pause-Menu; break }
                $review = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model `
                    -SystemPrompt "You are a senior code reviewer. Review this git diff for bugs, logic errors, style issues, and improvements. Be concise and use bullet points." `
                    -UserPrompt $diff
                Write-Host "`n$review" -ForegroundColor White
                Pause-Menu
            }
            "6" {
                Write-Host "1. Stash changes   2. Pop stash   3. List stashes"
                $sc = Read-Host "Select"
                Push-Location $repoPath
                switch ($sc) {
                    "1" { $msg = Read-Host "Stash message"; git stash push -m $msg }
                    "2" { git stash pop }
                    "3" { git stash list }
                }
                Pop-Location
                Pause-Menu
            }
            "7" {
                Push-Location $repoPath
                git branch -a
                Pop-Location
                Pause-Menu
            }
            "8" {
                Push-Location $repoPath
                $diff = git diff HEAD
                Pop-Location
                if (-not $diff) { Write-Warn "No uncommitted changes."; Pause-Menu; break }
                $audit = Invoke-OllamaWithSystem -Model $Agents["Cyclops"].Model `
                    -SystemPrompt "You are a security code auditor. Review this git diff for hardcoded secrets, API keys, passwords, security vulnerabilities, and risky code patterns. List any findings with severity." `
                    -UserPrompt $diff
                Write-Host "`n$audit" -ForegroundColor White
                Pause-Menu
            }
            "9" {
                $newPath = Read-Host "Repo path"
                if (Test-Path $newPath) {
                    $cfg.GitRepoPath = $newPath
                    Save-DevOpsConfig $cfg
                    Write-OK "Repo path saved: $newPath"
                } else { Write-Err "Path not found." }
                Pause-Menu
            }
            "0" { return }
        }
    } while ($c -ne "0")
}

# -----------------------------
# LM Studio Support
# LM Studio runs an OpenAI-compatible API at localhost:1234
# -----------------------------
function Invoke-LMStudio {
    param([string]$Prompt, [string]$System = "You are a helpful assistant.", [string]$Model = "")
    $uri = "http://localhost:1234/v1/chat/completions"
    # Get available model if none specified
    if (-not $Model) {
        try {
            $models = Invoke-RestMethod -Uri "http://localhost:1234/v1/models" -TimeoutSec 3
            if ($models.data -and $models.data.Count -gt 0) { $Model = $models.data[0].id }
        } catch { Write-Err "LM Studio not reachable on port 1234. Start LM Studio and load a model."; return $null }
    }
    $body = @{
        model    = $Model
        messages = @(
            @{ role = "system"; content = $System }
            @{ role = "user";   content = $Prompt }
        )
        max_tokens  = 2048
        temperature = 0.7
    } | ConvertTo-Json -Depth 5
    try {
        $resp = Invoke-RestMethod -Uri $uri -Method POST -ContentType "application/json" -Body $body -TimeoutSec 120
        return $resp.choices[0].message.content
    } catch { Write-Err "LM Studio request failed: $_"; return $null }
}

function LMStudio-Menu {
    do {
        Show-Header
        Write-Host "=== LM Studio ===" -ForegroundColor Yellow
        Write-Host "(LM Studio must be running with a model loaded on port 1234)" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "1. List loaded models"
        Write-Host "2. Chat with loaded model"
        Write-Host "3. Side-by-side: LM Studio vs Ollama (Forge)"
        Write-Host "4. Code task (LM Studio)"
        Write-Host "5. Security analysis (LM Studio)"
        Write-Host "6. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1" {
                try {
                    $models = Invoke-RestMethod -Uri "http://localhost:1234/v1/models" -TimeoutSec 3
                    Write-Info "LM Studio loaded models:"
                    $models.data | ForEach-Object { Write-Host "  $($_.id)" -ForegroundColor Cyan }
                } catch { Write-Err "LM Studio not reachable on port 1234." }
                Pause-Menu
            }
            "2" {
                $prompt = Read-Host "Your prompt"
                $r = Invoke-LMStudio -Prompt $prompt
                if ($r) { Write-Host "`nLM Studio:" -ForegroundColor Yellow; Write-Host $r -ForegroundColor White }
                Pause-Menu
            }
            "3" {
                $prompt = Read-Host "Prompt"
                Write-Info "Querying LM Studio..."
                $lms = Invoke-LMStudio -Prompt $prompt
                Write-Info "Querying Forge (Ollama)..."
                $forge = Invoke-OllamaWithSystem -Model $Agents["Forge"].Model -SystemPrompt $Agents["Forge"].Role -UserPrompt $prompt
                Write-Host "`n--- LM Studio ---" -ForegroundColor Yellow
                Write-Host $lms
                Write-Host "`n--- Forge (Ollama) ---" -ForegroundColor Cyan
                Write-Host $forge
                Pause-Menu
            }
            "4" {
                $task = Read-Host "Code task description"
                $r = Invoke-LMStudio -Prompt $task -System "You are an expert programmer. Write clean, working code. Output only the code."
                if ($r) { Write-Host "`n$r" -ForegroundColor White }
                Pause-Menu
            }
            "5" {
                $target = Read-Host "Paste code or describe what to analyze"
                $r = Invoke-LMStudio -Prompt $target -System "You are a security analyst. Identify vulnerabilities, risks, and recommendations."
                if ($r) { Write-Host "`n$r" -ForegroundColor White }
                Pause-Menu
            }
            "6" { return }
        }
    } while ($c -ne "6")
}

# -----------------------------
# Intelligence Hub  -  master submenu for all new enhancements
# -----------------------------
function IntelHub-Menu {
    do {
        Show-Header
        Write-Host "=== CEREBRO Intelligence Hub ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1.  Conversation History (persistent agent memory)" -ForegroundColor Cyan
        Write-Host "2.  Cloud API Fallback (OpenAI / Claude)"           -ForegroundColor Cyan
        Write-Host "3.  Clipboard AI"                                   -ForegroundColor Cyan
        Write-Host "4.  WSL Manager"                                    -ForegroundColor Cyan
        Write-Host "5.  Live Dashboard"                                 -ForegroundColor Cyan
        Write-Host "6.  Windows Event Log Watcher"                     -ForegroundColor Cyan
        Write-Host "7.  Network Scanner"                               -ForegroundColor Cyan
        Write-Host "8.  File & Code Analyzer"                          -ForegroundColor Cyan
        Write-Host "9.  Git Tools"                                      -ForegroundColor Cyan
        Write-Host "10. LM Studio"                                      -ForegroundColor Cyan
        Write-Host "11. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1"  { History-Menu }
            "2"  { CloudFallback-Menu }
            "3"  { Invoke-ClipboardAI }
            "4"  { WSL-Menu }
            "5"  { Show-LiveDashboard }
            "6"  { EventLog-Menu }
            "7"  { NetworkScanner-Menu }
            "8"  { FileAnalyzer-Menu }
            "9"  { GitTools-Menu }
            "10" { LMStudio-Menu }
            "11" { return }
            default { Speak-CHAMP "Invalid selection."; Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "11")
}

# ============================================================
# CEREBRO CONVERSATION MODE
# Text chat and voice conversation with X-Agents
# ============================================================

# Try to load speech recognition assembly (Windows built-in)
$Global:SpeechRecognitionAvailable = $false
try {
    Add-Type -AssemblyName System.Speech -ErrorAction Stop
    $Global:SpeechRecognitionAvailable = $true
} catch {}

function Invoke-SpeechRecognition {
    # Returns recognised text string, or $null if failed/timeout
    if (-not $Global:SpeechRecognitionAvailable) { return $null }
    try {
        $recognizer = New-Object System.Speech.Recognition.SpeechRecognitionEngine
        $recognizer.SetInputToDefaultAudioDevice()
        $grammar = New-Object System.Speech.Recognition.DictationGrammar
        $recognizer.LoadGrammar($grammar)
        $recognizer.InitialSilenceTimeout = [TimeSpan]::FromSeconds(5)
        $recognizer.BabbleTimeout         = [TimeSpan]::FromSeconds(3)
        $recognizer.EndSilenceTimeout     = [TimeSpan]::FromSeconds(2)
        Write-Host "  [Listening...]" -ForegroundColor Green
        $result = $recognizer.Recognize([TimeSpan]::FromSeconds(15))
        $recognizer.Dispose()
        if ($result -and $result.Text) { return $result.Text }
        return $null
    } catch {
        return $null
    }
}

# -----------------------------
# Wake Word Listener
# Listens for "Hey CEREBRO" or "CEREBRO" in the background
# Uses a grammar-constrained recognizer (not dictation) for reliability
# -----------------------------
$Global:WakeWordActive   = $false
$Global:WakeWordJob      = $null
$Global:WakeWordTrigger  = "$PSScriptRoot\.wake-trigger"

function Start-WakeWordListener {
    if (-not $Global:SpeechRecognitionAvailable) {
        Write-Warn "Speech recognition not available  -  wake word cannot start."
        Pause-Menu; return
    }
    if ($Global:WakeWordActive) {
        Write-Warn "Wake word listener is already running."
        Pause-Menu; return
    }

    # Remove any stale trigger file
    if (Test-Path $Global:WakeWordTrigger) { Remove-Item $Global:WakeWordTrigger -Force }

    # Spawn a background job that listens for the wake phrase
    # The job writes a trigger file when it hears the wake word
    $triggerPath = $Global:WakeWordTrigger
    $Global:WakeWordJob = Start-Job -ScriptBlock {
        param($triggerPath)
        Add-Type -AssemblyName System.Speech
        $recognizer = New-Object System.Speech.Recognition.SpeechRecognitionEngine
        $recognizer.SetInputToDefaultAudioDevice()

        # Dictation grammar: catches free speech, then we filter for "cerebro"
        # This is far more tolerant than constrained grammar for wake-word use
        $grammar = New-Object System.Speech.Recognition.DictationGrammar
        $recognizer.LoadGrammar($grammar)

        # Listen in a loop until the trigger file signals stop
        while (-not (Test-Path "$triggerPath.stop")) {
            try {
                $result = $recognizer.Recognize([TimeSpan]::FromSeconds(4))
                if ($result -and $result.Text) {
                    $text = $result.Text.ToLower()
                    # Match any phrase containing "cerebro" (covers "hey cerebro",
                    # "cerebro wake up", and mis-heard variants like "serebro")
                    if ($text -match 'cerebro|serebro|cerabro|cerebra') {
                        Set-Content -Path $triggerPath -Value $result.Text -Encoding UTF8
                    }
                }
            } catch {}
        }
        $recognizer.Dispose()
    } -ArgumentList $triggerPath

    $Global:WakeWordActive = $true
    Write-OK "Wake word listener started. Say 'Hey CEREBRO' at any time."
    Write-Info "CEREBRO will activate voice conversation mode when it hears you."
    Speak-CHAMP "Wake word listener is active, Carnell. Say Hey CEREBRO whenever you need me."
    Write-ActivityLog "Wake word listener started"
    Pause-Menu
}

function Stop-WakeWordListener {
    if (-not $Global:WakeWordActive) {
        Write-Warn "Wake word listener is not running."
        Pause-Menu; return
    }
    # Signal the background job to stop
    Set-Content -Path "$($Global:WakeWordTrigger).stop" -Value "stop" -Encoding UTF8
    if ($Global:WakeWordJob) {
        Stop-Job $Global:WakeWordJob -ErrorAction SilentlyContinue
        Remove-Job $Global:WakeWordJob -ErrorAction SilentlyContinue
        $Global:WakeWordJob = $null
    }
    $Global:WakeWordActive = $false
    # Clean up trigger files
    Remove-Item $Global:WakeWordTrigger       -Force -ErrorAction SilentlyContinue
    Remove-Item "$($Global:WakeWordTrigger).stop" -Force -ErrorAction SilentlyContinue
    Write-OK "Wake word listener stopped."
    Speak-CHAMP "Wake word listener deactivated."
    Write-ActivityLog "Wake word listener stopped"
    Pause-Menu
}

function Test-WakeWordMic {
    if (-not $Global:SpeechRecognitionAvailable) {
        Write-Warn "System.Speech assembly not available on this machine."
        Pause-Menu; return
    }
    Write-Host ""
    Write-Host "  MIC / WAKE WORD DIAGNOSTIC" -ForegroundColor Cyan
    Write-Host "  ----------------------------" -ForegroundColor DarkGray
    Write-Host "  Speak anything for 5 seconds. CEREBRO will show what it heard." -ForegroundColor Yellow
    Write-Host "  (If nothing shows, your mic or Windows Speech Recognition needs setup.)" -ForegroundColor DarkGray
    Write-Host ""
    try {
        $rec = New-Object System.Speech.Recognition.SpeechRecognitionEngine
        $rec.SetInputToDefaultAudioDevice()
        $rec.LoadGrammar((New-Object System.Speech.Recognition.DictationGrammar))
        $result = $rec.Recognize([TimeSpan]::FromSeconds(5))
        $rec.Dispose()
        if ($result -and $result.Text) {
            Write-Host "  Heard: " -NoNewline -ForegroundColor Gray
            Write-Host $result.Text -ForegroundColor Green
            $lower = $result.Text.ToLower()
            if ($lower -match 'cerebro|serebro|cerabro|cerebra') {
                Write-OK "  Wake word DETECTED. Listener would have triggered."
            } else {
                Write-Warn "  Wake word NOT detected in what was heard."
                Write-Host "  Tip: try saying 'Hey CEREBRO' clearly and slowly." -ForegroundColor DarkGray
            }
        } else {
            Write-Warn "  Nothing recognized. Check that:"
            Write-Host "   1. Your microphone is set as the DEFAULT recording device in Windows Sound settings." -ForegroundColor DarkGray
            Write-Host "   2. Windows Speech Recognition is set up: Start -> 'Set up Speech Recognition'." -ForegroundColor DarkGray
            Write-Host "   3. No other app is using the microphone exclusively." -ForegroundColor DarkGray
        }
    } catch {
        Write-Warn "  Error initializing microphone: $_"
        Write-Host "  Run 'Set up Speech Recognition' from the Windows Start menu to configure your mic." -ForegroundColor DarkGray
    }
    Pause-Menu
}

# -----------------------------
# Voice Command Dispatcher
# After wake word, listens for a command and routes to the right action
# -----------------------------

# Full command routing table  -  maps spoken keywords to actions
$Global:VoiceCommands = @(
    # System / Services
    @{ Keywords=@("system status","check status","cerebro status","what is the status")       ; Action="Show-SystemStatus" }
    @{ Keywords=@("start ollama","ollama start","launch ollama","run ollama")                  ; Action="Start-Ollama" }
    @{ Keywords=@("stop ollama","ollama stop","shut down ollama","kill ollama")                 ; Action="Stop-Ollama" }
    @{ Keywords=@("start webui","start web ui","open webui","launch webui","start open webui") ; Action="Start-OpenWebUI" }
    @{ Keywords=@("stop webui","stop web ui","stop open webui")                                ; Action="Stop-OpenWebUI" }
    @{ Keywords=@("restart webui","restart web ui","reboot webui")                             ; Action="Restart-OpenWebUI" }
    @{ Keywords=@("open dashboard","open web dashboard","webui dashboard","browser")           ; Action="Open-WebDashboard" }
    @{ Keywords=@("show docker","docker containers","list containers","docker status")         ; Action="Show-DockerContainers" }
    @{ Keywords=@("list models","show models","what models","ollama models")                   ; Action="List-OllamaModels" }
    @{ Keywords=@("activity log","show log","open log","view log")                             ; Action="Show-ActivityLog" }
    @{ Keywords=@("live dashboard","dashboard","war room")                                     ; Action="Show-LiveDashboard" }
    @{ Keywords=@("open vs code","open vscode","launch vs code","open code","visual studio")   ; Action="VSCode-Menu" }
    @{ Keywords=@("clipboard","send clipboard","clipboard ai")                                 ; Action="Invoke-ClipboardAI" }
    @{ Keywords=@("wolverine","health scan","health check","recover services","watchdog")      ; Action="Wolverine-HealthScan" }
    @{ Keywords=@("pull all models","download all models","update all models")                 ; Action="Pull-AgentModels" }
    @{ Keywords=@("register agents","register models","create named models","webui agents")    ; Action="Register-AgentModels" }
    @{ Keywords=@("network scan","scan network","port scan")                                   ; Action="NetworkScanner-Menu" }
    @{ Keywords=@("event log","windows errors","system errors","check errors")                 ; Action="EventLog-Menu" }
    @{ Keywords=@("git status","git tools","git")                                              ; Action="GitTools-Menu" }
    @{ Keywords=@("devops","dev ops control","proxmox","terraform","ansible")                  ; Action="DevOps-Menu" }
    @{ Keywords=@("ai tools","dev tools","development tools")                                  ; Action="AIDevTools-Menu" }
    @{ Keywords=@("agent map","show agents","list agents","show roster")                       ; Action="Show-AgentMap" }
    @{ Keywords=@("backup","back up","restore")                                                ; Action="# Backup (no direct function  -  go to AI tools)" }
)

# Agent launch keywords  -  "launch forge", "activate beast", "use cyclops" etc.
$Global:VoiceAgentKeywords = @("launch","activate","start agent","use","run","open","wake up","call","bring up","switch to","talk to","chat with","speak to")

function Invoke-VoiceCommand {
    param([string]$CommandText)

    $cmd = $CommandText.ToLower().Trim()
    Write-Host "  [Command: '$cmd']" -ForegroundColor DarkGray

    # --- Check for agent launch commands ---
    $agentMatch = $null
    foreach ($kw in $Global:VoiceAgentKeywords) {
        if ($cmd -like "*$kw*") {
            # Try to match an agent name in the remaining text
            foreach ($agentName in $Agents.Keys) {
                $shortName = $agentName.ToLower().Replace("-"," ")
                if ($cmd -like "*$shortName*" -or $cmd -like "*$($agentName.ToLower())*") {
                    $agentMatch = $agentName
                    break
                }
            }
        }
        if ($agentMatch) { break }
    }

    # Also match agent names directly without a verb  -  "forge", "professor x", etc.
    if (-not $agentMatch) {
        foreach ($agentName in $Agents.Keys) {
            $shortName = $agentName.ToLower().Replace("-"," ")
            if ($cmd -eq $shortName -or $cmd -eq $agentName.ToLower()) {
                $agentMatch = $agentName
                break
            }
        }
    }

    if ($agentMatch) {
        # "chat with" or "talk to" → conversation mode; otherwise → one-shot activation
        $chatVerbs = @("chat with","talk to","speak to","conversation with","speak with")
        $isChatMode = $false
        foreach ($v in $chatVerbs) { if ($cmd -like "*$v*") { $isChatMode = $true; break } }

        if ($isChatMode) {
            Speak-CHAMP "Opening conversation with $agentMatch, Carnell."
            CEREBRO-ChatMode -AgentName $agentMatch -VoiceInput $true
        } else {
            Speak-CHAMP "Launching $agentMatch, Carnell."
            Write-ActivityLog "Voice command: launch $agentMatch"
            if ($agentMatch -eq "Scout" -or $agentMatch -eq "Rogue" -or $agentMatch -eq "Longshot") {
                Activate-Scout
            } else {
                Activate-Agent $agentMatch
            }
        }
        return
    }

    # --- Check action commands ---
    $matched = $false
    foreach ($entry in $Global:VoiceCommands) {
        foreach ($kw in $entry.Keywords) {
            if ($cmd -like "*$kw*") {
                $action = $entry.Action
                Write-ActivityLog "Voice command: $action"
                switch ($action) {
                    "Show-SystemStatus"   { Speak-CHAMP "Checking system status.";             Show-SystemStatus }
                    "Start-Ollama"        { Speak-CHAMP "Starting Ollama.";                    Start-Ollama }
                    "Stop-Ollama"         { Speak-CHAMP "Stopping Ollama.";                    Stop-Ollama }
                    "Start-OpenWebUI"     { Speak-CHAMP "Starting Open WebUI.";                Start-OpenWebUI }
                    "Stop-OpenWebUI"      { Speak-CHAMP "Stopping Open WebUI.";                Stop-OpenWebUI }
                    "Restart-OpenWebUI"   { Speak-CHAMP "Restarting Open WebUI.";              Restart-OpenWebUI }
                    "Open-WebDashboard"   { Speak-CHAMP "Opening Open WebUI dashboard.";       Open-WebDashboard }
                    "Show-DockerContainers"{ Speak-CHAMP "Showing Docker containers.";         Show-DockerContainers }
                    "List-OllamaModels"   { Speak-CHAMP "Listing Ollama models.";              List-OllamaModels }
                    "Show-ActivityLog"    { Speak-CHAMP "Opening activity log.";               Show-ActivityLog }
                    "Show-LiveDashboard"  { Speak-CHAMP "Launching live dashboard.";           Show-LiveDashboard }
                    "VSCode-Menu"         { Speak-CHAMP "Opening VS Code integration.";        VSCode-Menu }
                    "Invoke-ClipboardAI"  { Speak-CHAMP "Sending clipboard to an agent.";      Invoke-ClipboardAI }
                    "Wolverine-HealthScan"{ Speak-CHAMP "Running Wolverine health scan.";      Wolverine-HealthScan }
                    "Pull-AgentModels"    { Speak-CHAMP "Pulling all agent models.";           Pull-AgentModels }
                    "Register-AgentModels"{ Speak-CHAMP "Registering agents in Open WebUI.";   Register-AgentModels }
                    "NetworkScanner-Menu" { Speak-CHAMP "Opening network scanner.";            NetworkScanner-Menu }
                    "EventLog-Menu"       { Speak-CHAMP "Opening Windows event log watcher.";  EventLog-Menu }
                    "GitTools-Menu"       { Speak-CHAMP "Opening git tools.";                  GitTools-Menu }
                    "DevOps-Menu"         { Speak-CHAMP "Opening DevOps control panel.";       DevOps-Menu }
                    "AIDevTools-Menu"     { Speak-CHAMP "Opening AI development tools.";       AIDevTools-Menu }
                    "Show-AgentMap"       { Speak-CHAMP "Displaying agent roster.";            Show-AgentMap }
                    default {
                        Speak-CHAMP "I recognized the command but could not execute it directly. Please use the menu."
                    }
                }
                $matched = $true
                break
            }
        }
        if ($matched) { break }
    }

    # --- Fallback: treat as a question for Professor-X ---
    if (-not $matched) {
        Speak-CHAMP "I will ask Professor X."
        $response = Invoke-OllamaWithSystem `
            -Model $Agents["Professor-X"].Model `
            -SystemPrompt $AgentSystemPrompts["Professor-X"] `
            -UserPrompt $CommandText
        if ($response) {
            $speakText = if ($response.Length -gt 400) { $response.Substring(0,400) + "... full answer on screen." } else { $response }
            Write-Host "`nProfessor-X > " -ForegroundColor Yellow -NoNewline
            Write-Host $response -ForegroundColor White
            Speak-CHAMP $speakText
            Add-AgentHistory -Agent "Professor-X" -Role "user"      -Content $CommandText
            Add-AgentHistory -Agent "Professor-X" -Role "assistant" -Content $response
        }
    }
}

function Test-WakeWordTriggered {
    # Called each time the main menu loop runs  -  checks for trigger file
    if (-not $Global:WakeWordActive) { return }
    if (Test-Path $Global:WakeWordTrigger) {
        $phrase = Get-Content $Global:WakeWordTrigger -Raw -ErrorAction SilentlyContinue
        Remove-Item $Global:WakeWordTrigger -Force -ErrorAction SilentlyContinue
        if ($phrase) {
            [console]::beep(900,100); [console]::beep(1100,150)
            Write-Host ""
            Write-Host "  [Wake word detected]" -ForegroundColor Green
            Speak-CHAMP "Yes, Carnell. What would you like me to do?"

            # Listen for the actual command
            $command = Invoke-SpeechRecognition
            if ($command) {
                Write-Host "  [You said: '$command']" -ForegroundColor Cyan
                Invoke-VoiceCommand -CommandText $command
            } else {
                # No voice heard  -  drop into text command entry
                Write-Host ""
                $command = Read-Host "  Command (or Enter for voice chat)"
                if ([string]::IsNullOrWhiteSpace($command)) {
                    CEREBRO-ChatMode -AgentName "Professor-X" -VoiceInput $true
                } else {
                    Invoke-VoiceCommand -CommandText $command
                }
            }
        }
    }
}

function CEREBRO-ChatMode {
    param(
        [string]$AgentName   = "Professor-X",
        [bool]$VoiceInput    = $false
    )

    $modelInfo = $Agents[$AgentName]
    if (-not $modelInfo) {
        # Default to Nightcrawler for general chat if agent not found
        $AgentName = "Nightcrawler"
        $modelInfo = $Agents[$AgentName]
    }

    $model  = $modelInfo.Model
    $system = if ($AgentSystemPrompts[$AgentName]) {
        $AgentSystemPrompts[$AgentName]
    } else {
        $modelInfo.Role
    }

    Show-Header
    Write-Host "=== CEREBRO Conversation  -  $AgentName ===" -ForegroundColor Yellow
    if ($VoiceInput) {
        Write-Host "  Voice mode ON   -  speak after [Listening...] appears" -ForegroundColor Green
    } else {
        Write-Host "  Text mode  -  type your message, or 'exit' to leave" -ForegroundColor DarkGray
    }
    Write-Host "  Type 'switch' to change agent   'clear' to reset history" -ForegroundColor DarkGray
    Write-Host "  Type 'voice on' / 'voice off' to toggle microphone input" -ForegroundColor DarkGray
    Write-Host ""

    Speak-CHAMP "CEREBRO conversation mode active. You are now speaking with $AgentName. How can I help you, Carnell?"

    while ($true) {
        Write-Host ""
        Write-Host "Carnell > " -ForegroundColor Cyan -NoNewline

        $userInput = $null

        if ($VoiceInput) {
            $userInput = Invoke-SpeechRecognition
            if ($userInput) {
                Write-Host $userInput -ForegroundColor White
            } else {
                Write-Host "(no speech detected  -  type your message or say something)" -ForegroundColor DarkGray
                $userInput = Read-Host ""
            }
        } else {
            $userInput = Read-Host ""
        }

        if ([string]::IsNullOrWhiteSpace($userInput)) { continue }

        # Commands
        switch ($userInput.ToLower().Trim()) {
            "exit"       { Speak-CHAMP "Ending conversation. Goodbye, Carnell."; return }
            "quit"       { Speak-CHAMP "Ending conversation. Goodbye, Carnell."; return }
            "bye"        { Speak-CHAMP "Goodbye, Carnell."; return }
            "clear"      {
                Clear-AgentHistory -Agent $AgentName
                Speak-CHAMP "Conversation history cleared. Fresh start, Carnell."
                continue
            }
            "voice on"   {
                if ($Global:SpeechRecognitionAvailable) {
                    $VoiceInput = $true
                    Speak-CHAMP "Voice input enabled. I am listening, Carnell."
                } else {
                    Write-Warn "Speech recognition not available on this system."
                }
                continue
            }
            "voice off"  {
                $VoiceInput = $false
                Speak-CHAMP "Voice input disabled. Back to text mode."
                continue
            }
            "switch"     {
                Write-Host ""
                Write-Host "Available agents:" -ForegroundColor Yellow
                $agentNames = $Agents.Keys | Sort-Object
                $i = 1
                foreach ($a in $agentNames) { Write-Host "  $i. $a"; $i++ }
                $pick = Read-Host "Agent number"
                if ($pick -match '^\d+$') {
                    $idx = [int]$pick - 1
                    $newAgent = @($agentNames)[$idx]
                    if ($newAgent) {
                        $AgentName = $newAgent
                        $modelInfo = $Agents[$AgentName]
                        $model     = $modelInfo.Model
                        $system    = if ($AgentSystemPrompts[$AgentName]) { $AgentSystemPrompts[$AgentName] } else { $modelInfo.Role }
                        Speak-CHAMP "Switching to $AgentName. Standing by, Carnell."
                    }
                }
                continue
            }
        }

        # Build context from history
        $history = Get-AgentHistory -Agent $AgentName -MaxEntries 10
        $contextBlock = ""
        if ($history.Count -gt 0) {
            $contextBlock = "Previous conversation:`n"
            foreach ($h in $history) { $contextBlock += "$($h.role.ToUpper()): $($h.content)`n" }
            $contextBlock += "`nCurrent message:"
        }
        $fullPrompt = if ($contextBlock) { "$contextBlock`n$userInput" } else { $userInput }

        # Save user turn
        Add-AgentHistory -Agent $AgentName -Role "user" -Content $userInput

        # Get response (streaming)
        Write-Host ""
        Write-Host "$AgentName > " -ForegroundColor Yellow -NoNewline
        $response = Invoke-OllamaStream -Model $model -Prompt $fullPrompt -SystemPrompt $system

        if ($response) {
            Add-AgentHistory -Agent $AgentName -Role "assistant" -Content $response

            # Speak  -  truncate very long responses for voice
            $speakText = if ($response.Length -gt 600) {
                $response.Substring(0, 600) + "... response continues on screen."
            } else { $response }
            Speak-CHAMP $speakText

            Write-ActivityLog "CEREBRO Chat [$AgentName]: $($userInput.Substring(0,[Math]::Min(60,$userInput.Length)))"
        } else {
            Speak-CHAMP "I did not get a response. Please check that Ollama is running, Carnell."
        }
    }
}

function Chat-Menu {
    do {
        Show-Header
        Write-Host "=== CEREBRO Conversation Mode ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Chat with Professor-X  (strategy & planning)"    -ForegroundColor Cyan
        Write-Host "2. Chat with Forge        (code & dev)"             -ForegroundColor Cyan
        Write-Host "3. Chat with Gambit       (long context chat)"      -ForegroundColor Cyan
        Write-Host "4. Chat with Nightcrawler (quick questions)"        -ForegroundColor Cyan
        Write-Host "5. Chat with any agent    (choose from full roster)" -ForegroundColor Cyan
        Write-Host ""
        if ($Global:SpeechRecognitionAvailable) {
            Write-Host "6. VOICE conversation with Professor-X" -ForegroundColor Green
            Write-Host "7. VOICE conversation  -  choose agent"   -ForegroundColor Green
        } else {
            Write-Host "6. Voice input not available (System.Speech not found)" -ForegroundColor DarkGray
        }
        Write-Host ""
        if ($Global:WakeWordActive) {
            Write-Host "8. Stop wake word listener  [ACTIVE]" -ForegroundColor Green
        } else {
            Write-Host "8. Start wake word listener (say 'Hey CEREBRO' anytime)" -ForegroundColor DarkGreen
        }
        Write-Host "9. Test Microphone / Wake Word (diagnostic)" -ForegroundColor DarkYellow
        Write-Host "10. Back"
        Write-Host ""
        Write-Host "  In conversation: type 'exit' to leave, 'switch' to change agent," -ForegroundColor DarkGray
        Write-Host "  'voice on/off' to toggle mic, 'clear' to reset memory." -ForegroundColor DarkGray
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1" { CEREBRO-ChatMode -AgentName "Professor-X" -VoiceInput $false }
            "2" { CEREBRO-ChatMode -AgentName "Forge"       -VoiceInput $false }
            "3" { CEREBRO-ChatMode -AgentName "Gambit"      -VoiceInput $false }
            "4" { CEREBRO-ChatMode -AgentName "Nightcrawler"-VoiceInput $false }
            "5" {
                $agentNames = $Agents.Keys | Sort-Object
                $i = 1; foreach ($a in $agentNames) { Write-Host "$i. $a"; $i++ }
                $pick = Read-Host "Agent number"
                if ($pick -match '^\d+$') {
                    $agent = @($agentNames)[[int]$pick - 1]
                    if ($agent) { CEREBRO-ChatMode -AgentName $agent -VoiceInput $false }
                }
            }
            "6" {
                if ($Global:SpeechRecognitionAvailable) {
                    CEREBRO-ChatMode -AgentName "Professor-X" -VoiceInput $true
                } else { Write-Warn "Voice input not available."; Pause-Menu }
            }
            "7" {
                if ($Global:SpeechRecognitionAvailable) {
                    $agentNames = $Agents.Keys | Sort-Object
                    $i = 1; foreach ($a in $agentNames) { Write-Host "$i. $a"; $i++ }
                    $pick = Read-Host "Agent number"
                    if ($pick -match '^\d+$') {
                        $agent = @($agentNames)[[int]$pick - 1]
                        if ($agent) { CEREBRO-ChatMode -AgentName $agent -VoiceInput $true }
                    }
                } else { Write-Warn "Voice input not available."; Pause-Menu }
            }
            "8" {
                if ($Global:WakeWordActive) { Stop-WakeWordListener } else { Start-WakeWordListener }
            }
            "9" { Test-WakeWordMic }
            "10" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "10")
}

# -----------------------------
# Sub-menus
# -----------------------------
function Agent-Category-Lightning {
    do {
        Show-Header
        Write-Host "=== LIGHTNING FAST  -  Tiny Models (runs on any hardware) ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Dazzler      - llama3.2:1b  (~1GB)   - Absolute fastest, trivial lookups"
        Write-Host "2. Jubilee      - llama3.2:3b  (~2GB)   - Ultra-fast, young and snappy"
        Write-Host "3. Nightcrawler - phi3:mini    (~2.2GB) - Fast lightweight assistant"
        Write-Host "4. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1" { Activate-Agent "Dazzler" }
            "2" { Activate-Agent "Jubilee" }
            "3" { Activate-Agent "Nightcrawler" }
            "4" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "4")
}

function Agent-Category-Core {
    do {
        Show-Header
        Write-Host "=== CORE TEAM  -  7-9B Workhorses (runs on 16GB+ RAM) ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1.  Professor-X - llama3.1:8b      - Strategy & planning"
        Write-Host "2.  Forge       - qwen2.5-coder:7b - Coding & infrastructure"
        Write-Host "3.  Cyclops     - mistral:7b        - Cybersecurity & analysis"
        Write-Host "4.  Wolverine   - phi3:mini         - Recovery & resilience"
        Write-Host "5.  Magneto     - codellama:7b      - Experimental engineering"
        Write-Host "6.  Beast       - deepseek-r1:7b   - Scientific reasoning"
        Write-Host "7.  Storm       - gemma2:9b         - Creative writing"
        Write-Host "8.  Psylocke    - qwen2.5:7b        - Multilingual & structured"
        Write-Host "9.  Havok       - openchat:7b       - Natural conversation"
        Write-Host "10. Bishop      - solar:10.7b       - Balanced all-rounder"
        Write-Host "11. Sage        - mathstral:7b      - Mathematics specialist"
        Write-Host "12. Cypher      - sqlcoder:7b       - SQL & data specialist"
        Write-Host "13. Moira       - meditron:7b       - Medical & health AI"
        Write-Host "14. Cannonball  - granite3.1-dense:8b - IBM enterprise"
        Write-Host "15. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1"  { Activate-Agent "Professor-X" }
            "2"  { Activate-Agent "Forge" }
            "3"  { Activate-Agent "Cyclops" }
            "4"  { Activate-Agent "Wolverine" }
            "5"  { Activate-Agent "Magneto" }
            "6"  { Activate-Agent "Beast" }
            "7"  { Activate-Agent "Storm" }
            "8"  { Activate-Agent "Psylocke" }
            "9"  { Activate-Agent "Havok" }
            "10" { Activate-Agent "Bishop" }
            "11" { Activate-Agent "Sage" }
            "12" { Activate-Agent "Cypher" }
            "13" { Activate-Agent "Moira" }
            "14" { Activate-Agent "Cannonball" }
            "15" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "15")
}

function Agent-Category-Enhanced {
    do {
        Show-Header
        Write-Host "=== ENHANCED  -  10-22B Models (runs on 24-32GB RAM) ===" -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host "1. Gambit      - mistral-nemo:12b   (~7GB)  - Long context conversation"
        Write-Host "2. Cable       - nous-hermes2:10.7b (~6GB)  - Precise instruction following"
        Write-Host "3. Sunfire     - gemma3:12b         (~8GB)  - Google Gemma 3 latest"
        Write-Host "4. Banshee     - phi4:14b           (~9GB)  - Microsoft Phi-4 precision"
        Write-Host "5. Mr-Sinister - deepseek-r1:14b    (~9GB)  - Deep analytical reasoning"
        Write-Host "6. Iceman      - starcoder2:15b     (~9GB)  - Pure code 80+ languages"
        Write-Host "7. Shadowcat   - codestral:22b      (~13GB) - Mistral code specialist"
        Write-Host "8. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1" { Activate-Agent "Gambit" }
            "2" { Activate-Agent "Cable" }
            "3" { Activate-Agent "Sunfire" }
            "4" { Activate-Agent "Banshee" }
            "5" { Activate-Agent "Mr-Sinister" }
            "6" { Activate-Agent "Iceman" }
            "7" { Activate-Agent "Shadowcat" }
            "8" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "8")
}

function Agent-Category-Vision {
    do {
        Show-Header
        Write-Host "=== VISION AGENTS  -  Multimodal Models ===" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "1. Scout    - llava:7b               (~4.7GB) - Standard vision agent"
        Write-Host "2. Rogue    - llava:13b              (~8GB)   - Enhanced vision detail"
        Write-Host "3. Longshot - llama3.2-vision:11b   (~8GB)   - Multimodal Llama"
        Write-Host "4. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1" { Activate-Scout }
            "2" { Activate-Agent "Rogue" }
            "3" { Activate-Agent "Longshot" }
            "4" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "4")
}

function Agent-Category-HeavyHitters {
    do {
        Show-Header
        Write-Host "=== HEAVY HITTERS  -  26-70B Models (needs 48GB+ RAM or GPU) ===" -ForegroundColor Red
        Write-Host ""
        Write-Host "1. Legion     - mixtral:8x7b    (~26GB) - Mixture of experts MoE"
        Write-Host "2. Emma-Frost - command-r:35b   (~20GB) - 128K context long documents"
        Write-Host "3. Colossus   - llama3.1:70b    (~40GB) - Strongest 70B general"
        Write-Host "4. Phoenix    - llama3.3:70b    (~40GB) - Latest 70B powerhouse"
        Write-Host "5. Stryfe     - deepseek-r1:70b (~40GB) - 70B deep reasoning"
        Write-Host ""
        Write-Host "6. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1" { Activate-Agent "Legion" }
            "2" { Activate-Agent "Emma-Frost" }
            "3" { Activate-Agent "Colossus" }
            "4" { Activate-Agent "Phoenix" }
            "5" { Activate-Agent "Stryfe" }
            "6" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "6")
}

function Agent-Category-Titans {
    do {
        Show-Header
        Write-Host "=== TITANS  -  100B+ Models (upgrade required: 96GB+ RAM) ===" -ForegroundColor DarkRed
        Write-Host ""
        Write-Host "1. Onslaught  - mixtral:8x22b       (~80GB)  - Largest MoE model"
        Write-Host "2. Apocalypse - command-r-plus:104b (~60GB)  - 104B ultimate context"
        Write-Host ""
        Write-Host "3. Back"
        Write-Host ""
        $c = Read-Host "Select"
        switch ($c) {
            "1" { Activate-Agent "Onslaught" }
            "2" { Activate-Agent "Apocalypse" }
            "3" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($c -ne "3")
}

function Show-AgentMenu {
    Show-Header
    Write-Info "X-Agent Launcher  -  34 Agents"
    Write-Info "-----------------------------"
    Write-Host "1. Lightning Fast    - Dazzler, Jubilee, Nightcrawler (1-3B)" -ForegroundColor Yellow
    Write-Host "2. Core Team         - 14 agents, 7-10B workhorses"           -ForegroundColor Cyan
    Write-Host "3. Enhanced          - 7 agents, 10-22B specialists"          -ForegroundColor DarkCyan
    Write-Host "4. Vision Agents     - Scout, Rogue, Longshot (multimodal)"   -ForegroundColor Magenta
    Write-Host "5. Heavy Hitters     - 5 agents, 26-70B (needs 48GB+)"        -ForegroundColor Red
    Write-Host "6. Titans            - Onslaught, Apocalypse (100B+)"         -ForegroundColor DarkRed
    Write-Host "7. Run Custom Model"
    Write-Host "8. Quick Query (one-shot prompt)"
    Write-Host "9. Smart Agent Router"
    Write-Host "10. Back"
}

function Agent-Menu {
    do {
        Show-AgentMenu
        $choice = Read-Host "Select category"
        switch ($choice) {
            "1"  { Agent-Category-Lightning }
            "2"  { Agent-Category-Core }
            "3"  { Agent-Category-Enhanced }
            "4"  { Agent-Category-Vision }
            "5"  { Agent-Category-HeavyHitters }
            "6"  { Agent-Category-Titans }
            "7"  { Run-CustomModel }
            "8"  { Quick-QueryAgent }
            "9"  { Smart-RouteAgent }
            "10" { return }
            default { Speak-CHAMP "Invalid agent selection."; Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "10")
}

function Show-WolverineMenu {
    Show-Header
    Write-Info "Wolverine Recovery Center"
    Write-Info "-------------------------"
    Write-Host "1. Wolverine Health Scan"
    Write-Host "2. Wolverine Recover Services"
    Write-Host "3. Wolverine Emergency Restart"
    Write-Host "9. Add/Repair Hosts Entry (champ-ai-Control-center)"
    Write-Host "4. Back"
}

function Wolverine-Menu {
    do {
        Show-WolverineMenu
        $choice = Read-Host "Select Wolverine action"
        switch ($choice) {
            "1" { Wolverine-HealthScan }
            "2" { Wolverine-RecoverServices }
            "3" { Wolverine-EmergencyRestart }
            "9" { Install-HostsEntry }
            "4" { return }
            default { Speak-CHAMP "Invalid Wolverine selection."; Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "4")
}

# ============================================================
# AGENT OPERATIONS, CHAMP-QN, WHISPER, THREAT INTEL, ZERO TRUST, AUDIT
# ============================================================

$Global:CHAMPMode   = "Default"
$PerformanceFile    = "$PSScriptRoot\CHAMP-Memory\agent-metrics.json"
$SchedulerFile      = "$PSScriptRoot\CHAMP-Memory\scheduled-tasks.json"
$AuditFile          = "$PSScriptRoot\CHAMP-Memory\audit-trail.json"
$CustomAgentsFile   = "$PSScriptRoot\CHAMP-Memory\custom-agents.json"
$CHAMPQNConfigFile  = "$PSScriptRoot\.champqn-config.json"

# -------------------------------------------------------
# Whisper Local STT
# -------------------------------------------------------
function Test-WhisperAvailable {
    try { $r = python -c "import whisper" 2>&1; return ($r -notmatch "Error|No module") } catch { return $false }
}

function Install-WhisperSTT {
    Show-Header
    if (-not (Test-CommandExists "python")) { Write-Err "Python not found. Install Python 3.9+ from python.org."; Pause-Menu; return }
    Write-Info "Installing OpenAI Whisper..."
    pip install openai-whisper sounddevice numpy 2>&1 | Write-Host
    $helperPath = "$PSScriptRoot\whisper-listen.py"
    Set-Content $helperPath -Encoding UTF8 -Value @'
import sys, whisper, sounddevice as sd, numpy as np
duration   = int(sys.argv[1]) if len(sys.argv) > 1 else 5
model_size = sys.argv[2]      if len(sys.argv) > 2 else "base"
model  = whisper.load_model(model_size)
audio  = sd.rec(int(duration * 16000), samplerate=16000, channels=1, dtype="float32")
sd.wait()
result = model.transcribe(audio.flatten(), fp16=False)
print(result["text"].strip())
'@
    Write-OK "Whisper installed. Script: $helperPath"; Pause-Menu
}

function Invoke-WhisperListen {
    param([int]$DurationSeconds = 5, [string]$ModelSize = "base")
    if (-not (Test-WhisperAvailable)) { return (Invoke-SpeechRecognition) }
    $helperPath = "$PSScriptRoot\whisper-listen.py"
    if (-not (Test-Path $helperPath)) { return (Invoke-SpeechRecognition) }
    Write-Info "Listening $DurationSeconds seconds (Whisper)..."
    try { $r = python $helperPath $DurationSeconds $ModelSize 2>$null; if ($r) { return $r.Trim() } } catch {}
    return (Invoke-SpeechRecognition)
}

# -------------------------------------------------------
# Multi-Agent Collaboration
# -------------------------------------------------------
function Invoke-AgentCouncil {
    Show-Header
    Write-Info "Multi-Agent Council"; Write-Info "-------------------"
    $task = Read-Host "Task or question for the council"
    $councilAgents = @("Professor-X","Forge","Cyclops","Beast")
    $responses = @{}
    Write-Info "Round 1 - Independent responses..."
    foreach ($agent in $councilAgents) {
        Write-Host "  $agent thinking..." -ForegroundColor DarkCyan
        $prompt = "$($AgentSystemPrompts[$agent])`n`nTask: $task`n`nProvide your expert perspective and recommendation."
        $body = @{ model=$Agents[$agent].Model; prompt=$prompt; stream=$false } | ConvertTo-Json
        try {
            $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 180
            $responses[$agent] = $resp.response; Write-Host "  $agent done." -ForegroundColor Green
        } catch { $responses[$agent] = "Error: $_"; Write-Warn "$agent failed." }
    }
    Write-Info "Round 2 - Professor-X synthesizing..."
    $allResponses = ""; foreach ($a in $councilAgents) { $allResponses += "=== $a ===`n$($responses[$a])`n`n" }
    $synthPrompt = "$($AgentSystemPrompts["Professor-X"])`n`nYou have council perspectives on: $task`n`n$allResponses`n`nSynthesize into one comprehensive actionable recommendation."
    $synthBody = @{ model=$Agents["Professor-X"].Model; prompt=$synthPrompt; stream=$false } | ConvertTo-Json
    try {
        $synthResp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $synthBody -ContentType "application/json" -TimeoutSec 180
        Write-Host ""; Write-Host "COUNCIL SYNTHESIS" -ForegroundColor Yellow; Write-Host "=================" -ForegroundColor Yellow
        Write-Host $synthResp.response -ForegroundColor Cyan
        $sessDir = "$PSScriptRoot\CHAMP-Sessions"
        if (-not (Test-Path $sessDir)) { New-Item -ItemType Directory -Path $sessDir | Out-Null }
        $outFile = "$sessDir\Council-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
        $md = "# Agent Council`n`n**Task:** $task`n`n**Date:** $(Get-Date)`n`n"
        foreach ($a in $councilAgents) { $md += "## $a`n`n$($responses[$a])`n`n---`n`n" }
        $md += "## Synthesis`n`n$($synthResp.response)"
        Set-Content $outFile -Value $md -Encoding UTF8
        Write-OK "Saved to $outFile"; Speak-CHAMP "The council has reached a consensus."
    } catch { Write-Err "Synthesis failed: $_" }
    Pause-Menu
}

function Invoke-AgentChain {
    Show-Header; Write-Info "Agent Chain Pipeline"; Write-Info "--------------------"
    $task = Read-Host "Initial task"
    $availableAgents = $Agents.Keys | Sort-Object
    $chain = @()
    Write-Info "Build chain (blank to start):"
    for ($i = 1; $i -le 5; $i++) {
        for ($j = 0; $j -lt $availableAgents.Count; $j++) { Write-Host "  $($j+1). $($availableAgents[$j])" }
        $sel = Read-Host "Agent $i (or blank to start)"
        if ([string]::IsNullOrWhiteSpace($sel)) { break }
        if ($sel -match "^\d+$") { $idx=[int]$sel-1; if ($idx -ge 0 -and $idx -lt $availableAgents.Count) { $chain += $availableAgents[$idx] } }
    }
    if ($chain.Count -eq 0) { Write-Warn "No agents selected."; Pause-Menu; return }
    Write-Info "Chain: $($chain -join ' -> ')"; $currentInput = $task; $chainLog = @()
    foreach ($agent in $chain) {
        Write-Host ""; Write-Host "[$agent] Processing..." -ForegroundColor Cyan
        $prompt = "$($AgentSystemPrompts[$agent])`n`nChain step $($chain.IndexOf($agent)+1). Previous output:`n$currentInput`n`nProcess and improve."
        $body = @{ model=$Agents[$agent].Model; prompt=$prompt; stream=$false } | ConvertTo-Json
        try {
            $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 180
            $currentInput = $resp.response; $chainLog += @{ Agent=$agent; Output=$resp.response }
            Write-Host $resp.response -ForegroundColor White; Write-Host "---" -ForegroundColor DarkGray
        } catch { Write-Warn "$agent failed: $_" }
    }
    $sessDir = "$PSScriptRoot\CHAMP-Sessions"
    if (-not (Test-Path $sessDir)) { New-Item -ItemType Directory -Path $sessDir | Out-Null }
    $md = "# Agent Chain: $($chain -join ' -> ')`n`n**Task:** $task`n`n**Date:** $(Get-Date)`n`n"
    foreach ($entry in $chainLog) { $md += "## $($entry.Agent)`n`n$($entry.Output)`n`n---`n`n" }
    Set-Content "$sessDir\Chain-$(Get-Date -Format 'yyyyMMdd-HHmmss').md" -Value $md -Encoding UTF8
    Write-OK "Chain saved."; Speak-CHAMP "Agent chain complete."; Pause-Menu
}

# -------------------------------------------------------
# Agent Performance Tracker
# -------------------------------------------------------
function Record-AgentMetric {
    param([string]$AgentName, [double]$ResponseTimeSeconds, [string]$TaskType = "general")
    try {
        Initialize-MemoryLayer
        $metrics = if (Test-Path $PerformanceFile) { Get-Content $PerformanceFile -Raw | ConvertFrom-Json } else { @() }
        $metrics += @{ Agent=$AgentName; Time=$ResponseTimeSeconds; TaskType=$TaskType; Date=(Get-Date -Format "yyyy-MM-dd HH:mm") }
        $metrics | ConvertTo-Json -Depth 5 | Set-Content $PerformanceFile -Encoding UTF8
    } catch {}
}

function Show-AgentPerformance {
    Show-Header; Initialize-MemoryLayer
    if (-not (Test-Path $PerformanceFile)) { Write-Warn "No metrics yet."; Pause-Menu; return }
    $metrics = Get-Content $PerformanceFile -Raw | ConvertFrom-Json
    if ($metrics.Count -eq 0) { Write-Warn "No metrics recorded."; Pause-Menu; return }
    Write-Info "Agent Performance Report"; Write-Info "------------------------"
    $grouped = $metrics | Group-Object Agent
    foreach ($g in $grouped | Sort-Object Name) {
        $avg = [Math]::Round(($g.Group | Measure-Object Time -Average).Average, 2)
        $min = [Math]::Round(($g.Group | Measure-Object Time -Minimum).Minimum, 2)
        $max = [Math]::Round(($g.Group | Measure-Object Time -Maximum).Maximum, 2)
        Write-Host ""; Write-Host "  $($g.Name)" -ForegroundColor Yellow
        Write-Host "  Queries: $($g.Count)  Avg: ${avg}s  Min: ${min}s  Max: ${max}s"
    }
    $fastest = ($grouped | Sort-Object { ($_.Group | Measure-Object Time -Average).Average } | Select-Object -First 1).Name
    Write-Host ""; Write-Host "  Fastest: $fastest" -ForegroundColor Green; Pause-Menu
}

function Reset-AgentMetrics {
    Show-Header
    if ((Read-Host "Reset all agent metrics? (YES)") -eq "YES") {
        Set-Content $PerformanceFile -Value "[]" -Encoding UTF8; Write-OK "Metrics reset."
    }
    Pause-Menu
}

# -------------------------------------------------------
# Scheduled Autonomous Tasks
# -------------------------------------------------------
function Initialize-Scheduler {
    Initialize-MemoryLayer
    if (-not (Test-Path $SchedulerFile)) { Set-Content $SchedulerFile -Value "[]" -Encoding UTF8 }
}

function New-ScheduledAgentTask {
    Show-Header; Initialize-Scheduler
    $name     = Read-Host "Task name"
    $agent    = Read-Host "Agent (e.g. Cyclops, Professor-X)"
    if (-not $Agents.ContainsKey($agent)) { Write-Err "Unknown agent '$agent'."; Pause-Menu; return }
    $prompt   = Read-Host "Prompt for the agent"
    Write-Host "1. Hourly  2. Daily  3. Weekly  4. On Launch"
    $interval = Read-Host "Interval"
    $intervalName = switch ($interval) { "1"{"Hourly"} "2"{"Daily"} "3"{"Weekly"} default{"OnLaunch"} }
    $tasks = Get-Content $SchedulerFile -Raw | ConvertFrom-Json
    $tasks += @{ Id=[guid]::NewGuid().ToString(); Name=$name; Agent=$agent; Prompt=$prompt; Interval=$intervalName; Created=(Get-Date -Format "yyyy-MM-dd HH:mm"); LastRun=$null; Enabled=$true }
    $tasks | ConvertTo-Json -Depth 10 | Set-Content $SchedulerFile -Encoding UTF8
    Write-OK "Scheduled task '$name' created ($intervalName)."; Pause-Menu
}

function List-ScheduledTasks {
    Show-Header; Initialize-Scheduler
    $tasks = Get-Content $SchedulerFile -Raw | ConvertFrom-Json
    if (-not $tasks -or $tasks.Count -eq 0) { Write-Warn "No scheduled tasks."; Pause-Menu; return }
    Write-Info "Scheduled Tasks"; Write-Info "---------------"
    foreach ($t in $tasks) {
        $status = if ($t.Enabled) { "ENABLED" } else { "DISABLED" }
        Write-Host ""; Write-Host "  $($t.Name) [$status]" -ForegroundColor Yellow
        Write-Host "  Agent: $($t.Agent)  Interval: $($t.Interval)"
        Write-Host "  Last Run: $(if($t.LastRun){$t.LastRun}else{'Never'})"
    }
    Pause-Menu
}

function Run-DueScheduledTasks {
    Initialize-Scheduler
    $tasks = Get-Content $SchedulerFile -Raw | ConvertFrom-Json
    $now = Get-Date; $modified = $false
    foreach ($task in $tasks) {
        if (-not $task.Enabled) { continue }
        $isDue = if (-not $task.LastRun) { $task.Interval -eq "OnLaunch" }
                 else {
                     $lastRun = [datetime]::Parse($task.LastRun)
                     switch ($task.Interval) {
                         "Hourly"  { ($now-$lastRun).TotalHours -ge 1 }
                         "Daily"   { ($now-$lastRun).TotalHours -ge 24 }
                         "Weekly"  { ($now-$lastRun).TotalDays  -ge 7 }
                         default   { $false }
                     }
                 }
        if ($isDue) {
            Write-Info "Running scheduled task: $($task.Name)..."
            $body = @{ model=$Agents[$task.Agent].Model; prompt=$task.Prompt; stream=$false } | ConvertTo-Json
            try {
                $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 180
                $sessDir = "$PSScriptRoot\CHAMP-Sessions"
                if (-not (Test-Path $sessDir)) { New-Item -ItemType Directory -Path $sessDir | Out-Null }
                $fname = "$sessDir\Sched-$($task.Name -replace '\s','-')-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
                Set-Content $fname -Value "# Scheduled: $($task.Name)`n`n**Agent:** $($task.Agent)`n`n**Date:** $(Get-Date)`n`n$($resp.response)" -Encoding UTF8
                Write-OK "Task '$($task.Name)' complete."; Speak-CHAMP "Scheduled task $($task.Name) complete."
            } catch { Write-Warn "Task '$($task.Name)' failed: $_" }
            $task.LastRun = (Get-Date -Format "yyyy-MM-dd HH:mm"); $modified = $true
        }
    }
    if ($modified) { $tasks | ConvertTo-Json -Depth 10 | Set-Content $SchedulerFile -Encoding UTF8 }
}

function Toggle-ScheduledTask {
    Show-Header; Initialize-Scheduler
    $tasks = Get-Content $SchedulerFile -Raw | ConvertFrom-Json
    if (-not $tasks -or $tasks.Count -eq 0) { Write-Warn "No tasks."; Pause-Menu; return }
    for ($i=0;$i -lt $tasks.Count;$i++) { Write-Host "$($i+1). $($tasks[$i].Name) [$(if($tasks[$i].Enabled){'ON'}else{'OFF'})]" }
    $sel = [int](Read-Host "Select task to toggle") - 1
    if ($sel -ge 0 -and $sel -lt $tasks.Count) {
        $tasks[$sel].Enabled = -not $tasks[$sel].Enabled
        $tasks | ConvertTo-Json -Depth 10 | Set-Content $SchedulerFile -Encoding UTF8
        Write-OK "Task '$($tasks[$sel].Name)' $(if($tasks[$sel].Enabled){'enabled'}else{'disabled'})."
    }
    Pause-Menu
}

function Show-SchedulerMenu {
    Show-Header; Write-Info "Scheduled Autonomous Tasks"; Write-Info "--------------------------"
    Write-Host "1. New Scheduled Task"; Write-Host "2. List Tasks"
    Write-Host "3. Enable / Disable Task"; Write-Host "4. Run All Due Tasks Now"; Write-Host "5. Back"
}

function Scheduler-Menu {
    do {
        Show-SchedulerMenu; $choice = Read-Host "Select"
        switch ($choice) {
            "1" { New-ScheduledAgentTask } "2" { List-ScheduledTasks }
            "3" { Toggle-ScheduledTask } "4" { Run-DueScheduledTasks; Pause-Menu } "5" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "5")
}

# -------------------------------------------------------
# Natural Language Infrastructure
# -------------------------------------------------------
function Invoke-NLInfrastructure {
    Show-Header; Write-Info "Natural Language Infrastructure"; Write-Info "--------------------------------"
    Write-Host "  Examples: 'Build a 3-node Redis cluster with monitoring'"
    Write-Host "            'Set up zero-trust Nginx reverse proxy'"
    Write-Host ""
    $intent = Read-Host "Describe the infrastructure you need"
    Write-Info "Professor-X designing architecture..."
    $body1 = @{ model=$Agents["Professor-X"].Model; prompt="$($AgentSystemPrompts["Professor-X"])`n`nDesign infrastructure architecture for: $intent`nList components, topology, security, and resource requirements."; stream=$false } | ConvertTo-Json
    $design = ""
    try { $r1=$( Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body1 -ContentType "application/json" -TimeoutSec 180); $design=$r1.response; Write-Host $design -ForegroundColor Yellow } catch { Write-Err "Design failed."; Pause-Menu; return }
    Write-Info "Forge generating Terraform..."
    $body2 = @{ model=$Agents["Forge"].Model; prompt="$($AgentSystemPrompts["Forge"])`n`nGenerate complete Terraform HCL for: $intent`nContext:`n$design`nOutput ONLY Terraform code."; stream=$false } | ConvertTo-Json
    $terraform = ""
    try { $r2=(Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body2 -ContentType "application/json" -TimeoutSec 180); $terraform=$r2.response } catch { Write-Warn "Terraform failed." }
    Write-Info "Forge generating Ansible playbook..."
    $body3 = @{ model=$Agents["Forge"].Model; prompt="$($AgentSystemPrompts["Forge"])`n`nGenerate complete Ansible playbook for: $intent`nOutput ONLY YAML."; stream=$false } | ConvertTo-Json
    $ansible = ""
    try { $r3=(Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body3 -ContentType "application/json" -TimeoutSec 180); $ansible=$r3.response } catch { Write-Warn "Ansible failed." }
    $infraDir = "$PSScriptRoot\CHAMP-Deploy\infra-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $infraDir -Force | Out-Null
    Set-Content "$infraDir\architecture.md" -Value "# Architecture`n`n$design" -Encoding UTF8
    if ($terraform) { Set-Content "$infraDir\main.tf"       -Value $terraform -Encoding UTF8 }
    if ($ansible)   { Set-Content "$infraDir\playbook.yml"  -Value $ansible   -Encoding UTF8 }
    Write-OK "Infrastructure files saved to $infraDir"; Speak-CHAMP "Infrastructure design complete."; Pause-Menu
}

# -------------------------------------------------------
# Custom Agent Builder
# -------------------------------------------------------
function Initialize-CustomAgents {
    Initialize-MemoryLayer
    if (-not (Test-Path $CustomAgentsFile)) { Set-Content $CustomAgentsFile -Value "{}" -Encoding UTF8 }
}

function New-CustomAgent {
    Show-Header; Initialize-CustomAgents
    $name    = (Read-Host "Agent name (no spaces)") -replace '\s','-'
    $model   = Read-Host "Base model (e.g. llama3.1:8b)"
    $role    = Read-Host "Role description"
    Write-Host "Enter system prompt (type END on a new line to finish):"
    $lines   = @(); do { $line=Read-Host; if($line -ne "END"){$lines+=$line} } while ($line -ne "END")
    $sysPrompt = $lines -join "`n"
    $keywords  = Read-Host "Keywords for routing (comma-separated)"
    $agentObj  = @{ Model=$model; Role=$role; Keywords=($keywords -split ",").Trim(); Custom=$true; Created=(Get-Date -Format "yyyy-MM-dd HH:mm") }
    $customAgents = Get-Content $CustomAgentsFile -Raw | ConvertFrom-Json
    $customAgents | Add-Member -NotePropertyName $name -NotePropertyValue $agentObj -Force
    $customAgents | ConvertTo-Json -Depth 10 | Set-Content $CustomAgentsFile -Encoding UTF8
    $Agents[$name] = $agentObj; $AgentSystemPrompts[$name] = $sysPrompt
    if ((Read-Host "Register in Ollama? (Y/N)") -match "^[Yy]") {
        $mfPath = "$PSScriptRoot\Modelfile-$name"
        Set-Content $mfPath -Value "FROM $model`nSYSTEM `"$sysPrompt`"" -Encoding UTF8
        ollama create $name -f $mfPath 2>&1; Write-OK "Registered in Ollama as '$name'."
    }
    Write-OK "Custom agent '$name' created."; Pause-Menu
}

function List-CustomAgents {
    Show-Header; Initialize-CustomAgents
    $customAgents = Get-Content $CustomAgentsFile -Raw | ConvertFrom-Json
    $props = $customAgents.PSObject.Properties
    if (-not $props -or ($props | Measure-Object).Count -eq 0) { Write-Warn "No custom agents yet."; Pause-Menu; return }
    Write-Info "Custom Agents"; Write-Info "-------------"
    foreach ($p in $props) { Write-Host ""; Write-Host "  $($p.Name)" -ForegroundColor Yellow; Write-Host "  Model: $($p.Value.Model)  Role: $($p.Value.Role)" }
    Pause-Menu
}

function Remove-CustomAgent {
    Show-Header; Initialize-CustomAgents
    $customAgents = Get-Content $CustomAgentsFile -Raw | ConvertFrom-Json
    $names = $customAgents.PSObject.Properties.Name
    if (-not $names -or $names.Count -eq 0) { Write-Warn "No custom agents."; Pause-Menu; return }
    for ($i=0;$i -lt $names.Count;$i++) { Write-Host "$($i+1). $($names[$i])" }
    $sel = [int](Read-Host "Select to remove") - 1
    if ($sel -ge 0 -and $sel -lt $names.Count) {
        $aName = $names[$sel]; $customAgents.PSObject.Properties.Remove($aName)
        $customAgents | ConvertTo-Json -Depth 10 | Set-Content $CustomAgentsFile -Encoding UTF8
        if ($Agents.ContainsKey($aName)) { $Agents.Remove($aName) }
        Write-OK "Removed '$aName'."
    }
    Pause-Menu
}

function Show-AgentBuilderMenu {
    Show-Header; Write-Info "Custom Agent Builder"; Write-Info "--------------------"
    Write-Host "1. Create New Agent"; Write-Host "2. List Custom Agents"; Write-Host "3. Remove Agent"; Write-Host "4. Back"
}

function AgentBuilder-Menu {
    do {
        Show-AgentBuilderMenu; $choice = Read-Host "Select"
        switch ($choice) { "1"{New-CustomAgent} "2"{List-CustomAgents} "3"{Remove-CustomAgent} "4"{return} default{Play-ErrorSound;Pause-Menu} }
    } while ($choice -ne "4")
}

# -------------------------------------------------------
# Full Audit Trail
# -------------------------------------------------------
function Initialize-AuditTrail {
    Initialize-MemoryLayer
    if (-not (Test-Path $AuditFile)) { Set-Content $AuditFile -Value "[]" -Encoding UTF8 }
}

function Write-AuditEntry {
    param([string]$Action, [string]$Agent = "", [string]$Details = "")
    try {
        Initialize-AuditTrail
        $entries = Get-Content $AuditFile -Raw | ConvertFrom-Json
        $entries += @{ Timestamp=(Get-Date -Format "yyyy-MM-dd HH:mm:ss"); User="Carnell"; Action=$Action; Agent=$Agent; Details=$Details }
        if ($entries.Count -gt 10000) { $entries = $entries | Select-Object -Last 10000 }
        $entries | ConvertTo-Json -Depth 5 | Set-Content $AuditFile -Encoding UTF8
    } catch {}
}

function Search-AuditTrail {
    Show-Header; Initialize-AuditTrail; Write-Info "Audit Trail"; Write-Info "-----------"
    Write-Host "1. Last 50 entries"; Write-Host "2. Keyword search"; Write-Host "3. Filter by agent"; Write-Host "4. Export CSV"; Write-Host "5. Back"
    $choice = Read-Host "Select"
    $entries = Get-Content $AuditFile -Raw | ConvertFrom-Json
    switch ($choice) {
        "1" { $entries | Select-Object -Last 50 | ForEach-Object { Write-Host "$($_.Timestamp)  [$($_.Agent)]  $($_.Action)" -ForegroundColor Cyan } }
        "2" { $kw=(Read-Host "Keyword"); $entries | Where-Object { $_.Action -match $kw -or $_.Details -match $kw -or $_.Agent -match $kw } | Select-Object -Last 100 | ForEach-Object { Write-Host "$($_.Timestamp)  [$($_.Agent)]  $($_.Action)" -ForegroundColor Cyan } }
        "3" { $ag=(Read-Host "Agent name"); $entries | Where-Object { $_.Agent -eq $ag } | Select-Object -Last 100 | ForEach-Object { Write-Host "$($_.Timestamp)  $($_.Action)" -ForegroundColor Cyan } }
        "4" { $csv="$PSScriptRoot\CHAMP-Sessions\audit-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"; $entries | Export-Csv $csv -NoTypeInformation -Encoding UTF8; Write-OK "Exported to $csv" }
    }
    Pause-Menu
}

# -------------------------------------------------------
# Zero Trust Policy Generator
# -------------------------------------------------------
function Generate-ZeroTrustPolicy {
    Show-Header; Write-Info "Zero Trust Policy Generator"; Write-Info "---------------------------"
    $env = Read-Host "Describe your environment (e.g. '50-node hybrid cloud, Windows + Linux')"
    Write-Info "Cyclops generating Zero Trust policy..."
    $prompt = "$($AgentSystemPrompts["Cyclops"])`n`nGenerate a comprehensive Zero Trust security policy for:`n$env`n`nInclude: identity verification, device trust, network segmentation, least-privilege, continuous monitoring, and incident response triggers."
    $body = @{ model=$Agents["Cyclops"].Model; prompt=$prompt; stream=$false } | ConvertTo-Json
    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 180
        Write-Host ""; Write-Host $resp.response -ForegroundColor Cyan
        if ((Read-Host "Save policy? (Y/N)") -match "^[Yy]") {
            $sessDir = "$PSScriptRoot\CHAMP-Sessions"; if (-not (Test-Path $sessDir)) { New-Item -ItemType Directory $sessDir | Out-Null }
            Set-Content "$sessDir\zerotrust-$(Get-Date -Format 'yyyyMMdd-HHmmss').md" -Value "# Zero Trust Policy`n`n**Environment:** $env`n`n$($resp.response)" -Encoding UTF8; Write-OK "Saved."
        }
    } catch { Write-Err "Policy generation failed: $_" }
    Pause-Menu
}

function Generate-FirewallACL {
    Show-Header
    $scenario = Read-Host "Describe the network scenario for firewall ACL generation"
    $prompt = "$($AgentSystemPrompts["Cyclops"])`n`nGenerate firewall ACL rules for: $scenario`nInclude allow and deny rules with comments."
    $body = @{ model=$Agents["Cyclops"].Model; prompt=$prompt; stream=$false } | ConvertTo-Json
    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 120
        Write-Host ""; Write-Host $resp.response -ForegroundColor Green
        if ((Read-Host "Save ACL rules? (Y/N)") -match "^[Yy]") {
            $sessDir = "$PSScriptRoot\CHAMP-Sessions"; if (-not (Test-Path $sessDir)) { New-Item -ItemType Directory $sessDir | Out-Null }
            Set-Content "$sessDir\acl-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt" -Value $resp.response -Encoding UTF8; Write-OK "Saved."
        }
    } catch { Write-Err "ACL generation failed: $_" }
    Pause-Menu
}

# -------------------------------------------------------
# Threat Intelligence Feed
# -------------------------------------------------------
function Fetch-OTXFeed {
    Show-Header
    $apiKey = Get-EnvKey "OTX_API_KEY"
    if (-not $apiKey) { Write-Warn "No OTX_API_KEY in .env (free key at otx.alienvault.com)"; $apiKey=Read-Host "Enter OTX key (or Enter to skip)"; if(-not $apiKey){Pause-Menu;return} }
    Write-Info "Fetching latest OTX threat pulses..."
    try {
        $resp = Invoke-RestMethod -Uri "https://otx.alienvault.com/api/v1/pulses/subscribed?limit=10" -Headers @{"X-OTX-API-KEY"=$apiKey} -TimeoutSec 30
        Write-Host ""; Write-Info "Latest Threat Pulses:"
        foreach ($pulse in $resp.results) {
            Write-Host ""; Write-Host "  $($pulse.name)" -ForegroundColor Yellow
            Write-Host "  TLP: $($pulse.tlp)  IOCs: $($pulse.indicators_count)  Modified: $($pulse.modified)"
        }
        if ((Read-Host "Analyze with Cyclops? (Y/N)") -match "^[Yy]") {
            $summary = ($resp.results | ForEach-Object { "- $($_.name): $($_.description.Substring(0,[Math]::Min(150,$_.description.Length)))" }) -join "`n"
            $prompt  = "$($AgentSystemPrompts["Cyclops"])`n`nAnalyze these threat pulses and identify critical threats:`n$summary"
            $body    = @{ model=$Agents["Cyclops"].Model; prompt=$prompt; stream=$false } | ConvertTo-Json
            $aiResp  = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 120
            Write-Host ""; Write-Host "Cyclops Analysis:" -ForegroundColor Red; Write-Host $aiResp.response
        }
    } catch { Write-Err "OTX feed failed: $_" }
    Pause-Menu
}

# -------------------------------------------------------
# CHAMP-QN Integration
# -------------------------------------------------------
function Initialize-CHAMPQNConfig {
    if (-not (Test-Path $CHAMPQNConfigFile)) { @{ Host=""; Port="8089"; ApiKey=""; NodeId="" } | ConvertTo-Json | Set-Content $CHAMPQNConfigFile -Encoding UTF8 }
}

function Configure-CHAMPQNConnection {
    Show-Header; Initialize-CHAMPQNConfig; Write-Info "CHAMP-QN Connection Setup"
    $config = Get-Content $CHAMPQNConfigFile -Raw | ConvertFrom-Json
    $h = Read-Host "Host (current: $(if($config.Host){$config.Host}else{'not set'}))"; $p = Read-Host "Port (current: $($config.Port))"
    $k = Read-Host "API key"; $n = Read-Host "Node ID"
    if ($h) { $config.Host=$h }; if ($p) { $config.Port=$p }; if ($k) { $config.ApiKey=$k }; if ($n) { $config.NodeId=$n }
    $config | ConvertTo-Json | Set-Content $CHAMPQNConfigFile -Encoding UTF8
    Write-OK "CHAMP-QN connection configured."; Pause-Menu
}

function Get-CHAMPQNStatus {
    Show-Header; Initialize-CHAMPQNConfig
    $config = Get-Content $CHAMPQNConfigFile -Raw | ConvertFrom-Json
    if (-not $config.Host) { Write-Warn "CHAMP-QN not configured. Use option 1."; Pause-Menu; return }
    try {
        $resp = Invoke-RestMethod -Uri "http://$($config.Host):$($config.Port)/api/status" -Headers @{"Authorization"="Bearer $($config.ApiKey)"} -TimeoutSec 10
        Write-Host ""; Write-Host ($resp | ConvertTo-Json -Depth 5) -ForegroundColor Green
    } catch { Write-Warn "Could not reach CHAMP-QN at $($config.Host):$($config.Port)" }
    Pause-Menu
}

function Send-CHAMPQNQuery {
    Show-Header; Initialize-CHAMPQNConfig
    $config = Get-Content $CHAMPQNConfigFile -Raw | ConvertFrom-Json
    if (-not $config.Host) { Write-Warn "CHAMP-QN not configured."; Pause-Menu; return }
    $query = Read-Host "Query to send to CHAMP-QN"; $agent = Read-Host "AI agent for synthesis (e.g. Professor-X)"
    if (-not $Agents.ContainsKey($agent)) { $agent = "Professor-X" }
    try {
        $headers = @{ "Authorization"="Bearer $($config.ApiKey)"; "Content-Type"="application/json" }
        $body    = @{ query=$query; nodeId=$config.NodeId } | ConvertTo-Json
        $resp    = Invoke-RestMethod -Uri "http://$($config.Host):$($config.Port)/api/query" -Method POST -Headers $headers -Body $body -TimeoutSec 30
        Write-Host ""; Write-Host ($resp | ConvertTo-Json -Depth 5) -ForegroundColor Cyan
        if ((Read-Host "Analyze with $agent? (Y/N)") -match "^[Yy]") {
            $aiPrompt = "$($AgentSystemPrompts[$agent])`n`nAnalyze this CHAMP-QN result:`nQuery: $query`nResult: $($resp | ConvertTo-Json)"
            $aiBody   = @{ model=$Agents[$agent].Model; prompt=$aiPrompt; stream=$false } | ConvertTo-Json
            $aiResp   = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $aiBody -ContentType "application/json" -TimeoutSec 120
            Write-Host ""; Write-Host $aiResp.response -ForegroundColor Yellow
        }
    } catch { Write-Err "CHAMP-QN query failed: $_" }
    Pause-Menu
}

function Show-CHAMPQNMenu {
    Show-Header; Write-Info "CHAMP-QN Integration"; Write-Info "--------------------"
    Write-Host "1. Configure Connection"; Write-Host "2. Node Status"
    Write-Host "3. Send Query + AI Analysis"; Write-Host "4. Back"
}

function CHAMPQN-Menu {
    do {
        Show-CHAMPQNMenu; $choice = Read-Host "Select"
        switch ($choice) { "1"{Configure-CHAMPQNConnection} "2"{Get-CHAMPQNStatus} "3"{Send-CHAMPQNQuery} "4"{return} default{Play-ErrorSound;Pause-Menu} }
    } while ($choice -ne "4")
}

# -------------------------------------------------------
# Agent Operations Menu (Option 27)
# -------------------------------------------------------
function Show-AgentOpsMenu {
    Show-Header; Write-Info "Agent Operations  [Mode: $Global:CHAMPMode]"; Write-Info "------------------------------------------"
    Write-Host "1. Multi-Agent Council      (4 agents debate + synthesize)" -ForegroundColor Yellow
    Write-Host "2. Agent Chain Pipeline     (output flows agent to agent)"   -ForegroundColor Yellow
    Write-Host "3. Custom Agent Builder     (create and register new agents)" -ForegroundColor Cyan
    Write-Host "4. Agent Performance        (response time stats)"           -ForegroundColor Cyan
    Write-Host "5. Scheduled Tasks          (run agents on a timer)"         -ForegroundColor Green
    Write-Host "6. Natural Language Infra   (describe it, Forge builds it)"  -ForegroundColor Green
    Write-Host "7. Whisper STT Setup        (local speech recognition)"      -ForegroundColor Magenta
    Write-Host "8. Audit Trail              (search all AI interactions)"    -ForegroundColor DarkCyan
    Write-Host "9. Back"
}

function AgentOps-Menu {
    do {
        Show-AgentOpsMenu; $choice = Read-Host "Select"
        switch ($choice) {
            "1" { Invoke-AgentCouncil } "2" { Invoke-AgentChain }
            "3" { AgentBuilder-Menu }  "4" { Show-AgentPerformance }
            "5" { Scheduler-Menu }     "6" { Invoke-NLInfrastructure }
            "7" { Show-Header; if (Test-WhisperAvailable) { Write-OK "Whisper ready." } else { Install-WhisperSTT } }
            "8" { Search-AuditTrail }  "9" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "9")
}

# ============================================================
# ADVANCED AI PLATFORM
# ============================================================

$Global:CHAMPMode   = "Default"
$MemoryPath         = "$PSScriptRoot\CHAMP-Memory"
$RAGPath            = "$PSScriptRoot\CHAMP-RAG"
$Global:APIGatewayJob = $null
$APIGatewayPort     = 8090
$ObsStackPath       = "$PSScriptRoot\champ-observability"

$CHAMPModes = @{
    "Default"        = @{ DefaultAgent = "Professor-X"; Color = "Cyan";    Description = "Balanced general-purpose mode" }
    "Builder"        = @{ DefaultAgent = "Forge";       Color = "Green";   Description = "Code, DevOps, infrastructure focus" }
    "Cyber"          = @{ DefaultAgent = "Cyclops";     Color = "Red";     Description = "Cybersecurity and threat analysis focus" }
    "Research"       = @{ DefaultAgent = "Beast";       Color = "Blue";    Description = "Deep research and scientific reasoning" }
    "CHAMP-QN"       = @{ DefaultAgent = "Professor-X"; Color = "Yellow";  Description = "Orchestration and Zero Trust automation" }
    "Infrastructure" = @{ DefaultAgent = "Cannonball";  Color = "Magenta"; Description = "IBM enterprise and infrastructure ops" }
    "Executive"      = @{ DefaultAgent = "Professor-X"; Color = "White";   Description = "High-level strategy and executive summaries" }
}

# -------------------------------------------------------
# Memory Layer
# -------------------------------------------------------
function Initialize-MemoryLayer {
    if (-not (Test-Path $MemoryPath)) { New-Item -ItemType Directory -Path $MemoryPath | Out-Null }
    if (-not (Test-Path $RAGPath))    { New-Item -ItemType Directory -Path $RAGPath    | Out-Null }
    if (-not (Test-Path "$MemoryPath\projects.json"))  { Set-Content "$MemoryPath\projects.json"  "[]" -Encoding UTF8 }
    if (-not (Test-Path "$MemoryPath\knowledge.json")) { Set-Content "$MemoryPath\knowledge.json" "[]" -Encoding UTF8 }
}

function New-ProjectProfile {
    Show-Header; Initialize-MemoryLayer
    $name   = Read-Host "Project name"
    $desc   = Read-Host "Description"
    $agents = Read-Host "Agents used (comma-separated)"
    $tags   = Read-Host "Tags (comma-separated)"
    $profile = @{
        Id = [guid]::NewGuid().ToString(); Name = $name; Description = $desc
        Agents = ($agents -split ",").Trim(); Tags = ($tags -split ",").Trim()
        Created = (Get-Date -Format "yyyy-MM-dd HH:mm"); Updated = (Get-Date -Format "yyyy-MM-dd HH:mm")
        Notes = @()
    }
    $pf = "$MemoryPath\projects.json"
    $projects = Get-Content $pf -Raw | ConvertFrom-Json
    $projects += $profile
    $projects | ConvertTo-Json -Depth 10 | Set-Content $pf -Encoding UTF8
    Write-OK "Project '$name' saved."; Pause-Menu
}

function List-ProjectProfiles {
    Show-Header; Initialize-MemoryLayer
    $projects = Get-Content "$MemoryPath\projects.json" -Raw | ConvertFrom-Json
    if (-not $projects -or $projects.Count -eq 0) { Write-Warn "No projects saved yet."; Pause-Menu; return }
    Write-Info "Saved Projects"; Write-Info "--------------"
    foreach ($p in $projects) {
        Write-Host ""; Write-Host "  $($p.Name)" -ForegroundColor Yellow
        Write-Host "  $($p.Description)"; Write-Host "  Agents : $($p.Agents -join ', ')"
        Write-Host "  Tags   : $($p.Tags -join ', ')"; Write-Host "  Created: $($p.Created)"
    }
    Pause-Menu
}

function Save-KnowledgeNote {
    Show-Header; Initialize-MemoryLayer
    $title    = Read-Host "Note title"
    $category = Read-Host "Category (architecture/security/grant/runbook/other)"
    Write-Host "Enter note content (type END on a new line to finish):"
    $lines = @()
    do { $line = Read-Host; if ($line -ne "END") { $lines += $line } } while ($line -ne "END")
    $note = @{
        Id = [guid]::NewGuid().ToString(); Title = $title; Category = $category
        Content = ($lines -join "`n"); Created = (Get-Date -Format "yyyy-MM-dd HH:mm")
    }
    $kf = "$MemoryPath\knowledge.json"
    $notes = Get-Content $kf -Raw | ConvertFrom-Json
    $notes += $note
    $notes | ConvertTo-Json -Depth 10 | Set-Content $kf -Encoding UTF8
    Write-OK "Note '$title' saved."; Pause-Menu
}

function Search-KnowledgeNotes {
    Show-Header; Initialize-MemoryLayer
    $query = Read-Host "Search query"
    $notes = Get-Content "$MemoryPath\knowledge.json" -Raw | ConvertFrom-Json
    $results = $notes | Where-Object { $_.Title -match $query -or $_.Content -match $query -or $_.Category -match $query }
    if (-not $results -or $results.Count -eq 0) { Write-Warn "No notes found matching '$query'."; Pause-Menu; return }
    foreach ($r in $results) {
        Write-Host ""; Write-Host "  [$($r.Category)] $($r.Title)" -ForegroundColor Yellow
        Write-Host "  $($r.Content.Substring(0, [Math]::Min(200, $r.Content.Length)))..."
    }
    Pause-Menu
}

function Add-ProjectNote {
    Show-Header; Initialize-MemoryLayer
    $projects = Get-Content "$MemoryPath\projects.json" -Raw | ConvertFrom-Json
    if (-not $projects -or $projects.Count -eq 0) { Write-Warn "No projects yet."; Pause-Menu; return }
    for ($i = 0; $i -lt $projects.Count; $i++) { Write-Host "$($i+1). $($projects[$i].Name)" }
    $sel = [int](Read-Host "Select project") - 1
    if ($sel -lt 0 -or $sel -ge $projects.Count) { Pause-Menu; return }
    $note = Read-Host "Note"
    $projects[$sel].Notes += @{ Text = $note; Date = (Get-Date -Format "yyyy-MM-dd HH:mm") }
    $projects[$sel].Updated = (Get-Date -Format "yyyy-MM-dd HH:mm")
    $projects | ConvertTo-Json -Depth 10 | Set-Content "$MemoryPath\projects.json" -Encoding UTF8
    Write-OK "Note added to '$($projects[$sel].Name)'."; Pause-Menu
}

function Show-MemoryMenu {
    Show-Header; Write-Info "AI Memory Layer"; Write-Info "---------------"
    Write-Host "1. New Project Profile"; Write-Host "2. List Projects"
    Write-Host "3. Add Note to Project"; Write-Host "4. Save Knowledge Note"
    Write-Host "5. Search Knowledge"; Write-Host "6. Back"
}

function Memory-Menu {
    do {
        Show-MemoryMenu
        $choice = Read-Host "Select"
        switch ($choice) {
            "1" { New-ProjectProfile } "2" { List-ProjectProfiles } "3" { Add-ProjectNote }
            "4" { Save-KnowledgeNote } "5" { Search-KnowledgeNotes } "6" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "6")
}

# -------------------------------------------------------
# Local RAG / Knowledge Base
# -------------------------------------------------------
function Get-OllamaEmbedding {
    param([string]$Text, [string]$Model = "nomic-embed-text")
    try {
        $body = @{ model = $Model; prompt = $Text } | ConvertTo-Json
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/embeddings" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 30
        return $response.embedding
    } catch { return $null }
}

function Get-CosineSimilarity {
    param([float[]]$A, [float[]]$B)
    if ($A.Count -ne $B.Count) { return 0 }
    $dot = 0.0; $magA = 0.0; $magB = 0.0
    for ($i = 0; $i -lt $A.Count; $i++) { $dot += $A[$i]*$B[$i]; $magA += $A[$i]*$A[$i]; $magB += $B[$i]*$B[$i] }
    $mag = [Math]::Sqrt($magA) * [Math]::Sqrt($magB)
    if ($mag -eq 0) { return 0 }
    return $dot / $mag
}

function Chunk-TextContent {
    param([string]$Text, [int]$ChunkSize = 500, [int]$Overlap = 50)
    $words = $Text -split '\s+'; $chunks = @(); $i = 0
    while ($i -lt $words.Count) {
        $end = [Math]::Min($i + $ChunkSize, $words.Count)
        $chunks += ($words[$i..($end-1)] -join " "); $i += $ChunkSize - $Overlap
    }
    return $chunks
}

function Ingest-FileToRAG {
    Show-Header; Initialize-MemoryLayer
    $filePath = Read-Host "File path (TXT, MD, PS1, CSV, LOG, JSON, YAML)"
    if (-not (Test-Path $filePath)) { Write-Err "File not found."; Pause-Menu; return }
    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
    $content = ""
    switch ($ext) {
        { $_ -in ".txt",".md",".ps1",".csv",".log",".json",".yaml",".yml",".conf",".ini" } {
            $content = Get-Content $filePath -Raw -Encoding UTF8 }
        default {
            try { $content = Get-Content $filePath -Raw }
            catch { Write-Err "Cannot read file."; Pause-Menu; return }
        }
    }
    if ([string]::IsNullOrWhiteSpace($content)) { Write-Err "File is empty."; Pause-Menu; return }
    $fileName = [System.IO.Path]::GetFileName($filePath)
    $chunks   = Chunk-TextContent -Text $content
    Write-Info "Chunking '$fileName' into $($chunks.Count) chunks..."
    $indexFile = "$RAGPath\index.json"
    $index = if (Test-Path $indexFile) { Get-Content $indexFile -Raw | ConvertFrom-Json } else { @() }
    $hasEmbed = (ollama list 2>&1) -match "nomic-embed"
    $embedded = 0
    foreach ($chunk in $chunks) {
        $entry = @{ Id=[guid]::NewGuid().ToString(); Source=$fileName; FilePath=$filePath; Text=$chunk; Ingested=(Get-Date -Format "yyyy-MM-dd HH:mm"); Embedding=$null }
        if ($hasEmbed) { $emb = Get-OllamaEmbedding -Text $chunk; if ($emb) { $entry.Embedding = $emb; $embedded++ } }
        $index += $entry; Write-Host "." -NoNewline
    }
    Write-Host ""
    $index | ConvertTo-Json -Depth 10 | Set-Content $indexFile -Encoding UTF8
    Write-OK "Ingested '$fileName': $($chunks.Count) chunks ($embedded with embeddings)."
    if (-not $hasEmbed) { Write-Warn "Run 'ollama pull nomic-embed-text' for semantic search." }
    Pause-Menu
}

function Search-RAGKnowledge {
    Show-Header; Initialize-MemoryLayer
    $indexFile = "$RAGPath\index.json"
    if (-not (Test-Path $indexFile)) { Write-Warn "No documents ingested yet. Use option 1 first."; Pause-Menu; return }
    $index = Get-Content $indexFile -Raw | ConvertFrom-Json
    if ($index.Count -eq 0) { Write-Warn "RAG index is empty."; Pause-Menu; return }
    $query = Read-Host "Ask a question or enter search terms"
    $hasEmbed = (ollama list 2>&1) -match "nomic-embed"
    $results = @()
    if ($hasEmbed) {
        Write-Info "Running semantic search..."
        $queryEmb = Get-OllamaEmbedding -Text $query
        if ($queryEmb) {
            foreach ($entry in $index) {
                if ($entry.Embedding) {
                    $sim = Get-CosineSimilarity -A $queryEmb -B $entry.Embedding
                    $results += @{ Entry = $entry; Score = $sim }
                }
            }
            $results = $results | Sort-Object { $_.Score } -Descending | Select-Object -First 5
        }
    }
    if ($results.Count -eq 0) {
        Write-Info "Falling back to keyword search..."
        $results = $index | Where-Object { $_.Text -match $query } | Select-Object -First 5 | ForEach-Object { @{ Entry = $_; Score = 0 } }
    }
    if ($results.Count -eq 0) { Write-Warn "No results found."; Pause-Menu; return }
    Write-Info "Top results:"; $context = ""
    foreach ($r in $results) {
        Write-Host ""; Write-Host "  [Source: $($r.Entry.Source)] Score: $([Math]::Round($r.Score, 3))" -ForegroundColor Yellow
        Write-Host "  $($r.Entry.Text.Substring(0, [Math]::Min(200, $r.Entry.Text.Length)))..."
        $context += $r.Entry.Text + "`n---`n"
    }
    $askAI = Read-Host "Send to AI for synthesis? (Y/N)"
    if ($askAI -match "^[Yy]") {
        $agent = if ($CHAMPModes[$Global:CHAMPMode]) { $CHAMPModes[$Global:CHAMPMode].DefaultAgent } else { "Professor-X" }
        $model = $Agents[$agent].Model
        $prompt = "Based on the following context, answer this question: $query`n`nContext:`n$context"
        $body = @{ model = $model; prompt = $prompt; stream = $false } | ConvertTo-Json
        try {
            $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 120
            Write-Host ""; Write-Host $resp.response -ForegroundColor Cyan
            Speak-CHAMP "RAG query complete."
        } catch { Write-Err "AI query failed: $_" }
    }
    Pause-Menu
}

function List-RAGDocuments {
    Show-Header; Initialize-MemoryLayer
    $indexFile = "$RAGPath\index.json"
    if (-not (Test-Path $indexFile)) { Write-Warn "No documents ingested yet."; Pause-Menu; return }
    $index = Get-Content $indexFile -Raw | ConvertFrom-Json
    $sources = $index | Group-Object Source
    Write-Info "Ingested Documents"; Write-Info "------------------"
    foreach ($s in $sources) { Write-Host "  $($s.Name) - $($s.Count) chunks" -ForegroundColor Yellow }
    Write-Host ""; Write-Host "Total chunks: $($index.Count)"
    Pause-Menu
}

function Remove-RAGDocument {
    Show-Header; Initialize-MemoryLayer
    $indexFile = "$RAGPath\index.json"
    if (-not (Test-Path $indexFile)) { Write-Warn "No documents ingested yet."; Pause-Menu; return }
    $index   = Get-Content $indexFile -Raw | ConvertFrom-Json
    $sources = ($index | Group-Object Source).Name
    for ($i = 0; $i -lt $sources.Count; $i++) { Write-Host "$($i+1). $($sources[$i])" }
    $sel = [int](Read-Host "Select document to remove") - 1
    if ($sel -lt 0 -or $sel -ge $sources.Count) { Pause-Menu; return }
    $sourceName = $sources[$sel]
    $newIndex = $index | Where-Object { $_.Source -ne $sourceName }
    $newIndex | ConvertTo-Json -Depth 10 | Set-Content $indexFile -Encoding UTF8
    Write-OK "Removed '$sourceName' from RAG index."; Pause-Menu
}

function Show-RAGMenu {
    Show-Header; Write-Info "Local RAG / Knowledge Base"; Write-Info "--------------------------"
    Write-Host "1. Ingest Document"; Write-Host "2. Search / Ask Knowledge Base"
    Write-Host "3. List Ingested Documents"; Write-Host "4. Remove Document"; Write-Host "5. Back"
}

function RAG-Menu {
    do {
        Show-RAGMenu; $choice = Read-Host "Select"
        switch ($choice) {
            "1" { Ingest-FileToRAG } "2" { Search-RAGKnowledge } "3" { List-RAGDocuments }
            "4" { Remove-RAGDocument } "5" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "5")
}

# -------------------------------------------------------
# AI API Gateway
# -------------------------------------------------------
function Start-AIAPIGateway {
    Show-Header
    if ($Global:APIGatewayJob -and $Global:APIGatewayJob.State -eq "Running") {
        Write-Warn "API Gateway already running on port $APIGatewayPort."; Pause-Menu; return
    }
    Write-Info "Starting CHAMP AI API Gateway on http://localhost:$APIGatewayPort/api/..."
    $port = $APIGatewayPort
    $Global:APIGatewayJob = Start-Job -ScriptBlock {
        param($port, $scriptRoot)
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://localhost:$port/api/")
        $listener.Prefixes.Add("http://localhost:$port/")
        $listener.Start()
        while ($listener.IsListening) {
            try {
                $ctx = $listener.GetContext()
                $req = $ctx.Request; $res = $ctx.Response
                $res.ContentType = "application/json"
                $res.Headers.Add("Access-Control-Allow-Origin","*")
                $path = $req.Url.AbsolutePath
                $body = ""
                if ($req.HasEntityBody) {
                    $reader = New-Object System.IO.StreamReader($req.InputStream)
                    $body = $reader.ReadToEnd(); $reader.Close()
                }
                $responseObj = switch -Regex ($path) {
                    "/api/status" { @{ status="online"; version="1.0"; timestamp=(Get-Date -Format "o") } }
                    "/api/agents" { @{ agents=@("Professor-X","Forge","Cyclops","Beast","Storm","Psylocke","Wolverine","Magneto","Havok","Bishop","Sage","Cypher","Moira","Cannonball","Scout","Gambit","Cable","Sunfire","Banshee","Iceman","Shadowcat","Rogue","Longshot","Dazzler","Jubilee","Nightcrawler") } }
                    "/api/models" { $models=(ollama list 2>&1 | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] }); @{ models=$models } }
                    "/api/chat"   {
                        try {
                            $reqObj = $body | ConvertFrom-Json
                            $ob = @{ model=$reqObj.model; prompt=$reqObj.prompt; stream=$false } | ConvertTo-Json
                            $or = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $ob -ContentType "application/json" -TimeoutSec 120
                            @{ response=$or.response; model=$reqObj.model }
                        } catch { @{ error=$_.ToString() } }
                    }
                    "^/$"          {
                        $htmlPath = "$scriptRoot\CHAMP-WebUI\index.html"
                        if (Test-Path $htmlPath) {
                            $htmlBytes = [System.IO.File]::ReadAllBytes($htmlPath)
                            $res.ContentType = "text/html; charset=utf-8"
                            $res.ContentLength64 = $htmlBytes.Length
                            $res.OutputStream.Write($htmlBytes, 0, $htmlBytes.Length)
                            $res.OutputStream.Close()
                            continue
                        }
                        @{ error="Web UI not found. Run Initialize-WebUI first." }
                    }
                    default { @{ error="Unknown endpoint. Available: /api/status /api/agents /api/models /api/chat" } }
                }
                $json  = $responseObj | ConvertTo-Json -Depth 5
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentLength64 = $bytes.Length
                $res.OutputStream.Write($bytes,0,$bytes.Length)
                $res.OutputStream.Close()
            } catch { Start-Sleep -Milliseconds 100 }
        }
    } -ArgumentList $port, $PSScriptRoot
    Start-Sleep -Seconds 1
    if ($Global:APIGatewayJob.State -eq "Running") {
        Write-OK "API Gateway running at http://localhost:$APIGatewayPort/api/"
        Write-Info "Endpoints: /api/status  /api/agents  /api/models  /api/chat"
    } else { Write-Err "Failed to start API Gateway." }
    Pause-Menu
}

function Stop-AIAPIGateway {
    Show-Header
    if ($Global:APIGatewayJob) {
        Stop-Job $Global:APIGatewayJob -ErrorAction SilentlyContinue
        Remove-Job $Global:APIGatewayJob -ErrorAction SilentlyContinue
        $Global:APIGatewayJob = $null; Write-OK "API Gateway stopped."
    } else { Write-Warn "API Gateway is not running." }
    Pause-Menu
}

function Test-AIAPIGateway {
    Show-Header; Write-Info "Testing CHAMP AI API Gateway..."
    try {
        $status = Invoke-RestMethod -Uri "http://localhost:$APIGatewayPort/api/status" -TimeoutSec 5
        Write-OK "Gateway online: $($status | ConvertTo-Json)"
    } catch { Write-Err "Gateway not responding. Start it first (option 1)." }
    Pause-Menu
}

function Show-APIGatewayMenu {
    Show-Header
    $status = if ($Global:APIGatewayJob -and $Global:APIGatewayJob.State -eq "Running") { "RUNNING :$APIGatewayPort" } else { "STOPPED" }
    Write-Info "AI API Gateway  [$status]"; Write-Info "----------------------------"
    Write-Host "1. Start Gateway"; Write-Host "2. Stop Gateway"; Write-Host "3. Test Gateway"; Write-Host "4. Back"
}

function APIGateway-Menu {
    do {
        Show-APIGatewayMenu; $choice = Read-Host "Select"
        switch ($choice) {
            "1" { Start-AIAPIGateway } "2" { Stop-AIAPIGateway } "3" { Test-AIAPIGateway } "4" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "4")
}

# -------------------------------------------------------
# Autonomous Agents
# -------------------------------------------------------
function Invoke-AutonomousAgent {
    param([string]$AgentName, [string]$Goal, [string]$Model, [string[]]$Steps)
    Show-Header; Write-Info "Autonomous Agent: $AgentName"; Write-Info "Goal: $Goal"; Write-Host ""
    $results = @()
    foreach ($step in $Steps) {
        Write-Host "Step: $step" -ForegroundColor Cyan
        $prompt = "$($AgentSystemPrompts[$AgentName])`n`nGoal: $Goal`n`nCurrent step: $step`n`nProvide a detailed actionable response."
        $body = @{ model=$Model; prompt=$prompt; stream=$false } | ConvertTo-Json
        try {
            $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 180
            Write-Host $resp.response -ForegroundColor White
            $results += @{ Step=$step; Output=$resp.response }
            Write-Host "---" -ForegroundColor DarkGray
        } catch { Write-Warn "Step failed: $_"; $results += @{ Step=$step; Output="ERROR: $_" } }
    }
    $sessDir = "$PSScriptRoot\CHAMP-Sessions"
    if (-not (Test-Path $sessDir)) { New-Item -ItemType Directory -Path $sessDir | Out-Null }
    $outFile = "$sessDir\AutoAgent-$AgentName-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    $md = "# Autonomous Agent: $AgentName`n`n**Goal:** $Goal`n`n**Date:** $(Get-Date)`n`n"
    foreach ($r in $results) { $md += "## $($r.Step)`n`n$($r.Output)`n`n---`n`n" }
    Set-Content $outFile -Value $md -Encoding UTF8
    Write-OK "Results saved to $outFile"
    Speak-CHAMP "Autonomous agent $AgentName has completed the task."
    Pause-Menu
}

function Run-DevOpsAgent {
    $goal = Read-Host "DevOps goal"
    Invoke-AutonomousAgent -AgentName "Forge" -Goal $goal -Model $Agents["Forge"].Model -Steps @(
        "Analyze the infrastructure requirements for: $goal",
        "Identify potential risks and blockers",
        "Create a step-by-step implementation plan",
        "Generate required configuration files or scripts",
        "Define success criteria and testing approach"
    )
}

function Run-ThreatHunterAgent {
    $target = Read-Host "Threat hunting target (IP, domain, hash, or threat description)"
    Invoke-AutonomousAgent -AgentName "Cyclops" -Goal "Threat hunt: $target" -Model $Agents["Cyclops"].Model -Steps @(
        "Profile the threat: $target -- classify type, severity, and known TTPs",
        "Map to MITRE ATT&CK framework -- identify relevant tactics and techniques",
        "Define indicators of compromise (IOCs) to hunt for",
        "Create detection rules in Sigma/KQL/SPL format",
        "Recommend containment and remediation actions"
    )
}

function Run-DocumentationAgent {
    $subject = Read-Host "What to document"
    Invoke-AutonomousAgent -AgentName "Professor-X" -Goal "Create documentation for: $subject" -Model $Agents["Professor-X"].Model -Steps @(
        "Create an executive summary for: $subject",
        "Write a technical overview with architecture details",
        "Document all components, interfaces, and dependencies",
        "Write installation and configuration instructions",
        "Add troubleshooting guide and FAQ"
    )
}

function Run-ResearchAgent {
    $topic = Read-Host "Research topic"
    Invoke-AutonomousAgent -AgentName "Beast" -Goal "Research: $topic" -Model $Agents["Beast"].Model -Steps @(
        "Provide a comprehensive overview of: $topic",
        "Analyze current state-of-the-art and key developments",
        "Identify key challenges, open problems, and opportunities",
        "Compare top approaches, tools, or frameworks in this space",
        "Synthesize findings into actionable recommendations"
    )
}

function Run-InfrastructureAgent {
    $goal = Read-Host "Infrastructure goal"
    Invoke-AutonomousAgent -AgentName "Cannonball" -Goal $goal -Model $Agents["Cannonball"].Model -Steps @(
        "Assess requirements and constraints for: $goal",
        "Design the infrastructure architecture",
        "Specify hardware, software, and network requirements",
        "Create Terraform or Ansible automation scripts",
        "Define monitoring, alerting, and maintenance plan"
    )
}

function Run-GrantWriterAgent {
    $grant = Read-Host "Grant name and funding opportunity"
    Invoke-AutonomousAgent -AgentName "Professor-X" -Goal "Write grant proposal for: $grant" -Model $Agents["Professor-X"].Model -Steps @(
        "Write an executive summary and project abstract for: $grant",
        "Define the problem statement and significance",
        "Describe the proposed solution, methodology, and innovation",
        "Outline the project timeline, milestones, and deliverables",
        "Write the budget justification and evaluation plan"
    )
}

function Show-AutonomousAgentsMenu {
    Show-Header; Write-Info "Autonomous Agents"; Write-Info "-----------------"
    Write-Host "1. DevOps Agent      (Forge)"
    Write-Host "2. Threat Hunter     (Cyclops)"
    Write-Host "3. Documentation     (Professor-X)"
    Write-Host "4. Research Agent    (Beast)"
    Write-Host "5. Infrastructure    (Cannonball)"
    Write-Host "6. Grant Writer      (Professor-X)"
    Write-Host "7. Back"
}

function AutonomousAgents-Menu {
    do {
        Show-AutonomousAgentsMenu; $choice = Read-Host "Select agent"
        switch ($choice) {
            "1" { Run-DevOpsAgent } "2" { Run-ThreatHunterAgent } "3" { Run-DocumentationAgent }
            "4" { Run-ResearchAgent } "5" { Run-InfrastructureAgent } "6" { Run-GrantWriterAgent }
            "7" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "7")
}

# -------------------------------------------------------
# Enhanced Auto Multi-Model Routing
# -------------------------------------------------------
function AutoRoute-Task {
    Show-Header; Write-Info "Auto Multi-Model Router"; Write-Info "-----------------------"
    $task = Read-Host "Describe your task"
    Write-Info "Analyzing task and selecting best agent..."
    $classifyPrompt = @"
You are a task router. Analyze the following task and respond with ONLY the agent name that best matches from this list:
Forge (coding/scripts/DevOps), Cyclops (cybersecurity/threats/logs), Beast (scientific reasoning/research),
Storm (creative writing/long-form), Psylocke (multilingual/structured output), Sage (math/STEM),
Cypher (SQL/databases), Moira (medical/health), Professor-X (strategy/planning/general),
Havok (casual conversation), Bishop (balanced all-purpose), Iceman (pure code/80+ languages),
Shadowcat (advanced code), Gambit (long context), Banshee (precision tasks)

Task: $task

Respond with ONLY the agent name, nothing else.
"@
    $body = @{ model=$Agents["Professor-X"].Model; prompt=$classifyPrompt; stream=$false } | ConvertTo-Json
    try {
        $resp   = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 60
        $routed = $resp.response.Trim()
        if (-not $Agents.ContainsKey($routed)) { $routed = "Professor-X" }
        Write-OK "Routing to: $routed ($($Agents[$routed].Model))"
        Write-Host "Role: $($Agents[$routed].Role)" -ForegroundColor DarkCyan
        Speak-CHAMP "Routing your task to $routed."
        $taskPrompt = "$($AgentSystemPrompts[$routed])`n`nTask: $task"
        $taskBody   = @{ model=$Agents[$routed].Model; prompt=$taskPrompt; stream=$false } | ConvertTo-Json
        $taskResp   = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $taskBody -ContentType "application/json" -TimeoutSec 180
        Write-Host ""; Write-Host $taskResp.response -ForegroundColor Cyan
        Speak-CHAMP "$routed has completed the task."
    } catch { Write-Err "Auto-routing failed: $_" }
    Pause-Menu
}

# -------------------------------------------------------
# Cybersecurity Toolkit
# -------------------------------------------------------
function Get-EnvKey {
    param([string]$KeyName)
    $envFile = "$PSScriptRoot\.env"
    if (Test-Path $envFile) {
        $line = Get-Content $envFile | Where-Object { $_ -match "^$KeyName=" }
        if ($line) { return ($line -split "=",2)[1].Trim() }
    }
    return ""
}

function Lookup-VirusTotal {
    Show-Header
    $apiKey = Get-EnvKey "VIRUSTOTAL_API_KEY"
    if (-not $apiKey) {
        Write-Warn "No VIRUSTOTAL_API_KEY in .env (free key at virustotal.com)"
        $apiKey = Read-Host "Enter VirusTotal API key (or Enter to skip)"
        if (-not $apiKey) { Pause-Menu; return }
    }
    $ioc = Read-Host "Enter IP, domain, URL, or file hash"
    $iocType = if ($ioc -match "^\d{1,3}(\.\d{1,3}){3}$") { "ip_addresses" }
               elseif ($ioc -match "^[a-fA-F0-9]{32,64}$") { "files" }
               elseif ($ioc -match "^https?://") { "urls" }
               else { "domains" }
    Write-Info "Looking up $ioc on VirusTotal..."
    try {
        $headers = @{ "x-apikey"=$apiKey }
        $resp    = Invoke-RestMethod -Uri "https://www.virustotal.com/api/v3/$iocType/$ioc" -Headers $headers -TimeoutSec 30
        $stats   = $resp.data.attributes.last_analysis_stats
        Write-Host ""
        $malColor = if ($stats.malicious -gt 0) { "Red" } else { "Green" }
        Write-Host "  MALICIOUS  : $($stats.malicious)" -ForegroundColor $malColor
        Write-Host "  Suspicious : $($stats.suspicious)" -ForegroundColor Yellow
        Write-Host "  Harmless   : $($stats.harmless)"   -ForegroundColor Green
        Write-Host "  Undetected : $($stats.undetected)"
        if ($stats.malicious -gt 0) {
            $analysis = "VirusTotal result for $ioc`: $($stats.malicious) malicious detections."
            $prompt = "$($AgentSystemPrompts["Cyclops"])`n`nAnalyze this threat intelligence and provide recommendations:`n$analysis"
            $body   = @{ model=$Agents["Cyclops"].Model; prompt=$prompt; stream=$false } | ConvertTo-Json
            $aiResp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 120
            Write-Host ""; Write-Host "Cyclops Analysis:" -ForegroundColor Red; Write-Host $aiResp.response
        }
    } catch { Write-Err "VirusTotal lookup failed: $_" }
    Pause-Menu
}

function Lookup-AbuseIPDB {
    Show-Header
    $apiKey = Get-EnvKey "ABUSEIPDB_API_KEY"
    if (-not $apiKey) {
        Write-Warn "No ABUSEIPDB_API_KEY in .env (free key at abuseipdb.com)"
        $apiKey = Read-Host "Enter AbuseIPDB API key (or Enter to skip)"
        if (-not $apiKey) { Pause-Menu; return }
    }
    $ip = Read-Host "Enter IP address to check"
    Write-Info "Querying AbuseIPDB for $ip..."
    try {
        $headers = @{ "Key"=$apiKey; "Accept"="application/json" }
        $resp    = Invoke-RestMethod -Uri "https://api.abuseipdb.com/api/v2/check?ipAddress=$ip&maxAgeInDays=90" -Headers $headers -TimeoutSec 30
        $data    = $resp.data
        $scoreColor = if ($data.abuseConfidenceScore -gt 50) { "Red" } elseif ($data.abuseConfidenceScore -gt 10) { "Yellow" } else { "Green" }
        Write-Host ""
        Write-Host "  IP          : $($data.ipAddress)"
        Write-Host "  Abuse Score : $($data.abuseConfidenceScore)%" -ForegroundColor $scoreColor
        Write-Host "  Reports     : $($data.totalReports)"
        Write-Host "  Country     : $($data.countryCode)"
        Write-Host "  ISP         : $($data.isp)"
        Write-Host "  Tor         : $($data.isTor)"
    } catch { Write-Err "AbuseIPDB lookup failed: $_" }
    Pause-Menu
}

function Lookup-CVE {
    Show-Header
    $cve = Read-Host "Enter CVE ID (e.g. CVE-2024-1234)"
    Write-Info "Querying NVD for $cve..."
    try {
        $resp = Invoke-RestMethod -Uri "https://services.nvd.nist.gov/rest/json/cves/2.0?cveId=$cve" -TimeoutSec 30
        $vuln = $resp.vulnerabilities[0].cve
        $desc = ($vuln.descriptions | Where-Object { $_.lang -eq "en" } | Select-Object -First 1).value
        Write-Host ""; Write-Host "  CVE  : $($vuln.id)" -ForegroundColor Yellow
        Write-Host "  Desc : $desc"
        $cvss = $vuln.metrics.cvssMetricV31[0].cvssData
        if ($cvss) {
            $sevColor = switch ($cvss.baseSeverity) { "CRITICAL"{"Red"} "HIGH"{"DarkRed"} "MEDIUM"{"Yellow"} default{"Green"} }
            Write-Host "  CVSS : $($cvss.baseScore) $($cvss.baseSeverity)" -ForegroundColor $sevColor
            Write-Host "  Vec  : $($cvss.vectorString)"
        }
        $prompt = "$($AgentSystemPrompts["Cyclops"])`n`nAnalyze this vulnerability and provide mitigation recommendations:`n$cve - $desc"
        $body   = @{ model=$Agents["Cyclops"].Model; prompt=$prompt; stream=$false } | ConvertTo-Json
        $aiResp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 120
        Write-Host ""; Write-Host "Cyclops Mitigation Advice:" -ForegroundColor Cyan; Write-Host $aiResp.response
    } catch { Write-Err "CVE lookup failed: $_" }
    Pause-Menu
}

function Generate-YARARule {
    Show-Header
    $target = Read-Host "Describe the threat or malware for YARA rule generation"
    Write-Info "Generating YARA rule with Cyclops..."
    $prompt = "$($AgentSystemPrompts["Cyclops"])`n`nCreate a professional YARA rule for the following threat. Include metadata, strings, and condition sections. Output ONLY the YARA rule code:`n`n$target"
    $body = @{ model=$Agents["Cyclops"].Model; prompt=$prompt; stream=$false } | ConvertTo-Json
    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 120
        Write-Host ""; Write-Host $resp.response -ForegroundColor Green
        $save = Read-Host "Save YARA rule? (Y/N)"
        if ($save -match "^[Yy]") {
            $sessDir = "$PSScriptRoot\CHAMP-Sessions"
            if (-not (Test-Path $sessDir)) { New-Item -ItemType Directory -Path $sessDir | Out-Null }
            $fname = "$sessDir\yara-$(Get-Date -Format 'yyyyMMdd-HHmmss').yar"
            Set-Content $fname -Value $resp.response -Encoding UTF8; Write-OK "Saved to $fname"
        }
    } catch { Write-Err "YARA generation failed: $_" }
    Pause-Menu
}

function Map-MITREAttack {
    Show-Header
    $behavior = Read-Host "Describe attacker behavior or threat to map to MITRE ATT&CK"
    Write-Info "Mapping to MITRE ATT&CK with Cyclops..."
    $prompt = "$($AgentSystemPrompts["Cyclops"])`n`nMap the following behavior to MITRE ATT&CK. List Tactic, Technique ID, Technique Name, and recommended detections for each:`n`n$behavior"
    $body = @{ model=$Agents["Cyclops"].Model; prompt=$prompt; stream=$false } | ConvertTo-Json
    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 120
        Write-Host ""; Write-Host $resp.response -ForegroundColor Cyan
    } catch { Write-Err "MITRE mapping failed: $_" }
    Pause-Menu
}

function Generate-SigmaRule {
    Show-Header
    $threat = Read-Host "Describe the threat or attack pattern for Sigma rule generation"
    Write-Info "Generating Sigma detection rule with Cyclops..."
    $prompt = "$($AgentSystemPrompts["Cyclops"])`n`nCreate a Sigma detection rule for the following threat. Use proper Sigma YAML format with title, status, description, logsource, detection, and falsepositives. Output ONLY the Sigma rule:`n`n$threat"
    $body = @{ model=$Agents["Cyclops"].Model; prompt=$prompt; stream=$false } | ConvertTo-Json
    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 120
        Write-Host ""; Write-Host $resp.response -ForegroundColor Green
        $save = Read-Host "Save Sigma rule? (Y/N)"
        if ($save -match "^[Yy]") {
            $sessDir = "$PSScriptRoot\CHAMP-Sessions"
            if (-not (Test-Path $sessDir)) { New-Item -ItemType Directory -Path $sessDir | Out-Null }
            $fname = "$sessDir\sigma-$(Get-Date -Format 'yyyyMMdd-HHmmss').yml"
            Set-Content $fname -Value $resp.response -Encoding UTF8; Write-OK "Saved to $fname"
        }
    } catch { Write-Err "Sigma generation failed: $_" }
    Pause-Menu
}

function Show-CyberMenu {
    Show-Header; Write-Info "AI Cybersecurity Toolkit"; Write-Info "------------------------"
    Write-Host "1. VirusTotal IOC Lookup"
    Write-Host "2. AbuseIPDB IP Reputation"
    Write-Host "3. CVE Lookup (NVD)"
    Write-Host "4. Generate YARA Rule"
    Write-Host "5. MITRE ATT&CK Mapping"
    Write-Host "6. Generate Sigma Rule"
    Write-Host "7. Zero Trust Policy Generator"
    Write-Host "8. Firewall ACL Generator"
    Write-Host "9. Threat Intelligence Feed (OTX)"
    Write-Host "10. Back"
}

function Cyber-Menu {
    do {
        Show-CyberMenu; $choice = Read-Host "Select"
        switch ($choice) {
            "1"  { Lookup-VirusTotal } "2"  { Lookup-AbuseIPDB } "3"  { Lookup-CVE }
            "4"  { Generate-YARARule } "5"  { Map-MITREAttack }  "6"  { Generate-SigmaRule }
            "7"  { Generate-ZeroTrustPolicy } "8" { Generate-FirewallACL }
            "9"  { Fetch-OTXFeed }     "10" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "10")
}

# -------------------------------------------------------
# Observability Stack
# -------------------------------------------------------
function Deploy-ObservabilityStack {
    Show-Header
    if (-not (Test-DockerRunning)) { Write-Err "Docker is not running."; Pause-Menu; return }
    Write-Info "Deploying Prometheus + Grafana + Loki..."
    if (-not (Test-Path $ObsStackPath)) { New-Item -ItemType Directory -Path $ObsStackPath | Out-Null }
    Set-Content "$ObsStackPath\prometheus.yml" -Encoding UTF8 -Value @"
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'ollama'
    static_configs:
      - targets: ['host.docker.internal:11434']
    metrics_path: '/metrics'
"@
    Set-Content "$ObsStackPath\docker-compose.yml" -Encoding UTF8 -Value @"
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: champ-prometheus
    ports:
      - "9091:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
  grafana:
    image: grafana/grafana:latest
    container_name: champ-grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=champ1969
    volumes:
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
    restart: unless-stopped
  loki:
    image: grafana/loki:latest
    container_name: champ-loki
    ports:
      - "3100:3100"
    restart: unless-stopped
volumes:
  prometheus_data:
  grafana_data:
"@
    Push-Location $ObsStackPath
    docker compose up -d 2>&1
    Pop-Location
    Write-OK "Observability stack deployed:"
    Write-Info "  Prometheus : http://localhost:9091"
    Write-Info "  Grafana    : http://localhost:3001  (admin / champ1969)"
    Write-Info "  Loki       : http://localhost:3100"
    Speak-CHAMP "Observability stack is online."
    Pause-Menu
}

function Stop-ObservabilityStack {
    Show-Header
    if (-not (Test-Path "$ObsStackPath\docker-compose.yml")) { Write-Warn "Observability stack not deployed."; Pause-Menu; return }
    Push-Location $ObsStackPath; docker compose down 2>&1; Pop-Location
    Write-OK "Observability stack stopped."; Pause-Menu
}

function Show-ObservabilityMenu {
    Show-Header; Write-Info "AI Infrastructure Observability"; Write-Info "-------------------------------"
    Write-Host "1. Deploy Stack (Prometheus + Grafana + Loki)"
    Write-Host "2. Stop Stack"
    Write-Host "3. Open Grafana  http://localhost:3001  (admin / champ1969)"
    Write-Host "4. Open Prometheus  http://localhost:9091"
    Write-Host "5. Back"
}

function Observability-Menu {
    do {
        Show-ObservabilityMenu; $choice = Read-Host "Select"
        switch ($choice) {
            "1" { Deploy-ObservabilityStack }
            "2" { Stop-ObservabilityStack }
            "3" { Start-Process "http://localhost:3001"; Pause-Menu }
            "4" { Start-Process "http://localhost:9091"; Pause-Menu }
            "5" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "5")
}

# -------------------------------------------------------
# AI Deployment Engine
# -------------------------------------------------------
function Invoke-DeploymentEngine {
    Show-Header; Write-Info "AI Deployment Engine"; Write-Info "--------------------"
    $appDesc = Read-Host "Describe the app to deploy (e.g. 'FastAPI IOC dashboard on port 8080')"
    Write-Info "Forge is designing the deployment..."
    $dockerPrompt = "$($AgentSystemPrompts["Forge"])`n`nGenerate a production-ready Dockerfile for: $appDesc`nOutput ONLY the Dockerfile content."
    $body = @{ model=$Agents["Forge"].Model; prompt=$dockerPrompt; stream=$false } | ConvertTo-Json
    $dockerfile = ""
    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 120
        $dockerfile = $resp.response; Write-Host "Dockerfile generated." -ForegroundColor Green
    } catch { Write-Err "Dockerfile generation failed: $_"; Pause-Menu; return }
    $composePrompt = "$($AgentSystemPrompts["Forge"])`n`nGenerate a docker-compose.yml for: $appDesc`nInclude health checks. Output ONLY the docker-compose.yml content."
    $body2 = @{ model=$Agents["Forge"].Model; prompt=$composePrompt; stream=$false } | ConvertTo-Json
    $composeContent = ""
    try {
        $resp2 = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $body2 -ContentType "application/json" -TimeoutSec 120
        $composeContent = $resp2.response; Write-Host "docker-compose.yml generated." -ForegroundColor Green
    } catch { Write-Err "Compose generation failed: $_" }
    $appName    = ($appDesc -split " ")[0].ToLower() -replace "[^a-z0-9]",""
    $deployPath = "$PSScriptRoot\CHAMP-Deploy\$appName-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $deployPath -Force | Out-Null
    Set-Content "$deployPath\Dockerfile"         -Value $dockerfile     -Encoding UTF8
    if ($composeContent) { Set-Content "$deployPath\docker-compose.yml" -Value $composeContent -Encoding UTF8 }
    Write-OK "Deployment files saved to $deployPath"
    $deploy = Read-Host "Deploy now with docker compose? (Y/N)"
    if ($deploy -match "^[Yy]") {
        if (-not (Test-DockerRunning)) { Write-Err "Docker is not running."; Pause-Menu; return }
        Push-Location $deployPath; docker compose up -d 2>&1; Pop-Location
        Speak-CHAMP "Deployment complete. Your application is starting up."
        Write-OK "Application deployed. Check 'docker ps' for status."
    }
    if ($appDesc -match "port\s+(\d+)") {
        $port = $Matches[1]
        $open = Read-Host "Open http://localhost:$port in browser? (Y/N)"
        if ($open -match "^[Yy]") { Start-Process "http://localhost:$port" }
    }
    Pause-Menu
}

function Show-DeploymentMenu {
    Show-Header; Write-Info "AI Deployment Engine"; Write-Info "--------------------"
    Write-Host "1. Deploy Application (AI-generated Dockerfile + Compose)"
    Write-Host "2. Back"
}

function Deployment-Menu {
    do {
        Show-DeploymentMenu; $choice = Read-Host "Select"
        switch ($choice) {
            "1" { Invoke-DeploymentEngine } "2" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "2")
}

# -------------------------------------------------------
# Multi-Mode Personalities
# -------------------------------------------------------
function Switch-CHAMPMode {
    Show-Header
    Write-Info "CHAMP AI Mode Selector  [Current: $Global:CHAMPMode]"; Write-Host ""
    $modes = $CHAMPModes.Keys | Sort-Object
    for ($i = 0; $i -lt $modes.Count; $i++) {
        $m = $modes[$i]; $marker = if ($m -eq $Global:CHAMPMode) { " <-- ACTIVE" } else { "" }
        Write-Host "$($i+1). $m - $($CHAMPModes[$m].Description)$marker" -ForegroundColor $CHAMPModes[$m].Color
    }
    Write-Host "$($modes.Count+1). Back"
    $sel = Read-Host "Select mode"
    if ($sel -match "^\d+$") {
        $idx = [int]$sel - 1
        if ($idx -ge 0 -and $idx -lt $modes.Count) {
            $Global:CHAMPMode = $modes[$idx]
            Write-OK "Mode: $Global:CHAMPMode  |  Default agent: $($CHAMPModes[$Global:CHAMPMode].DefaultAgent)"
            Speak-CHAMP "CHAMP AI is now in $Global:CHAMPMode mode."
        }
    }
    Pause-Menu
}

# -------------------------------------------------------
# Advanced AI Platform Menu
# -------------------------------------------------------
function Show-AdvancedMenu {
    Show-Header
    Write-Info "Advanced AI Platform  [Mode: $Global:CHAMPMode]"
    Write-Info "-----------------------------------------------"
    Write-Host "1. AI Memory Layer          (projects, notes, knowledge)" -ForegroundColor Cyan
    Write-Host "2. Local RAG / Knowledge    (ingest docs, semantic search)" -ForegroundColor Cyan
    Write-Host "3. AI API Gateway           (REST API for all agents)" -ForegroundColor Cyan
    Write-Host "4. Autonomous Agents        (multi-step goal execution)" -ForegroundColor Yellow
    Write-Host "5. Auto Multi-Model Router  (AI picks best agent)" -ForegroundColor Yellow
    Write-Host "6. AI Deployment Engine     (describe app, deploy it)" -ForegroundColor Green
    Write-Host "7. Mode Switcher            (Builder/Cyber/Research/Executive)" -ForegroundColor Magenta
    Write-Host "8. Back"
}

function Advanced-Menu {
    do {
        Show-AdvancedMenu; $choice = Read-Host "Select"
        switch ($choice) {
            "1" { Memory-Menu } "2" { RAG-Menu } "3" { APIGateway-Menu }
            "4" { AutonomousAgents-Menu } "5" { AutoRoute-Task }
            "6" { Deployment-Menu } "7" { Switch-CHAMPMode } "8" { return }
            default { Play-ErrorSound; Pause-Menu }
        }
    } while ($choice -ne "8")
}

# Main Menu
# -----------------------------
function Show-MainMenu {
    Show-Header
    Write-Host "1.  CEREBRO System Status"
    Write-Host "2.  Start Ollama"
    Write-Host "2S. Stop Ollama"
    Write-Host "3.  X-Agent Launcher"
    Write-Host "4.  Show X-Agent Model Map"
    Write-Host "5.  Pull/Update Single X-Agent Model"
    Write-Host "6.  Pull All X-Agent Models"
    Write-Host "6R. Register Agents in Open WebUI (create named models)" -ForegroundColor Green
    Write-Host "6D. Remove Named Agent Models"
    Write-Host "7.  List Ollama Models"
    Write-Host "8.  Start Open WebUI"
    Write-Host "9.  Stop Open WebUI"
    Write-Host "10. Restart Open WebUI"
    Write-Host "11. Update Open WebUI Manually"
    Write-Host "12. Open Open WebUI Dashboard"
    Write-Host "13. Show Docker Containers"
    Write-Host "14. VS Code Integration" -ForegroundColor Cyan
    Write-Host "15. Wolverine Recovery Center"
    Write-Host "16. Toggle Voice Responses"
    Write-Host "17. Toggle Sound Alerts"
    Write-Host "18. View Activity Log"
    Write-Host "19. AI Development Tools" -ForegroundColor Cyan
    Write-Host "20. DevOps Control Panel" -ForegroundColor Magenta
    Write-Host "21. Intelligence Hub" -ForegroundColor Yellow
    Write-Host "22. CEREBRO Chat / Voice Conversation" -ForegroundColor Green
    Write-Host "23. Exit"
    Write-Host "24. Advanced AI Platform    (Memory, RAG, API, Agents, Deploy)" -ForegroundColor Cyan
    Write-Host "25. Cybersecurity Toolkit   (VirusTotal, CVE, YARA, MITRE, Sigma, ZT, OTX)" -ForegroundColor Red
    Write-Host "26. Observability Stack     (Prometheus + Grafana + Loki)" -ForegroundColor Yellow
    Write-Host "27. Agent Operations        (Council, Chain, Builder, Scheduler, NL Infra)" -ForegroundColor Magenta
    Write-Host "28. CHAMP-QN Integration    (connect to CHAMP-QN orchestration platform)" -ForegroundColor Green
    Write-Host "29. Plugins                 (drop .ps1 files in CHAMP-Plugins\ to extend)" -ForegroundColor DarkYellow
    Write-Host ""
    if ($EnableVoice)  { Write-OK   "Voice  : ON"  } else { Write-Warn "Voice  : OFF" }
    if ($EnableSounds) { Write-OK   "Sounds : ON"  } else { Write-Warn "Sounds : OFF" }
    if ($Global:WakeWordActive) { Write-OK "Wake Word : ACTIVE  -  say 'Hey CEREBRO'" } else { Write-Warn "Wake Word : OFF" }
}

CHAMP-Greeting
Ensure-HostsEntry
Initialize-Plugins
Initialize-WebUI -ScriptRoot $PSScriptRoot
Write-ActivityLog "CHAMP AI Control Center started"

do {
    Test-WakeWordTriggered
    Run-DueScheduledTasks
    Show-MainMenu
    $choice = Read-Host "Select an option"
    switch ($choice) {
        "1"  { Show-SystemStatus }
        "2"  { Start-Ollama }
        "2S" { Stop-Ollama }
        "2s" { Stop-Ollama }
        "3"  { Agent-Menu }
        "4"  { Show-AgentMap }
        "5"  { Pull-SingleAgentModel }
        "6"  { Pull-AgentModels }
        "6R" { Register-AgentModels }
        "6r" { Register-AgentModels }
        "6D" { Remove-AgentModels }
        "6d" { Remove-AgentModels }
        "7"  { List-OllamaModels }
        "8"  { Start-OpenWebUI }
        "9"  { Stop-OpenWebUI }
        "10" { Restart-OpenWebUI }
        "11" { Update-OpenWebUI }
        "12" { Open-WebDashboard }
        "13" { Show-DockerContainers }
        "14" { VSCode-Menu }
        "15" { Wolverine-Menu }
        "16" { Toggle-Voice }
        "17" { Toggle-Sounds }
        "18" { Show-ActivityLog }
        "19" { AIDevTools-Menu }
        "20" { DevOps-Menu }
        "21" { IntelHub-Menu }
        "22" { Chat-Menu }
        "23" { Speak-CHAMP "CEREBRO shutting down. Goodbye, Carnell. Until next time."; Write-ActivityLog "CHAMP AI Control Center exited"; Write-Host "Exiting..." }
        "24" { Advanced-Menu }
        "25" { Cyber-Menu }
        "26" { Observability-Menu }
        "27" { AgentOps-Menu }
        "28" { CHAMPQN-Menu }
        "29" { Plugins-Menu }
        default { Speak-CHAMP "Invalid selection."; Play-ErrorSound; Pause-Menu }
    }
} while ($choice -ne "23")
