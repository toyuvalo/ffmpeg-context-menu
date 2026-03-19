# uninstall.ps1 — Remove all FFmpeg context menu entries
# Run: powershell -ExecutionPolicy Bypass -File uninstall.ps1

Write-Host "Removing FFmpeg Context Menu entries..." -ForegroundColor Cyan

$keys = @(
    "HKCU:\Software\Classes\*\shell\FFmpegConvert",
    "HKCU:\Software\Classes\Directory\shell\FFmpegBatchConvert",
    "HKCU:\Software\Classes\Directory\Background\shell\FFmpegBatchConvert"
)

foreach ($key in $keys) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force
        Write-Host "  Removed: $key" -ForegroundColor Gray
    } else {
        Write-Host "  Not found (skip): $key" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Uninstall complete!" -ForegroundColor Green
Write-Host "Restart Explorer or log out/in if menu entries still appear." -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to close"
