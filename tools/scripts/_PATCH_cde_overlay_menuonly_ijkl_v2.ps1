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

$inUpdate = $false
$updateBraceDepth = 0
$moveIdx = New-Object System.Collections.Generic.List[int]
$foundTick = $false

# pass 1: locate Update(...) and first 4 _bridge.Move( lines before _bridge.Tick()
for($i=0; $i -lt $lines.Length; $i++){
  $ln = $lines[$i]
  if(-not $inUpdate){
    if($ln -match "public\s+override\s+void\s+Update\s*\("){ $inUpdate = $true; $updateBraceDepth = 0; $foundTick = $false }
    continue
  }
  # track braces once inUpdate started
  $opens  = ([regex]::Matches($ln,"\{")).Count
  $closes = ([regex]::Matches($ln,"\}")).Count
  $updateBraceDepth += ($opens - $closes)

  if(-not $foundTick -and $ln -match "_bridge\.Tick\s*\("){ $foundTick = $true }
  if(-not $foundTick -and $ln -match "_bridge\.Move\s*\("){ [void]$moveIdx.Add($i) }

  if($updateBraceDepth -le 0 -and $i -gt 0){ break }
}

if($moveIdx.Count -lt 4){ Die ("PATCH_FAILED_NEED_4_MOVE_LINES_FOUND=" + $moveIdx.Count + ": " + $Overlay) }
$m0 = $moveIdx[0]; $m1 = $moveIdx[1]; $m2 = $moveIdx[2]; $m3 = $moveIdx[3]

# pass 2: rewrite file; replace the 4 move lines with menu-only IJKL block; also remap K/L->O/P and update hint
for($i=0; $i -lt $lines.Length; $i++){
  $ln = $lines[$i]

  if($i -eq $m0){
    [void]$out.Add("        if (_menu)")
    [void]$out.Add("        {")
    [void]$out.Add("            // CDE_KERNEL_OVERLAY_MENUONLY_IJKL_V1")
    [void]$out.Add("            if (k.IsKeyDown(Keys.J)) _bridge.Move(-s, 0);")
    [void]$out.Add("            if (k.IsKeyDown(Keys.L)) _bridge.Move( s, 0);")
    [void]$out.Add("            if (k.IsKeyDown(Keys.I)) _bridge.Move(0, -s);")
    [void]$out.Add("            if (k.IsKeyDown(Keys.K)) _bridge.Move(0,  s);")
    [void]$out.Add("        }")
    # skip original 4 move lines
    if($m3 -gt $m0){ $i = $m3; continue }
  }

  if($ln -match "Pressed\(Keys\.K,\s*k,\s*_prev\)\)\s*_bridge\.ApplyDamage\("){ $ln = ($ln -replace "Keys\.K","Keys.O") }
  if($ln -match "Pressed\(Keys\.L,\s*k,\s*_prev\)\)\s*_bridge\.Heal\("){        $ln = ($ln -replace "Keys\.L","Keys.P") }
  $ln = $ln -replace "\((ESC menu, F5 reset, )K dmg, L heal\)","(ESC menu, F5 reset, O dmg, P heal, IJKL move when menu ON)"

  [void]$out.Add($ln)
}

$newText = (@($out.ToArray()) -join "`n") + "`n"
Write-Utf8NoBomLf $Overlay $newText
Write-Host ("PATCH_OK: overlay MENU-only IJKL movement; remapped dmg/heal to O/P: " + $Overlay) -ForegroundColor Green
Write-Host "NEXT: dotnet build .\CDE.sln -c Debug" -ForegroundColor Yellow
Write-Host "NEXT: dotnet run --project .\src\CDE.Game\CDE.Game.csproj -c Debug" -ForegroundColor Yellow
