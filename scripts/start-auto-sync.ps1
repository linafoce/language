[CmdletBinding()]
param(
    [string]$RepoPath = "",
    [int]$DebounceSeconds = 15,
    [int]$SyncIntervalSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = (Resolve-Path (Join-Path $scriptRoot "..")).Path
} else {
    $RepoPath = (Resolve-Path $RepoPath).Path
}

$autoSyncScript = Join-Path $scriptRoot "auto-sync.ps1"
if (-not (Test-Path $autoSyncScript)) {
    throw "Cannot find $autoSyncScript"
}

$escapedRepo = [Regex]::Escape($RepoPath)

$running = Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq "powershell.exe" -and
        $_.CommandLine -match "auto-sync\.ps1" -and
        $_.CommandLine -match $escapedRepo
    }

if ($running) {
    Write-Host "Auto sync is already running for $RepoPath"
    exit 0
}

$arguments = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$autoSyncScript`"",
    "-RepoPath", "`"$RepoPath`"",
    "-DebounceSeconds", $DebounceSeconds,
    "-SyncIntervalSeconds", $SyncIntervalSeconds
)

Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle Hidden | Out-Null
Write-Host "Auto sync started in background for $RepoPath"
