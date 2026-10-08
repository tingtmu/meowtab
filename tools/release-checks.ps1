<#
.SYNOPSIS
    Check a downloaded MeowTab release against SHA256SUMS.txt and scan it on VirusTotal.

.DESCRIPTION
    <Folder> holds meowtab.zip and SHA256SUMS.txt as CI made them, i.e. the draft release's files:
    `gh release download v0.1.0 -D <folder>` (build.ps1 doesn't write SHA256SUMS.txt). Run it as the
    release's author, before publishing:

      1. Every line of SHA256SUMS.txt is checked against its file: meowtab.zip in <Folder>, the other
         paths among the zip's entries (the exes are read out of the zip into a temp folder).
         Any mismatch or missing file fails the script.
      2. Without $env:VT_API_KEY it stops here, saying the hashes passed and VirusTotal was skipped.
      3. With a key (a free one is enough: 4 requests per minute), the zip and both exes are uploaded
         to VirusTotal, the analyses are awaited, and a Markdown table (file, SHA-256, detections,
         report link) is printed for the release notes.

    Everything uploaded to VirusTotal becomes public there, so run it on release files only. The
    key is read from the environment and is never printed.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\release-checks.ps1 C:\tmp\v0.1.0
    (VT_API_KEY set once with `setx VT_API_KEY <key>` and a new terminal, so the key stays out of command history)
#>
param(
    [Parameter(Mandatory)][string]$Folder    # folder with meowtab.zip and SHA256SUMS.txt
)
$ErrorActionPreference = 'Stop'
$VtApi = 'https://www.virustotal.com/api/v3'
$ScanTimeoutMinutes = 20
$required = 'meowtab.zip', 'meowtab/meowtab.exe', 'meowtab/meowtab-classic.exe'

function Get-Sha256([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower() }

# Reads SHA256SUMS.txt (sha256sum format) into @{ Hash; Path } entries.
function Read-Sums([string]$file) {
    $entries = @()
    foreach ($line in (Get-Content -LiteralPath $file)) {
        if (-not $line.Trim()) { continue }
        if ($line -notmatch '^([0-9a-fA-F]{64}) [ *](\S.*)$') { throw "SHA256SUMS.txt: can't read the line '$line'." }
        $path = $Matches[2]
        if ($path -match '(^|/)\.\.(/|$)|^/|:|\\') { throw "SHA256SUMS.txt: unsafe path '$path'." }
        $entries += @{ Hash = $Matches[1].ToLower(); Path = $path }
    }
    foreach ($name in $required) {
        if (-not ($entries | Where-Object { $_.Path -eq $name })) { throw "SHA256SUMS.txt has no line for $name." }
    }
    return $entries
}

# Checks every entry; returns name -> local file path (the zip, plus the exes extracted into $tmp).
function Test-Sums($entries, [string]$dir, [string]$tmp) {
    $zipPath = Join-Path $dir 'meowtab.zip'
    if (-not (Test-Path -LiteralPath $zipPath)) { throw "meowtab.zip is not in $dir." }
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    try { $zip = [IO.Compression.ZipFile]::OpenRead($zipPath) } catch { throw "meowtab.zip is not a readable zip file." }
    $files = @{}
    $failed = 0
    try {
        foreach ($e in $entries) {
            $local = $null
            if ($e.Path -eq 'meowtab.zip') {
                $local = $zipPath
            } else {
                $entry = $zip.Entries | Where-Object { $_.FullName -eq $e.Path } | Select-Object -First 1
                if ($entry) {
                    $local = Join-Path $tmp ($e.Path -replace '/', '\')
                    New-Item -ItemType Directory -Force (Split-Path $local) | Out-Null
                    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $local, $true)
                }
            }
            if (-not $local) {
                Write-Host ("MISSING  {0} (not in the zip)" -f $e.Path) -ForegroundColor Red
                $failed++
                continue
            }
            $actual = Get-Sha256 $local
            if ($actual -eq $e.Hash) {
                Write-Host ("OK       {0}" -f $e.Path)
                $files[$e.Path] = $local
            } else {
                Write-Host ("MISMATCH {0}`n         expected {1}`n         got      {2}" -f $e.Path, $e.Hash, $actual) -ForegroundColor Red
                $failed++
            }
        }
    } finally { $zip.Dispose() }
    if ($failed) { throw "$failed file(s) do not match SHA256SUMS.txt. Do not publish this release." }
    return $files
}

# --- VirusTotal -------------------------------------------------------------------------------

# Sends one request (GET, or POST with a form) and returns the parsed JSON.
function Send-Vt($client, [string]$method, [string]$url, $content, [string]$what) {
    Start-Sleep -Seconds 16   # free key: 4 requests/min, spaced from the previous answer
    try {
        if ($method -eq 'POST') { $resp = $client.PostAsync($url, $content).GetAwaiter().GetResult() }
        else { $resp = $client.GetAsync($url).GetAwaiter().GetResult() }
    } catch { throw "Could not reach VirusTotal ($what): $($_.Exception.GetBaseException().Message)" }
    try {
        $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $code = [int]$resp.StatusCode
        $json = $null
        try { $json = $body | ConvertFrom-Json } catch { }
        if (-not $resp.IsSuccessStatusCode) {
            $detail = ''
            if ($json -and $json.error -and $json.error.message) { $detail = " ($($json.error.code): $($json.error.message))" }
            if ($code -eq 401 -or $code -eq 403) { throw "VirusTotal rejected VT_API_KEY (HTTP $code)$detail." }
            if ($code -eq 429) { throw "VirusTotal's request or daily quota is used up (HTTP 429)$detail. Wait a minute and run again." }
            throw "VirusTotal answered HTTP $code for $what$detail."
        }
        if (-not $json) { throw "VirusTotal's answer for $what was not JSON." }
        return $json
    } finally { $resp.Dispose() }
}

# Uploads one file as a plain multipart/form-data "file" part (like curl -F); returns the analysis id.
function Send-VtFile($client, [string]$path) {
    $name = Split-Path $path -Leaf
    $form = New-Object System.Net.Http.MultipartFormDataContent
    try {
        $part = New-Object System.Net.Http.ByteArrayContent (, [IO.File]::ReadAllBytes($path))
        $part.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue 'application/octet-stream'
        $cd = New-Object System.Net.Http.Headers.ContentDispositionHeaderValue 'form-data'
        $cd.Name = '"file"'; $cd.FileName = "`"$name`""
        $part.Headers.ContentDisposition = $cd
        $form.Add($part)
        $json = Send-Vt $client 'POST' "$VtApi/files" $form "the upload of $name"
    } finally { $form.Dispose() }
    $id = $json.data.id
    if (-not $id -or $id -isnot [string]) { throw "VirusTotal's answer to the upload of $name has no analysis id." }
    return $id
}
# Returns the analysis once it is completed, or $null while it is still running.
function Get-VtAnalysis($client, [string]$id, [string]$name, [string]$sha256) {
    $json = Send-Vt $client 'GET' "$VtApi/analyses/$id" $null "the analysis of $name"
    $attr = $json.data.attributes
    if (-not $attr -or $attr.status -isnot [string]) { throw "VirusTotal's analysis of $name has no status." }
    $seen = $json.meta.file_info.sha256
    if ($seen -and $seen.ToLower() -ne $sha256) { throw "VirusTotal analysed a different file than $name (SHA-256 $seen)." }
    if ($attr.status -ne 'completed') { return $null }
    foreach ($key in 'malicious', 'suspicious', 'undetected', 'harmless') {
        if ($null -eq $attr.stats -or -not $attr.stats.PSObject.Properties[$key]) { throw "VirusTotal's analysis of $name has no '$key' count." }
    }
    return $attr.stats
}

function Invoke-VtScan($files, [string]$key) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 'Tls12'
    Add-Type -AssemblyName System.Net.Http
    $client = New-Object System.Net.Http.HttpClient
    try {
        $client.Timeout = [TimeSpan]::FromMinutes(10)
        $client.DefaultRequestHeaders.Add('x-apikey', $key)

        $jobs = @()
        foreach ($name in $required) {
            Write-Host "Uploading $name to VirusTotal..."
            $jobs += @{ Name = $name; Sha = Get-Sha256 $files[$name]; Id = (Send-VtFile $client $files[$name]); Stats = $null }
        }

        $deadline = (Get-Date).AddMinutes($ScanTimeoutMinutes)
        while ($true) {
            foreach ($j in $jobs | Where-Object { -not $_.Stats }) {
                $j.Stats = Get-VtAnalysis $client $j.Id $j.Name $j.Sha
                if ($j.Stats) { Write-Host "Scan finished: $($j.Name)" }
            }
            if (-not ($jobs | Where-Object { -not $_.Stats })) { break }
            if ((Get-Date) -gt $deadline) { throw "VirusTotal did not finish within $ScanTimeoutMinutes minutes. Run the script again later." }
        }
    } finally { $client.Dispose() }
    return $jobs
}

function Write-Markdown($jobs) {
    Write-Host ''
    Write-Host 'Paste into the release notes:'
    Write-Host ''
    '| File | SHA-256 | Detections | VirusTotal |'
    '| --- | --- | --- | --- |'
    foreach ($j in $jobs) {
        $s = $j.Stats
        $engines = [int]$s.malicious + [int]$s.suspicious + [int]$s.undetected + [int]$s.harmless
        '| {0} | `{1}` | {2} malicious, {3} suspicious of {4} engines | [report](https://www.virustotal.com/gui/file/{1}) |' -f `
            $j.Name, $j.Sha, [int]$s.malicious, [int]$s.suspicious, $engines
    }
}

# --- main -------------------------------------------------------------------------------------

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('meowtab-release-' + [Guid]::NewGuid().ToString('N'))
try {
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { throw "Folder not found: $Folder" }
    $Folder = (Resolve-Path -LiteralPath $Folder).Path
    $sums = Join-Path $Folder 'SHA256SUMS.txt'
    if (-not (Test-Path -LiteralPath $sums)) { throw "SHA256SUMS.txt is not in $Folder." }

    New-Item -ItemType Directory -Force $tmp | Out-Null
    $files = Test-Sums (Read-Sums $sums) $Folder $tmp
    Write-Host 'All hashes match SHA256SUMS.txt.'

    if (-not $env:VT_API_KEY) {
        Write-Host 'VT_API_KEY is not set, so VirusTotal was skipped. The hash check passed; set the key to scan the files too.'
        return
    }
    Write-Markdown (Invoke-VtScan $files $env:VT_API_KEY)
} catch {
    Write-Host "release-checks failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
}
