<#
.SYNOPSIS
    Compile cutout.c to machine code and write it as base64 into cutout-mcode.ahk.

.DESCRIPTION
    Uses a pinned Zig (zig cc, a clang) taken from -Zig, $env:ZIG or build\zig. With none of those,
    the pinned release is downloaded from ziglang.org into build\zig (git-ignored) and its SHA-256
    is checked before it is extracted. Nothing is installed.

    The .text section of the COFF object is the machine code, and it must hold no relocations: the
    bytes are copied to executable memory by the AHK script, so nothing can be patched in. A
    relocation means the C code used a global, a constant table, a jump table, or a library call
    (memset, memcpy, __chkstk). The entry offset is the value of the cutout_run symbol.

    The same source and Zig version always give byte-identical output. -Check builds into build\check
    instead and fails if the committed file differs (line endings are ignored), for CI.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File build-mcode.ps1
    powershell -ExecutionPolicy Bypass -File build-mcode.ps1 -Check
#>
param(
    [string]$Zig = $env:ZIG,                    # path to zig.exe
    [string]$Source = 'cutout.c',               # C file to compile
    [string]$Output = 'cutout-mcode.ahk',       # generated AHK file
    [switch]$Check                              # compare with the committed output, write nothing there
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$ZigVersion = '0.17.0'
$ZigSha256 = 'b5663f69581dcf391293fbf16c06cb80d81d806545ce618b4d0bab7f0eb8c428'
$ZigUrl = "https://ziglang.org/download/$ZigVersion/zig-x86_64-windows-$ZigVersion.zip"
$flags = '-target', 'x86_64-windows-gnu', '-O2', '-ffreestanding', '-fno-builtin', '-nostdlib',
    '-fno-stack-protector', '-fno-jump-tables', '-mno-stack-arg-probe', '-fno-asynchronous-unwind-tables',
    '-fno-vectorize', '-fno-slp-vectorize'

function Get-FullPath([string]$p) { [IO.Path]::GetFullPath([IO.Path]::Combine($root, $p)) }   # absolute paths win

function Get-Zig {
    $dir = Join-Path $root 'build\zig'
    $exe = Join-Path $dir 'zig.exe'
    if (Test-Path $exe) { return $exe }
    Write-Host "Downloading Zig $ZigVersion..."
    New-Item -ItemType Directory -Force (Split-Path $dir) | Out-Null
    $zip = "$dir.zip"
    $ProgressPreference = 'SilentlyContinue'      # the progress bar makes Invoke-WebRequest very slow in 5.1
    Invoke-WebRequest $ZigUrl -OutFile $zip -UseBasicParsing
    $actual = (Get-FileHash $zip -Algorithm SHA256).Hash
    if ($actual -ne $ZigSha256) { Remove-Item $zip; throw "SHA-256 mismatch for ${ZigUrl}: $actual" }
    $tmp = "$dir.extract"
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
    Move-Item (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName $dir
    Remove-Item $tmp, $zip -Recurse -Force
    if (-not (Test-Path $exe)) { throw "zig.exe not found in the Zig $ZigVersion zip." }
    return $exe
}

# Minimal COFF reader: returns .text bytes, relocation count and target names, and a symbol lookup.
function Read-Coff([string]$path) {
    $b = [IO.File]::ReadAllBytes($path)
    $nSec = [BitConverter]::ToUInt16($b, 2)
    $symPtr = [BitConverter]::ToUInt32($b, 8)
    $nSym = [BitConverter]::ToUInt32($b, 12)
    $strBase = $symPtr + 18 * $nSym
    $symName = {
        param([int]$i)
        $o = $symPtr + 18 * $i
        if ([BitConverter]::ToUInt32($b, $o) -ne 0) { return ([Text.Encoding]::ASCII.GetString($b, $o, 8)).TrimEnd([char]0) }
        $s = $strBase + [BitConverter]::ToUInt32($b, $o + 4)
        $e = $s; while ($b[$e] -ne 0) { $e++ }
        return [Text.Encoding]::ASCII.GetString($b, $s, $e - $s)
    }
    $text = $null; $textNo = 0
    for ($i = 0; $i -lt $nSec; $i++) {
        $o = 20 + [BitConverter]::ToUInt16($b, 16) + 40 * $i
        if (([Text.Encoding]::ASCII.GetString($b, $o, 8)).TrimEnd([char]0) -ne '.text') { continue }
        $size = [BitConverter]::ToUInt32($b, $o + 16); $ptr = [BitConverter]::ToUInt32($b, $o + 20)
        $relPtr = [BitConverter]::ToUInt32($b, $o + 24); $nRel = [BitConverter]::ToUInt16($b, $o + 32)
        $targets = for ($r = 0; $r -lt $nRel; $r++) { & $symName ([BitConverter]::ToUInt32($b, $relPtr + 10 * $r + 4)) }
        $code = New-Object byte[] $size
        [Array]::Copy($b, $ptr, $code, 0, $size)
        $text = @{ Code = $code; Relocs = $nRel; Targets = @($targets) }; $textNo = $i + 1
    }
    if (-not $text) { throw "No .text section in $path." }
    $entry = $null
    for ($i = 0; $i -lt $nSym; $i++) {
        $o = $symPtr + 18 * $i
        if ((& $symName $i) -eq 'cutout_run' -and [BitConverter]::ToInt16($b, $o + 12) -eq $textNo) { $entry = [BitConverter]::ToUInt32($b, $o + 8) }
        $i += $b[$o + 17]                          # skip auxiliary records
    }
    $text.Entry = $entry
    return $text
}

function Format-Mcode($coff, [string]$src) {
    $b64 = [Convert]::ToBase64String($coff.Code)
    $lines = for ($i = 0; $i -lt $b64.Length; $i += 100) { '        . "' + $b64.Substring($i, [Math]::Min(100, $b64.Length - $i)) + '"' }
    $head = "; Generated by build-mcode.ps1 from $src with Zig $ZigVersion. Do not edit.",
        "; Machine code for cutout.ahk (x64, no relocations): entry is cutout_run's byte offset.",
        'CutoutMcode() {',
        "    return {entry: $($coff.Entry), size: $($coff.Code.Length), code: `"`""
    return (($head + $lines + '    }', '}') -join "`n") + "`n"
}

$Zig = if ($Zig) { $Zig } else { Get-Zig }
if (-not (Test-Path -LiteralPath $Zig)) { throw "zig.exe not found: $Zig" }
$ver = (& $Zig version).Trim()
if ($ver -ne $ZigVersion) { throw "Zig $ver found, but this script is pinned to $ZigVersion (output must be reproducible)." }
$srcPath = Get-FullPath $Source
if (-not (Test-Path -LiteralPath $srcPath)) { throw "Source not found: $srcPath" }
$outDir = Join-Path $root 'build'
if ($Check) { $outDir = Join-Path $outDir 'check' }
New-Item -ItemType Directory -Force $outDir | Out-Null
$obj = Join-Path $outDir ([IO.Path]::GetFileNameWithoutExtension($srcPath) + '.o')
if (Test-Path $obj) { Remove-Item $obj }

$env:ZIG_GLOBAL_CACHE_DIR = Join-Path $root 'build\zig-cache'      # keep zig's cache inside the repo's build\
$env:ZIG_LOCAL_CACHE_DIR = $env:ZIG_GLOBAL_CACHE_DIR
& $Zig cc @flags -c $srcPath -o $obj
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $obj)) { throw "Compiling $Source failed (exit code $LASTEXITCODE)." }

$coff = Read-Coff $obj
if ($coff.Relocs -ne 0) {
    $names = ($coff.Targets | Sort-Object -Unique) -join ', '
    throw ("$Source needs $($coff.Relocs) relocation(s) in .text (targets: $names). MCode cannot be patched: " +
        'avoid globals, static tables, float constants, jump tables and library calls (memset/memcpy/__chkstk); ' +
        'write plain loops instead.')
}
if ($null -eq $coff.Entry) { throw "Symbol cutout_run not found in .text of $Source." }
# -mno-stack-arg-probe drops __chkstk, so a frame of 4 KB or more could jump past the stack guard page
$c = $coff.Code
for ($i = 0; $i -le $c.Length - 7; $i++) {
    if ($c[$i] -eq 0x48 -and $c[$i + 1] -eq 0x81 -and $c[$i + 2] -eq 0xEC -and [BitConverter]::ToUInt32($c, $i + 3) -ge 4096) {
        throw "$Source has a stack frame of $([BitConverter]::ToUInt32($c, $i + 3)) bytes (sub rsp at $i): keep each under 4 KB."
    }
}

$text = Format-Mcode $coff (Split-Path $srcPath -Leaf)
$target = Get-FullPath $Output
if ($Check) {
    $have = if (Test-Path -LiteralPath $target) { [IO.File]::ReadAllText($target).Replace("`r`n", "`n") } else { '' }
    if ($have -cne $text) { throw "$Output is out of date: run build-mcode.ps1 and commit the result." }
    Write-Host "$Output is up to date ($($coff.Code.Length) bytes, entry $($coff.Entry))."
} else {
    [IO.File]::WriteAllText($target, $text, (New-Object Text.UTF8Encoding $false))
    Write-Host "Wrote $Output ($($coff.Code.Length) bytes, entry $($coff.Entry), Zig $ZigVersion)."
}
