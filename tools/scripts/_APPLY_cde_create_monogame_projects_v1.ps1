param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [ValidateSet("DesktopGL","WindowsDX")][string]$Flavor = "DesktopGL"
)

$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){
  $dir = Split-Path -Parent $path
  if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $bytes = $utf8.GetBytes($text.Replace("`r`n","`n"))
  [System.IO.File]::WriteAllBytes($path,$bytes)
}
function Parse-GateFile([string]$p){
  if(-not (Test-Path -LiteralPath $p -PathType Leaf)){ Die ("PARSE_GATE_MISSING: " + $p) }
  $tokens = $null
  $errs = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$tokens,[ref]$errs)
  if($errs -ne $null -and $errs.Count -gt 0){
    $msg = ($errs | ForEach-Object { $_.ToString() }) -join "`n"
    Die ("PARSE_GATE_FAIL:`n" + $p + "`n" + $msg)
  }
}

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Sln = Join-Path $RepoRootAbs "CDE.sln"
if(-not (Test-Path -LiteralPath $Sln -PathType Leaf)){ Die ("MISSING_SOLUTION: " + $Sln) }

$Pkg = if($Flavor -eq "WindowsDX"){ "MonoGame.Framework.WindowsDX" } else { "MonoGame.Framework.DesktopGL" }
Write-Host ("CDE_MONOGAME_FLAVOR: " + $Flavor + " package=" + $Pkg) -ForegroundColor Cyan

$GameDir = Join-Path $RepoRootAbs "src\CDE.Game"
$StudioDir = Join-Path $RepoRootAbs "src\CDE.SpriteStudio"
Ensure-Dir $GameDir
Ensure-Dir $StudioDir

$GameProj = Join-Path $GameDir "CDE.Game.csproj"
$StudioProj = Join-Path $StudioDir "CDE.SpriteStudio.csproj"
$RuntimeProj = Join-Path $RepoRootAbs "src\CDE.Runtime\CDE.Runtime.csproj"
if(-not (Test-Path -LiteralPath $RuntimeProj -PathType Leaf)){ Die ("MISSING_RUNTIME_PROJ: " + $RuntimeProj) }

# Create CDE.Game.csproj (WinExe, MonoGame package)
$gameCsproj = @()"@
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="$Pkg" Version="3.8.1.303" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\CDE.Runtime\CDE.Runtime.csproj" />
  </ItemGroup>
</Project>
"@
Write-Utf8NoBomLf $GameProj $gameCsproj

# Create CDE.SpriteStudio.csproj (WinExe, MonoGame package)
$studioCsproj = @()"@
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="$Pkg" Version="3.8.1.303" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\CDE.Runtime\CDE.Runtime.csproj" />
  </ItemGroup>
</Project>
"@
Write-Utf8NoBomLf $StudioProj $studioCsproj

Write-Host ("WROTE: " + $GameProj) -ForegroundColor Green
Write-Host ("WROTE: " + $StudioProj) -ForegroundColor Green

# Add to solution (idempotent-ish: dotnet sln add will no-op if already added)
& dotnet sln $Sln add $RuntimeProj | Out-Host
& dotnet sln $Sln add $GameProj | Out-Host
& dotnet sln $Sln add $StudioProj | Out-Host

# Restore
& dotnet restore $Sln | Out-Host

Write-Host "CDE_PROJECTS_OK: Game+SpriteStudio created and added to solution" -ForegroundColor Green
Write-Host "NEXT: run Forge" -ForegroundColor Yellow
Write-Host ("  dotnet run --project .\src\CDE.Tools.Forge\CDE.Tools.Forge.csproj -- run") -ForegroundColor Yellow
