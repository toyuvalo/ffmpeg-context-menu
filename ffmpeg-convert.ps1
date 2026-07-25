# ffmpeg-convert.ps1 — FFmpeg converter with progress UI and parallel processing  v1.3.0
#
# 2026-07-25 — awkward characters in a file name no longer break the run:
#   * launcher.vbs now hands over a UTF-8 file list. It used to write the list
#     in the system codepage while this script read it back as UTF-8, so a
#     smart quote (’), accent or dash turned into a replacement character, the
#     path stopped resolving, and the file silently vanished from the batch.
#   * every path operation uses -LiteralPath — '[' and ']' in a name were
#     treated as a wildcard character class, dropping those files too.
#   * each file is temporarily renamed to a sanitised name for the duration of
#     the conversion; afterwards the source name is restored and the output is
#     renamed to the original name with the new extension. Nothing is ever
#     overwritten — colliding names get a _1, _2, ... suffix.
param(
    [string]$Path,
    [string]$ListFile,

    [ValidateSet("mp3","wav","flac","aac","mp4","mkv","webm","extract-mp3","extract-wav","")]
    [string]$Format
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptVersion = "1.3.0"

# ── Check ffmpeg ──
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    [System.Windows.Forms.MessageBox]::Show("ffmpeg not found on PATH.`nInstall it and make sure it's in your system PATH.", "FFmpeg Convert", "OK", "Error") | Out-Null
    exit 1
}

