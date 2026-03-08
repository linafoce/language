[CmdletBinding()]
param(
    [string]$RepoPath = "",
    [int]$DebounceSeconds = 15,
    [int]$SyncIntervalSeconds = 120,
    [string[]]$WatchFolders = @("inbox", "courses", "topics"),
    [string]$LogFile = "",
    [switch]$RunOnce
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = (Resolve-Path (Join-Path $scriptRoot "..")).Path
} else {
    $RepoPath = (Resolve-Path $RepoPath).Path
}

if ([string]::IsNullOrWhiteSpace($LogFile)) {
    $LogFile = Join-Path $RepoPath "logs\auto-sync.log"
}

$logDirectory = Split-Path -Parent $LogFile
if (-not (Test-Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
}

$script:IsSyncing = $false

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

function Invoke-Git {
    param(
        [string[]]$GitArgs,
        [switch]$AllowFail
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & git -C $RepoPath @GitArgs 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $text = ($output | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $_.Exception.Message
            } else {
                $_.ToString()
            }
        }) -join "`n"

    if ($exitCode -ne 0 -and -not $AllowFail) {
        throw "git $($GitArgs -join ' ') failed with exit code $exitCode. $text"
    }

    [PSCustomObject]@{
        ExitCode = $exitCode
        Output   = $text
    }
}

function Test-GitRepository {
    $gitCheck = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCheck) {
        Write-Log -Level "ERROR" -Message "Git is not installed or not in PATH."
        return $false
    }

    if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
        Write-Log -Level "ERROR" -Message "Path '$RepoPath' is not a Git repository."
        return $false
    }

    $insideRepo = Invoke-Git -GitArgs @("rev-parse", "--is-inside-work-tree") -AllowFail
    if ($insideRepo.ExitCode -ne 0) {
        Write-Log -Level "ERROR" -Message "Path '$RepoPath' is not a Git repository."
        return $false
    }

    return $true
}

function Get-CurrentBranch {
    $symbolic = Invoke-Git -GitArgs @("symbolic-ref", "--short", "HEAD") -AllowFail
    if ($symbolic.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($symbolic.Output)) {
        return $symbolic.Output.Trim()
    }

    $result = Invoke-Git -GitArgs @("rev-parse", "--abbrev-ref", "HEAD") -AllowFail
    if ($result.ExitCode -ne 0) {
        return ""
    }

    return $result.Output.Trim()
}

function Test-HasOrigin {
    $result = Invoke-Git -GitArgs @("remote", "get-url", "origin") -AllowFail
    return $result.ExitCode -eq 0
}

function Test-HasUpstream {
    $result = Invoke-Git -GitArgs @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}") -AllowFail
    return $result.ExitCode -eq 0
}

function Test-WorkingTreeClean {
    $result = Invoke-Git -GitArgs @("status", "--porcelain") -AllowFail
    if ($result.ExitCode -ne 0) {
        return $false
    }
    return [string]::IsNullOrWhiteSpace($result.Output)
}

function Get-AheadCount {
    if (-not (Test-HasUpstream)) {
        return 0
    }

    $result = Invoke-Git -GitArgs @("rev-list", "--count", "@{u}..HEAD") -AllowFail
    if ($result.ExitCode -ne 0) {
        return 0
    }

    $count = 0
    if ([int]::TryParse($result.Output.Trim(), [ref]$count)) {
        return $count
    }

    return 0
}

function Invoke-PullOnly {
    if ($script:IsSyncing) {
        return
    }

    $script:IsSyncing = $true
    try {
        if (-not (Test-GitRepository)) {
            return
        }

        $branch = Get-CurrentBranch
        if ([string]::IsNullOrWhiteSpace($branch)) {
            return
        }

        if (-not (Test-HasOrigin)) {
            return
        }

        if (-not (Test-HasUpstream)) {
            return
        }

        if (-not (Test-WorkingTreeClean)) {
            Write-Log -Message "Periodic pull skipped because local workspace has uncommitted changes."
            return
        }

        $pull = Invoke-Git -GitArgs @("pull", "--rebase") -AllowFail
        if ($pull.ExitCode -ne 0) {
            Write-Log -Level "ERROR" -Message "Periodic pull --rebase failed. $($pull.Output)"
            return
        }

        $pullOut = $pull.Output.Trim()
        if (-not [string]::IsNullOrWhiteSpace($pullOut) -and
            $pullOut -notmatch "Already up[ -]to[ -]date" -and
            $pullOut -notmatch "up to date") {
            Write-Log -Message "Periodic pull applied updates."
        }
    } finally {
        $script:IsSyncing = $false
    }
}

