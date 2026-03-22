# FFmpeg Context Menu

Windows right-click context menu for audio and video conversion. Select any media file in Explorer → **FFmpeg Convert** → pick a format from the dark GUI → done. No terminal, no admin rights.

## Install

### One-click installer (recommended)

Download **[FFmpegConvertSetup.exe](https://github.com/toyuvalo/ffmpeg-context-menu/releases/latest)** and run it.

The installer:
- Copies scripts to `%LOCALAPPDATA%\FFmpegMenu\`
- Downloads the latest ffmpeg automatically if not found or outdated
- Registers the context menu entry in HKCU (no admin required)

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

- **Format picker GUI** — dark-themed Windows Forms dialog, pick format before converting
- **Parallel conversion** — up to 4 simultaneous jobs (capped to CPU core count)
- **Live progress window** — per-file status: Queued → Converting → Done / Failed, with file size before and after
- **Sample rate preservation** — ffprobe reads source sample rate and passes it through (floored at 44100 Hz)
- **Originals kept safe** — on success, originals moved to a `preconvert/` subfolder, never deleted
- **Auto ffmpeg download** — installer fetches a compatible ffmpeg build automatically
- **No admin rights** — all registry entries written to HKCU

## Requirements

- Windows 10/11
- ffmpeg (auto-downloaded by the installer)

## Build the installer

Requires Windows (IExpress ships with the OS):

```cmd
build.cmd
```

Produces `FFmpegConvertSetup.exe` in the repo root.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\FFmpegMenu\uninstall.ps1"
```

## Related

- [doc-convert-menu](https://github.com/toyuvalo/doc-convert-menu) — same idea for image and document conversion

## License

MIT with [Commons Clause](https://commonsclause.com/) — free to use, modify, and share. Commercial resale not permitted.
