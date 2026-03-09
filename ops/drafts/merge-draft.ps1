param(
  [Parameter(Mandatory = $true)]
  [string]$DraftFile,
  [Parameter(Mandatory = $true)]
  [string]$TargetFile,
  [switch]$DeleteDraft
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$scriptPath = Join-Path $repoRoot "tools\drafts\merge_draft.py"
$args = @($scriptPath, $DraftFile, $TargetFile)
if ($DeleteDraft) {
  $args += "--delete-draft"
}

python @args
exit $LASTEXITCODE
