<#
.SYNOPSIS
    Install or update the latest published MeowTab ZIP for the current user.
.DESCRIPTION
    Requires Windows 11 x64 and Windows PowerShell 5.1 or PowerShell 7. No
    administrator rights, AutoHotkey or package manager is needed. Exit MeowTab
    from its tray menu before rerunning. Installs in LOCALAPPDATA\Programs\MeowTab
    and starts meowtab.exe; never changes APPDATA\MeowTab settings or pictures.
    The ZIP and SHA256SUMS.txt are selected from one release and checked before
    extraction. Only installations with this helper's metadata can be replaced.
.EXAMPLE
    & .\tools\install.ps1
    Run a downloaded copy after reviewing its source, or use the README one-liner.
#>
$ErrorActionPreference = 'Stop'

function Get-MeowTabRelease {
    $release = Invoke-RestMethod 'https://api.github.com/repos/tingtmu/meowtab/releases/latest' `
        -Headers @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'MeowTab-installer' }
    if ($release.draft -isnot [bool] -or $release.prerelease -isnot [bool] -or
        $release.draft -or $release.prerelease -or $release.tag_name -isnot [string] -or
        $release.tag_name -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?$') {
        throw 'GitHub did not return a valid published MeowTab release.'
    }
    $assets = foreach ($name in 'meowtab.zip', 'SHA256SUMS.txt') {
        $matches = @($release.assets | Where-Object { $_.name -ceq $name })
        $expected = 'https://github.com/tingtmu/meowtab/releases/download/{0}/{1}' -f $release.tag_name, $name
        if ($matches.Count -ne 1 -or $matches[0].browser_download_url -cne $expected) {
            throw "The selected release has no single valid $name asset."
        }
        [pscustomobject]@{ Name = $name; Url = $expected }
    }
    [pscustomobject]@{ Tag = $release.tag_name; Assets = @($assets) }
}

function Save-MeowTabAsset([string]$Url, [string]$Path) {
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Path
}

function Test-MeowTabChecksum([string]$ZipPath, [string]$SumsPath) {
    $entries = foreach ($line in Get-Content -LiteralPath $SumsPath) {
        if (-not $line.Trim()) { continue }
        if ($line -notmatch '^([0-9a-fA-F]{64}) [ *](\S.*)$') {
            throw 'SHA256SUMS.txt contains a malformed checksum entry.'
        }
        [pscustomobject]@{ Hash = $Matches[1]; Path = $Matches[2] }
    }
    $zipSums = @($entries | Where-Object { $_.Path -ceq 'meowtab.zip' })
    if ($zipSums.Count -ne 1) { throw 'SHA256SUMS.txt must contain exactly one meowtab.zip checksum.' }
    if ((Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash -ne $zipSums[0].Hash) {
        throw 'meowtab.zip SHA-256 mismatch. Nothing from this download will be installed.'
    }
}

function Test-MeowTabArchive([string]$ZipPath) {
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $names = foreach ($entry in $zip.Entries) {
            $name = $entry.FullName
            $parts = $name.TrimEnd('/').Split('/')
            if ($parts[0] -cne 'meowtab' -or $parts.Count -lt 1 -or
                ($parts.Count -eq 1 -and $name -cne 'meowtab/') -or
                @($parts | Where-Object { $_ -match '^[.]?$|^[.][.]$|[<>:"\\|?*\x00-\x1f]|[. ]$|^(?i:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:[.]|$)' }).Count -gt 0 -or
                $name -ieq 'meowtab/.zip-install.json' -or
                (($entry.ExternalAttributes -shr 16) -band 0xf000) -eq 0xa000) {
                throw "Unsafe ZIP entry: $name"
            }
            $name.TrimEnd('/').ToLowerInvariant()
        }
        if ($names | Group-Object | Where-Object { $_.Count -gt 1 }) {
            throw 'The ZIP contains duplicate paths.'
        }
        foreach ($required in 'meowtab.exe', 'meowtab-classic.exe', 'images/chill_few.png',
            'images/chill_some.png', 'images/chill_many.png', 'README.md', 'LICENSE') {
            $found = @($zip.Entries | Where-Object { $_.FullName -ceq "meowtab/$required" -and $_.Length -gt 0 })
            if ($found.Count -ne 1) { throw "The ZIP is missing the required file $required." }
        }
    } finally { $zip.Dispose() }
}

function Get-MeowTabPackage([string]$Workspace) {
    $release = Get-MeowTabRelease
    foreach ($asset in $release.Assets) {
        Save-MeowTabAsset $asset.Url (Join-Path $Workspace $asset.Name)
    }
    $zip = Join-Path $Workspace 'meowtab.zip'
    Test-MeowTabChecksum $zip (Join-Path $Workspace 'SHA256SUMS.txt')
    Test-MeowTabArchive $zip
    Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $Workspace 'unpacked')
    [pscustomobject]@{ Tag = $release.Tag; Folder = (Join-Path $Workspace 'unpacked/meowtab') }
}

function Assert-MeowTabPlainPath([string]$Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing a linked installation path: $current"
            }
        }
        $current = Split-Path $current -Parent
    }
}

function Assert-MeowTabDestination([string]$Destination) {
    Assert-MeowTabPlainPath $Destination
    if (-not (Test-Path -LiteralPath $Destination)) { return }
    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
        throw "The installation destination is occupied: $Destination"
    }
    $items = @(Get-ChildItem -LiteralPath $Destination -Force -Recurse)
    if ($items | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) {
        throw "Refusing linked files in the installation: $Destination"
    }
    if (-not $items.Count) { return }
    $marker = Join-Path $Destination '.zip-install.json'
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) {
        throw "The destination is not owned by this ZIP installer: $Destination. Keep using its existing installation method."
    }
    try { $metadata = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json } catch {
        throw "Cannot read ZIP installer ownership metadata in $Destination`: $($_.Exception.Message)"
    }
    if ($metadata.format -cne 'meowtab-zip-v1' -or $metadata.tag -isnot [string] -or
        $metadata.tag -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?$') {
        throw "Invalid ZIP installer ownership metadata in $Destination."
    }
}

