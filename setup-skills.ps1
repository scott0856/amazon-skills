# setup-skills.ps1
# Link all skills from configured repos into each AI tool's skills dir via Junction.
# Supports two repo layouts:
#   multi  : each subfolder under <repo>\skills\ is one skill
#   single : the repo root itself is one skill (SKILL.md at root)
# Idempotent: safe to re-run after `git pull` to link newly added skills.

param(
  [switch]$IncludeTrae,
  [string]$TraeProjectsRoot
)

$ErrorActionPreference = 'Stop'

# ===== Repos to sync (paths are relative to $HOME) =====
$repos = @(
  @{ Path = (Join-Path $HOME 'amazon-skills');         Type = 'multi'  },
  @{ Path = (Join-Path $HOME 'amazon-listing-doctor'); Type = 'single' }
)

# Resolve skill entries: list of @{ Name; Path }
$skills = @()
foreach ($r in $repos) {
  if (-not (Test-Path -LiteralPath $r.Path)) {
    Write-Warning "Repo not found, skipped: $($r.Path)"
    continue
  }
  if ($r.Type -eq 'multi') {
    $sd = Join-Path $r.Path 'skills'
    if (Test-Path -LiteralPath $sd) {
      Get-ChildItem -LiteralPath $sd -Directory | Where-Object { $_.Name -notlike '.*' } | ForEach-Object {
        $skills += @{ Name = $_.Name; Path = $_.FullName }
      }
    } else {
      Write-Warning "No skills dir under repo, skipped: $($r.Path)"
    }
  } else {
    if (Test-Path -LiteralPath (Join-Path $r.Path 'SKILL.md')) {
      $skills += @{ Name = (Split-Path $r.Path -Leaf); Path = $r.Path }
    } else {
      Write-Warning "No SKILL.md at repo root, skipped: $($r.Path)"
    }
  }
}

if (-not $skills) {
  Write-Host "No skills found."
  exit 0
}
Write-Host "Found $($skills.Count) skill(s): $($skills.Name -join ', ')"

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
    New-Item -ItemType Junction -Path $dest -Target $s.Path | Out-Null
    Write-Host "  [link] $($s.Name)"
  }
}

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