param(
  [Parameter(Mandatory = $true)]
  [string]$DraftFile,
  [Parameter(Mandatory = $true)]
  [string]$TargetFile,
  [switch]$DeleteDraft
)

$scriptPath = Join-Path $PSScriptRoot "merge_draft.py"
$args = @($scriptPath, $DraftFile, $TargetFile)
if ($DeleteDraft) {
  $args += "--delete-draft"
}

python @args
exit $LASTEXITCODE
