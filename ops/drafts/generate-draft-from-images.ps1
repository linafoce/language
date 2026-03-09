param(
  [Parameter(Mandatory = $true)]
  [string]$Folder,
  [string]$Topic
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$scriptPath = Join-Path $repoRoot "tools\drafts\generate_draft_from_images.py"
$args = @($scriptPath, $Folder)
if ($Topic) {
  $args += @("--topic", $Topic)
}

python @args
exit $LASTEXITCODE