# ── Format picker if not specified ──
if (-not $Format) {
    $pickerForm = New-Object System.Windows.Forms.Form
    $pickerForm.Text = "FFmpeg Convert v$scriptVersion"
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

if ($ListFile -and (Test-Path -LiteralPath $ListFile)) {
    # ReadAllLines honours the BOM (UTF-8 from launcher.vbs, UTF-16 from anything
    # else) and defaults to UTF-8. Get-Content -Encoding UTF8 used to mangle every
    # non-ASCII character the launcher wrote in the system codepage.
    $listFullPath = (Resolve-Path -LiteralPath $ListFile).Path
    $paths = @([System.IO.File]::ReadAllLines($listFullPath) | Where-Object { $_.Trim() -ne "" })
    foreach ($p in $paths) {
        $p = $p.Trim()
        # -LiteralPath throughout: '[' / ']' in a file name are wildcards otherwise.
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            $files += Get-Item -LiteralPath $p
        } elseif (Test-Path -LiteralPath $p -PathType Container) {
            $files += @(Get-ChildItem -LiteralPath $p -File)
        }
    }
    Remove-Item -LiteralPath $listFullPath -Force -ErrorAction SilentlyContinue
} elseif ($Path) {
    if (Test-Path -LiteralPath $Path -PathType Container) {
        $files += @(Get-ChildItem -LiteralPath $Path -File)
    } elseif (Test-Path -LiteralPath $Path -PathType Leaf) {
        $files += Get-Item -LiteralPath $Path
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
$form.Text = "FFmpeg Convert v$scriptVersion - $formatLabel"
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

# ══════════════════════════════════════
#  FILE NAME SANITISING
#  Rather than trying to escape every awkward character, the file is renamed
#  to a safe name for the duration of the conversion and renamed back after.
#  Nothing is overwritten: every target name is checked first and gets a
#  _1 / _2 / ... suffix if it is already taken.
# ══════════════════════════════════════

# Anything outside this set gets replaced. Deliberately narrow — it covers
# smart quotes and other non-ASCII (mangled in transit), '%' (ffmpeg reads it
# as an image2 sequence pattern), and quoting characters.
$script:unsafeCharPattern = '[^A-Za-z0-9 ._\-()\[\]]'

# Names already claimed by a queued/running job, so parallel jobs can't pick
# the same temporary name.
$script:reservedPaths = @()

function Test-NameIsSafe {
    param([string]$Base)
    if ($Base -match $script:unsafeCharPattern) { return $false }
    if ($Base -match '^\s*-')                   { return $false }   # ffmpeg reads a leading - as an option
    return $true
}

function ConvertTo-SafeBaseName {
    param([string]$Base)
    $safe = [regex]::Replace($Base, $script:unsafeCharPattern, '_')
    $safe = $safe -replace '_{2,}', '_'
    $safe = $safe -replace '^[\s.]+|[\s.]+$', ''
    if ($safe -match '^-') { $safe = "_$safe" }
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = 'ffmpeg_input' }
    return $safe
}

# Returns a path that is free right now. $Ignore lets a caller treat one
# existing path (its own output file) as available.
function Get-NonCollidingPath {
    param([string]$Dir, [string]$Base, [string]$Ext, [string]$Ignore = "")
    $candidate = Join-Path $Dir "$Base$Ext"
    $n = 1
    while ($candidate -ne $Ignore -and
           ((Test-Path -LiteralPath $candidate) -or ($script:reservedPaths -contains $candidate))) {
        $candidate = Join-Path $Dir ("{0}_{1}{2}" -f $Base, $n, $Ext)
        $n++
        if ($n -gt 9999) { break }
    }
    return $candidate
}

# Puts the source file back under the name the user gave it. Safe to call more
# than once and on every exit path — success, failure and cancel.
function Restore-SourceName {
    param([hashtable]$Job)
    if (-not $Job.Renamed) { return }
    try {
        Rename-Item -LiteralPath $Job.SourcePath -NewName $Job.OrigName -ErrorAction Stop
        $Job.SourcePath = $Job.OrigPath
        $Job.Renamed    = $false
    } catch {}
}

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
        'wav'         { $a += "-codec:a pcm_s24le -ar $sampleRate -vn" }
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
        $dir      = $file.DirectoryName
        $origName = $file.Name
        $origPath = $file.FullName
        $origBase = [System.IO.Path]::GetFileNameWithoutExtension($origName)
        $origExt  = [System.IO.Path]::GetExtension($origName)

        # Convert against a sanitised name; the original name is restored below.
        $sourcePath = $origPath
        $renamed    = $false
        if (-not (Test-NameIsSafe $origBase)) {
            $safePath = Get-NonCollidingPath -Dir $dir -Base (ConvertTo-SafeBaseName $origBase) -Ext $origExt
            try {
                Rename-Item -LiteralPath $origPath -NewName ([System.IO.Path]::GetFileName($safePath)) -ErrorAction Stop
                $sourcePath = $safePath
                $renamed    = $true
                $script:reservedPaths += $safePath
            } catch {
                # Locked or read-only — leave it alone and let ffmpeg try as-is.
            }
        }

        # Free by construction, so a failed job's partial output is always safe
        # to delete and never clobbers an existing file.
        $workBase   = [System.IO.Path]::GetFileNameWithoutExtension($sourcePath)
        $outputPath = Get-NonCollidingPath -Dir $dir -Base $workBase -Ext $outExt
        $script:reservedPaths += $outputPath

        $argString = Get-FFmpegArgString -InputFile $sourcePath -OutputFile $outputPath -Fmt $Format

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
            Process    = $proc
            OutputPath = $outputPath
            File       = $file
            SourcePath = $sourcePath
            Renamed    = $renamed
            OrigPath   = $origPath
            OrigName   = $origName
            OrigBase   = $origBase
            OrigExt    = $origExt
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

            $succeeded = ($proc.ExitCode -eq 0) -and (Test-Path -LiteralPath $job.OutputPath)

            # Whatever happened, the source goes back to the name the user knows.
            Restore-SourceName $job

            if ($succeeded) {
                # Move original to preconvert
                $dir = $job.File.DirectoryName
                $preDir = Join-Path $dir "preconvert"
                if (-not (Test-Path -LiteralPath $preDir)) {
                    New-Item -Path $preDir -ItemType Directory -Force | Out-Null
                }
                $dest = Get-NonCollidingPath -Dir $preDir -Base $job.OrigBase -Ext $job.OrigExt
                try {
                    Move-Item -LiteralPath $job.SourcePath -Destination $dest -Force
                } catch {}

                # Now give the output the original name with the new extension.
                # Runs after the move so the source's own name is free again.
                $finalPath = Get-NonCollidingPath -Dir $dir -Base $job.OrigBase -Ext $outExt -Ignore $job.OutputPath
                if ($finalPath -ne $job.OutputPath) {
                    try {
                        Rename-Item -LiteralPath $job.OutputPath -NewName ([System.IO.Path]::GetFileName($finalPath)) -ErrorAction Stop
                    } catch {
                        $finalPath = $job.OutputPath
                    }
                }

                $listView.Items[$idx].SubItems[0].Text = [System.IO.Path]::GetFileName($finalPath)
                $listView.Items[$idx].SubItems[1].Text = "Done"
                $listView.Items[$idx].ForeColor = [System.Drawing.Color]::FromArgb(100, 220, 100)

                # Show new file size
                if (Test-Path -LiteralPath $finalPath) {
                    $newSize = [math]::Round((Get-Item -LiteralPath $finalPath).Length / 1MB, 1)
                    $listView.Items[$idx].SubItems[2].Text = "$newSize MB"
                }

                $script:successCount++
            } else {
                # The output path was free when the job started, so anything
                # there now is ffmpeg's partial write — safe to clean up.
                if (Test-Path -LiteralPath $job.OutputPath) {
                    Remove-Item -LiteralPath $job.OutputPath -Force -ErrorAction SilentlyContinue
                }
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
        $job = $kvp.Value
        try { $job.Process.Kill(); $job.Process.WaitForExit(2000) | Out-Null } catch {}
        # Cancelled mid-flight: put the name back and drop the partial output.
        Restore-SourceName $job
        if (Test-Path -LiteralPath $job.OutputPath) {
            Remove-Item -LiteralPath $job.OutputPath -Force -ErrorAction SilentlyContinue
        }
    }
})

[System.Windows.Forms.Application]::Run($form)
