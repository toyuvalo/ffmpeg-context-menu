; FFmpegConvert.iss -- Inno Setup script for FFmpegConvertSetup.exe (v1.4.1)
; Replaces the IExpress package. IExpress extracted to %TEMP% and ran
; setup.cmd -> powershell -ExecutionPolicy Bypass, the same chain malware
; droppers use, and antivirus flags it. This installer runs no scripts: it
; copies files, writes the HKCU context-menu key itself, and (only when ffmpeg
; is not already installed) downloads it -- see dvlce-deps.iss, shared with
; Shrink Menu. v1.4.1 moved ffmpeg from {app}fmpeg to the shared folder.
; Build: build.cmd (needs Inno Setup 6, ISCC.exe).

#define AppVersion "1.4.1"
#define AppGuid "B3E91F4A-2C7D-4A58-9E16-5D0C8F2A7B43"
#define NeedFFmpeg

[Setup]
AppId={{{#AppGuid}}
AppName=FFmpeg Convert
AppVersion={#AppVersion}
AppPublisher=DVLCE
AppPublisherURL=https://webdev.dvlce.ca/ffmpeg
AppSupportURL=https://github.com/toyuvalo/ffmpeg-context-menu
VersionInfoVersion={#AppVersion}
VersionInfoDescription=FFmpeg Convert Setup
; Per-user install, no admin. Same folder as the old installer, so it upgrades in place.
PrivilegesRequired=lowest
DefaultDirName={localappdata}\FFmpegMenu
DisableDirPage=yes
DisableProgramGroupPage=yes
OutputDir=..
OutputBaseFilename=FFmpegConvertSetup
SetupIconFile=..\ffmpeg.ico
UninstallDisplayIcon={app}\FFmpegConvert.exe
UninstallDisplayName=FFmpeg Convert
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ChangesEnvironment=yes
#ifdef SIGN
; build.cmd passes /DSIGN and /Sazsign=<command> (Azure Artifact Signing).
SignTool=azsign
SignedUninstaller=yes
#endif

[Files]
Source: "..\build\FFmpegConvert.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\ffmpeg-convert.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\ffmpeg.ico"; DestDir: "{app}"; Flags: ignoreversion

[InstallDelete]
; Left behind by the IExpress-era installer.
Type: files; Name: "{app}\launcher.vbs"
Type: files; Name: "{app}\setup.cmd"
Type: files; Name: "{app}\setup.ps1"
Type: files; Name: "{app}\install.ps1"
Type: files; Name: "{app}\install-silent.ps1"
Type: files; Name: "{app}\install.cmd"
Type: files; Name: "{app}\uninstall.ps1"

[UninstallDelete]
; v1.4.0 downloaded ffmpeg here. [Code] moves it to the shared folder; this catches any leftover.
Type: filesandordirs; Name: "{app}\ffmpeg"

[Registry]
; Old menu entries from earlier versions.
Root: HKCU; Subkey: "Software\Classes\Directory\shell\FFmpegBatchConvert"; ValueType: none; Flags: deletekey dontcreatekey
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\FFmpegBatchConvert"; ValueType: none; Flags: deletekey dontcreatekey
Root: HKCU; Subkey: "Software\Classes\*\shell\FFmpegConvert"; ValueType: none; Flags: deletekey
Root: HKCU; Subkey: "Software\Classes\*\shell\FFmpegConvert"; ValueType: string; ValueName: ""; ValueData: "FFmpeg Convert"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\*\shell\FFmpegConvert"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\ffmpeg.ico,0"
Root: HKCU; Subkey: "Software\Classes\*\shell\FFmpegConvert"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKCU; Subkey: "Software\Classes\*\shell\FFmpegConvert\command"; ValueType: string; ValueName: ""; ValueData: """{app}\FFmpegConvert.exe"" ""%1"""

; Folder and folder-background menus: convert every file in the folder.
Root: HKCU; Subkey: "Software\Classes\Directory\shell\FFmpegConvert"; ValueType: none; Flags: deletekey
Root: HKCU; Subkey: "Software\Classes\Directory\shell\FFmpegConvert"; ValueType: string; ValueName: ""; ValueData: "FFmpeg Convert (all files)"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Directory\shell\FFmpegConvert"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\ffmpeg.ico,0"
Root: HKCU; Subkey: "Software\Classes\Directory\shell\FFmpegConvert\command"; ValueType: string; ValueName: ""; ValueData: """{app}\FFmpegConvert.exe"" --folder ""%1"""
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\FFmpegConvert"; ValueType: none; Flags: deletekey
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\FFmpegConvert"; ValueType: string; ValueName: ""; ValueData: "FFmpeg Convert (all files)"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\FFmpegConvert"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\ffmpeg.ico,0"
Root: HKCU; Subkey: "Software\Classes\Directory\Background\shell\FFmpegConvert\command"; ValueType: string; ValueName: ""; ValueData: """{app}\FFmpegConvert.exe"" --folder ""%V"""

#include "dvlce-deps.iss"

// v1.4.0 kept its own ffmpeg in <app>\ffmpeg. Move it to the shared folder (same
// volume, so a rename), or drop it when the shared folder already has one.
procedure MigrateOldFFmpeg();
var
  Old: String;
begin
  Old := ExpandConstant('{app}\ffmpeg');
  if not FileExists(Old + '\ffmpeg.exe') then Exit;
  RemoveFromUserPath(Old);
  if not FileExists(SharedDir('ffmpeg') + '\ffmpeg.exe') then
  begin
    DelTree(SharedDir('ffmpeg'), True, True, True);
    ForceDirectories(ExpandConstant('{localappdata}\Programs\DVLCE'));
    if RenameFile(Old, SharedDir('ffmpeg')) then Exit;
  end;
  DelTree(Old, True, True, True);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep <> ssPostInstall then Exit;
  MigrateOldFFmpeg();
  InstallDeps();
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep <> usPostUninstall then Exit;
  RemoveFromUserPath(ExpandConstant('{app}\ffmpeg'));
  UninstallDeps();
end;
