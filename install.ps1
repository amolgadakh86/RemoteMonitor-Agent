$ErrorActionPreference = 'Stop'
$Raw = 'https://raw.githubusercontent.com/amolgadakh86/RemoteMonitor-Agent/main'
$InstallDir = Join-Path $env:ProgramData 'RemoteMonitorV2.4'
$PythonDir = Join-Path $InstallDir 'Python'
$TaskName = 'RemoteMonitor V2.4 Agent'
$ZipPath = Join-Path $env:TEMP 'RemoteMonitor_V2.4_Agent_Package.zip'
$PyInstaller = Join-Path $env:TEMP 'python-3.12.10-amd64.exe'
$Extract = Join-Path $env:TEMP ('RMA_' + [guid]::NewGuid())
function Stop-OldAgent { Get-Process python,pythonw -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*RemoteMonitor*' -or $_.CommandLine -like '*agent.py*' } | Stop-Process -Force -ErrorAction SilentlyContinue; Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue }
function Need-Admin { $p=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent(); if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){ throw 'Run PowerShell as Administrator.' } }
Need-Admin
Write-Host 'Remote Monitor V2.4 - Corrected Agent Installer' -ForegroundColor Cyan
Stop-OldAgent
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Invoke-WebRequest -UseBasicParsing "$Raw/RemoteMonitor_V2.4_Agent_Package.zip" -OutFile $ZipPath
if(!(Test-Path $ZipPath)){throw 'Agent package download failed.'}
Remove-Item $Extract -Recurse -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force -Path $Extract | Out-Null
Expand-Archive $ZipPath $Extract -Force
$src=Join-Path $Extract 'Agent'; if(!(Test-Path (Join-Path $src 'agent.py'))){throw 'Agent package is invalid.'}
Get-ChildItem $InstallDir -Force | Where-Object { $_.Name -notin @('Python') } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $src '*') $InstallDir -Recurse -Force
if(Test-Path $PythonDir){Remove-Item $PythonDir -Recurse -Force}
New-Item -ItemType Directory -Force -Path $PythonDir | Out-Null
$pyUrl='https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe'
Write-Host 'Downloading Python 3.12.10...'
Invoke-WebRequest -UseBasicParsing $pyUrl -OutFile $PyInstaller
if(!(Test-Path $PyInstaller)){throw 'Python download failed.'}
Write-Host 'Installing Python...'
$pi=Start-Process $PyInstaller -ArgumentList @('/quiet','InstallAllUsers=1','PrependPath=0','Include_pip=1','Include_test=0',('TargetDir='+$PythonDir)) -Wait -PassThru
if($pi.ExitCode -ne 0){throw "Python installer failed: $($pi.ExitCode)"}
$PythonExe=Join-Path $PythonDir 'python.exe'
if(!(Test-Path $PythonExe)){ $f=Get-ChildItem $PythonDir -Filter python.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){$PythonExe=$f.FullName}else{throw "python.exe was not installed under $PythonDir"} }
Write-Host "Python: $PythonExe"; & $PythonExe --version
& $PythonExe -m pip install --disable-pip-version-check -r (Join-Path $InstallDir 'requirements.txt')
if($LASTEXITCODE -ne 0){throw 'Agent dependencies failed.'}
$config=Join-Path $InstallDir 'config.json'; $cfg=Get-Content $config -Raw | ConvertFrom-Json
$u=Read-Host 'Server URL [Enter = http://127.0.0.1:8765]'; if([string]::IsNullOrWhiteSpace($u)){$u='http://127.0.0.1:8765'}; $cfg.server_url=$u.TrimEnd('/')
$t=Read-Host 'Authorized Agent Token'; if([string]::IsNullOrWhiteSpace($t)){throw 'Agent Token is required.'}; $cfg.agent_token=$t.Trim(); $cfg | ConvertTo-Json -Depth 10 | Set-Content $config -Encoding UTF8
$interactive=(Get-CimInstance Win32_ComputerSystem).UserName; if([string]::IsNullOrWhiteSpace($interactive)){$interactive="$env:USERDOMAIN\$env:USERNAME"}
$action=New-ScheduledTaskAction -Execute $PythonExe -Argument ('"'+(Join-Path $InstallDir 'agent.py')+'"')
$trigger=New-ScheduledTaskTrigger -AtLogOn -User $interactive
$principal=New-ScheduledTaskPrincipal -UserId $interactive -LogonType Interactive -RunLevel Limited
$settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName
Start-Sleep 3
$info=Get-ScheduledTaskInfo $TaskName
Write-Host "Task user: $interactive"; Write-Host "Task result: $($info.LastTaskResult)"; Write-Host "Log: $InstallDir\agent.log" -ForegroundColor Green
Write-Host 'Installation completed. Check agent.log for REGISTERED/ERROR messages.' -ForegroundColor Green
Remove-Item $ZipPath,$PyInstaller -Force -ErrorAction SilentlyContinue; Remove-Item $Extract -Recurse -Force -ErrorAction SilentlyContinue
