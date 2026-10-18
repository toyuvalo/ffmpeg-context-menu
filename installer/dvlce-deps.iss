; dvlce-deps.iss -- shared runtime-dependency code for the DVLCE right-click tools
; (ffmpeg + ffprobe, ImageMagick). The SAME file is in each tool repo that needs it:
;   ffmpeg-context-menu, shrink-menu, doc-convert-menu-build -- keep the copies identical.
;
; A dependency already on the PATH is used as-is. Otherwise its newest release is found
; through the GitHub API, downloaded (sha256-checked) to %LOCALAPPDATA%\Programs\DVLCE\<dep>,
; one copy shared by every tool, and that folder is added to the user PATH. Uninstall
; removes a shared copy only when no other tool that needs it is still installed.
; (Not %LOCALAPPDATA%\DVLCE: other DVLCE software keeps state there.)
;   ffmpeg:      GyanD/codexffmpeg, gyan.dev's own GitHub mirror, essentials build .7z
;   ImageMagick: ImageMagick/ImageMagick, portable Q16 x64 .7z
; Both are .7z: Inno's ExtractArchive reads it. The Windows 10 tar.exe cannot (no LZMA).
;
; The including script defines, before #include:
;   #define AppGuid "<guid without braces>"   (also used for AppId)
;   #define NeedFFmpeg / #define NeedMagick    (one or both)
;   Test only: DepsTestIgnorePath (act as if nothing is on the PATH) and
;   DepsTestTools "<AppIds>" (replaces the tool lists). See test\deps-harness.iss.
; and calls InstallDeps() at ssPostInstall and UninstallDeps() at usPostUninstall.

[Code]
const
  EnvKey = 'Environment';
  UninstKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\';
  SelfAppId = '{' + '{#AppGuid}' + '}';
  { AppIds of the tools that use each dependency: FFmpeg Convert, Shrink Menu, Doc Convert. }
#ifndef DepsTestTools
  FFmpegTools = '{B3E91F4A-2C7D-4A58-9E16-5D0C8F2A7B43} {9C4D2E7B-1A6F-4B83-8E25-6F3B0A9D1C57}';
  MagickTools = '{9C4D2E7B-1A6F-4B83-8E25-6F3B0A9D1C57} {6F1C2B7E-4D3A-4E8B-9C1F-2A7D5E0B3C91}';
#else
  FFmpegTools = '{#DepsTestTools}';
  MagickTools = '{#DepsTestTools}';
#endif
  FFmpegRepo = 'GyanD/codexffmpeg';
  FFmpegAsset = '-essentials_build.7z';
  MagickRepo = 'ImageMagick/ImageMagick';
  MagickAsset = '-portable-Q16-x64.7z';
  { Used when the GitHub API cannot be read (offline, rate limit). GitHub keeps old releases. }
  FFmpegPinnedUrl = 'https://github.com/GyanD/codexffmpeg/releases/download/9.0.2/ffmpeg-9.0.2-essentials_build.7z';
  FFmpegPinnedSha = '4705843ccaaf54257c16ad90f3e952ece33c17df964ecf7bfdbb0f49c7171077';
  MagickPinnedUrl = 'https://github.com/ImageMagick/ImageMagick/releases/download/7.1.2-34/ImageMagick-7.1.2-34-portable-Q16-x64.7z';
  MagickPinnedSha = '52cc6a441c7884f5ff4274b410c9b90c4b7d54245dcdf4d32988bb4e4df4e5d1';

