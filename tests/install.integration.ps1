<#
.SYNOPSIS
    Exercise the latest published ZIP without touching the current user's MeowTab data.
.DESCRIPTION
    Opt-in network/desktop check. Run separately from offline tests in either PowerShell.
    Uses the released EXE's own embedded script (#1) with a prelude setting the existing
    DATA_DIR test seam. No installed AutoHotkey, rebuilding, or release-binary edits.
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../tools/install.ps1')
$integrationRoot = Join-Path ([IO.Path]::GetTempPath()) ('meowtab-live-test-' + [guid]::NewGuid().ToString('N'))
$savedLocal = $env:LOCALAPPDATA
$realData = Join-Path $env:APPDATA 'MeowTab'
$initialProcesses = @(Get-MeowTabProcesses | Select-Object -ExpandProperty ProcessId)

function DataSnapshot([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '<absent>' }
    (Get-ChildItem -LiteralPath $Path -Recurse -Force -File | Sort-Object FullName | ForEach-Object {
        $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash
    }) -join "`n"
}
function Require($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$realBefore = DataSnapshot $realData
try {
    New-Item -ItemType Directory -Path $integrationRoot | Out-Null
    $env:LOCALAPPDATA = Join-Path $integrationRoot 'local'
    $destination = Join-Path $env:LOCALAPPDATA 'Programs/MeowTab'
    $testData = Join-Path $integrationRoot 'user-data'
    $desktop = Join-Path $integrationRoot 'desktop'
    $startup = Join-Path $integrationRoot 'startup'
    New-Item -ItemType Directory -Path $testData,$desktop,$startup | Out-Null
    [IO.File]::WriteAllText((Join-Path $testData 'settings.ini'), "[state]`nwelcomed=1`n")
    $prelude = Join-Path $integrationRoot 'isolate.ahk'
    $record = Join-Path $integrationRoot 'app-check.txt'
    $output = Join-Path $integrationRoot 'app-errors.txt'
    $preludeSource = @'
#SingleInstance Off
DATA_DIR := "__DATA__"
STARTUP_DIR := "__STARTUP__"
OnError((e, *) => (FileAppend("ERROR: " e.Message, "__RECORD__"), ExitApp(3)))
SetTimer(InstallerLiveCheck, -500)
InstallerLiveCheck() {
    global DESKTOP_DIR := "__DESKTOP__"
    if DataDir() != "__DATA__" || !A_IsCompiled || A_ScriptDir != "__APP__"
        throw Error("Release script isolation or compiled app path failed")
    SettingsOpen()
    for c in pnl.cards {
        if !c.thumb || !c.big || !FileExist(c.file)
            throw Error("Picture did not load: " c.file)
        if !InStr(c.file, "__APP__\images\") && !InStr(c.file, "__DATA__\images\")
            throw Error("Picture came from outside isolated app/data")
    }
    if IMG_PREFIX = "custom" && (FONT_SIZE != 14 || pnl.cards[1].file != "__DATA__\images\custom_few.png")
        throw Error("Updated installation did not reuse settings and custom picture")
    FileAppend("PASS compiled release loaded settings and pictures: " IMG_PREFIX, "__RECORD__")
    PanelClose()
    ExitApp(0)
}
'@
    $preludeSource = $preludeSource.Replace('__DATA__', $testData).Replace('__DESKTOP__', $desktop).Replace('__STARTUP__', $startup).Replace('__APP__', $destination).Replace('__RECORD__', $record)
    [IO.File]::WriteAllText($prelude, $preludeSource, (New-Object Text.UTF8Encoding $false))
    function Start-MeowTab([string]$Executable) {
        # Test-only launch boundary executes the original embedded release script.
        $script:testProcess = Start-Process -FilePath $Executable -ArgumentList @('/script', '/ErrorStdOut', '/include', ('"' + $prelude + '"'), '*#1') `
            -WorkingDirectory (Split-Path $Executable -Parent) -WindowStyle Hidden -PassThru -RedirectStandardOutput $output
        # Retain the process handle so Windows PowerShell can read its exit code later.
        $null = $script:testProcess.Handle
    }
    function Await-AppCheck {
        Require ($script:testProcess.WaitForExit(20000)) 'Released app did not complete its isolated check in 20 seconds.'
        $diagnostic = if (Test-Path -LiteralPath $record) { [IO.File]::ReadAllText($record) } else { [IO.File]::ReadAllText($output) }
        Require ($script:testProcess.ExitCode -eq 0) ("Released app failed (exit $($script:testProcess.ExitCode)): " + $diagnostic)
        Require (Test-Path -LiteralPath $record) 'Released app produced no picture/settings verification.'
        $result = [IO.File]::ReadAllText($record)
        Require ($result.StartsWith('PASS')) $result
        Write-Host $result
    }
    Invoke-MeowTabInstall
    Await-AppCheck
    $metadata = Get-Content -LiteralPath (Join-Path $destination '.zip-install.json') -Raw | ConvertFrom-Json
    $version = (Get-Item -LiteralPath (Join-Path $destination 'meowtab.exe')).VersionInfo.FileVersion
    Require ($metadata.tag -eq ('v' + $version)) "Installed release $($metadata.tag) differs from EXE version $version."
    Write-Host "PASS reported release $($metadata.tag) matches EXE version $version"

    New-Item -ItemType Directory -Path (Join-Path $testData 'images') | Out-Null
    foreach ($mood in 'few', 'some', 'many') {
        Copy-Item -LiteralPath (Join-Path $destination "images/chill_$mood.png") -Destination (Join-Path $testData "images/custom_$mood.png")
    }
    [IO.File]::WriteAllText((Join-Path $testData 'settings.ini'), "[settings]`nFONT_SIZE=14`nIMG_PREFIX=custom`n[state]`nwelcomed=1`n")
    $testBefore = DataSnapshot $testData
    Remove-Item -LiteralPath $record
    Invoke-MeowTabInstall
    Await-AppCheck
    Require ((DataSnapshot $testData) -ceq $testBefore) 'Test settings or custom pictures changed during update.'
    $fullDestination = [IO.Path]::GetFullPath($destination)
    Require ($fullDestination.StartsWith($integrationRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Removal escaped the test root.'
    Remove-Item -LiteralPath $fullDestination -Recurse -Force
    Require ((DataSnapshot $testData) -ceq $testBefore) 'Removal changed test user data.'
    Require ((DataSnapshot $realData) -ceq $realBefore) 'Real user data changed during integration.'
    $remainingIds = @(Get-MeowTabProcesses | Select-Object -ExpandProperty ProcessId)
    foreach ($id in $initialProcesses) { Require ($remainingIds -contains $id) "Existing app process $id disappeared during integration." }
    Write-Host 'PASS install, pictures, exit, settings/custom picture update, repeat install and removal; real data and existing processes unchanged'
} finally {
    $env:LOCALAPPDATA = $savedLocal
    if ($script:testProcess -and -not $script:testProcess.HasExited) {
        # Only our exact child process, never an existing installation.
        $script:testProcess.Kill(); $script:testProcess.WaitForExit(5000) | Out-Null
    }
    if (Test-Path -LiteralPath $integrationRoot) {
        $full = [IO.Path]::GetFullPath($integrationRoot)
        Require ((Split-Path $full -Parent).TrimEnd('\') -ieq ([IO.Path]::GetTempPath()).TrimEnd('\')) 'Cleanup escaped Temp.'
        Require ((Split-Path $full -Leaf) -match '^meowtab-live-test-[0-9a-f]{32}$') 'Cleanup root is not our allocated test tree.'
        Remove-Item -LiteralPath $full -Recurse -Force
    }
}
