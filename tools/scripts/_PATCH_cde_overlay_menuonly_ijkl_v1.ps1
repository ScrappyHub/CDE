param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir = Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u = New-Object System.Text.UTF8Encoding($false); $bytes = $u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$bytes) }
function Backup-IfExists([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force; Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow } }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Overlay = Join-Path $RepoRootAbs "src\CDE.Runtime\Engine\KernelOverlayComponent.cs"
if(-not (Test-Path -LiteralPath $Overlay -PathType Leaf)){ Die ("MISSING_OVERLAY: " + $Overlay) }
$t = [System.IO.File]::ReadAllText($Overlay,[System.Text.Encoding]::UTF8).Replace("`r`n","`n")
if($t -match "CDE_KERNEL_OVERLAY_MENUONLY_IJKL_V1"){ Write-Host ("SKIP: overlay already patched: " + $Overlay) -ForegroundColor Yellow; return }
Backup-IfExists $Overlay
$lines = $t -split "`n", -1
$out = New-Object System.Collections.Generic.List[string]
$didMove = $false
$changedKeys = 0

for($i=0; $i -lt $lines.Length; $i++){
  $ln = $lines[$i]

  # Replace movement block (4 lines) once: arrows/WASD -> menu-only IJKL
  if(-not $didMove -and $ln -match '_bridge\.Move\(-s,\s*0\)' -and $ln -match 'Keys\.(Left|A)' ){
    # expect next 3 lines are the other Move lines
    $didMove = $true
    [void]$out.Add("        if (_menu)")
    [void]$out.Add("        {")
    [void]$out.Add("            // CDE_KERNEL_OVERLAY_MENUONLY_IJKL_V1")
    [void]$out.Add("            if (k.IsKeyDown(Keys.J)) _bridge.Move(-s, 0);")
    [void]$out.Add("            if (k.IsKeyDown(Keys.L)) _bridge.Move( s, 0);")
    [void]$out.Add("            if (k.IsKeyDown(Keys.I)) _bridge.Move(0, -s);")
    [void]$out.Add("            if (k.IsKeyDown(Keys.K)) _bridge.Move(0,  s);")
    [void]$out.Add("        }")
    $i += 3
    continue
  }

  # Move damage/heal off K/L so IJKL is free: K->O, L->P
  if($ln -match 'Pressed\(Keys\.K,\s*k,\s*_prev\)\)\s*_bridge\.ApplyDamage\('){ $ln = ($ln -replace 'Keys\.K','Keys.O'); $changedKeys++ }
  if($ln -match 'Pressed\(Keys\.L,\s*k,\s*_prev\)\)\s*_bridge\.Heal\('){        $ln = ($ln -replace 'Keys\.L','Keys.P'); $changedKeys++ }

  # Update title hint if present
  if($ln -match '\(ESC menu, F5 reset, K dmg, L heal\)'){
    $ln = $ln -replace '\(ESC menu, F5 reset, K dmg, L heal\)','(ESC menu, F5 reset, O dmg, P heal, IJKL move when menu ON)'
    $changedKeys++
  }

  [void]$out.Add($ln)
}

if(-not $didMove){ Die ("PATCH_FAILED_NO_MOVE_BLOCK_FOUND: " + $Overlay) }
$newText = (@($out.ToArray()) -join "`n") + "`n"
Write-Utf8NoBomLf $Overlay $newText
Write-Host ("PATCH_OK: overlay menu-only IJKL movement + O/P dmg/heal. changedKeys=" + $changedKeys) -ForegroundColor Green
Write-Host "NEXT: dotnet build .\CDE.sln -c Debug" -ForegroundColor Yellow
Write-Host "NEXT: dotnet run --project .\src\CDE.Game\CDE.Game.csproj -c Debug" -ForegroundColor Yellow
