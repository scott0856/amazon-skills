# setup-skills.ps1
# Link every skill under <repo>\skills into each AI tool's skills dir via Junction.
# Idempotent: safe to re-run after `git pull` to link newly added skills.

param(
  [string]$SkillsSource = (Join-Path $PSScriptRoot 'skills'),
  [switch]$IncludeTrae,
  [string]$TraeProjectsRoot
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SkillsSource)) {
  Write-Error "Skills source not found: $SkillsSource"
  exit 1
}

function Link-Skills {
  param([string]$DestRoot, $Skills, [string]$Label)
  if (-not (Test-Path -LiteralPath $DestRoot)) {
    New-Item -ItemType Directory -Path $DestRoot -Force | Out-Null
  }
  Write-Host "== $Label -> $DestRoot"
  foreach ($s in $Skills) {
    $dest = Join-Path $DestRoot $s.Name
    if (Test-Path -LiteralPath $dest) {
      $item = Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
      if ($item.LinkType -eq 'Junction') {
        Write-Host "  [kept] $($s.Name)"
      } else {
        Write-Host "  [skip] $($s.Name) (existing non-link folder, remove it first)"
      }
      continue
    }
    New-Item -ItemType Junction -Path $dest -Target $s.FullName | Out-Null
    Write-Host "  [link] $($s.Name)"
  }
}

$skills = Get-ChildItem -LiteralPath $SkillsSource -Directory | Where-Object { $_.Name -notlike '.*' } | Sort-Object Name
if (-not $skills) {
  Write-Host "No skills found under $SkillsSource"
  exit 0
}
Write-Host "Found $($skills.Count) skill(s): $($skills.Name -join ', ')"

$tools = @(
  @{ Label = 'Codex';  Dir = Join-Path $HOME '.codex\skills' },
  @{ Label = 'Claude'; Dir = Join-Path $HOME '.claude\skills' },
  @{ Label = 'Cursor'; Dir = Join-Path $HOME '.cursor\skills' }
)
foreach ($t in $tools) {
  Link-Skills -DestRoot $t.Dir -Skills $skills -Label $t.Label
}

if ($IncludeTrae) {
  $base = if ($TraeProjectsRoot) { $TraeProjectsRoot }
          else { Join-Path $env:APPDATA 'TRAE SOLO CN\ModularData\ai-agent\work-mode-projects' }
  if (Test-Path -LiteralPath $base) {
    Get-ChildItem -LiteralPath $base -Directory | ForEach-Object {
      Link-Skills -DestRoot (Join-Path $_.FullName '.trae\skills') -Skills $skills -Label ("TRAE:" + $_.Name)
    }
  } else {
    Write-Warning "TRAE projects root not found: $base"
  }
}

Write-Host "Done."