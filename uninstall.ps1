$ErrorActionPreference = "Stop"
$TaskName = "RemoteMonitor V2.4 Agent"
$InstallDir = Join-Path $env:ProgramData "RemoteMonitorV2.4"
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
Write-Host "Remote Monitor V2.4 Agent removed."
