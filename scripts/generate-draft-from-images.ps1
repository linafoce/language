param(
  [Parameter(Mandatory = $true)]
  [string]$Folder,
  [string]$Topic
)

$scriptPath = Join-Path $PSScriptRoot "generate_draft_from_images.py"
$args = @($scriptPath, $Folder)
if ($Topic) {
  $args += @("--topic", $Topic)
}

python @args
exit $LASTEXITCODE
