$ErrorActionPreference = "Stop"

$Repo = "https://github.com/amolgadakh86/RemoteMonitor-Agent"
$Raw = "https://raw.githubusercontent.com/amolgadakh86/RemoteMonitor-Agent/main"
$InstallDir = Join-Path $env:ProgramData "RemoteMonitorV2.4"
$PythonDir = Join-Path $InstallDir "Python"
$ZipUrl = "$Raw/RemoteMonitor_V2.4_Agent_Package.zip"
$ZipPath = Join-Path $env:TEMP "RemoteMonitor_V2.4_Agent_Package.zip"
$PythonInstaller = Join-Path $env:TEMP "python-installer.exe"

Write-Host "Remote Monitor V2.4 - authorized Agent installer"

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

Write-Host "Downloading Agent package..."
Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath

$Extract = Join-Path $env:TEMP ("RemoteMonitorAgent_" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force -Path $Extract | Out-Null
Expand-Archive -Path $ZipPath -DestinationPath $Extract -Force

$AgentSource = Join-Path $Extract "Agent"
if (!(Test-Path $AgentSource)) { throw "Agent folder was not found in downloaded package." }

Copy-Item (Join-Path $AgentSource "*") $InstallDir -Recurse -Force

# Use an official Python installer; no security/UAC bypass is attempted.
$pyUrl = "https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe"
Write-Host "Downloading Python runtime..."
Invoke-WebRequest -Uri $pyUrl -OutFile $PythonInstaller

Write-Host "Installing Python runtime..."
Start-Process -FilePath $PythonInstaller -ArgumentList "/quiet InstallAllUsers=0 PrependPath=0 Include_test=0 TargetDir=`"$PythonDir`"" -Wait

$PythonExe = Join-Path $PythonDir "python.exe"
if (!(Test-Path $PythonExe)) { throw "Python installation failed." }

Write-Host "Installing Agent dependencies..."
& $PythonExe -m pip install --upgrade pip
& $PythonExe -m pip install -r (Join-Path $InstallDir "requirements.txt")

# First-time configuration: server URL and token are required.
$configPath = Join-Path $InstallDir "config.json"
$cfg = Get-Content $configPath -Raw | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($cfg.server_url) -or $cfg.server_url -eq "http://127.0.0.1:8765") {
    $answer = Read-Host "Server URL (press Enter for http://127.0.0.1:8765)"
    if ($answer) { $cfg.server_url = $answer.TrimEnd("/") }
}

if ($cfg.agent_token -eq "PUT_AGENT_TOKEN_HERE") {
    $token = Read-Host "Enter the authorized Agent Token"
    if ([string]::IsNullOrWhiteSpace($token)) { throw "Agent Token is required." }
    $cfg.agent_token = $token
}

$cfg | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8

# Authorized per-user startup task. This does not bypass UAC/security.
$taskName = "RemoteMonitor V2.4 Agent"
$pythonArgs = "`"$InstallDir\agent.py`""
$action = New-ScheduledTaskAction -Execute $PythonExe -Argument $pythonArgs
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Start-ScheduledTask -TaskName $taskName

Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
Remove-Item $PythonInstaller -Force -ErrorAction SilentlyContinue
Remove-Item $Extract -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Agent installation completed."
Write-Host "Installed at: $InstallDir"
Write-Host "Startup task: $taskName"
