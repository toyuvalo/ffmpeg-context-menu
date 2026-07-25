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
    "HKCU:\Software\Classes\Directory\shell\FFmpegConvert",
    "HKCU:\Software\Classes\Directory\Background\shell\FFmpegConvert",
    "HKCU:\Software\Classes\Directory\shell\FFmpegBatchConvert",
    "HKCU:\Software\Classes\Directory\Background\shell\FFmpegBatchConvert"
)
foreach ($key in $oldKeys) {
    # -LiteralPath is mandatory: HKCU:\Software\Classes\*\shell\... contains a
    # literal '*' (the Windows wildcard verb-class). Without -LiteralPath, PS
    # treats '*' as a glob and Remove-Item / Test-Path enumerate every class.
    if (Test-Path -LiteralPath $key) {
        Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Removed old: $key" -ForegroundColor DarkGray
    }
}

$icoPath = Join-Path $PSScriptRoot "ffmpeg.ico"

# ══════════════════════════════════════
#  FILE context menu (right-click files)
#  Single entry — format picker shown in GUI
#  Uses VBS launcher for fast multi-select collection
# ══════════════════════════════════════

$fileRoot = "HKCU:\Software\Classes\*\shell\FFmpegConvert"

# CRITICAL: -LiteralPath everywhere. The path contains a literal '*' (the
# Windows shell wildcard-class for "any file"). Without -LiteralPath,
# PowerShell's provider treats '*' as a glob:
#   - Set-Item -Path '*\...' HANGS trying to enumerate every file class
#   - Set-ItemProperty -Path '*\...' silently fails to write (Default)
# Together those produced the "no app associated" symptom 2026-05-19.
# Also use Set-ItemProperty -Name '(default)' (lowercase) for the unnamed
# default value — that's the canonical form.
New-Item -Path $fileRoot -Force | Out-Null
Set-ItemProperty -LiteralPath $fileRoot -Name "(default)"        -Value "FFmpeg Convert"
Set-ItemProperty -LiteralPath $fileRoot -Name "Icon"             -Value "$icoPath,0"
Set-ItemProperty -LiteralPath $fileRoot -Name "MultiSelectModel" -Value "Player"

$commandKey = "$fileRoot\command"
New-Item -Path $commandKey -Force | Out-Null

$cmd = "wscript.exe `"$launcherPath`" `"%1`""
Set-ItemProperty -LiteralPath $commandKey -Name "(default)" -Value $cmd

# ══════════════════════════════════════
#  FOLDER context menu (right-click folder + empty space inside folder)
#  Converts every file in the folder. Format picker still appears.
#  Bypasses launcher.vbs — no multi-select collection needed for a directory arg.
# ══════════════════════════════════════

$folderCmd = "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$scriptPath`" -Path `"%V`""

foreach ($folderRoot in @(
    "HKCU:\Software\Classes\Directory\shell\FFmpegConvert",
    "HKCU:\Software\Classes\Directory\Background\shell\FFmpegConvert"
)) {
    # Directory paths don't contain '*' but use -LiteralPath for consistency.
    New-Item -Path $folderRoot -Force | Out-Null
    Set-ItemProperty -LiteralPath $folderRoot -Name "(default)" -Value "FFmpeg Convert (all files)"
    Set-ItemProperty -LiteralPath $folderRoot -Name "Icon"      -Value "$icoPath,0"

    $folderCommandKey = "$folderRoot\command"
    New-Item -Path $folderCommandKey -Force | Out-Null
    Set-ItemProperty -LiteralPath $folderCommandKey -Name "(default)" -Value $folderCmd
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "You should now see:" -ForegroundColor White
Write-Host '  - "FFmpeg Convert" when right-clicking any file(s)' -ForegroundColor Gray
Write-Host '  - "FFmpeg Convert (all files)" when right-clicking a folder' -ForegroundColor Gray
Write-Host '    or empty space inside a folder' -ForegroundColor Gray
Write-Host '  - A format picker dialog will appear after clicking' -ForegroundColor Gray
Write-Host ""
Write-Host "If the menu doesn't appear, restart Explorer or log out/in." -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to close"
