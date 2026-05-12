# CHAMP AI Control Center — Workstation Deployment Guide

## Prerequisites

Install these before deploying. All are free.

| Tool | Download | Notes |
| --- | --- | --- |
| PowerShell 7+ | https://aka.ms/powershell | Required — not Windows PowerShell 5 |
| Ollama | https://ollama.com/download | Local LLM runtime |
| Docker Desktop | https://www.docker.com/products/docker-desktop | For Open WebUI |
| VS Code (optional) | https://code.visualstudio.com | For project folder integration |
| NVIDIA GPU Driver (optional) | https://www.nvidia.com/drivers | For GPU hardware monitor |

---

## Step 1 — Choose a Permanent Home

Move the folder out of Downloads to somewhere stable. Downloads gets cleared; this should not.

Recommended locations:

```
C:\Tools\champ-ai-control-center-xagents\
  -- or --
C:\Users\<you>\AppData\Local\CHAMP-AI\
```

To move it now, open PowerShell 7 and run:

```powershell
Move-Item "$env:USERPROFILE\Downloads\champ-ai-control-center-xagents" "C:\Tools\champ-ai-control-center-xagents"
```

All runtime files (`CHAMP-activity.log`, `CHAMP-prompts.json`, `.env`, Modelfiles, `champ-ai-env\`) are created in the same folder as the script, so keeping them together in `C:\Tools\` means nothing gets left behind in Downloads.

---

## Step 2 — Allow PowerShell to Run the Script

Open PowerShell 7 **as Administrator** and run once:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

This allows locally-created scripts to run without requiring a digital signature.

---

## Step 3 — Create a Desktop Shortcut

This shortcut launches the control center in a PowerShell 7 window.

Open PowerShell 7 and paste the block below. Edit the `$installPath` if you chose a different location in Step 1.

```powershell
$installPath = "C:\Tools\champ-ai-control-center-xagents"
$scriptFile  = "$installPath\champ-ai-control-center-xagents.ps1"
$iconFile    = "$installPath\champ-icon.ico"
$shortcutPath = "$env:USERPROFILE\Desktop\CHAMP AI Control Center.lnk"

$wsh    = New-Object -ComObject WScript.Shell
$lnk    = $wsh.CreateShortcut($shortcutPath)
$lnk.TargetPath       = "pwsh.exe"
$lnk.Arguments        = "-NoExit -ExecutionPolicy Bypass -File `"$scriptFile`""
$lnk.WorkingDirectory = $installPath
$lnk.WindowStyle      = 1
$lnk.Description      = "CHAMP AI Control Center - X-Agent Edition"
# Use the icon file if present, otherwise fall back to pwsh icon
if (Test-Path $iconFile) { $lnk.IconLocation = $iconFile } else { $lnk.IconLocation = "pwsh.exe,0" }
$lnk.Save()

Write-Host "Shortcut created: $shortcutPath"
```

---

## Step 4 — Pin to Taskbar

Windows does not support pinning a `.ps1` or `.bat` file directly to the taskbar, but pinning a shortcut `.exe` works. Use this two-step approach:

### Option A — Pin the shortcut via the Start Menu (recommended)

1. Run the Step 3 script above so the Desktop shortcut exists.
2. Right-click the shortcut on the Desktop.
3. Select **Show more options** → **Pin to taskbar**.

That is all. The icon will appear in your taskbar and launch the control center in a PowerShell 7 window with one click.

### Option B — Automated pin via PowerShell (no clicking required)

Paste this in PowerShell 7. It uses the Windows Shell verb to pin programmatically.

```powershell
$shortcutPath = "$env:USERPROFILE\Desktop\CHAMP AI Control Center.lnk"

if (-not (Test-Path $shortcutPath)) {
    Write-Host "Shortcut not found. Run Step 3 first." -ForegroundColor Red
} else {
    $shell  = New-Object -ComObject Shell.Application
    $folder = $shell.Namespace((Split-Path $shortcutPath))
    $item   = $folder.ParseName((Split-Path $shortcutPath -Leaf))
    $item.InvokeVerb("taskbarpin")
    Write-Host "Pinned to taskbar." -ForegroundColor Green
}
```

> **Note:** `taskbarpin` is an undocumented Shell verb present in Windows 10 and Windows 11. If it silently does nothing (Microsoft occasionally blocks it via policy), use Option A instead.

---

## Step 5 — (Optional) Add a Custom Icon

Windows will show the default PowerShell icon unless you supply a `.ico` file.

To use a custom icon:

1. Find or create a 256x256 `.ico` file.
2. Save it as `champ-icon.ico` inside the install folder.
3. Re-run the Step 3 shortcut script — it will pick the icon up automatically.

Free icon resources: [https://icons8.com](https://icons8.com) or [https://www.flaticon.com](https://www.flaticon.com) — search "AI", "brain", or "X".

---

## Step 6 — Pull All Agent Models

On first launch, download all six agent models. This requires internet access and ~15–25 GB of disk space depending on which models are already cached.

1. Launch CHAMP AI Control Center from the taskbar.
2. Select **2** — Start Ollama.
3. Select **6** — Pull All X-Agent Models, type `YES` to confirm.
4. Wait for all six models to finish. A Windows toast notification will fire when complete.

Models pulled:

| Agent | Model | Approx size |
| --- | --- | --- |
| Professor-X | llama3.1:8b | ~4.7 GB |
| Forge | qwen2.5-coder:7b | ~4.4 GB |
| Cyclops | mistral:7b | ~4.1 GB |
| Nightcrawler | phi3:mini | ~2.2 GB |
| Wolverine | phi3:mini | (shared with Nightcrawler) |
| Magneto | codellama:7b | ~3.8 GB |

---

## Step 7 — Start Open WebUI

1. Start Docker Desktop and wait for it to finish loading.
2. In CHAMP AI, select **8** — Start Open WebUI.
3. Select **12** — Open Open WebUI Dashboard.
4. Create your admin account on first visit to `http://localhost:3000`.

---

## Verify Everything is Working

Run a quick health check from the main menu:

- **Option 1** — CEREBRO System Status: RAM, disk, Docker, Ollama, loaded models.
- **Option 15 → 1** — Wolverine Health Scan: service-by-service green/yellow/red report.
- **Option 19 → 9** — AI Services Port Dashboard: confirm Ollama (11434) and Open WebUI (3000) show ACTIVE.

---

## Auto-Start Ollama on Login (Optional)

If you want Ollama running before you open the control center:

```powershell
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$wsh  = New-Object -ComObject WScript.Shell
$lnk  = $wsh.CreateShortcut("$startupPath\Ollama.lnk")
$lnk.TargetPath       = (Get-Command ollama).Source
$lnk.Arguments        = "serve"
$lnk.WindowStyle      = 7   # minimized
$lnk.Description      = "Ollama AI runtime"
$lnk.Save()
Write-Host "Ollama will start minimized on next login."
```

Remove it later by deleting `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Ollama.lnk`.

---

## Uninstall

1. Delete the install folder (`C:\Tools\champ-ai-control-center-xagents`).
2. Delete the Desktop shortcut.
3. Right-click the taskbar icon → **Unpin from taskbar**.
4. If you added the Ollama startup entry, delete `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Ollama.lnk`.
5. Ollama and Docker Desktop have their own uninstallers in **Settings → Apps**.
