# setup.ps1 — FFmpeg Convert installer with automatic ffmpeg check/download

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$dest = Join-Path $env:LOCALAPPDATA "FFmpegMenu"
$ffmpegDir = Join-Path $env:LOCALAPPDATA "FFmpegMenu\ffmpeg"
$ffmpegExe = Join-Path $ffmpegDir "ffmpeg.exe"
$ffprobeExe = Join-Path $ffmpegDir "ffprobe.exe"

# ── UI ──
$form = New-Object System.Windows.Forms.Form
$form.Text = "FFmpeg Convert — Setup"
$form.Size = New-Object System.Drawing.Size(460, 220)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.TopMost = $true

$title = New-Object System.Windows.Forms.Label
$title.Text = "Installing FFmpeg Convert..."
$title.Location = New-Object System.Drawing.Point(20, 15)
$title.Size = New-Object System.Drawing.Size(400, 28)
$title.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
$form.Controls.Add($title)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Starting..."
$status.Location = New-Object System.Drawing.Point(20, 55)
$status.Size = New-Object System.Drawing.Size(400, 22)
$status.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$form.Controls.Add($status)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(20, 85)
$progress.Size = New-Object System.Drawing.Size(400, 24)
$progress.Style = "Continuous"
$progress.Minimum = 0
$progress.Maximum = 100
$form.Controls.Add($progress)

$detail = New-Object System.Windows.Forms.Label
$detail.Text = ""
$detail.Location = New-Object System.Drawing.Point(20, 118)
$detail.Size = New-Object System.Drawing.Size(400, 20)
$detail.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 120)
$detail.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$form.Controls.Add($detail)

$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Text = "Close"
$closeBtn.Location = New-Object System.Drawing.Point(330, 148)
$closeBtn.Size = New-Object System.Drawing.Size(90, 30)
$closeBtn.FlatStyle = "Flat"
$closeBtn.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
$closeBtn.ForeColor = [System.Drawing.Color]::White
$closeBtn.Visible = $false
$closeBtn.Add_Click({ $form.Close() })
$form.Controls.Add($closeBtn)

function Update-Status($msg, $pct, $det) {
    $status.Text = $msg
    if ($pct -ge 0) { $progress.Value = [Math]::Min($pct, 100) }
    if ($det) { $detail.Text = $det }
    $form.Refresh()
}

function Get-InstalledFFmpegVersion {
    # Check our bundled copy first, then PATH
    $exe = $null
    if (Test-Path $ffmpegExe) { $exe = $ffmpegExe }
    elseif (Get-Command ffmpeg -ErrorAction SilentlyContinue) { $exe = (Get-Command ffmpeg).Source }
    if (-not $exe) { return $null }

    try {
        $out = & $exe -version 2>&1 | Select-Object -First 1
        if ($out -match 'ffmpeg version (\S+)') { return $Matches[1] }
    } catch {}
    return $null
}

function Get-LatestFFmpegUrl {
    # Use gyan.dev release page to find latest essentials build
    try {
        $page = Invoke-WebRequest -Uri "https://www.gyan.dev/ffmpeg/builds/" -UseBasicParsing -TimeoutSec 10
        # Find the latest release essentials zip link
        $link = $page.Links | Where-Object { $_.href -match "ffmpeg-release-essentials\.zip$" } | Select-Object -First 1
        if ($link) {
            $href = $link.href
            if ($href -notmatch '^https?://') {
                $href = "https://www.gyan.dev/ffmpeg/builds/$href"
            }
            # Extract version from URL
            $version = $null
            if ($href -match 'ffmpeg-([\d\.\-]+)-') { $version = $Matches[1] }
            return @{ Url = $href; Version = $version }
        }
    } catch {}

    # Fallback: direct known URL pattern
    return @{
        Url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
        Version = $null
    }
}

function Install-FFmpeg {
    param([string]$Url)

    $zipPath = Join-Path $env:TEMP "ffmpeg-essentials.zip"
    $extractPath = Join-Path $env:TEMP "ffmpeg-extract"

    # Download
    Update-Status "Downloading ffmpeg..." 30 $Url
    try {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($Url, $zipPath)
    } catch {
        Update-Status "Download failed: $_" 0 ""
        return $false
    }

    # Extract
    Update-Status "Extracting ffmpeg..." 60 ""
    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
    try {
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    } catch {
        Update-Status "Extract failed: $_" 0 ""
        return $false
    }

    # Find the bin folder inside the extracted archive
    $binDir = Get-ChildItem -Path $extractPath -Recurse -Directory -Filter "bin" | Select-Object -First 1
    if (-not $binDir) {
        Update-Status "Could not find ffmpeg binaries in archive" 0 ""
        return $false
    }

    # Copy ffmpeg.exe and ffprobe.exe to our directory
    Update-Status "Installing ffmpeg binaries..." 80 ""
    if (-not (Test-Path $ffmpegDir)) { New-Item -Path $ffmpegDir -ItemType Directory -Force | Out-Null }
    Copy-Item -Path (Join-Path $binDir.FullName "ffmpeg.exe") -Destination $ffmpegDir -Force
    Copy-Item -Path (Join-Path $binDir.FullName "ffprobe.exe") -Destination $ffmpegDir -Force

    # Clean up
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

    return $true
}