function SharedDir(const Dep: String): String;
begin
  Result := ExpandConstant('{localappdata}\Programs\DVLCE\') + Dep;
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

{ Full path of Exe on the PATH (process PATH, then the user PATH in the registry,
  which is newer when another installer has just changed it), or ''. A copy inside
  FFmpeg Convert v1.4.0's private folder does not count: its uninstall deletes it.
  Setup is 32-bit: without disabling redirection, System32 is searched as SysWOW64. }
function FindOnPath(const Exe: String): String;
var
  UserPath: String;
  OldRedir: Boolean;
begin
  if not RegQueryStringValue(HKCU, EnvKey, 'Path', UserPath) then UserPath := '';
  if IsWin64 then OldRedir := EnableFsRedirection(False);
  try
    Result := FileSearch(Exe, GetEnv('PATH') + ';' + UserPath);
  finally
    if IsWin64 then EnableFsRedirection(OldRedir);
  end;
  if Pos('\FFMPEGMENU\FFMPEG\', Uppercase(Result)) > 0 then Result := '';
#ifdef DepsTestIgnorePath
  Result := '';
#endif
end;

{ True when another installed tool (not this one) is in the space-separated AppId list. }
function OtherToolNeeds(const Tools: String): Boolean;
var
  Rest, Id: String;
  P: Integer;
begin
  Result := False;
  Rest := Tools + ' ';
  while Rest <> '' do
  begin
    P := Pos(' ', Rest);
    Id := Copy(Rest, 1, P - 1);
    Delete(Rest, 1, P);
    if (Id <> '') and (Id <> SelfAppId) and RegKeyExists(HKCU, UninstKey + Id + '_is1') then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if ProgressMax > 0 then
    WizardForm.StatusLabel.Caption := Format('Downloading %s (%d of %d MB)...', [FileName,
      Integer(Progress div 1048576), Integer(ProgressMax div 1048576)]);
  Result := True;
end;

{ Last position of Sub in S that starts before Before, or 0. }
function LastPosBefore(const Sub, S: String; Before: Integer): Integer;
var
  P: Integer;
begin
  Result := 0;
  P := Before - Length(Sub);
  while P > 0 do
  begin
    if Copy(S, P, Length(Sub)) = Sub then
    begin
      Result := P;
      Exit;
    end;
    P := P - 1;
  end;
end;

{ Reads the latest release of Repo from the GitHub API and finds the asset whose name
  ends in Suffix: its download URL and sha256. Returns False when anything looks wrong;
  the caller then keeps its pinned URL and hash. }
function LatestGitHubAsset(const Repo, Suffix: String; var Url, Sha: String): Boolean;
var
  Json: AnsiString;
  S, U, Prefix, Tag: String;
  P, Q, D: Integer;
begin
  Result := False;
  Prefix := 'https://github.com/' + Repo + '/releases/download/';
  try
    DownloadTemporaryFile('https://api.github.com/repos/' + Repo + '/releases/latest', 'release.json', '', nil);
  except
    Log(Repo + ' release lookup failed: ' + GetExceptionMessage);
    Exit;
  end;
  if not LoadStringFromFile(ExpandConstant('{tmp}\release.json'), Json) then Exit;
  S := Json;
  Tag := '"browser_download_url":"';
  // Each asset object: ..."digest":"sha256:<hex>",...,"browser_download_url":"<url>"
  P := Pos(Tag, S);
  while P > 0 do
  begin
    Delete(S, 1, P + Length(Tag) - 1);
    Q := Pos('"', S);
    U := Copy(S, 1, Q - 1);
    if (Copy(U, Length(U) - Length(Suffix) + 1, Length(Suffix)) = Suffix) and (Pos(Prefix, U) = 1) then
    begin
      { This asset's digest is the nearest "digest": before its URL. }
      P := Pos(Tag + U + '"', Json);
      D := LastPosBefore('"digest":', Json, P);
      if (D > 0) and (Copy(Json, D, Length('"digest":"sha256:')) = '"digest":"sha256:') then
      begin
        Url := U;
        Sha := Copy(Json, D + Length('"digest":"sha256:'), 64);
        Result := True;
      end;
      Exit;
    end;
    P := Pos(Tag, S);
  end;
end;

{ Downloads the latest (else the pinned) .7z of a dependency and unpacks it into Dest. }
function FetchAndExtract(const Name, Repo, Suffix, PinnedUrl, PinnedSha, Dest: String): Boolean;
var
  Url, Sha, Archive: String;
begin
  Result := False;
  WizardForm.StatusLabel.Caption := 'Finding the latest ' + Name + '...';
  if not LatestGitHubAsset(Repo, Suffix, Url, Sha) then
  begin
    Url := PinnedUrl;
    Sha := PinnedSha;
  end;
  Log(Name + ': ' + Url);
  Archive := Lowercase(Name) + '.7z';
  try
    DownloadTemporaryFile(Url, Archive, Sha, @OnDownloadProgress);
  except
    Log(Name + ' download failed: ' + GetExceptionMessage);
    Exit;
  end;
  WizardForm.StatusLabel.Caption := 'Unpacking ' + Name + '...';
  ForceDirectories(Dest);
  try
    ExtractArchive(ExpandConstant('{tmp}\') + Archive, Dest, '', True, nil);
  except
    Log(Name + ' unpack failed: ' + GetExceptionMessage);
    Exit;
  end;
  Result := True;
end;

#ifdef NeedFFmpeg
{ The archive holds ffmpeg-<version>-essentials_build\bin\. Returns that bin folder. }
function FindFFmpegBin(const Root: String): String;
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

{ Fills Stage (a scratch folder that EnsureDep renames into place) with ffmpeg + ffprobe. }
function DownloadFFmpeg(const Stage: String): Boolean;
var
  Unpack, Bin: String;
begin
  Result := False;
  Unpack := ExpandConstant('{tmp}\ffmpeg-unpack');
  if not FetchAndExtract('ffmpeg', FFmpegRepo, FFmpegAsset, FFmpegPinnedUrl, FFmpegPinnedSha, Unpack) then Exit;
  Bin := FindFFmpegBin(Unpack);
  if Bin = '' then Exit;
  ForceDirectories(Stage);
  Result := FileCopy(Bin + '\ffprobe.exe', Stage + '\ffprobe.exe', False) and
            FileCopy(Bin + '\ffmpeg.exe', Stage + '\ffmpeg.exe', False);
end;
#endif

#ifdef NeedMagick
{ Fills Stage with the portable ImageMagick. }
function DownloadMagick(const Stage: String): Boolean;
begin
  Result := False;
  if not FetchAndExtract('ImageMagick', MagickRepo, MagickAsset, MagickPinnedUrl, MagickPinnedSha, Stage) then Exit;
  { The portable build ships 8 identical 32 MB exes; magick.exe does the work of all. }
  DeleteFile(Stage + '\compare.exe');
  DeleteFile(Stage + '\composite.exe');
  DeleteFile(Stage + '\conjure.exe');
  DeleteFile(Stage + '\identify.exe');
  DeleteFile(Stage + '\mogrify.exe');
  DeleteFile(Stage + '\montage.exe');
  DeleteFile(Stage + '\stream.exe');
  Result := FileExists(Stage + '\magick.exe');
end;
#endif

{ Uses a copy already on the PATH, else installs the shared copy. The download goes to
  <dir>.partial and is renamed into place only when complete, so a failed or cancelled
  run never leaves a half copy that the next run would trust. Returns True on success. }
function EnsureDep(const Dep, Exe: String): Boolean;
var
  Dir, Stage: String;
begin
  Result := True;
  Dir := SharedDir(Dep);
  if FileExists(Dir + '\' + Exe) then
  begin
    AddToUserPath(Dir);
    Exit;
  end;
  if FindOnPath(Exe) <> '' then Exit;
  Stage := Dir + '.partial';
  DelTree(Stage, True, True, True);
  Result := False;
#ifdef NeedFFmpeg
  if Dep = 'ffmpeg' then Result := DownloadFFmpeg(Stage);
#endif
#ifdef NeedMagick
  if Dep = 'imagemagick' then Result := DownloadMagick(Stage);
#endif
  if Result then
  begin
    DelTree(Dir, True, True, True);
    Result := RenameFile(Stage, Dir);
  end;
  if Result then
    AddToUserPath(Dir)
  else
    DelTree(Stage, True, True, True);
end;

procedure InstallDeps();
var
  Failed: String;
begin
  Failed := '';
#ifdef NeedFFmpeg
  if not EnsureDep('ffmpeg', 'ffmpeg.exe') then Failed := Failed + #13#10 + '- ffmpeg: https://www.gyan.dev/ffmpeg/builds/';
#endif
#ifdef NeedMagick
  if not EnsureDep('imagemagick', 'magick.exe') then Failed := Failed + #13#10 + '- ImageMagick: https://imagemagick.org/script/download.php';
#endif
  if Failed <> '' then
    SuppressibleMsgBox('{#SetupSetting("AppName")} is installed, but this download failed:' + #13#10 + Failed + #13#10 + #13#10 +
      'Run this installer again, or install it yourself and add it to PATH.', mbError, MB_OK, IDOK);
end;

procedure RemoveSharedDep(const Dep, Tools: String);
var
  Dir: String;
begin
  Dir := SharedDir(Dep);
  if not DirExists(Dir) or OtherToolNeeds(Tools) then Exit;
  DelTree(Dir, True, True, True);
  RemoveFromUserPath(Dir);
  RemoveDir(ExpandConstant('{localappdata}\Programs\DVLCE'));
end;

procedure UninstallDeps();
begin
#ifdef NeedFFmpeg
  RemoveSharedDep('ffmpeg', FFmpegTools);
#endif
#ifdef NeedMagick
  RemoveSharedDep('imagemagick', MagickTools);
#endif
end;
