@echo off
REM build.cmd -- Builds build\FFmpegConvert.exe and FFmpegConvertSetup.exe, signed
REM Requires: csc.exe (in-box .NET Framework 4.x) and Inno Setup 6 (ISCC.exe)
REM   winget install JRSoftware.InnoSetup
REM Signing (v1.4.0+): Azure Artifact Signing, publisher "Yuval Olsha", through
REM   the shared helper azsign.cmd (signtool + Artifact Signing dlib + az login).
REM   Override its path with AZSIGN. Set NOSIGN=1 to build unsigned.
REM v1.4.0 replaced IExpress + launcher.vbs: antivirus flags that chain as a trojan.

setlocal
set "ROOT=%~dp0"
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"

set "ISCC="
for %%P in ("%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" "%ProgramFiles%\Inno Setup 6\ISCC.exe") do (
    if not defined ISCC if exist %%P set "ISCC=%%~P"
)
if not defined ISCC (
    echo   ERROR: Inno Setup 6 not found. Install: winget install JRSoftware.InnoSetup
    exit /b 1
)

if not defined AZSIGN set "AZSIGN=G:\dev-tools\artifact-signing-client\azsign.cmd"
if not defined NOSIGN if not exist "%AZSIGN%" (
    echo   ERROR: signing helper not found at %AZSIGN%. Set AZSIGN, or NOSIGN=1.
    exit /b 1
)

if not exist "%ROOT%build" mkdir "%ROOT%build"
"%CSC%" /nologo /target:winexe /optimize+ /win32icon:"%ROOT%ffmpeg.ico" ^
 /r:Microsoft.CSharp.dll /out:"%ROOT%build\FFmpegConvert.exe" "%ROOT%launcher\FFmpegConvertLauncher.cs"
if errorlevel 1 (
    echo   ERROR: launcher compile failed.
    exit /b 1
)

REM Sign a copy of the script, so the source file in git stays unsigned.
copy /y "%ROOT%ffmpeg-convert.ps1" "%ROOT%build\ffmpeg-convert.ps1" >nul

if defined NOSIGN (
    "%ISCC%" /Q "%ROOT%installer\FFmpegConvert.iss"
    goto :isccdone
)
call "%AZSIGN%" "%ROOT%build\FFmpegConvert.exe" "%ROOT%build\ffmpeg-convert.ps1"
if errorlevel 1 (
    echo   ERROR: signing failed. Check: az login, and the Signer role on dvlce-signing.
    exit /b 1
)
REM Inno Setup signs the uninstaller and the setup exe with this command.
"%ISCC%" /Q /DSIGN "/Sazsign=$q%COMSPEC%$q /d /c $q$q%AZSIGN%$q $f$q" "%ROOT%installer\FFmpegConvert.iss"
:isccdone
if errorlevel 1 (
    echo   ERROR: Inno Setup build failed.
    exit /b 1
)

echo.
echo   Built: %ROOT%FFmpegConvertSetup.exe
echo.
