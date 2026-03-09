[CmdletBinding()]
param(
    [string]$RepoPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = (Resolve-Path (Join-Path $scriptRoot "..\..")).Path
} else {
    $RepoPath = (Resolve-Path $RepoPath).Path
}

$repo = $RepoPath
$escapedRepo = [Regex]::Escape($repo)
$autoSyncScript = (Resolve-Path (Join-Path $scriptRoot "auto-sync.ps1")).Path
$escapedScript = [Regex]::Escape($autoSyncScript)

$targets = Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq "powershell.exe" -and
        $_.CommandLine -match $escapedScript -and
        $_.CommandLine -match $escapedRepo
    }

if (-not $targets) {
    Write-Host "No auto sync process found for $repo"
    exit 0
}

$targetList = @($targets)
foreach ($proc in $targetList) {
    Stop-Process -Id $proc.ProcessId -Force
}

Write-Host "Stopped $($targetList.Count) auto sync process(es) for $repo"