function Invoke-Sync {
    if ($script:IsSyncing) {
        Write-Log -Level "WARN" -Message "A sync is already running; skipping this trigger."
        return
    }

    $script:IsSyncing = $true

    try {
        if (-not (Test-GitRepository)) {
            return
        }

        $branch = Get-CurrentBranch
        if ([string]::IsNullOrWhiteSpace($branch)) {
            Write-Log -Level "ERROR" -Message "Branch not found. Sync stopped."
            return
        }

        Invoke-Git -GitArgs @("add", "-A") | Out-Null

        $staged = Invoke-Git -GitArgs @("diff", "--cached", "--name-only") -AllowFail
        if ($staged.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($staged.Output)) {
            $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
            $commit = Invoke-Git -GitArgs @("commit", "-m", "notes: auto-sync $stamp") -AllowFail
            if ($commit.ExitCode -ne 0) {
                Write-Log -Level "ERROR" -Message "Commit failed. $($commit.Output)"
                return
            }

            Write-Log -Message "Commit created on '$branch'."
        } else {
            Write-Log -Message "No new staged changes."
        }

        if (-not (Test-HasOrigin)) {
            Write-Log -Level "WARN" -Message "Remote 'origin' not configured. Skipping pull/push."
            return
        }

        $hasUpstream = Test-HasUpstream
        if ($hasUpstream) {
            $pull = Invoke-Git -GitArgs @("pull", "--rebase") -AllowFail
            if ($pull.ExitCode -ne 0) {
                Write-Log -Level "ERROR" -Message "git pull --rebase failed. Resolve conflicts manually, then continue. $($pull.Output)"
                return
            }

            Write-Log -Message "Pull --rebase succeeded."
        } else {
            Write-Log -Level "WARN" -Message "Upstream missing for '$branch'. First push will set upstream."
        }

        $ahead = Get-AheadCount
        if ($ahead -gt 0 -or -not $hasUpstream) {
            if ($hasUpstream) {
                $push = Invoke-Git -GitArgs @("push") -AllowFail
            } else {
                $push = Invoke-Git -GitArgs @("push", "-u", "origin", $branch) -AllowFail
            }

            if ($push.ExitCode -ne 0) {
                Write-Log -Level "ERROR" -Message "Push failed. Local commits are kept and will retry on next change. $($push.Output)"
                return
            }

            Write-Log -Message "Push succeeded."
        } else {
            Write-Log -Message "No commits to push."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Sync error: $($_.Exception.Message)"
    } finally {
        $script:IsSyncing = $false
    }
}

function Register-Watchers {
    $watchers = @()

    foreach ($folder in $WatchFolders) {
        $path = Join-Path $RepoPath $folder
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $path
        $watcher.Filter = "*.md"
        $watcher.IncludeSubdirectories = $true
        $watcher.NotifyFilter = [System.IO.NotifyFilters]"FileName, DirectoryName, LastWrite, CreationTime, Size"
        $watcher.EnableRaisingEvents = $true

        $watchers += $watcher

        foreach ($eventName in @("Created", "Changed", "Deleted", "Renamed")) {
            $sourceId = "AutoSync.$folder.$eventName"
            Register-ObjectEvent -InputObject $watcher -EventName $eventName -SourceIdentifier $sourceId | Out-Null
        }
    }

    return $watchers
}

if ($RunOnce) {
    Invoke-Sync
    exit 0
}

Write-Log -Message "Auto sync started. Repo='$RepoPath', debounce=${DebounceSeconds}s."
Write-Log -Message "Periodic pull interval: ${SyncIntervalSeconds}s."
$registeredWatchers = Register-Watchers
Write-Log -Message ("Watching folders: {0}" -f ($WatchFolders -join ", "))

$lastChange = $null
$lastPeriodicPull = Get-Date

try {
    while ($true) {
        $event = Wait-Event -Timeout 1
        if ($null -ne $event) {
            if ($event.SourceIdentifier -like "AutoSync.*") {
                $path = ""
                if ($null -ne $event.SourceEventArgs) {
                    if ($event.SourceEventArgs.PSObject.Properties.Name -contains "FullPath") {
                        $path = $event.SourceEventArgs.FullPath
                    }
                }

                if ([string]::IsNullOrWhiteSpace($path)) {
                    $path = "(unknown)"
                }

                Write-Log -Message ("Detected file change: {0}" -f $path)
                $lastChange = Get-Date
            }

            Remove-Event -EventIdentifier $event.EventIdentifier -ErrorAction SilentlyContinue
        }

        if ($null -ne $lastChange) {
            $elapsed = (Get-Date) - $lastChange
            if ($elapsed.TotalSeconds -ge $DebounceSeconds) {
                Invoke-Sync
                $lastChange = $null
                $lastPeriodicPull = Get-Date
            }
        }

        if ($SyncIntervalSeconds -gt 0 -and $null -eq $lastChange) {
            $intervalElapsed = (Get-Date) - $lastPeriodicPull
            if ($intervalElapsed.TotalSeconds -ge $SyncIntervalSeconds) {
                Invoke-PullOnly
                $lastPeriodicPull = Get-Date
            }
        }
    }
} finally {
    Write-Log -Message "Shutting down auto sync watcher."

    Get-EventSubscriber |
        Where-Object { $_.SourceIdentifier -like "AutoSync.*" } |
        Unregister-Event

    foreach ($watcher in $registeredWatchers) {
        $watcher.EnableRaisingEvents = $false
        $watcher.Dispose()
    }
}
