$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repoRoot ".claude\skill"
$destRoot = Join-Path $HOME ".codex\skills"
$validator = Join-Path $destRoot ".system\skill-creator\scripts\quick_validate.py"
$python = if (Get-Command python -ErrorAction SilentlyContinue) { "python" } else { "py" }

if (-not (Test-Path $sourceRoot)) {
    throw "Skill source directory not found: $sourceRoot"
}

New-Item -ItemType Directory -Force $destRoot | Out-Null

$skills = Get-ChildItem -Path $sourceRoot -Directory | Sort-Object Name
if (-not $skills) {
    Write-Host "No skills found under $sourceRoot"
    exit 0
}

foreach ($skill in $skills) {
    $skillMd = Join-Path $skill.FullName "SKILL.md"
    if (-not (Test-Path $skillMd)) {
        Write-Warning "Skip $($skill.Name): missing SKILL.md"
        continue
    }

    if (Test-Path $validator) {
        $env:PYTHONUTF8 = "1"
        & $python $validator $skill.FullName
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Skip $($skill.Name): validation failed"
            continue
        }
    }

    $destDir = Join-Path $destRoot $skill.Name
    if (Test-Path $destDir) {
        Remove-Item -Recurse -Force $destDir
    }

    Copy-Item -Recurse -Force $skill.FullName $destDir
    Write-Host "Synced $($skill.Name) -> $destDir"
}
