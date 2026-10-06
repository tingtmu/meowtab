<#
.SYNOPSIS
    Compile peek-alttab.exe and elegant-alttab.exe and pack dist\peek-alttab.zip.

.DESCRIPTION
    Needs AutoHotkey v2 (its AutoHotkey64.exe is the base of the exe) and Ahk2Exe, the official
    compiler. Ahk2Exe is taken from -Ahk2Exe, $env:AHK2EXE or AutoHotkey's Compiler folder; with
    none of those, the latest release is downloaded from github.com/AutoHotkey/Ahk2Exe into
    build\ahk2exe (git-ignored). Nothing is installed.

    The exe's name, version, description and icon come from the ;@Ahk2Exe-... lines at the top
    of each script.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File build.ps1
    powershell -ExecutionPolicy Bypass -File build.ps1 -Ahk2Exe C:\tools\Ahk2Exe.exe
#>
param(
    [string]$Ahk2Exe = $env:AHK2EXE,   # path to Ahk2Exe.exe
    [string]$Base = $env:AHK_BASE      # path to AutoHotkey64.exe (v2)
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dist = Join-Path $root 'dist'
$scripts = 'peek-alttab', 'elegant-alttab'

function Find-First([string[]]$paths) {
    foreach ($p in $paths) { if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path } }
    return $null
}

function Get-Ahk2Exe {
    $dir = Join-Path $root 'build\ahk2exe'
    $exe = Join-Path $dir 'Ahk2Exe.exe'
    if (Test-Path $exe) { return $exe }
    Write-Host 'Downloading the latest Ahk2Exe release...'
    $rel = Invoke-RestMethod 'https://api.github.com/repos/AutoHotkey/Ahk2Exe/releases/latest'
    $asset = $rel.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
    if (-not $asset) { throw "No zip in Ahk2Exe release $($rel.tag_name)." }
    New-Item -ItemType Directory -Force $dir | Out-Null
    $zip = Join-Path $dir $asset.name
    Invoke-WebRequest $asset.browser_download_url -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath $dir -Force
    if (-not (Test-Path $exe)) { throw "Ahk2Exe.exe not found in $($asset.name)." }
    return $exe
}

$Base = Find-First @($Base,
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe")
if (-not $Base) { throw 'AutoHotkey v2 not found: pass -Base <path to AutoHotkey64.exe> or set AHK_BASE.' }
$Ahk2Exe = Find-First @($Ahk2Exe,
    "$env:LOCALAPPDATA\Programs\AutoHotkey\Compiler\Ahk2Exe.exe",
    "$env:ProgramFiles\AutoHotkey\Compiler\Ahk2Exe.exe")
if (-not $Ahk2Exe) { $Ahk2Exe = Get-Ahk2Exe }
Write-Host "Base:    $Base"
Write-Host "Ahk2Exe: $Ahk2Exe"

# Fresh dist\peek-alttab\ (the zip's top-level folder)
$stage = Join-Path $dist 'peek-alttab'
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $stage 'images') | Out-Null

foreach ($name in $scripts) {
    $out = Join-Path $stage "$name.exe"
    $argList = @('/in', "`"$root\$name.ahk`"", '/out', "`"$out`"", '/base', "`"$Base`"",
        '/icon', "`"$root\assets\peek-alttab.ico`"", '/compress', '0', '/silent', 'verbose')
    $p = Start-Process $Ahk2Exe -ArgumentList $argList -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -ne 0 -or -not (Test-Path $out)) { throw "Compiling $name.ahk failed (exit code $($p.ExitCode))." }
}

# Only the shipped placeholder images: never the user's own (custom_*) or a local settings.ini
Copy-Item (Join-Path $root 'images\chill_*.png') (Join-Path $stage 'images')
Copy-Item (Join-Path $root 'cutout.py'), (Join-Path $root 'README.md'), (Join-Path $root 'LICENSE') $stage

# Entries added one by one: Windows PowerShell 5.1's Compress-Archive and CreateFromDirectory write
# backslashes into entry names, which some unzip tools turn into flat "peek-alttab\..." files.
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zipPath = Join-Path $dist 'peek-alttab.zip'
$zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
try {
    Get-ChildItem $stage -Recurse -File | ForEach-Object {
        $entry = 'peek-alttab/' + $_.FullName.Substring($stage.Length + 1).Replace('\', '/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entry,
            [IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $zip.Dispose() }

# Fail on anything outside the allowlist, so a private file can never reach a release
$allowed = '^peek-alttab/((peek|elegant)-alttab\.exe|images/chill_[^/]+\.png|cutout\.py|README\.md|LICENSE)$'
$zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
try { $bad = @($zip.Entries.FullName | Where-Object { $_ -notmatch $allowed }) } finally { $zip.Dispose() }
if ($bad) { throw "Unexpected files in the zip: $($bad -join ', ')" }

Write-Host ''
Get-ChildItem $stage -Recurse -File | ForEach-Object {
    '{0,-28} {1,10:N0} bytes' -f $_.FullName.Substring($stage.Length + 1), $_.Length
}
'{0,-28} {1,10:N0} bytes' -f 'dist\peek-alttab.zip', (Get-Item $zipPath).Length
