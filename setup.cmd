@echo off
REM setup.cmd — Called by the self-extracting installer
REM Copies files to %LOCALAPPDATA%\FFmpegMenu and registers context menu

set "DEST=%LOCALAPPDATA%\FFmpegMenu"
set "LAUNCHER=%DEST%\launcher.vbs"

REM Create destination
if not exist "%DEST%" mkdir "%DEST%"

REM Copy files (iexpress extracts to a temp dir, we copy from there)
copy /y "launcher.vbs" "%DEST%\" >nul
copy /y "ffmpeg-convert.ps1" "%DEST%\" >nul
copy /y "install.ps1" "%DEST%\" >nul
copy /y "install-silent.ps1" "%DEST%\" >nul
copy /y "install.cmd" "%DEST%\" >nul
copy /y "uninstall.ps1" "%DEST%\" >nul

REM Clean old registry entries
reg delete "HKCU\Software\Classes\*\shell\FFmpegConvert" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\FFmpegBatchConvert" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\FFmpegBatchConvert" /f >nul 2>&1

REM Register single context menu entry
set "FK=HKCU\Software\Classes\*\shell\FFmpegConvert"
reg add "%FK%" /ve /d "FFmpeg Convert" /f >nul
reg add "%FK%" /v "Icon" /d "shell32.dll,277" /f >nul
reg add "%FK%" /v "MultiSelectModel" /d "Player" /f >nul
reg add "%FK%\command" /ve /d "wscript.exe \"%LAUNCHER%\" \"%%1\"" /f >nul

REM Show success
msg "%USERNAME%" "FFmpeg Convert installed! Right-click any file to use it." >nul 2>&1
if errorlevel 1 (
    echo.
    echo   FFmpeg Convert installed successfully!
    echo   Right-click any file to use it.
    echo.
    timeout /t 3 >nul
)
