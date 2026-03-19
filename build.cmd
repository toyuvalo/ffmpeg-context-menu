@echo off
REM build.cmd — Builds FFmpegConvertSetup.exe from the current directory
REM Requires: iexpress.exe (built into Windows)

set "SED=%TEMP%\ffmpeg_build.sed"
set "OUT=%~dp0FFmpegConvertSetup.exe"
set "SRC=%~dp0"

(
echo [Version]
echo Class=IEXPRESS
echo SEDVersion=3
echo [Options]
echo PackagePurpose=InstallApp
echo ShowInstallProgramWindow=0
echo HideExtractAnimation=0
echo UseLongFileName=1
echo InsideCompressed=0
echo CAB_FixedSize=0
echo CAB_ResvCodeSigning=0
echo RebootMode=N
echo InstallPrompt=
echo DisplayLicense=
echo FinishMessage=
echo TargetName=%OUT%
echo FriendlyName=FFmpeg Convert Installer
echo AppLaunched=setup.cmd
echo PostInstallCmd=^<None^>
echo AdminQuietInstCmd=
echo UserQuietInstCmd=
echo SourceFiles=SourceFiles
echo [Strings]
echo FILE0="setup.cmd"
echo FILE1="launcher.vbs"
echo FILE2="ffmpeg-convert.ps1"
echo FILE3="install.ps1"
echo FILE4="install-silent.ps1"
echo FILE5="install.cmd"
echo FILE6="uninstall.ps1"
echo FILE7="setup.ps1"
echo [SourceFiles]
echo SourceFiles0=%SRC%
echo [SourceFiles0]
echo %%FILE0%%=
echo %%FILE1%%=
echo %%FILE2%%=
echo %%FILE3%%=
echo %%FILE4%%=
echo %%FILE5%%=
echo %%FILE6%%=
echo %%FILE7%%=
) > "%SED%"

iexpress /N /Q "%SED%"
del "%SED%" >nul 2>&1

if exist "%OUT%" (
    echo.
    echo   Built: %OUT%
    echo.
) else (
    echo.
    echo   ERROR: Build failed.
    echo.
)
