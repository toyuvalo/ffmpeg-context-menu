@echo off
REM setup.cmd — Called by the self-extracting installer
REM Launches the PowerShell setup script which handles everything

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup.ps1"
