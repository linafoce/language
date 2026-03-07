[CmdletBinding()]
param(
    [string]$TaskName = "NotebookAutoSync",
    [string]$RepoPath = "",
    [int]$DebounceSeconds = 15
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

$currentUser = "$env:USERDOMAIN\$env:USERNAME"

$actionArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$autoSyncScript`"",
    "-RepoPath", "`"$RepoPath`"",
    "-DebounceSeconds", $DebounceSeconds
) -join " "

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $actionArgs
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
$principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Limited

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description "Auto sync markdown notes to git on login." `
    -Force | Out-Null

Write-Host "Scheduled task '$TaskName' installed for $currentUser."
