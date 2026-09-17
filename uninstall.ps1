$ErrorActionPreference='SilentlyContinue'
Unregister-ScheduledTask -TaskName 'RemoteMonitor V2.4 Agent' -Confirm:$false
Remove-Item 'C:\ProgramData\RemoteMonitorV2.4' -Recurse -Force
Write-Host 'Remote Monitor V2.4 Agent removed.'
