; FFmpegConvert.iss -- Inno Setup script for FFmpegConvertSetup.exe (v1.4.0)
; Replaces the IExpress package. IExpress extracted to %TEMP% and ran
; setup.cmd -> powershell -ExecutionPolicy Bypass, the same chain malware
; droppers use, and antivirus flags it. This installer runs no scripts: it
; copies files, writes the HKCU context-menu key itself, and (only when ffmpeg
; is not already installed) downloads the gyan.dev essentials build, unpacks
; it with the in-box tar.exe and adds it to the user PATH.
; Build: build.cmd (needs Inno Setup 6, ISCC.exe).

#define AppVersion "1.4.0"
#define FFmpegUrl "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

[Setup]
AppId={{B3E91F4A-2C7D-4A58-9E16-5D0C8F2A7B43}
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
; ffmpeg.exe / ffprobe.exe are downloaded by [Code], so Inno does not track them.
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

[Code]
const
  EnvKey = 'Environment';

function FFmpegDir(): String;
begin
  Result := ExpandConstant('{app}\ffmpeg');
end;

{ True when ffmpeg.exe is in our folder or anywhere on the PATH. Setup is a
  32-bit process: without disabling redirection, C:\Windows\System32 on the
  PATH is searched as SysWOW64 and a 64-bit ffmpeg there is missed. }
function FFmpegPresent(): Boolean;
var
  OldRedir: Boolean;
begin
  Result := FileExists(FFmpegDir() + '\ffmpeg.exe');
  if Result then Exit;
  if IsWin64 then OldRedir := EnableFsRedirection(False);
  try
    Result := FileSearch('ffmpeg.exe', GetEnv('PATH')) <> '';
  finally
    if IsWin64 then EnableFsRedirection(OldRedir);
  end;
end;

function PathHas(const Path, Dir: String): Boolean;
begin
  Result := Pos(';' + Uppercase(Dir) + ';', ';' + Uppercase(Path) + ';') > 0;
end;

procedure AddToUserPath(const Dir: String);
var
  Path: String;
begin
  if not RegQueryStringValue(HKCU, EnvKey, 'Path', Path) then Path := '';
  if PathHas(Path, Dir) then Exit;
  if (Path <> '') and (Copy(Path, Length(Path), 1) <> ';') then Path := Path + ';';
  RegWriteExpandStringValue(HKCU, EnvKey, 'Path', Path + Dir);
end;

procedure RemoveFromUserPath(const Dir: String);
var
  Path: String;
  P: Integer;
begin
  if not RegQueryStringValue(HKCU, EnvKey, 'Path', Path) then Exit;
  Path := ';' + Path + ';';
  P := Pos(';' + Uppercase(Dir) + ';', Uppercase(Path));
  if P = 0 then Exit;
  Delete(Path, P, Length(Dir) + 1);
  Path := Copy(Path, 2, Length(Path) - 2);
  RegWriteExpandStringValue(HKCU, EnvKey, 'Path', Path);
end;

{ The zip holds ffmpeg-<version>-essentials_build\bin\. Returns that bin folder. }
function FindBinDir(const Root: String): String;
var
  F: TFindRec;
begin
  Result := '';
  if FindFirst(Root + '\*', F) then
  try
    repeat
      if (F.Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0) and (F.Name <> '.') and (F.Name <> '..') and
         FileExists(Root + '\' + F.Name + '\bin\ffmpeg.exe') then
      begin
        Result := Root + '\' + F.Name + '\bin';
        Exit;
      end;
    until not FindNext(F);
  finally
    FindClose(F);
  end;
end;

function InstallFFmpeg(): Boolean;
var
  Zip, Unpack, Bin: String;
  Code: Integer;
begin
  Result := False;
  WizardForm.StatusLabel.Caption := 'Downloading ffmpeg (about 100 MB)...';
  try
    DownloadTemporaryFile('{#FFmpegUrl}', 'ffmpeg.zip', '', nil);
  except
    Log('ffmpeg download failed: ' + GetExceptionMessage);
    Exit;
  end;
  WizardForm.StatusLabel.Caption := 'Unpacking ffmpeg...';
  Zip := ExpandConstant('{tmp}\ffmpeg.zip');
  Unpack := ExpandConstant('{tmp}\ffmpeg-unpack');
  ForceDirectories(Unpack);
  if not Exec(ExpandConstant('{sys}\tar.exe'), '-xf "' + Zip + '" -C "' + Unpack + '"', '', SW_HIDE, ewWaitUntilTerminated, Code) or (Code <> 0) then
  begin
    Log('tar.exe failed, exit ' + IntToStr(Code));
    Exit;
  end;
  Bin := FindBinDir(Unpack);
  if Bin = '' then Exit;
  ForceDirectories(FFmpegDir());
  Result := FileCopy(Bin + '\ffmpeg.exe', FFmpegDir() + '\ffmpeg.exe', False) and
            FileCopy(Bin + '\ffprobe.exe', FFmpegDir() + '\ffprobe.exe', False);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep <> ssPostInstall then Exit;
  if FileExists(FFmpegDir() + '\ffmpeg.exe') then
    AddToUserPath(FFmpegDir())
  else if not FFmpegPresent() then
  begin
    if InstallFFmpeg() then
      AddToUserPath(FFmpegDir())
    else
      SuppressibleMsgBox('FFmpeg Convert is installed, but downloading ffmpeg failed.' + #13#10 +
        'Install ffmpeg yourself (https://www.gyan.dev/ffmpeg/builds/) and add it to PATH.',
        mbError, MB_OK, IDOK);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    RemoveFromUserPath(ExpandConstant('{app}\ffmpeg'));
end;
