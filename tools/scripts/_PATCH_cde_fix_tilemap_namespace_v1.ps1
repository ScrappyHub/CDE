param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir=Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u=New-Object System.Text.UTF8Encoding($false); $b=$u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$b) }
function Backup-File([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=(Get-Date).ToString("yyyyMMdd_HHmmss"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force | Out-Null; return $bak }; return "" }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Sln = Join-Path $RepoRootAbs "CDE.sln"
if(-not (Test-Path -LiteralPath $Sln -PathType Leaf)){ Die ("MISSING_SOLUTION: " + $Sln) }

$Plat = Join-Path $RepoRootAbs "src\CDE.Runtime\Engine\Platformer\Controller\PlatformerController.cs"
if(-not (Test-Path -LiteralPath $Plat -PathType Leaf)){ Die ("MISSING_FILE: " + $Plat) }

$orig = [System.IO.File]::ReadAllText($Plat,[System.Text.Encoding]::UTF8)
$text = $orig
$changed = $false

# Remove any Tilemap using/alias lines (we will fully-qualify the type)
$lines = $text -split "`n"
$out = New-Object System.Collections.Generic.List[string]
for($i=0; $i -lt $lines.Length; $i++){
  $ln = $lines[$i]
  $trim = $ln.Trim()
  if($trim -eq "using CDE.Runtime.Engine.Tilemap;" ){ $changed = $true; continue }
  if($trim -like "using Tilemap = *"){ $changed = $true; continue }
  [void]$out.Add($ln)
}
$text2 = (@($out.ToArray()) -join "`n")

# Replace whole-word Tilemap tokens with fully qualified type name
$fq = "CDE.Runtime.Engine.Tilemap.Tilemap"
$rx = [regex]::new("(?<![A-Za-z0-9_\.])Tilemap(?![A-Za-z0-9_])")
$repl = $rx.Replace($text2, $fq)
if($repl -ne $text2){ $changed = $true }

if($changed){
  $bak = Backup-File $Plat
  if(-not $repl.EndsWith("`n")){ $repl = $repl + "`n" }
  Write-Utf8NoBomLf $Plat $repl
  Write-Host ("PATCH_OK: Tilemap type fully-qualified (backup=" + $bak + "): " + $Plat) -ForegroundColor Green
} else {
  Write-Host ("PATCH_NOOP: no Tilemap changes needed: " + $Plat) -ForegroundColor Yellow
}

& dotnet build $Sln -c Debug | Out-Host
if($LASTEXITCODE -ne 0){ Die "DOTNET_BUILD_FAILED_AFTER_TILEMAP_PATCH" }
Write-Host "CDE_TILEMAP_PATCH_OK: build ok" -ForegroundColor Green
