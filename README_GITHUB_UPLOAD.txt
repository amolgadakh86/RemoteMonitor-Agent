GITHUB UPLOAD - REMOTE MONITOR V2.4 AGENT

Upload these three files to the repository root:
1. install.ps1
2. RemoteMonitor_V2.4_Agent_Package.zip
3. uninstall.ps1 (optional)

Run from an elevated PowerShell window:
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/amolgadakh86/RemoteMonitor-Agent/main/install.ps1' | iex"

The installer:
- Downloads the Agent package from GitHub.
- Installs official Python 3.12.10 to C:\ProgramData\RemoteMonitorV2.4\Python.
- Verifies python.exe exists before continuing.
- Installs requests, websockets and Pillow.
- Prompts for Server URL and authorized Agent Token.
- Creates a standard interactive Windows Scheduled Task at user logon.
- Starts the Agent and writes connection diagnostics to agent.log.
- Does not bypass UAC or Windows security.
