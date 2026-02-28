param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir = Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u = New-Object System.Text.UTF8Encoding($false); $bytes = $u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$bytes) }
function ReadAllTextUtf8([string]$p){ return [System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8) }
function Backup-IfExists([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force; Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow } }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$StatePath = Join-Path $RepoRootAbs "src\CDE.Runtime\Engine\KernelOverlayState.cs"
$GameRoot  = Join-Path $RepoRootAbs "src\CDE.Game\GameRoot.cs"
if(-not (Test-Path -LiteralPath $StatePath -PathType Leaf)){ Die ("MISSING_STATE: " + $StatePath) }
if(-not (Test-Path -LiteralPath $GameRoot -PathType Leaf)){ Die ("MISSING_GAMEROOT: " + $GameRoot) }

Backup-IfExists $StatePath
$s = ReadAllTextUtf8 $StatePath
$s = $s.Replace("`r`n","`n")
$s2 = [System.Text.RegularExpressions.Regex]::Replace($s, "(?m)^\s*internal\s+static\s+class\s+KernelOverlayState\s*$", "public static class KernelOverlayState", 1)
if($s2 -eq $s){
  # maybe already public; accept if contains public static class
  if($s -notmatch "(?m)^\s*public\s+static\s+class\s+KernelOverlayState\s*$"){ Die ("STATE_VISIBILITY_PATCH_NOOP_UNEXPECTED: " + $StatePath) }
  Write-Host "PATCH_OK: KernelOverlayState already public" -ForegroundColor Green
} else {
  Write-Utf8NoBomLf $StatePath ($s2 + "`n")
  Write-Host ("PATCH_OK: KernelOverlayState made public: " + $StatePath) -ForegroundColor Green
}

Backup-IfExists $GameRoot
$g = ReadAllTextUtf8 $GameRoot
$g = $g.Replace("`r`n","`n")
if($g -notmatch "CDE_KERNEL_MENU_INPUT_GATE_V1"){ Die ("MISSING_GATE_MARKER_CDE_KERNEL_MENU_INPUT_GATE_V1: " + $GameRoot) }

# Replace only the _dbg.Update line inside our gate block with a null-safe form
$before = $g
$g = [System.Text.RegularExpressions.Regex]::Replace($g, "(?m)^\s*_dbg\.Update\s*\(\s*gameTime\s*\)\s*;\s*$", "            if (_dbg != null) _dbg.Update(gameTime);", 1)
if($g -eq $before){
  # If it was already fixed, accept; otherwise error to avoid silent drift
  if($before -match "(?m)^\s*if\s*\(\s*_dbg\s*!=\s*null\s*\)\s*_dbg\.Update\s*\(\s*gameTime\s*\)\s*;\s*$"){
    Write-Host "PATCH_OK: GameRoot gate already null-safe" -ForegroundColor Green
  } else {
    Die ("GAMEROOT_GATE_NULLSAFE_PATCH_NOOP: " + $GameRoot)
  }
} else {
  Write-Utf8NoBomLf $GameRoot ($g + "`n")
  Write-Host ("PATCH_OK: GameRoot gate now null-safe for _dbg: " + $GameRoot) -ForegroundColor Green
}

Write-Host "NEXT: dotnet build .\CDE.sln -c Debug" -ForegroundColor Yellow
Write-Host "NEXT: dotnet run --project .\src\CDE.Game\CDE.Game.csproj -c Debug" -ForegroundColor Yellow
