$ErrorActionPreference = "Stop"

# Remote Monitor V2.4 - authorized Agent installer
# Standard installation only. No UAC/security bypass.
$Raw = "https://raw.githubusercontent.com/amolgadakh86/RemoteMonitor-Agent/main"
$InstallDir = Join-Path $env:ProgramData "RemoteMonitorV2.4"
$PythonDir = Join-Path $InstallDir "Python"
$ZipUrl = "$Raw/RemoteMonitor_V2.4_Agent_Package.zip"
$ZipPath = Join-Path $env:TEMP "RemoteMonitor_V2.4_Agent_Package.zip"
$PythonInstaller = Join-Path $env:TEMP "python-3.12.10-amd64.exe"
$Extract = Join-Path $env:TEMP ("RemoteMonitorAgent_" + [guid]::NewGuid().ToString())
$TaskName = "RemoteMonitor V2.4 Agent"

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Check-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Fail "Please run PowerShell as Administrator and run the installer again."
    }
}

Check-Admin
Write-Host "Remote Monitor V2.4 - Authorized Agent Installer" -ForegroundColor Cyan

# Remove stale task from previous broken installation.
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $PythonDir | Out-Null

Write-Host "Downloading Agent package..."
Invoke-WebRequest -UseBasicParsing -Uri $ZipUrl -OutFile $ZipPath
if (!(Test-Path $ZipPath) -or ((Get-Item $ZipPath).Length -lt 1000)) { Fail "Agent package download failed." }

New-Item -ItemType Directory -Force -Path $Extract | Out-Null
Expand-Archive -LiteralPath $ZipPath -DestinationPath $Extract -Force
$AgentSource = Join-Path $Extract "Agent"
if (!(Test-Path (Join-Path $AgentSource "agent.py"))) { Fail "Downloaded Agent package is invalid." }
Copy-Item (Join-Path $AgentSource "*") $InstallDir -Recurse -Force

# Clean old Python folder so a previous failed runtime cannot interfere.
if (Test-Path $PythonDir) { Remove-Item $PythonDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $PythonDir | Out-Null

$PyUrl = "https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe"
Write-Host "Downloading official Python 3.12.10 runtime..."
Invoke-WebRequest -UseBasicParsing -Uri $PyUrl -OutFile $PythonInstaller
if (!(Test-Path $PythonInstaller) -or ((Get-Item $PythonInstaller).Length -lt 1000000)) { Fail "Python runtime download failed." }

Write-Host "Installing Python runtime to $PythonDir ..."
$args = @(
    "/quiet",
    "InstallAllUsers=1",
    "PrependPath=0",
    "Include_pip=1",
    "Include_test=0",
    "TargetDir=`"$PythonDir`""
)
$p = Start-Process -FilePath $PythonInstaller -ArgumentList $args -Wait -PassThru
if ($p.ExitCode -ne 0) { Fail "Python installer failed with exit code $($p.ExitCode)." }

$PythonExe = Join-Path $PythonDir "python.exe"
if (!(Test-Path $PythonExe)) {
    Write-Host "Expected Python path not found. Searching ProgramData..."
    $found = Get-ChildItem $InstallDir -Filter python.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $PythonExe = $found.FullName } else { Fail "Python installation failed: python.exe was not created." }
}

Write-Host "Python found: $PythonExe"
& $PythonExe --version
if ($LASTEXITCODE -ne 0) { Fail "Installed Python cannot be started." }

Write-Host "Installing Agent dependencies..."
& $PythonExe -m pip install --disable-pip-version-check --upgrade pip
if ($LASTEXITCODE -ne 0) { Fail "pip installation/update failed." }
& $PythonExe -m pip install --disable-pip-version-check -r (Join-Path $InstallDir "requirements.txt")
if ($LASTEXITCODE -ne 0) { Fail "Agent dependency installation failed." }

$configPath = Join-Path $InstallDir "config.json"
$cfg = Get-Content $configPath -Raw | ConvertFrom-Json

$answer = Read-Host "Server URL [Enter = http://127.0.0.1:8765]"
if ([string]::IsNullOrWhiteSpace($answer)) { $answer = "http://127.0.0.1:8765" }
$cfg.server_url = $answer.TrimEnd('/')

$token = Read-Host "Authorized Agent Token"
if ([string]::IsNullOrWhiteSpace($token)) { Fail "Agent Token is required." }
$cfg.agent_token = $token.Trim()
$cfg | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8

# Create a standard per-user interactive logon task.
$action = New-ScheduledTaskAction -Execute $PythonExe -Argument "`"$InstallDir\agent.py`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "Starting Agent..."
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 3

# Verify task and process. The agent writes its connection log to agent.log.
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
$info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop
Write-Host "Task state: $($task.State)"
Write-Host "Last run: $($info.LastRunTime)"
Write-Host "Last result: $($info.LastTaskResult)"

Write-Host ""
Write-Host "Installation completed." -ForegroundColor Green
Write-Host "Agent folder: $InstallDir"
Write-Host "Agent log:    $(Join-Path $InstallDir 'agent.log')"
Write-Host ""
Write-Host "If the Server is on this same PC, the Agent is configured for 127.0.0.1:8765."

Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
Remove-Item $PythonInstaller -Force -ErrorAction SilentlyContinue
Remove-Item $Extract -Recurse -Force -ErrorAction SilentlyContinue