function Get-MeowTabProcesses {
    Get-CimInstance Win32_Process -Filter "Name = 'meowtab.exe' OR Name = 'meowtab-classic.exe'"
}

function Assert-MeowTabStopped([string]$Destination) {
    $targets = @((Join-Path $Destination 'meowtab.exe'), (Join-Path $Destination 'meowtab-classic.exe'))
    foreach ($process in Get-MeowTabProcesses) {
        if (-not $process.ExecutablePath) {
            throw 'Cannot check a running MeowTab process. Exit MeowTab from its tray menu, then rerun this command.'
        }
        if ($targets -icontains $process.ExecutablePath) {
            throw 'MeowTab is running in the installation folder. Exit from its tray menu, then rerun this command.'
        }
    }
}

# Cleanup only unique paths allocated by this invocation, never the destination or user data.
function Remove-MeowTabWorkFolder([string]$Path, [string]$Parent, [string]$Prefix) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $full = [IO.Path]::GetFullPath($Path)
    $expectedParent = [IO.Path]::GetFullPath($Parent).TrimEnd('\', '/')
    if ((Split-Path $full -Parent).TrimEnd('\', '/') -ine $expectedParent -or
        (Split-Path $full -Leaf) -notmatch ('^' + [regex]::Escape($Prefix) + '[0-9a-f]{32}$')) {
        throw "Refusing cleanup outside the installer workspace: $full"
    }
    Assert-MeowTabPlainPath $full
    if (Get-ChildItem -LiteralPath $full -Force -Recurse | Where-Object {
        $_.Attributes -band [IO.FileAttributes]::ReparsePoint
    }) { throw "Refusing cleanup of linked files: $full" }
    Remove-Item -LiteralPath $full -Recurse -Force
}

function Move-MeowTabFolder([string]$Source, [string]$Target) {
    [IO.Directory]::Move($Source, $Target)
}

function Set-MeowTabInstallation([string]$Stage, [string]$Destination, [string]$Backup) {
    Assert-MeowTabDestination $Destination
    Assert-MeowTabStopped $Destination
    $hadPrevious = Test-Path -LiteralPath $Destination
    if ($hadPrevious) { Move-MeowTabFolder $Destination $Backup }
    try { Move-MeowTabFolder $Stage $Destination } catch {
        $failure = $_.Exception.Message
        if ($hadPrevious) {
            try { Move-MeowTabFolder $Backup $Destination } catch {
                throw "Replacement failed ($failure). Restore the previous app from $Backup. Rollback failed: $($_.Exception.Message)"
            }
        }
        throw "Replacement failed; the previous installation is unchanged: $failure"
    }
}

function Start-MeowTab([string]$Executable) {
    Start-Process -FilePath $Executable -WorkingDirectory (Split-Path $Executable -Parent) | Out-Null
}

function Invoke-MeowTabInstall {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
        -not [Environment]::Is64BitOperatingSystem -or -not $env:LOCALAPPDATA -or
        -not [IO.Path]::IsPathRooted($env:LOCALAPPDATA)) {
        throw 'MeowTab needs 64-bit Windows with a valid LOCALAPPDATA folder.'
    }
    $parent = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs'))
    $destination = Join-Path $parent 'MeowTab'
    Assert-MeowTabDestination $destination
    Assert-MeowTabStopped $destination
    $token = [guid]::NewGuid().ToString('N')
    $tempParent = [IO.Path]::GetTempPath()
    $workspace = Join-Path $tempParent ('meowtab-download-' + $token)
    $stage = Join-Path $parent ('.MeowTab-stage-' + $token)
    $backup = Join-Path $parent ('.MeowTab-backup-' + $token)
    try {
        New-Item -ItemType Directory -Path $workspace | Out-Null
        $package = Get-MeowTabPackage $workspace
        Assert-MeowTabPlainPath $parent
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        Copy-Item -LiteralPath $package.Folder -Destination $stage -Recurse
        $metadata = [ordered]@{ format = 'meowtab-zip-v1'; tag = $package.Tag } | ConvertTo-Json
        [IO.File]::WriteAllText((Join-Path $stage '.zip-install.json'), $metadata, (New-Object Text.UTF8Encoding $false))
        Set-MeowTabInstallation $stage $destination $backup
        # A backup left by failed rollback is intentionally retained for recovery.
        try { Remove-MeowTabWorkFolder $backup $parent '.MeowTab-backup-' } catch {
            Write-Warning "Installed successfully, but the previous app backup remains at $backup`: $($_.Exception.Message)"
        }
    } catch {
        throw "MeowTab installation failed: $($_.Exception.Message)"
    } finally {
        foreach ($folder in @(
            @{ Path = $workspace; Parent = $tempParent; Prefix = 'meowtab-download-' },
            @{ Path = $stage; Parent = $parent; Prefix = '.MeowTab-stage-' }
        )) {
            try { Remove-MeowTabWorkFolder $folder.Path $folder.Parent $folder.Prefix } catch {
                Write-Warning "Installer cleanup failed for $($folder.Path): $($_.Exception.Message)"
            }
        }
    }
    $executable = Join-Path $destination 'meowtab.exe'
    Write-Host "Installed MeowTab $($package.Tag) in $destination"
    try { Start-MeowTab $executable } catch {
        throw "MeowTab was installed, but launch failed: $($_.Exception.Message). Start it manually: $executable"
    }
    Write-Host "Started $executable"
}

# Dot-source for offline checks; a file invocation or the README scriptblock runs the installer.
if ($MyInvocation.InvocationName -ne '.') { Invoke-MeowTabInstall }
