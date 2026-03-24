# ffmpeg-convert.ps1 — FFmpeg converter with progress UI and parallel processing  v1.2.0
param(
    [string]$Path,
    [string]$ListFile,

    [ValidateSet("mp3","wav","flac","aac","mp4","mkv","webm","extract-mp3","extract-wav","")]
    [string]$Format
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ── Check ffmpeg ──
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    [System.Windows.Forms.MessageBox]::Show("ffmpeg not found on PATH.`nInstall it and make sure it's in your system PATH.", "FFmpeg Convert", "OK", "Error") | Out-Null
    exit 1
}

# ── Format picker if not specified ──
if (-not $Format) {
    $pickerForm = New-Object System.Windows.Forms.Form
    $pickerForm.Text = "FFmpeg Convert"
    $pickerForm.Size = New-Object System.Drawing.Size(320, 400)
    $pickerForm.StartPosition = "CenterScreen"
    $pickerForm.FormBorderStyle = "FixedSingle"
    $pickerForm.MaximizeBox = $false
    $pickerForm.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $pickerForm.ForeColor = [System.Drawing.Color]::White
    $pickerForm.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $pickerForm.TopMost = $true

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Choose format"
    $title.Location = New-Object System.Drawing.Point(20, 12)
    $title.Size = New-Object System.Drawing.Size(260, 28)
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
    $pickerForm.Controls.Add($title)

    $script:pickedFormat = $null
    $yPos = 48

    function Add-FormatButton($label, $fmt, [ref]$y) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $label
        $btn.Location = New-Object System.Drawing.Point(20, $y.Value)
        $btn.Size = New-Object System.Drawing.Size(260, 30)
        $btn.FlatStyle = "Flat"
        $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
        $btn.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
        $btn.ForeColor = [System.Drawing.Color]::White
        $btn.TextAlign = "MiddleLeft"
        $btn.Padding = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
        $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btn.Tag = $fmt
        $btn.Add_Click({
            $script:pickedFormat = $this.Tag
            $pickerForm.Close()
        })
        $btn.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70) })
        $btn.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50) })
        $pickerForm.Controls.Add($btn)
        $y.Value += 34
    }

    $audioLabel = New-Object System.Windows.Forms.Label
    $audioLabel.Text = "Audio"
    $audioLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $audioLabel.Size = New-Object System.Drawing.Size(260, 20)
    $audioLabel.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
    $audioLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $pickerForm.Controls.Add($audioLabel)
    $yPos += 22

    Add-FormatButton "MP3" "mp3" ([ref]$yPos)
    Add-FormatButton "WAV" "wav" ([ref]$yPos)
    Add-FormatButton "FLAC" "flac" ([ref]$yPos)
    Add-FormatButton "AAC" "aac" ([ref]$yPos)

    $yPos += 6
    $videoLabel = New-Object System.Windows.Forms.Label
    $videoLabel.Text = "Video"
    $videoLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $videoLabel.Size = New-Object System.Drawing.Size(260, 20)
    $videoLabel.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
    $videoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $pickerForm.Controls.Add($videoLabel)
    $yPos += 22

    Add-FormatButton "MP4 (x264)" "mp4" ([ref]$yPos)
    Add-FormatButton "MKV (x264)" "mkv" ([ref]$yPos)
    Add-FormatButton "WebM (VP9)" "webm" ([ref]$yPos)

    $yPos += 6
    $extractLabel = New-Object System.Windows.Forms.Label
    $extractLabel.Text = "Extract Audio"
    $extractLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $extractLabel.Size = New-Object System.Drawing.Size(260, 20)
    $extractLabel.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
    $extractLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $pickerForm.Controls.Add($extractLabel)
    $yPos += 22

    Add-FormatButton "Extract Audio (MP3)" "extract-mp3" ([ref]$yPos)
    Add-FormatButton "Extract Audio (WAV)" "extract-wav" ([ref]$yPos)

    # ---- Shrink... button ----
    $yPos += 6
    $sepShrink = New-Object System.Windows.Forms.Panel
    $sepShrink.Location = New-Object System.Drawing.Point(20, $yPos)
    $sepShrink.Size = New-Object System.Drawing.Size(260, 1)
    $sepShrink.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 57)
    $pickerForm.Controls.Add($sepShrink)
    $yPos += 8

    $shrinkBtn = New-Object System.Windows.Forms.Button
    $shrinkBtn.Text = "Shrink..."
    $shrinkBtn.Location = New-Object System.Drawing.Point(20, $yPos)
    $shrinkBtn.Size = New-Object System.Drawing.Size(260, 28)
    $shrinkBtn.FlatStyle = "Flat"
    $shrinkBtn.FlatAppearance.BorderSize = 1
    $shrinkBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(120, 80, 20)
    $shrinkBtn.BackColor = [System.Drawing.Color]::FromArgb(44, 32, 12)
    $shrinkBtn.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 60)
    $shrinkBtn.TextAlign = "MiddleLeft"
    $shrinkBtn.Padding = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
    $shrinkBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $shrinkBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $shrinkBtn.Add_Click({
        $pickerForm.Close()
        $shrinkScript = Join-Path $env:LOCALAPPDATA "ShrinkMenu\shrink.ps1"
        if (Test-Path $shrinkScript) {
            $shrinkArgs = ""
            if ($ListFile -and (Test-Path $ListFile)) {
                $shrinkArgs = "-ListFile `"$ListFile`""
            } elseif ($Path) {
                $shrinkArgs = "-Path `"$Path`""
            }
            if ($shrinkArgs) {
                Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$shrinkScript`" $shrinkArgs" -WindowStyle Hidden
            }
        }
        exit 0
    })
    $shrinkBtn.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::FromArgb(60, 44, 18) })
    $shrinkBtn.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::FromArgb(44, 32, 12) })
    $pickerForm.Controls.Add($shrinkBtn)
    $yPos += 34

    $pickerForm.ClientSize = New-Object System.Drawing.Size(300, ($yPos + 12))

    [System.Windows.Forms.Application]::Run($pickerForm)

    if (-not $script:pickedFormat) { exit 0 }
    $Format = $script:pickedFormat
}

# ── Build file list (accept any file, let ffmpeg handle it) ──
$files = @()

if ($ListFile -and (Test-Path $ListFile)) {
    $paths = @(Get-Content -Path $ListFile -Encoding UTF8 | Where-Object { $_.Trim() -ne "" })
    foreach ($p in $paths) {
        $p = $p.Trim()
        if (Test-Path $p -PathType Leaf) {
            $files += Get-Item $p
        } elseif (Test-Path $p -PathType Container) {
            $files += @(Get-ChildItem -Path $p -File)
        }
    }
    Remove-Item -Path $ListFile -Force -ErrorAction SilentlyContinue
} elseif ($Path) {
    if (Test-Path $Path -PathType Container) {
        $files += @(Get-ChildItem -Path $Path -File)
    } elseif (Test-Path $Path -PathType Leaf) {
        $files += Get-Item $Path
    }
}

if ($files.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("No matching media files found.", "FFmpeg Convert", "OK", "Warning") | Out-Null
    exit 0
}

# ── Output extension ──
$outExt = switch ($Format) {
    'extract-mp3' { '.mp3' }
    'extract-wav' { '.wav' }
    default { ".$Format" }
}

$formatLabel = switch ($Format) {
    'mp3' { 'MP3' }; 'wav' { 'WAV' }; 'flac' { 'FLAC' }; 'aac' { 'AAC' }
    'mp4' { 'MP4 (x264)' }; 'mkv' { 'MKV (x264)' }; 'webm' { 'WebM (VP9)' }
    'extract-mp3' { 'Extract MP3' }; 'extract-wav' { 'Extract WAV' }
}

# ══════════════════════════════════════
#  BUILD THE UI
# ══════════════════════════════════════

$form = New-Object System.Windows.Forms.Form
$form.Text = "FFmpeg Convert - $formatLabel"
$form.Size = New-Object System.Drawing.Size(560, 420)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Title
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Converting $($files.Count) file(s) to $formatLabel"
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$titleLabel.Size = New-Object System.Drawing.Size(500, 25)
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
$form.Controls.Add($titleLabel)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 50)
$progressBar.Size = New-Object System.Drawing.Size(505, 28)
$progressBar.Style = "Continuous"
$progressBar.Minimum = 0
$progressBar.Maximum = $files.Count
$progressBar.Value = 0
$form.Controls.Add($progressBar)

# Status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Starting..."
$statusLabel.Location = New-Object System.Drawing.Point(20, 85)
$statusLabel.Size = New-Object System.Drawing.Size(505, 20)
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$form.Controls.Add($statusLabel)

# File list
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(20, 112)
$listView.Size = New-Object System.Drawing.Size(505, 220)
$listView.View = "Details"
$listView.FullRowSelect = $true
$listView.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$listView.ForeColor = [System.Drawing.Color]::White
$listView.Font = New-Object System.Drawing.Font("Consolas", 9)
$listView.BorderStyle = "None"
$listView.HeaderStyle = "Nonclickable"
$listView.GridLines = $false

$colFile = $listView.Columns.Add("File", 300)
$colStatus = $listView.Columns.Add("Status", 90)
$colSize = $listView.Columns.Add("Size", 95)

foreach ($file in $files) {
    $item = New-Object System.Windows.Forms.ListViewItem($file.Name)
    $item.SubItems.Add("Queued")
    $sizeKB = [math]::Round($file.Length / 1MB, 1)
    $item.SubItems.Add("$sizeKB MB")
    $item.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150)
    $listView.Items.Add($item) | Out-Null
}

$form.Controls.Add($listView)

# Close button (hidden until done)
$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Text = "Close"
$closeBtn.Location = New-Object System.Drawing.Point(420, 342)
$closeBtn.Size = New-Object System.Drawing.Size(105, 32)
$closeBtn.FlatStyle = "Flat"
$closeBtn.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$closeBtn.ForeColor = [System.Drawing.Color]::White
$closeBtn.Visible = $false
$closeBtn.Add_Click({ $form.Close() })
$form.Controls.Add($closeBtn)

# ── Conversion function ──
function Get-FFmpegArgString {
    param([string]$InputFile, [string]$OutputFile, [string]$Fmt)

    $sampleRate = 44100
    try {
        $probe = & ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$InputFile" 2>&1
        if ($probe -match '^\d+$') {
            $probed = [int]$probe
            if ($probed -gt 44100) { $sampleRate = $probed }
        }
    } catch {}

    $a = "-i `"$InputFile`" -y "

    switch ($Fmt) {
        'mp3'         { $a += "-codec:a libmp3lame -q:a 2 -ar $sampleRate -vn" }
        'wav'         { $a += "-codec:a pcm_s16le -ar $sampleRate -vn" }
        'flac'        { $a += "-codec:a flac -compression_level 8 -ar $sampleRate -vn" }
        'aac'         { $a += "-codec:a aac -b:a 192k -ar $sampleRate -vn" }
        'mp4'         { $a += "-codec:v libx264 -crf 23 -preset medium -codec:a aac -b:a 160k -movflags +faststart" }
        'mkv'         { $a += "-codec:v libx264 -crf 23 -preset medium -codec:a copy" }
        'webm'        { $a += "-codec:v libvpx-vp9 -crf 31 -b:v 0 -cpu-used 2 -row-mt 1 -codec:a libopus -b:a 128k" }
        'extract-mp3' { $a += "-codec:a libmp3lame -q:a 2 -ar $sampleRate -vn" }
        'extract-wav' { $a += "-codec:a pcm_s16le -ar $sampleRate -vn" }
    }

    $a += " `"$OutputFile`""
    return $a
}

# ── Run conversions after form is shown ──
$script:successCount = 0
$script:failCount = 0
$script:currentIndex = 0
$maxParallel = [Math]::Min(4, [Environment]::ProcessorCount)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200

$script:runningJobs = @{}
$script:jobQueue = New-Object System.Collections.Queue

# Pre-fill queue
for ($i = 0; $i -lt $files.Count; $i++) {
    $script:jobQueue.Enqueue($i)
}

function Start-NextJob {
    while ($script:runningJobs.Count -lt $maxParallel -and $script:jobQueue.Count -gt 0) {
        $idx = $script:jobQueue.Dequeue()
        $file = $files[$idx]
        $inputPath = $file.FullName
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $dir = $file.DirectoryName

        $outputPath = Join-Path $dir "$baseName$outExt"
        if ($outputPath -eq $inputPath) {
            $outputPath = Join-Path $dir "$($baseName)_converted$outExt"
        }

        $argString = Get-FFmpegArgString -InputFile $inputPath -OutputFile $outputPath -Fmt $Format

        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = "ffmpeg"
        $pinfo.Arguments = $argString
        $pinfo.UseShellExecute = $false
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.CreateNoWindow = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $pinfo
        $proc.Start() | Out-Null
        $proc.StandardOutput.ReadToEndAsync() | Out-Null
        $proc.StandardError.ReadToEndAsync() | Out-Null

        $listView.Items[$idx].SubItems[1].Text = "Converting"
        $listView.Items[$idx].ForeColor = [System.Drawing.Color]::FromArgb(255, 220, 100)

        $script:runningJobs[$idx] = @{
            Process = $proc
            OutputPath = $outputPath
            File = $file
        }
    }
}

$timer.Add_Tick({
    $completed = @()

    foreach ($kvp in $script:runningJobs.GetEnumerator()) {
        $idx = $kvp.Key
        $job = $kvp.Value
        $proc = $job.Process

        if ($proc.HasExited) {
            $completed += $idx

            if ($proc.ExitCode -eq 0 -and (Test-Path $job.OutputPath)) {
                # Move original to preconvert
                $dir = $job.File.DirectoryName
                $preDir = Join-Path $dir "preconvert"
                if (-not (Test-Path $preDir)) {
                    New-Item -Path $preDir -ItemType Directory -Force | Out-Null
                }
                $dest = Join-Path $preDir $job.File.Name
                try {
                    Move-Item -Path $job.File.FullName -Destination $dest -Force
                } catch {}

                $listView.Items[$idx].SubItems[1].Text = "Done"
                $listView.Items[$idx].ForeColor = [System.Drawing.Color]::FromArgb(100, 220, 100)

                # Show new file size
                if (Test-Path $job.OutputPath) {
                    $newSize = [math]::Round((Get-Item $job.OutputPath).Length / 1MB, 1)
                    $listView.Items[$idx].SubItems[2].Text = "$newSize MB"
                }

                $script:successCount++
            } else {
                $listView.Items[$idx].SubItems[1].Text = "Failed"
                $listView.Items[$idx].ForeColor = [System.Drawing.Color]::FromArgb(255, 80, 80)
                $script:failCount++
            }

            $progressBar.Value = $script:successCount + $script:failCount
        }
    }

    foreach ($idx in $completed) {
        $script:runningJobs.Remove($idx)
    }

    Start-NextJob

    $done = $script:successCount + $script:failCount
    $statusLabel.Text = "$done / $($files.Count) complete  |  $($script:successCount) OK  |  $($script:failCount) failed  |  $($script:runningJobs.Count) active"

    if ($done -eq $files.Count -and $script:runningJobs.Count -eq 0) {
        $timer.Stop()
        $titleLabel.Text = "All done! $($script:successCount) converted, $($script:failCount) failed"
        if ($script:failCount -eq 0) {
            $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 220, 100)
        } else {
            $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 180, 80)
        }
        $closeBtn.Visible = $true
        $closeBtn.Focus()
    }
})

$form.Add_Shown({
    Start-NextJob
    $timer.Start()
})

$form.Add_FormClosing({
    $timer.Stop()
    foreach ($kvp in $script:runningJobs.GetEnumerator()) {
        try { $kvp.Value.Process.Kill() } catch {}
    }
})

[System.Windows.Forms.Application]::Run($form)
