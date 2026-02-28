param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir = Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u = New-Object System.Text.UTF8Encoding($false); $bytes = $u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$bytes) }
function ReadAllTextUtf8([string]$p){ return [System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8) }
function Backup-IfExists([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force; Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow } }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Overlay = Join-Path $RepoRootAbs "src\CDE.Runtime\Engine\KernelOverlayComponent.cs"
if(-not (Test-Path -LiteralPath $Overlay -PathType Leaf)){ Die ("MISSING_OVERLAY: " + $Overlay) }
Backup-IfExists $Overlay
$t = ReadAllTextUtf8 $Overlay
$t = $t.Replace("`r`n","`n")

# 1) Remap dmg/heal to O/P (keep +/- if you want)
$c=0
$t2 = $t
$t2 = [System.Text.RegularExpressions.Regex]::Replace($t2, "Pressed\(Keys\.OemMinus", "Pressed(Keys.O", 1)
if($t2 -ne $t){ $t = $t2; $c++ }
$t2 = [System.Text.RegularExpressions.Regex]::Replace($t2, "Pressed\(Keys\.OemPlus",  "Pressed(Keys.P", 1)
if($t2 -ne $t){ $t = $t2; $c++ }

# 2) Gate IJKL movement under menu ON (marker anchored)
if($t -notmatch "CDE_KERNEL_OVERLAY_MENUONLY_IJKL_V1"){ Die ("MISSING_MARKER_CDE_KERNEL_OVERLAY_MENUONLY_IJKL_V1: " + $Overlay) }

# Find the four movement lines after the marker and wrap them in if (_menu) { ... } if not already
$lines = $t -split "`n"
$out = New-Object System.Collections.Generic.List[string]
$wrapped = $false
for($i=0; $i -lt $lines.Length; $i++){
  $ln = $lines[$i]
  if(-not $wrapped -and $ln -match "CDE_KERNEL_OVERLAY_MENUONLY_IJKL_V1"){
    [void]$out.Add($ln)
    # Expect next lines to be movement; if already gated, detect and skip
    $j = $i + 1
    while($j -lt $lines.Length -and [string]::IsNullOrWhiteSpace($lines[$j])){ [void]$out.Add($lines[$j]); $j++ }
    if($j -lt $lines.Length -and $lines[$j] -match "if\s*\(\s*_menu\s*\)"){ $wrapped = $true; $i = $j-1; continue }
    [void]$out.Add("            if (_menu)")
    [void]$out.Add("            {")
    $k = $j
    for($n=0; $n -lt 4 -and $k -lt $lines.Length; $n++){
      [void]$out.Add("            " + $lines[$k].TrimStart())
      $k++
    }
    [void]$out.Add("            }")
    $wrapped = $true
    $i = $k - 1
    continue
  }
  [void]$out.Add($ln)
}
if(-not $wrapped){ Die ("FAILED_TO_WRAP_IJKL_BLOCK: " + $Overlay) }
$newText = (@($out.ToArray()) -join "`n") + "`n"
Write-Utf8NoBomLf $Overlay $newText
Write-Host ("PATCH_OK: overlay gated IJKL under menu + remap dmg/heal to O/P. changes=" + $c) -ForegroundColor Green
Write-Host "NEXT: dotnet build .\CDE.sln -c Debug" -ForegroundColor Yellow
Write-Host "NEXT: dotnet run --project .\src\CDE.Game\CDE.Game.csproj -c Debug" -ForegroundColor Yellow
