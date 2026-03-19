# install-silent.ps1 — Same as install.ps1 but no Read-Host at the end
$launcherPath = Join-Path $PSScriptRoot "launcher.vbs"
$scriptPath = Join-Path $PSScriptRoot "ffmpeg-convert.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: ffmpeg-convert.ps1 not found in $PSScriptRoot" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $launcherPath)) {
    Write-Host "ERROR: launcher.vbs not found in $PSScriptRoot" -ForegroundColor Red
    exit 1
}

Write-Host "Installing FFmpeg Context Menu..." -ForegroundColor Cyan

# Clean up old entries
$oldKeys = @(
    "HKCU:\Software\Classes\*\shell\FFmpegConvert",
    "HKCU:\Software\Classes\Directory\shell\FFmpegBatchConvert",
    "HKCU:\Software\Classes\Directory\Background\shell\FFmpegBatchConvert"
)
foreach ($key in $oldKeys) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Removed old: $key" -ForegroundColor DarkGray
    }
}

# Single entry — format picker shown in GUI
$fileRoot = "HKCU:\Software\Classes\*\shell\FFmpegConvert"

New-Item -Path $fileRoot -Force | Out-Null
Set-ItemProperty -Path $fileRoot -Name "(Default)" -Value "FFmpeg Convert"
Set-ItemProperty -Path $fileRoot -Name "Icon" -Value "shell32.dll,277"
Set-ItemProperty -Path $fileRoot -Name "MultiSelectModel" -Value "Player"

$commandKey = "$fileRoot\command"
New-Item -Path $commandKey -Force | Out-Null
$cmd = "wscript.exe `"$launcherPath`" `"%1`""
Set-ItemProperty -Path $commandKey -Name "(Default)" -Value $cmd

Write-Host "  File menu: OK" -ForegroundColor Green
Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