function Add-ToUserPath {
    param([string]$Dir)
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -split ";" | ForEach-Object { $_.TrimEnd("\") } | Where-Object { $_ -eq $Dir.TrimEnd("\") }) {
        return # Already on PATH
    }
    $newPath = "$currentPath;$Dir"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    # Also update current session
    $env:Path = "$env:Path;$Dir"
}

# ── Main install logic (runs after form is shown) ──
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 100
$script:started = $false

$timer.Add_Tick({
    if ($script:started) { return }
    $script:started = $true
    $timer.Stop()

    try {
        # Step 1: Copy files
        Update-Status "Copying files..." 5 $dest
        if (-not (Test-Path $dest)) { New-Item -Path $dest -ItemType Directory -Force | Out-Null }

        $scriptDir = $PSScriptRoot
        if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.ScriptName }
        if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

        $filesToCopy = @("launcher.vbs", "ffmpeg-convert.ps1", "install.ps1", "install-silent.ps1", "install.cmd", "uninstall.ps1", "setup.cmd", "setup.ps1")
        foreach ($f in $filesToCopy) {
            $src = Join-Path $scriptDir $f
            if (Test-Path $src) { Copy-Item -Path $src -Destination $dest -Force }
        }
        $progress.Value = 10

        # Step 2: Check ffmpeg
        Update-Status "Checking ffmpeg..." 15 ""
        $installedVer = Get-InstalledFFmpegVersion
        $needsInstall = $false
        $needsUpdate = $false

        if (-not $installedVer) {
            $needsInstall = $true
            $detail.Text = "ffmpeg not found — will download"
        } else {
            $detail.Text = "Found ffmpeg $installedVer"
        }
        $form.Refresh()

        # Step 3: Check latest version
        Update-Status "Checking for latest ffmpeg version..." 20 ""
        $latest = Get-LatestFFmpegUrl

        if ($installedVer -and $latest.Version) {
            # Compare: strip non-numeric for basic comparison
            $instClean = $installedVer -replace '[^0-9\.]', '' -replace '\.+', '.'
            $latClean = $latest.Version -replace '[^0-9\.]', '' -replace '\.+', '.'
            if ($instClean -ne $latClean) {
                $needsUpdate = $true
                $detail.Text = "Update available: $installedVer -> $($latest.Version)"
                $form.Refresh()
            }
        }

        if ($needsInstall -or $needsUpdate) {
            $ok = Install-FFmpeg -Url $latest.Url
            if ($ok) {
                Add-ToUserPath $ffmpegDir
                $detail.Text = "ffmpeg installed to $ffmpegDir"
            } else {
                if ($needsInstall) {
                    $detail.Text = "WARNING: ffmpeg download failed — install it manually"
                    $detail.ForeColor = [System.Drawing.Color]::FromArgb(255, 180, 80)
                }
            }
        } else {
            $progress.Value = 80
            $detail.Text = "ffmpeg is up to date ($installedVer)"
        }
        $form.Refresh()

        # Step 4: Register context menu
        Update-Status "Registering context menu..." 90 ""
        $launcherPath = Join-Path $dest "launcher.vbs"

        # Clean old entries
        Remove-Item -Path "HKCU:\Software\Classes\*\shell\FFmpegConvert" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKCU:\Software\Classes\Directory\shell\FFmpegBatchConvert" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKCU:\Software\Classes\Directory\Background\shell\FFmpegBatchConvert" -Recurse -Force -ErrorAction SilentlyContinue

        # Create new entry
        $fileRoot = "HKCU:\Software\Classes\*\shell\FFmpegConvert"
        New-Item -Path $fileRoot -Force | Out-Null
        Set-ItemProperty -Path $fileRoot -Name "(Default)" -Value "FFmpeg Convert"
        Set-ItemProperty -Path $fileRoot -Name "Icon" -Value "shell32.dll,277"
        Set-ItemProperty -Path $fileRoot -Name "MultiSelectModel" -Value "Player"

        $commandKey = "$fileRoot\command"
        New-Item -Path $commandKey -Force | Out-Null
        Set-ItemProperty -Path $commandKey -Name "(Default)" -Value "wscript.exe `"$launcherPath`" `"%1`""

        # Done
        Update-Status "Done!" 100 ""
        $title.Text = "Installation complete!"
        $title.ForeColor = [System.Drawing.Color]::FromArgb(100, 220, 100)
        $status.Text = "Right-click any file(s) and choose FFmpeg Convert"
        $closeBtn.Visible = $true
        $closeBtn.Focus()

    } catch {
        $title.Text = "Installation failed"
        $title.ForeColor = [System.Drawing.Color]::FromArgb(255, 80, 80)
        $status.Text = $_.Exception.Message
        $closeBtn.Visible = $true
    }
})

$form.Add_Shown({ $timer.Start() })
[System.Windows.Forms.Application]::Run($form)
