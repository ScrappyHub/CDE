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

$csproj = Join-Path $RepoRootAbs "src\CDE.SpriteStudio\CDE.SpriteStudio.csproj"
if(-not (Test-Path -LiteralPath $csproj -PathType Leaf)){ Die ("MISSING_SPRITESTUDIO_CSPROJ: " + $csproj) }

$orig = [System.IO.File]::ReadAllText($csproj,[System.Text.Encoding]::UTF8)
$lines = $orig.Replace("`r`n","`n") -split "`n"
$out = New-Object System.Collections.Generic.List[string]
$changed = $false
$inProp = $false
$sawOutput = $false

for($i=0; $i -lt $lines.Length; $i++){
  $ln = $lines[$i]
  $trim = $ln.Trim()
  if($trim -like "<PropertyGroup*>" ){ $inProp = $true }
  if($inProp -and $trim -eq "</PropertyGroup>"){
    if(-not $sawOutput){
      [void]$out.Add("    <OutputType>Library</OutputType>")
      $changed = $true
    }
    $inProp = $false
    [void]$out.Add($ln)
    continue
  }

  if($inProp -and $trim -like "<OutputType>*</OutputType>"){
    $sawOutput = $true
    if($trim -ne "<OutputType>Library</OutputType>"){
      [void]$out.Add("    <OutputType>Library</OutputType>")
      $changed = $true
    } else {
      [void]$out.Add($ln)
    }
    continue
  }

  [void]$out.Add($ln)
}

if($changed){
  $bak = Backup-File $csproj
  $newText = (@($out.ToArray()) -join "`n")
  if(-not $newText.EndsWith("`n")){ $newText = $newText + "`n" }
  Write-Utf8NoBomLf $csproj $newText
  Write-Host ("PATCH_OK: SpriteStudio OutputType -> Library (backup=" + $bak + "): " + $csproj) -ForegroundColor Green
} else {
  Write-Host ("PATCH_NOOP: SpriteStudio csproj already Library: " + $csproj) -ForegroundColor Yellow
}

& dotnet build $Sln -c Debug | Out-Host
if($LASTEXITCODE -ne 0){ Die "DOTNET_BUILD_FAILED_AFTER_SPRITESTUDIO_PATCH" }
Write-Host "CDE_SPRITESTUDIO_PATCH_OK: build ok" -ForegroundColor Green
