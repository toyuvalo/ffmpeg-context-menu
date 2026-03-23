# install.ps1 — Register FFmpeg context menu entries (no admin required)
# Run: powershell -ExecutionPolicy Bypass -File install.ps1

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

# ── Clean up old entries first ──
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

# ══════════════════════════════════════
#  FILE context menu (right-click files)
#  Single entry — format picker shown in GUI
#  Uses VBS launcher for fast multi-select collection
# ══════════════════════════════════════

$fileRoot = "HKCU:\Software\Classes\*\shell\FFmpegConvert"

New-Item -Path $fileRoot -Force | Out-Null
Set-ItemProperty -Path $fileRoot -Name "(Default)" -Value "FFmpeg Convert"
$icoPath = Join-Path $PSScriptRoot "ffmpeg.ico"
Set-ItemProperty -Path $fileRoot -Name "Icon" -Value "$icoPath,0"
Set-ItemProperty -Path $fileRoot -Name "MultiSelectModel" -Value "Player"

$commandKey = "$fileRoot\command"
New-Item -Path $commandKey -Force | Out-Null

$cmd = "wscript.exe `"$launcherPath`" `"%1`""
Set-ItemProperty -Path $commandKey -Name "(Default)" -Value $cmd

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "You should now see:" -ForegroundColor White
Write-Host '  - "FFmpeg Convert" when right-clicking any file(s)' -ForegroundColor Gray
Write-Host '  - A format picker dialog will appear after clicking' -ForegroundColor Gray
Write-Host ""
Write-Host "If the menu doesn't appear, restart Explorer or log out/in." -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to close"
