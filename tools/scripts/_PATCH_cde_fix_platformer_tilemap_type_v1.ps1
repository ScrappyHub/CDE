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

# --- 1) Ensure Platformer Tilemap stub exists (the type Platformer expects) ---
$platTileDir = Join-Path $RepoRootAbs "src\CDE.Runtime\Engine\Platformer\Tilemap"
Ensure-Dir $platTileDir
$platTileFile = Join-Path $platTileDir "Tilemap.cs"
if(-not (Test-Path -LiteralPath $platTileFile -PathType Leaf)){
  $code = @(
    "namespace CDE.Runtime.Engine.Platformer.Tilemap;",
    "",
    "public sealed class Tilemap",
    "{",
    "    public int Width { get; } = 0;",
    "    public int Height { get; } = 0;",
    "    public int TileSize { get; } = 16;",
    "",
    "    public bool IsSolidAtCell(int x, int y) => false;",
    "}"
  ) -join "`n"
  Write-Utf8NoBomLf $platTileFile ($code + "`n")
  Write-Host ("WROTE: " + $platTileFile) -ForegroundColor Green
} else {
  Write-Host ("SKIP: Platformer Tilemap.cs exists: " + $platTileFile) -ForegroundColor Yellow
}

# --- 2) Patch PlatformerController to use Platformer Tilemap type ---
$Plat = Join-Path $RepoRootAbs "src\CDE.Runtime\Engine\Platformer\Controller\PlatformerController.cs"
if(-not (Test-Path -LiteralPath $Plat -PathType Leaf)){ Die ("MISSING_FILE: " + $Plat) }
$orig = [System.IO.File]::ReadAllText($Plat,[System.Text.Encoding]::UTF8)
$text = $orig
$changed = $false

# Replace any fully-qualified Engine.Tilemap.Tilemap with Platformer.Tilemap.Tilemap
$from = "CDE.Runtime.Engine.Tilemap.Tilemap"
$to   = "CDE.Runtime.Engine.Platformer.Tilemap.Tilemap"
if($text.Contains($from)){ $text = $text.Replace($from,$to); $changed = $true }

# Also replace any whole-word Tilemap tokens with Platformer Tilemap type (avoid namespace binding)
$rx = [regex]::new("(?<![A-Za-z0-9_\.])Tilemap(?![A-Za-z0-9_])")
$repl = $rx.Replace($text, $to)
if($repl -ne $text){ $text = $repl; $changed = $true }

if($changed){
  $bak = Backup-File $Plat
  if(-not $text.EndsWith("`n")){ $text = $text + "`n" }
  Write-Utf8NoBomLf $Plat $text
  Write-Host ("PATCH_OK: PlatformerController now uses Platformer.Tilemap.Tilemap (backup=" + $bak + "): " + $Plat) -ForegroundColor Green
} else {
  Write-Host ("PATCH_NOOP: PlatformerController already ok: " + $Plat) -ForegroundColor Yellow
}

# --- 3) Build ---
& dotnet build $Sln -c Debug | Out-Host
if($LASTEXITCODE -ne 0){ Die "DOTNET_BUILD_FAILED_AFTER_PLATFORMER_TILEMAP_PATCH" }
Write-Host "CDE_PLATFORMER_TILEMAP_PATCH_OK: build ok" -ForegroundColor Green
