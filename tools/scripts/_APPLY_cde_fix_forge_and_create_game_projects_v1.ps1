param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [ValidateSet("DesktopGL","WindowsDX")][string]$Flavor = "DesktopGL"
)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir=Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u=New-Object System.Text.UTF8Encoding($false); $b=$u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$b) }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Sln = Join-Path $RepoRootAbs "CDE.sln"
if(-not (Test-Path -LiteralPath $Sln -PathType Leaf)){ Die ("MISSING_SOLUTION: " + $Sln) }

$Pkg = if($Flavor -eq "WindowsDX"){ "MonoGame.Framework.WindowsDX" } else { "MonoGame.Framework.DesktopGL" }
Write-Host ("CDE_MONOGAME_FLAVOR: " + $Flavor + " package=" + $Pkg) -ForegroundColor Cyan

# --- 1) Fix Forge RunCommand.cs ---
$runCmd = Join-Path $RepoRootAbs "src\CDE.Tools.Forge\Commands\RunCommand.cs"
if(-not (Test-Path -LiteralPath $runCmd -PathType Leaf)){ Die ("MISSING_FILE: " + $runCmd) }
$lines = [System.IO.File]::ReadAllLines($runCmd)
$out = New-Object System.Collections.Generic.List[string]
$changed = $false
for($i=0; $i -lt $lines.Length; $i++){
  $ln = $lines[$i]
  if($ln -match "^\s*Arguments\s*="){
    # Deterministic correct C# string for quotes around path
    [void]$out.Add("            Arguments = $`"run --project \`"\{gameProj\}\`"`",")
    $changed = $true
  } else {
    [void]$out.Add($ln)
  }
}
if($changed){
  $newText = (@($out.ToArray()) -join "`n") + "`n"
  Write-Utf8NoBomLf $runCmd $newText
  Write-Host ("PATCH_OK: fixed RunCommand.cs Arguments line: " + $runCmd) -ForegroundColor Green
} else {
  Write-Host ("PATCH_NOOP: no Arguments= line found in RunCommand.cs: " + $runCmd) -ForegroundColor Yellow
}

# --- 2) Create CDE.Game + CDE.SpriteStudio projects (csproj only) ---
$GameDir = Join-Path $RepoRootAbs "src\CDE.Game"
$StudioDir = Join-Path $RepoRootAbs "src\CDE.SpriteStudio"
Ensure-Dir $GameDir
Ensure-Dir $StudioDir
$GameProj = Join-Path $GameDir "CDE.Game.csproj"
$StudioProj = Join-Path $StudioDir "CDE.SpriteStudio.csproj"
$RuntimeProj = Join-Path $RepoRootAbs "src\CDE.Runtime\CDE.Runtime.csproj"
if(-not (Test-Path -LiteralPath $RuntimeProj -PathType Leaf)){ Die ("MISSING_RUNTIME_PROJ: " + $RuntimeProj) }

$pkgLine = ("    <PackageReference Include=""{0}"" Version=""3.8.1.303"" />" -f $Pkg)

$csprojLines = @(
  "<Project Sdk=""Microsoft.NET.Sdk"">",
  "  <PropertyGroup>",
  "    <OutputType>WinExe</OutputType>",
  "    <TargetFramework>net8.0</TargetFramework>",
  "    <Nullable>enable</Nullable>",
  "    <ImplicitUsings>enable</ImplicitUsings>",
  "  </PropertyGroup>",
  "  <ItemGroup>",
  $pkgLine,
  "  </ItemGroup>",
  "  <ItemGroup>",
  "    <ProjectReference Include=""..\CDE.Runtime\CDE.Runtime.csproj"" />",
  "  </ItemGroup>",
  "</Project>"
)

Write-Utf8NoBomLf $GameProj ((@($csprojLines) -join "`n") + "`n")
Write-Utf8NoBomLf $StudioProj ((@($csprojLines) -join "`n") + "`n")
Write-Host ("WROTE: " + $GameProj) -ForegroundColor Green
Write-Host ("WROTE: " + $StudioProj) -ForegroundColor Green

# --- 3) Add to solution + restore ---
& dotnet sln $Sln add $RuntimeProj | Out-Host
& dotnet sln $Sln add $GameProj | Out-Host
& dotnet sln $Sln add $StudioProj | Out-Host
& dotnet restore $Sln | Out-Host

Write-Host "CDE_APPLY_OK: Forge fixed + Game/SpriteStudio projects created" -ForegroundColor Green
Write-Host "NEXT: dotnet run --project .\src\CDE.Tools.Forge\CDE.Tools.Forge.csproj -- doctor" -ForegroundColor Yellow
Write-Host "NEXT: dotnet run --project .\src\CDE.Tools.Forge\CDE.Tools.Forge.csproj -- run" -ForegroundColor Yellow
