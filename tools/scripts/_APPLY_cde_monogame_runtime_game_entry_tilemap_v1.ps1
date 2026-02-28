param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir=Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u=New-Object System.Text.UTF8Encoding($false); $b=$u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$b) }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Sln = Join-Path $RepoRootAbs "CDE.sln"
if(-not (Test-Path -LiteralPath $Sln -PathType Leaf)){ Die ("MISSING_SOLUTION: " + $Sln) }

# Source-of-truth MonoGame package+version from CDE.Game.csproj
$GameCsproj = Join-Path $RepoRootAbs "src\CDE.Game\CDE.Game.csproj"
if(-not (Test-Path -LiteralPath $GameCsproj -PathType Leaf)){ Die ("MISSING_GAME_CSPROJ: " + $GameCsproj) }
$gp = [System.IO.File]::ReadAllText($GameCsproj,[System.Text.Encoding]::UTF8)
$m = [regex]::Match($gp, "<PackageReference\s+Include=""([^""]+)""\s+Version=""([^""]+)""\s*/>")
if(-not $m.Success){ Die ("MISSING_MONOGAME_PACKAGEREF_IN_GAME: " + $GameCsproj) }
$Pkg = $m.Groups[1].Value
$Ver = $m.Groups[2].Value
Write-Host ("MONOGAME_PKG: " + $Pkg + " ver=" + $Ver) -ForegroundColor Cyan

# 1) Add MonoGame PackageReference to CDE.Runtime.csproj (required for Microsoft.Xna.*)
$RuntimeCsproj = Join-Path $RepoRootAbs "src\CDE.Runtime\CDE.Runtime.csproj"
if(-not (Test-Path -LiteralPath $RuntimeCsproj -PathType Leaf)){ Die ("MISSING_RUNTIME_CSPROJ: " + $RuntimeCsproj) }
$rt = [System.IO.File]::ReadAllText($RuntimeCsproj,[System.Text.Encoding]::UTF8)
if($rt -match [regex]::Escape("PackageReference Include=""$Pkg""")){
  Write-Host ("RUNTIME_HAS_MONOGAME_OK: " + $RuntimeCsproj) -ForegroundColor Green
} else {
  if($rt -notmatch "</Project>"){ Die ("BAD_XML: missing </Project> in " + $RuntimeCsproj) }
  $ins = @(
    "  <ItemGroup>",
    ("    <PackageReference Include=""{0}"" Version=""{1}"" />" -f $Pkg,$Ver),
    "  </ItemGroup>"
  ) -join "`n"
  $rt2 = $rt -replace "</Project>", ($ins + "`n</Project>")
  Write-Utf8NoBomLf $RuntimeCsproj ($rt2 + (if($rt2.EndsWith("`n")){""}else{"`n"}))
  Write-Host ("PATCH_OK: runtime now references MonoGame: " + $RuntimeCsproj) -ForegroundColor Green
}

# 2) Ensure CDE.Game has Program.cs entrypoint
$GameDir = Join-Path $RepoRootAbs "src\CDE.Game"
Ensure-Dir $GameDir
$ProgramCs = Join-Path $GameDir "Program.cs"
if(-not (Test-Path -LiteralPath $ProgramCs -PathType Leaf)){
  $code = @(
    "using System;",
    "using CDE.Runtime.Engine;",
    "",
    "namespace CDE.Game;",
    "",
    "internal static class Program",
    "{",
    "    [STAThread]",
    "    private static void Main()",
    "    {",
    "        using var game = new CdeGame();",
    "        game.Run();",
    "    }",
    "}"
  ) -join "`n"
  Write-Utf8NoBomLf $ProgramCs ($code + "`n")
  Write-Host ("WROTE: " + $ProgramCs) -ForegroundColor Green
} else {
  Write-Host ("SKIP: Program.cs exists: " + $ProgramCs) -ForegroundColor Yellow
}

# 3) Tilemap: create stub type + alias it in PlatformerController to avoid namespace/type collision
$TileDir = Join-Path $RepoRootAbs "src\CDE.Runtime\Engine\Tilemap"
Ensure-Dir $TileDir
$TileFile = Join-Path $TileDir "Tilemap.cs"
if(-not (Test-Path -LiteralPath $TileFile -PathType Leaf)){
  $tcode = @(
    "namespace CDE.Runtime.Engine.Tilemap;",
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
  Write-Utf8NoBomLf $TileFile ($tcode + "`n")
  Write-Host ("WROTE: " + $TileFile) -ForegroundColor Green
} else {
  Write-Host ("SKIP: Tilemap.cs exists: " + $TileFile) -ForegroundColor Yellow
}

$Plat = Join-Path $RepoRootAbs "src\CDE.Runtime\Engine\Platformer\Controller\PlatformerController.cs"
if(Test-Path -LiteralPath $Plat -PathType Leaf){
  $pl = [System.IO.File]::ReadAllLines($Plat)
  $alias = "using Tilemap = CDE.Runtime.Engine.Tilemap.Tilemap;"
  $has = $false
  for($i=0; $i -lt $pl.Length; $i++){ if($pl[$i].Trim() -eq $alias){ $has = $true; break } }
  if(-not $has){
    $o = New-Object System.Collections.Generic.List[string]
    $inserted = $false
    for($i=0; $i -lt $pl.Length; $i++){
      $ln = $pl[$i]
      if(-not $inserted -and $ln.Trim().StartsWith("namespace ")){
        [void]$o.Add($alias)
        [void]$o.Add("")
        $inserted = $true
      }
      [void]$o.Add($ln)
    }
    if(-not $inserted){
      $o2 = New-Object System.Collections.Generic.List[string]
      [void]$o2.Add($alias)
      [void]$o2.Add("")
      for($i=0; $i -lt $pl.Length; $i++){ [void]$o2.Add($pl[$i]) }
      $o = $o2
    }
    $new = (@($o.ToArray()) -join "`n") + "`n"
    Write-Utf8NoBomLf $Plat $new
    Write-Host ("PATCH_OK: added Tilemap alias: " + $Plat) -ForegroundColor Green
  } else {
    Write-Host ("SKIP: Tilemap alias already present: " + $Plat) -ForegroundColor Yellow
  }
} else {
  Write-Host ("SKIP: PlatformerController missing: " + $Plat) -ForegroundColor Yellow
}

# 4) Restore + build
& dotnet restore $Sln | Out-Host
& dotnet build $Sln -c Debug | Out-Host
Write-Host "CDE_PATCH_OK: runtime has MonoGame + game entry + tilemap stub + build ok" -ForegroundColor Green
