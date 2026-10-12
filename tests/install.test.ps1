# Offline checks, no Pester or installed MeowTab needed. Run in PowerShell 5.1 and 7:
# powershell -NoProfile -ExecutionPolicy Bypass -File tests/install.test.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../tools/install.ps1')
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('meowtab-install-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null

function Check([string]$Name, [scriptblock]$Run) {
    & $Run
    Write-Host "PASS $Name"
}
function Assert($Actual, $Expected) {
    if ($Actual -cne $Expected) { throw "Expected '$Expected'; got '$Actual'." }
}
function Reject([scriptblock]$Run, [string]$Pattern) {
    try { & $Run } catch {
        if ($_.Exception.Message -notmatch $Pattern) { throw }
        return
    }
    throw "Expected failure matching $Pattern."
}
function New-FixtureZip([string]$Path, [string[]]$Extra = @(), [string]$Skip = '') {
    $zip = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($name in @('meowtab/meowtab.exe', 'meowtab/meowtab-classic.exe',
            'meowtab/images/chill_few.png', 'meowtab/images/chill_some.png',
            'meowtab/images/chill_many.png', 'meowtab/images/chill.gif', 'meowtab/README.md', 'meowtab/LICENSE') + $Extra) {
            if ($name -ceq $Skip) { continue }
            $writer = New-Object IO.StreamWriter ($zip.CreateEntry($name).Open())
            try { $writer.Write('fixture-v1') } finally { $writer.Dispose() }
        }
    } finally { $zip.Dispose() }
}
$fixtureZip = Join-Path $testRoot 'fixture.zip'
New-FixtureZip $fixtureZip
$fixtureHash = (Get-FileHash -LiteralPath $fixtureZip).Hash
$fixtureSums = Join-Path $testRoot 'sums.txt'
[IO.File]::WriteAllText($fixtureSums, "$fixtureHash  meowtab.zip`n")
$fixtureRelease = [pscustomobject]@{
    tag_name = 'v1.2.3'; draft = $false; prerelease = $false
    assets = @(
        [pscustomobject]@{ name = 'meowtab.zip'; browser_download_url = 'https://github.com/tingtmu/meowtab/releases/download/v1.2.3/meowtab.zip' }
        [pscustomobject]@{ name = 'SHA256SUMS.txt'; browser_download_url = 'https://github.com/tingtmu/meowtab/releases/download/v1.2.3/SHA256SUMS.txt' }
    )
}
# Mock network boundaries only. Keep real release selection, hashing and ZIP extraction.
function Invoke-RestMethod { $script:apiCalls++; return $fixtureRelease }
function Save-MeowTabAsset([string]$Url, [string]$Path) {
    $script:downloads = @($script:downloads) + $Url
    Copy-Item -LiteralPath $(if ($Url.EndsWith('meowtab.zip')) { $fixtureZip } else { $fixtureSums }) -Destination $Path
}
try {
    Check 'resolve once; both versioned assets stay on selected release; extract valid ZIP' {
        $script:apiCalls = 0; $script:downloads = @()
        $package = Get-MeowTabPackage $testRoot
        Assert $apiCalls 1
        Assert ($downloads -join '|') (($fixtureRelease.assets.browser_download_url) -join '|')
        Assert $package.Tag 'v1.2.3'
        Assert ([IO.File]::ReadAllText((Join-Path $package.Folder 'meowtab.exe'))) 'fixture-v1'
        Assert ([IO.File]::ReadAllText((Join-Path $package.Folder 'images/chill.gif'))) 'fixture-v1'
    }
    Check 'reject prerelease, draft, bad tag, missing/duplicate or mismatched assets' {
        foreach ($bad in @(
            [pscustomobject]@{ draft = $true; prerelease = $false; tag_name = 'v1.2.3'; assets = $fixtureRelease.assets },
            [pscustomobject]@{ draft = $false; prerelease = $true; tag_name = 'v1.2.3'; assets = $fixtureRelease.assets },
            [pscustomobject]@{ draft = $false; prerelease = $false; tag_name = 'bad'; assets = $fixtureRelease.assets },
            [pscustomobject]@{ draft = $false; prerelease = $false; tag_name = 'v9.9.9'; assets = $fixtureRelease.assets },
            [pscustomobject]@{ draft = $false; prerelease = $false; tag_name = 'v1.2.3'; assets = @() },
            [pscustomobject]@{ draft = $false; prerelease = $false; tag_name = 'v1.2.3'; assets = $fixtureRelease.assets + $fixtureRelease.assets }
        )) {
            & { param($fixtureRelease) Reject { Get-MeowTabRelease } 'valid|asset' } $bad
        }
    }
    Check 'missing, duplicate, malformed checksum and mismatched hash fail' {
        foreach ($text in @("$fixtureHash  other.zip", "$fixtureHash  meowtab.zip`n$fixtureHash  meowtab.zip",
            'bad  meowtab.zip', (('0' * 64) + '  meowtab.zip'))) {
            $badSums = Join-Path $testRoot 'bad-sums.txt'
            [IO.File]::WriteAllText($badSums, $text)
            Reject { Test-MeowTabChecksum $fixtureZip $badSums } 'checksum|malformed|mismatch'
        }
    }
    Check 'unsafe, duplicate, Windows-aliased paths and missing payload fail before extraction' {
        $index = 0
        foreach ($path in 'meowtab/../escape', '/absolute', 'C:/absolute', 'meowtab\escape',
            'meowtab/images/../../escape', 'meowtab/meowtab.exe', 'meowtab/MEOWTAB.exe',
            'meowtab/file:stream', 'meowtab/file.', 'meowtab/NUL.txt', 'meowtab/.zip-install.json', 'meowtab//file') {
            $badZip = Join-Path $testRoot ("unsafe-$index.zip"); $index++
            New-FixtureZip $badZip @($path)
            Reject { Test-MeowTabArchive $badZip } 'Unsafe|duplicate'
        }
        $missing = Join-Path $testRoot 'missing.zip'
        New-FixtureZip $missing @() 'meowtab/images/chill_few.png'
        Reject { Test-MeowTabArchive $missing } 'missing'
    }
    Check 'PNG-only published releases are valid; later GIF assets are retained' {
        $pngOnly = Join-Path $testRoot 'png-only.zip'
        New-FixtureZip $pngOnly @() 'meowtab/images/chill.gif'
        Test-MeowTabArchive $pngOnly
        $unpacked = Join-Path $testRoot 'png-only'
        Expand-Archive -LiteralPath $pngOnly -DestinationPath $unpacked
        Assert (Test-Path -LiteralPath (Join-Path $unpacked 'meowtab/images/chill_few.png')) $true
        Assert (Test-Path -LiteralPath (Join-Path $unpacked 'meowtab/images/chill.gif')) $false
    }
    # All install destinations and user data are below the test's unique temp tree.
    $savedLocal = $env:LOCALAPPDATA; $savedAppData = $env:APPDATA
    $env:LOCALAPPDATA = Join-Path $testRoot 'local'; $env:APPDATA = Join-Path $testRoot 'roaming'
    $destination = Join-Path $env:LOCALAPPDATA 'Programs/MeowTab'
    $userData = Join-Path $env:APPDATA 'MeowTab/images'
    New-Item -ItemType Directory -Path $userData -Force | Out-Null
    $sentinel = Join-Path $userData 'custom_few.png'
    [IO.File]::WriteAllText($sentinel, 'user-picture')
    $settings = Join-Path (Split-Path $userData -Parent) 'settings.ini'
    [IO.File]::WriteAllText($settings, '[settings]')
    $script:processes = @(); $script:launches = @(); $script:launchFail = $false
    $script:downloadFail = $false; $script:moveFail = $false
    function Get-MeowTabProcesses { $script:processes }
    function Start-MeowTab([string]$Executable) {
        if ($script:launchFail) { throw 'fixture launch failure' }
        $script:launches = @($script:launches) + $Executable
    }
    function Save-MeowTabAsset([string]$Url, [string]$Path) {
        if ($script:downloadFail) { throw 'fixture download failure' }
        Copy-Item -LiteralPath $(if ($Url.EndsWith('meowtab.zip')) { $fixtureZip } else { $fixtureSums }) -Destination $Path
    }
    function Move-MeowTabFolder([string]$Source, [string]$Target) {
        if ($script:moveFail -and (Split-Path $Source -Leaf) -like '.MeowTab-stage-*') {
            throw 'fixture replacement failure'
        }
        [IO.Directory]::Move($Source, $Target)
    }
    function Preserve {
        Assert ([IO.File]::ReadAllText((Join-Path $destination 'meowtab.exe'))) 'fixture-v1'
        Assert ([IO.File]::ReadAllText($sentinel)) 'user-picture'
        Assert ([IO.File]::ReadAllText($settings)) '[settings]'
    }
    Check 'first installation reports metadata, launches main and preserves user data' {
        Invoke-MeowTabInstall
        Assert $launches.Count 1
        Assert $launches[0] (Join-Path $destination 'meowtab.exe')
        $metadata = Get-Content -LiteralPath (Join-Path $destination '.zip-install.json') -Raw | ConvertFrom-Json
        Assert $metadata.format 'meowtab-zip-v1'; Assert $metadata.tag 'v1.2.3'
        Preserve
    }
    Check 'repeat/update replaces app files and leaves user data and another manual copy alone' {
        $manual = Join-Path $testRoot 'manual-meowtab'; New-Item -ItemType Directory -Path $manual | Out-Null
        [IO.File]::WriteAllText((Join-Path $manual 'meowtab.exe'), 'manual-copy')
        $script:processes = @([pscustomobject]@{ ExecutablePath = (Join-Path $manual 'meowtab.exe') })
        [IO.File]::WriteAllText((Join-Path $destination 'stale.txt'), 'old-app')
        Invoke-MeowTabInstall
        Assert $launches.Count 2; Assert (Test-Path -LiteralPath (Join-Path $destination 'stale.txt')) $false
        Assert ([IO.File]::ReadAllText((Join-Path $manual 'meowtab.exe'))) 'manual-copy'
        Preserve; $script:processes = @()
    }
    Check 'both target executables still running refuse all changes and launches' {
        foreach ($exe in 'meowtab.exe', 'meowtab-classic.exe') {
            $script:processes = @([pscustomobject]@{ ExecutablePath = (Join-Path $destination $exe) })
            Reject { Invoke-MeowTabInstall } 'Exit.*tray'
            Assert $launches.Count 2; Preserve
        }
        $script:processes = @()
    }
    Check 'download, invalid extraction and failed replacement leave old app and user data intact' {
        $script:downloadFail = $true
        Reject { Invoke-MeowTabInstall } 'download failure'; Preserve
        $script:downloadFail = $false
        $script:moveFail = $true
        Reject { Invoke-MeowTabInstall } 'replacement failure'; Preserve
        $script:moveFail = $false
        # An archive with a file as an ancestor passes name checks, but extraction fails.
        $realZip = $fixtureZip; $realSums = $fixtureSums
        $fixtureZip = Join-Path $testRoot 'bad-extraction.zip'
        New-FixtureZip $fixtureZip @('meowtab/images')
        $fixtureSums = Join-Path $testRoot 'bad-extraction-sums.txt'
        [IO.File]::WriteAllText($fixtureSums, ((Get-FileHash $fixtureZip).Hash + '  meowtab.zip'))
        Reject { Invoke-MeowTabInstall } 'failed'; Preserve
        $fixtureZip = $realZip; $fixtureSums = $realSums
        Assert $launches.Count 2
        Assert (@(Get-ChildItem (Split-Path $destination -Parent) -Force | Where-Object Name -like '.MeowTab-*').Count) 0
    }
    Check 'post-install launch failure reports installed path separately' {
        $script:launchFail = $true
        Reject { Invoke-MeowTabInstall } 'installed, but launch failed.*meowtab.exe'
        Assert $launches.Count 2; Preserve
        $script:launchFail = $false
    }
    Check 'nonempty unmanaged destination and invalid ownership metadata are not modified' {
        $marker = Join-Path $destination '.zip-install.json'
        $original = [IO.File]::ReadAllText($marker)
        Remove-Item -LiteralPath $marker
        Reject { Invoke-MeowTabInstall } 'not owned'; Preserve
        foreach ($invalid in '{', '{"format":"other","tag":"v1.2.3"}', '{"format":"meowtab-zip-v1","tag":"bad"}') {
            [IO.File]::WriteAllText($marker, $invalid)
            Reject { Invoke-MeowTabInstall } 'metadata'; Preserve
            Assert ([IO.File]::ReadAllText($marker)) $invalid
        }
        [IO.File]::WriteAllText($marker, $original)
    }
    Check 'cleanup refuses paths outside its allocated boundary' {
        Reject { Remove-MeowTabWorkFolder $userData $testRoot 'meowtab-download-' } 'outside'
        Preserve
    }
    Check 'README and llms commands match, parse and bootstrap the actual local helper' {
        $readme = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../README.md'))
        $guide = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../llms.txt'))
        $command = [regex]::Match($readme, '(?m)^& \(\[scriptblock\].*$').Value.TrimEnd()
        Assert ([regex]::Matches($readme, '(?m)^& \(\[scriptblock\].*$').Count) 1
        Assert ([regex]::Match($guide, '(?m)^& \(\[scriptblock\].*$').Value.TrimEnd()) $command
        $tokens = $null; $parseErrors = $null
        [Management.Automation.Language.Parser]::ParseInput($command, [ref]$tokens, [ref]$parseErrors) | Out-Null
        Assert $parseErrors.Count 0
        function Invoke-WebRequest($Uri, $OutFile, [switch]$UseBasicParsing) {
            if ($OutFile) {
                Copy-Item -LiteralPath $(if ($Uri.EndsWith('meowtab.zip')) { $fixtureZip } else { $fixtureSums }) -Destination $OutFile
            } else {
                Assert $Uri 'https://raw.githubusercontent.com/tingtmu/meowtab/main/tools/install.ps1'
                [pscustomobject]@{ Content = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../tools/install.ps1')) }
            }
        }
        function Get-CimInstance { @() }
        function Start-Process($FilePath, $WorkingDirectory) {
            Assert $WorkingDirectory $destination
            $script:bootstrapLaunched = $FilePath
        }
        & ([scriptblock]::Create($command))
        Assert $bootstrapLaunched (Join-Path $destination 'meowtab.exe')
        Preserve
    }
    Write-Host 'ALL PASSED'
} finally {
    if ($savedLocal) { $env:LOCALAPPDATA = $savedLocal }; if ($savedAppData) { $env:APPDATA = $savedAppData }
    # Only delete our uniquely created temp tree, after verifying its absolute boundary.
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if ($resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path $resolved -Leaf) -like 'meowtab-install-test-*') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
