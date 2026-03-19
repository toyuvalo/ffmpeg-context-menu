@echo off
REM install.cmd — Register FFmpeg context menu entry (no admin required)
REM Single entry with format picker GUI — works with unlimited file selections

set "LAUNCHER=%LOCALAPPDATA%\FFmpegMenu\launcher.vbs"

echo.
echo   FFmpeg Context Menu Installer
echo   ==============================
echo.

REM ── Clean old entries ──
reg delete "HKCU\Software\Classes\*\shell\FFmpegConvert" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\FFmpegBatchConvert" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\FFmpegBatchConvert" /f >nul 2>&1

REM ── Single context menu entry ──
set "FK=HKCU\Software\Classes\*\shell\FFmpegConvert"
reg add "%FK%" /ve /d "FFmpeg Convert" /f >nul
reg add "%FK%" /v "Icon" /d "shell32.dll,277" /f >nul
reg add "%FK%" /v "MultiSelectModel" /d "Player" /f >nul
reg add "%FK%\command" /ve /d "wscript.exe \"%LAUNCHER%\" \"%%1\"" /f >nul

echo   Context menu: OK
echo.
echo   Done! "FFmpeg Convert" is now in your right-click menu.
echo   A format picker will appear when you click it.
echo.
echo   If the menu doesn't appear, restart Explorer or log out/in.
echo.
pause
