# FFmpeg Context Menu

Windows right-click context menu for audio and video conversion. Select any media file in Explorer — or right-click a folder to convert everything inside it — → **FFmpeg Convert** → pick a format from the dark GUI → done. No terminal, no admin rights.

**[Project page →](https://webdev.dvlce.ca/ffmpeg)**

## Install

### One-click installer (recommended)

Download **[FFmpegConvertSetup.exe](https://github.com/toyuvalo/ffmpeg-context-menu/releases/latest)** and run it.

The installer (Inno Setup, per-user, no admin, code-signed by Yuval Olsha):
- Copies `FFmpegConvert.exe` and `ffmpeg-convert.ps1` to `%LOCALAPPDATA%\FFmpegMenu\`
- Downloads ffmpeg (gyan.dev essentials build) only if none is found, and adds it to your user PATH
- Registers the file, folder and folder-background menu entries in HKCU
- Adds a normal uninstall entry in Settings > Apps. It runs no scripts

### Manual install

```powershell
git clone https://github.com/toyuvalo/ffmpeg-context-menu
cd ffmpeg-context-menu
powershell -ExecutionPolicy Bypass -File install.ps1
```

## Supported formats

| Category | Formats |
|----------|---------|
| Audio | MP3, WAV, FLAC, AAC |
| Video | MP4 (x264), MKV (x264), WebM (VP9) |
| Extract audio | MP3 from video, WAV from video |

## Features

- **Right-click files OR folders** — files trigger per-file conversion; folders convert every file inside (one shot, no need to select all)
- **Format picker GUI** — dark-themed Windows Forms dialog, pick format before converting
- **Parallel conversion** — up to 4 simultaneous jobs (capped to CPU core count)
- **Live progress window** — per-file status: Queued → Converting → Done / Failed, with file size before and after
- **Sample rate preservation** — ffprobe reads source sample rate and passes it through (floored at 44100 Hz)
- **Handles any file name** — smart quotes (`’`), accents, `[brackets]`, `%`, leading dashes. The file is temporarily renamed to a safe name for the conversion, then the output takes the original name with its new extension
- **Never overwrites** — if the target name is taken, the output gets a `_1`, `_2`, … suffix instead
- **Originals kept safe** — on success, originals moved to a `preconvert/` subfolder, never deleted
- **Auto ffmpeg download** — installer fetches a compatible ffmpeg build automatically
- **No admin rights** — all registry entries written to HKCU
- **Code-signed** — from v1.4.0 the installer, launcher, script and uninstaller are signed (publisher Yuval Olsha). Up to v1.3.0 the installer was an IExpress package running `powershell -ExecutionPolicy Bypass` plus a VBScript launcher, a chain antivirus flags

## Requirements

- Windows 10/11
- ffmpeg (auto-downloaded by the installer)

## Build the installer

Requires Inno Setup 6 (`winget install JRSoftware.InnoSetup`). The launcher is compiled with the in-box C# compiler. The build signs everything with Azure Artifact Signing; set `NOSIGN=1` to build unsigned:

```cmd
build.cmd
```

Produces `FFmpegConvertSetup.exe` in the repo root.

## Uninstall

Settings > Apps > FFmpeg Convert > Uninstall. For a manual install: `powershell -ExecutionPolicy Bypass -File uninstall.ps1`.

## Related

- [doc-convert-menu](https://github.com/toyuvalo/doc-convert-menu) — same idea for image and document conversion
- [webdev.dvlce.ca/ffmpeg](https://webdev.dvlce.ca/ffmpeg) — project page

## License

MIT with [Commons Clause](https://commonsclause.com/) — free to use, modify, and share. Commercial resale not permitted.
