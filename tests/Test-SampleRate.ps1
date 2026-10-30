# Test-SampleRate.ps1 — the sample rate each output format gets, run through real ffmpeg.
# Loads only Get-FFmpegArgString from ffmpeg-convert.ps1 (the script itself opens a window).
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\Test-SampleRate.ps1
# Exit 0 = all pass.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'ffmpeg-convert.ps1'), [ref]$null, [ref]$null)
$fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-FFmpegArgString' }, $true) | Select-Object -First 1
if (-not $fn) { Write-Host 'FAIL Get-FFmpegArgString not found'; exit 1 }
. ([scriptblock]::Create($fn.Extent.Text))

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ffcm-test-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp | Out-Null
$fail = 0
try {
    # input rate, format, expected output rate
    $cases = @(
        @(96000, 'mp3', 48000), @(96000, 'extract-mp3', 48000), @(48000, 'mp3', 48000), @(44100, 'mp3', 44100),
        @(22050, 'mp3', 44100), @(96000, 'wav', 96000), @(96000, 'flac', 96000), @(96000, 'aac', 96000)
    )
    foreach ($c in $cases) {
        $in = Join-Path $tmp ("in-" + $c[0] + ".wav")
        if (-not (Test-Path $in)) { & ffmpeg -v error -y -f lavfi -i "sine=frequency=440:sample_rate=$($c[0]):duration=1" -c:a pcm_s16le $in }
        $ext = @{ 'mp3' = 'mp3'; 'extract-mp3' = 'mp3'; 'wav' = 'wav'; 'flac' = 'flac'; 'aac' = 'm4a' }[$c[1]]
        $out = Join-Path $tmp ("out-" + $c[0] + "-" + $c[1] + "." + $ext)
        $argString = Get-FFmpegArgString -InputFile $in -OutputFile $out -Fmt $c[1]
        $p = Start-Process -FilePath ffmpeg -ArgumentList ("-v error " + $argString) -NoNewWindow -Wait -PassThru
        $rate = if (Test-Path $out) { [int](& ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 $out) } else { 0 }
        if ($p.ExitCode -eq 0 -and $rate -eq $c[2]) { Write-Host ("PASS {0,-12} {1,6} Hz -> {2} Hz" -f $c[1], $c[0], $rate) }
        else { Write-Host ("FAIL {0,-12} {1,6} Hz -> exit {2}, {3} Hz (want {4})" -f $c[1], $c[0], $p.ExitCode, $rate, $c[2]); $fail++ }
    }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force
}
if ($fail) { Write-Host "$fail failed"; exit 1 }
Write-Host 'all passed'
exit 0
