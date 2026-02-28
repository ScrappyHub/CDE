param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir = Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u = New-Object System.Text.UTF8Encoding($false); $bytes = $u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$bytes) }
function ReadAllTextUtf8([string]$p){ return [System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8) }
function Backup-IfExists([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force; Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow } }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$GameRoot = Join-Path $RepoRootAbs "src\CDE.Game\GameRoot.cs"
if(-not (Test-Path -LiteralPath $GameRoot -PathType Leaf)){ Die ("MISSING_GAMEROOT: " + $GameRoot) }
Backup-IfExists $GameRoot
$g = ReadAllTextUtf8 $GameRoot
$g = $g.Replace("`r`n","`n")

if($g -notmatch "CDE_KERNEL_MENU_INPUT_GATE_V1"){ Die ("MISSING_GATE_MARKER_CDE_KERNEL_MENU_INPUT_GATE_V1: " + $GameRoot) }
if($g -match "CDE_KERNEL_MENU_TOGGLE_V1"){ Write-Host "PATCH_OK: GameRoot already has kernel menu toggle (CDE_KERNEL_MENU_TOGGLE_V1)" -ForegroundColor Green; exit 0 }

if($g -notmatch "(?m)^\s*using\s+Microsoft\.Xna\.Framework\.Input\s*;\s*$"){
  $uIns = "using Microsoft.Xna.Framework.Input;"
  $mU = [System.Text.RegularExpressions.Regex]::Match($g, "(?m)^(using\s+[^\r\n]+;\s*)\n")
  if($mU.Success){
    # insert after first using block line
    $g2 = [System.Text.RegularExpressions.Regex]::Replace($g, "(?m)^(using\s+[^\r\n]+;\s*)\n", [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) ($mm.Groups[1].Value + "`n" + $uIns + "`n") }, 1)
    if($g2 -eq $g){ Die ("FAILED_TO_INSERT_USING_INPUT: " + $GameRoot) }
    $g = $g2
  } else {
    # fallback: insert at file top
    $g = ($uIns + "`n" + $g)
  }
}

$classPat = "(?m)^\s*(public\s+)?(sealed\s+)?class\s+GameRoot\b[^{]*\{\s*$"
$mC = [System.Text.RegularExpressions.Regex]::Match($g, $classPat)
if(-not $mC.Success){
  # fallback: find the first { after "class GameRoot"
  $mC2 = [System.Text.RegularExpressions.Regex]::Match($g, "(?s)\bclass\s+GameRoot\b.*?\{")
  if(-not $mC2.Success){ Die ("GAMEROOT_CLASS_NOT_FOUND: " + $GameRoot) }
  $rep = $mC2.Value + "`n    // CDE_KERNEL_MENU_TOGGLE_V1`n    private KeyboardState _kernelMenuPrev;"
  $g2 = [System.Text.RegularExpressions.Regex]::Replace($g, "(?s)\bclass\s+GameRoot\b.*?\{", [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $rep }, 1)
  if($g2 -eq $g){ Die ("FAILED_TO_INSERT_KERNELMENU_FIELD_FALLBACK: " + $GameRoot) }
  $g = $g2
} else {
  $rep = $mC.Value + "`n    // CDE_KERNEL_MENU_TOGGLE_V1`n    private KeyboardState _kernelMenuPrev;"
  $g2 = [System.Text.RegularExpressions.Regex]::Replace($g, $classPat, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $rep }, 1)
  if($g2 -eq $g){ Die ("FAILED_TO_INSERT_KERNELMENU_FIELD: " + $GameRoot) }
  $g = $g2
}

$uPat = "protected\s+override\s+void\s+Update\s*\(\s*GameTime\s+gameTime\s*\)\s*\{"
$mU2 = [System.Text.RegularExpressions.Regex]::Match($g, $uPat)
if(-not $mU2.Success){ Die ("GAMEROOT_UPDATE_SIGNATURE_NOT_FOUND: " + $GameRoot) }
$toggle = $mU2.Value + "`n        // CDE_KERNEL_MENU_TOGGLE_V1`n        var __kmNow = Keyboard.GetState();`n        if (__kmNow.IsKeyDown(Keys.Escape) && !_kernelMenuPrev.IsKeyDown(Keys.Escape))`n        {`n            global::CDE.Runtime.Engine.KernelOverlayState.MenuOpen = !global::CDE.Runtime.Engine.KernelOverlayState.MenuOpen;`n        }`n        _kernelMenuPrev = __kmNow;"
$g2 = [System.Text.RegularExpressions.Regex]::Replace($g, $uPat, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $toggle }, 1)
if($g2 -eq $g){ Die ("GAMEROOT_TOGGLE_INSERT_FAILED: " + $GameRoot) }
$g = $g2

Write-Utf8NoBomLf $GameRoot ($g + "`n")
Write-Host ("PATCH_OK: GameRoot now toggles KernelOverlayState.MenuOpen on ESC (independent of overlays): " + $GameRoot) -ForegroundColor Green
Write-Host "NEXT: dotnet build .\CDE.sln -c Debug" -ForegroundColor Yellow
Write-Host "NEXT: dotnet run --project .\src\CDE.Game\CDE.Game.csproj -c Debug" -ForegroundColor Yellow
