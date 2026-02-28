param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir = Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u = New-Object System.Text.UTF8Encoding($false); $bytes = $u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$bytes) }
function ReadAllTextUtf8([string]$p){ return [System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8) }
function Backup-IfExists([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force; Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow } }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$EngineDir = Join-Path $RepoRootAbs "src\CDE.Runtime\Engine"
Ensure-Dir $EngineDir
$StatePath = Join-Path $EngineDir "KernelOverlayState.cs"
$OverlayPath = Join-Path $EngineDir "KernelOverlayComponent.cs"
$GameRoot = Join-Path $RepoRootAbs "src\CDE.Game\GameRoot.cs"
if(-not (Test-Path -LiteralPath $OverlayPath -PathType Leaf)){ Die ("MISSING_RUNTIME_OVERLAY: " + $OverlayPath) }
if(-not (Test-Path -LiteralPath $GameRoot -PathType Leaf)){ Die ("MISSING_GAMEROOT: " + $GameRoot) }

Backup-IfExists $StatePath
$stateText = @(
  "namespace CDE.Runtime.Engine;",
  "",
  "internal static class KernelOverlayState",
  "{",
  "    // CDE_KERNEL_OVERLAY_STATE_V1",
  "    public static bool MenuOpen { get; set; } = false;",
  "}",
)
$stateOut = (@($stateText) -join "`n") + "`n"
Write-Utf8NoBomLf $StatePath $stateOut
Write-Host ("WROTE: " + $StatePath) -ForegroundColor Green

Backup-IfExists $OverlayPath
$t = ReadAllTextUtf8 $OverlayPath
$t = $t.Replace("`r`n","`n")
$changed = 0
if($t -notmatch "KernelOverlayState\.MenuOpen"){
  # anchor: toggle line
  $pat = "if\s*\(\s*Pressed\s*\(\s*Keys\.Escape\s*,\s*k\s*,\s*_prev\s*\)\s*\)\s*_menu\s*=\s*!_menu\s*;"
  $m = [System.Text.RegularExpressions.Regex]::Match($t, $pat)
  if(-not $m.Success){ Die ("RUNTIME_OVERLAY_ESCAPE_TOGGLE_NOT_FOUND: " + $OverlayPath) }
  $ins = $m.Value + "`n        KernelOverlayState.MenuOpen = _menu; // CDE_KERNEL_OVERLAY_STATE_SYNC_V1"
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t, $pat, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $ins }, 1)
  if($t2 -eq $t){ Die ("RUNTIME_OVERLAY_STATE_SYNC_INSERT_FAILED: " + $OverlayPath) }
  $t = $t2; $changed++
}
if($t -notmatch "KernelOverlayState\.MenuOpen\s*=\s*false"){
  $ctor = "public\s+KernelOverlayComponent\s*\([^\)]*\)\s*:\s*base\s*\(\s*game\s*\)\s*\{"
  $m2 = [System.Text.RegularExpressions.Regex]::Match($t, $ctor)
  if($m2.Success){
    $rep = $m2.Value + "`n        KernelOverlayState.MenuOpen = false; // CDE_KERNEL_OVERLAY_STATE_INIT_V1"
    $t2 = [System.Text.RegularExpressions.Regex]::Replace($t, $ctor, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $rep }, 1)
    if($t2 -ne $t){ $t = $t2; $changed++ }
  }
}
if($changed -gt 0){ Write-Utf8NoBomLf $OverlayPath ($t + "`n"); Write-Host ("PATCH_OK: runtime overlay now syncs KernelOverlayState.MenuOpen changes=" + $changed) -ForegroundColor Green } else { Write-Host "PATCH_OK: runtime overlay already had KernelOverlayState sync" -ForegroundColor Green }

Backup-IfExists $GameRoot
$g = ReadAllTextUtf8 $GameRoot
$g = $g.Replace("`r`n","`n")
if($g -notmatch "CDE_KERNEL_MENU_INPUT_GATE_V1"){
  $uPat = "protected\s+override\s+void\s+Update\s*\(\s*GameTime\s+gameTime\s*\)\s*\{"
  $m = [System.Text.RegularExpressions.Regex]::Match($g, $uPat)
  if(-not $m.Success){ Die ("GAMEROOT_UPDATE_SIGNATURE_NOT_FOUND: " + $GameRoot) }
  $guard = $m.Value + "`n        // CDE_KERNEL_MENU_INPUT_GATE_V1`n        if (global::CDE.Runtime.Engine.KernelOverlayState.MenuOpen)`n        {`n            _dbg.Update(gameTime);`n            base.Update(gameTime);`n            return;`n        }"
  $g2 = [System.Text.RegularExpressions.Regex]::Replace($g, $uPat, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $guard }, 1)
  if($g2 -eq $g){ Die ("GAMEROOT_INSERT_GATE_FAILED: " + $GameRoot) }
  $g = $g2
  Write-Utf8NoBomLf $GameRoot ($g + "`n")
  Write-Host ("PATCH_OK: GameRoot.Update now gates gameplay when kernel menu open: " + $GameRoot) -ForegroundColor Green
} else { Write-Host "PATCH_OK: GameRoot already gated (CDE_KERNEL_MENU_INPUT_GATE_V1 present)" -ForegroundColor Green }

Write-Host "NEXT: dotnet build .\CDE.sln -c Debug" -ForegroundColor Yellow
Write-Host "NEXT: dotnet run --project .\src\CDE.Game\CDE.Game.csproj -c Debug" -ForegroundColor Yellow
