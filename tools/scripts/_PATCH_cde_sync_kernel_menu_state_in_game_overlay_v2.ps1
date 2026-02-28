param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir = Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u = New-Object System.Text.UTF8Encoding($false); $bytes = $u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$bytes) }
function ReadAllTextUtf8([string]$p){ return [System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8) }
function Backup-IfExists([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force; Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow } }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Overlay = Join-Path $RepoRootAbs "src\CDE.Game\KernelOverlayComponent.cs"
if(-not (Test-Path -LiteralPath $Overlay -PathType Leaf)){ Die ("MISSING_GAME_OVERLAY: " + $Overlay) }
Backup-IfExists $Overlay
$t = ReadAllTextUtf8 $Overlay
$t = $t.Replace("`r`n","`n")
$changed = 0

if($t -notmatch "CDE_KERNEL_OVERLAY_STATE_INIT_GAME_V1"){
  $ctorPat = "public\s+KernelOverlayComponent\s*\([^\)]*\)\s*(?::\s*base\s*\(\s*game\s*\)\s*)?\{"
  $m = [System.Text.RegularExpressions.Regex]::Match($t, $ctorPat)
  if(-not $m.Success){ Die ("GAME_OVERLAY_CTOR_NOT_FOUND: " + $Overlay) }
  $ins = $m.Value + "`n        global::CDE.Runtime.Engine.KernelOverlayState.MenuOpen = false; // CDE_KERNEL_OVERLAY_STATE_INIT_GAME_V1"
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t, $ctorPat, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $ins }, 1)
  if($t2 -eq $t){ Die ("GAME_OVERLAY_INIT_INSERT_FAILED: " + $Overlay) }
  $t = $t2; $changed++
}

if($t -notmatch "CDE_KERNEL_OVERLAY_STATE_SYNC_GAME_V1"){
  $lines = $t -split "`n"
  $out = New-Object System.Collections.Generic.List[string]
  $did = $false
  for($i=0; $i -lt $lines.Length; $i++){
    $ln = $lines[$i]
    [void]$out.Add($ln)
    if(-not $did){
      # Heuristic: find an Escape reference, then within the next ~12 lines find a _menu assignment and inject after it.
      if($ln -like "*Keys.Escape*" -or $ln -like "*Escape*"){
        for($j=$i; $j -lt [Math]::Min($lines.Length, $i+12); $j++){
          $cand = $lines[$j]
          if($cand -match "\b_menu\b" -and $cand -match "=" -and $cand.TrimEnd().EndsWith(";")){
            # If the assignment line is not the current output tail, ensure it appears before we inject.
            if($j -gt $i){
              # We already added $ln; we need to add the intervening lines up to $j if they were not yet added.
              for($k=$i+1; $k -le $j; $k++){ [void]$out.Add($lines[$k]) }
              $i = $j
            }
            [void]$out.Add("        global::CDE.Runtime.Engine.KernelOverlayState.MenuOpen = _menu; // CDE_KERNEL_OVERLAY_STATE_SYNC_GAME_V1")
            $did = $true
            break
          }
        }
      }
    }
  }
  if(-not $did){ Die ("GAME_OVERLAY_MENU_SYNC_INSERT_FAILED_NO_ESCAPE_ASSIGNMENT: " + $Overlay) }
  $t = (@($out.ToArray()) -join "`n")
  $changed++
}

if($changed -gt 0){
  Write-Utf8NoBomLf $Overlay ($t + "`n")
  Write-Host ("PATCH_OK: game overlay now syncs KernelOverlayState.MenuOpen changes=" + $changed + " file=" + $Overlay) -ForegroundColor Green
} else {
  Write-Host "PATCH_OK: game overlay already synced KernelOverlayState.MenuOpen" -ForegroundColor Green
}

Write-Host "NEXT: dotnet build .\CDE.sln -c Debug" -ForegroundColor Yellow
Write-Host "NEXT: dotnet run --project .\src\CDE.Game\CDE.Game.csproj -c Debug" -ForegroundColor Yellow
