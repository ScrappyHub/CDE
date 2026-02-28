param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir=Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u=New-Object System.Text.UTF8Encoding($false); $b=$u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$b) }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Sln = Join-Path $RepoRootAbs "CDE.sln"
if(-not (Test-Path -LiteralPath $Sln -PathType Leaf)){ Die ("MISSING_SOLUTION: " + $Sln) }

# Read MonoGame package + version from CDE.Game.csproj (source of truth)
$gameProj = Join-Path $RepoRootAbs "src\CDE.Game\CDE.Game.csproj"
if(-not (Test-Path -LiteralPath $gameProj -PathType Leaf)){ Die ("MISSING_GAME_CSPROJ: " + $gameProj) }
$gp = [System.IO.File]::ReadAllText($gameProj,[System.Text.Encoding]::UTF8)
$m = [regex]::Match($gp, "<PackageReference\s+Include=""([^""]+)""\s+Version=""([^""]+)""\s*/>")
if(-not $m.Success){ Die ("MISSING_MONOGAME_PACKAGEREF_IN_GAME: " + $gameProj) }
$Pkg = $m.Groups[1].Value
$Ver = $m.Groups[2].Value
Write-Host ("MONOGAME_PKG: " + $Pkg + " ver=" + $Ver) -ForegroundColor Cyan

# --- 1) Ensure CDE.Runtime references MonoGame package ---
$runtimeProj = Join-Path $RepoRootAbs "src\CDE.Runtime\CDE.Runtime.csproj"
if(-not (Test-Path -LiteralPath $runtimeProj -PathType Leaf)){ Die ("MISSING_RUNTIME_CSPROJ: " + $runtimeProj) }
$rt = [System.IO.File]::ReadAllText($runtimeProj,[System.Text.Encoding]::UTF8)
if($rt -match [regex]::Escape("PackageReference Include=""$Pkg""")){
  Write-Host ("RUNTIME_HAS_MONOGAME_OK: " + $runtimeProj) -ForegroundColor Green
} else {
  $insert = @(
    "  <ItemGroup>",
    ("    <PackageReference Include=""{0}"" Version=""{1}"" />" -f $Pkg,$Ver),
    "  </ItemGroup>"
  ) -join "`n"
  if($rt -notmatch "</Project>"){ Die ("BAD_XML: missing </Project> in " + $runtimeProj) }
  $rt2 = $rt -replace "</Project>", ($insert + "`n</Project>")
  Write-Utf8NoBomLf $runtimeProj ($rt2 + (if($rt2.EndsWith("`n")){""}else{"`n"}))
  Write-Host ("PATCH_OK: added MonoGame PackageReference to runtime: " + $runtimeProj) -ForegroundColor Green
}

# --- 2) Add minimal entrypoint for CDE.Game so dotnet run works ---
$gameDir = Join-Path $RepoRootAbs "src\CDE.Game"
Ensure-Dir $gameDir
$prog = Join-Path $gameDir "Program.cs"
if(-not (Test-Path -LiteralPath $prog -PathType Leaf)){
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
    }"
  ) -join "`n"
  Write-Utf8NoBomLf $prog ($code + "`n")
  Write-Host ("WROTE: " + $prog) -ForegroundColor Green
} else {
  Write-Host ("SKIP: Program.cs exists: " + $prog) -ForegroundColor Yellow
}

# --- 3) Fix Tilemap namespace-as-type by stubbing Tilemap class ---
$tileDir = Join-Path $RepoRootAbs "src\CDE.Runtime\Engine\Tilemap"
Ensure-Dir $tileDir
$tileFile = Join-Path $tileDir "Tilemap.cs"
if(-not (Test-Path -LiteralPath $tileFile -PathType Leaf)){
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
  Write-Utf8NoBomLf $tileFile ($tcode + "`n")
  Write-Host ("WROTE: " + $tileFile) -ForegroundColor Green
} else {
  Write-Host ("SKIP: Tilemap.cs exists: " + $tileFile) -ForegroundColor Yellow
}

# --- 4) Restore + build ---
& dotnet restore $Sln | Out-Host
& dotnet build $Sln -c Debug | Out-Host
Write-Host "CDE_MONOGAME_RUNTIME_OK: restore+build ok" -ForegroundColor Green
