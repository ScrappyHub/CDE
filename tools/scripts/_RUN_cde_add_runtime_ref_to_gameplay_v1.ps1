param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir = Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u = New-Object System.Text.UTF8Encoding($false); $bytes = $u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$bytes) }
function Backup-IfExists([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force; Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow } }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$RuntimeProj = Join-Path $RepoRootAbs "src\CDE.Runtime\CDE.Runtime.csproj"
if(-not (Test-Path -LiteralPath $RuntimeProj -PathType Leaf)){ Die ("MISSING_RUNTIME_CSPROJ: " + $RuntimeProj) }
$GameplayProjRel = "..\CDE.Gameplay\CDE.Gameplay.csproj"

$t = [System.IO.File]::ReadAllText($RuntimeProj,[System.Text.Encoding]::UTF8)
$t = $t.Replace("`r`n","`n")
if($t -match "CDE\.Gameplay\.csproj"){
  Write-Host ("OK: CDE.Runtime already references CDE.Gameplay: " + $RuntimeProj) -ForegroundColor Green
} else {
  Backup-IfExists $RuntimeProj
  $ins = @(
    "  <ItemGroup>",
    ("    <ProjectReference Include=`"" + $GameplayProjRel + "`" />"),
    "  </ItemGroup>"
  )
  $insText = (@($ins) -join "`n")
  if($t -match "</Project>\s*$"){
    $t = [System.Text.RegularExpressions.Regex]::Replace($t,"</Project>\s*$",($insText + "`n</Project>`n"))
  } else { Die ("CSPROJ_NO_CLOSING_PROJECT_TAG: " + $RuntimeProj) }
  Write-Utf8NoBomLf $RuntimeProj ($t + "`n")
  Write-Host ("PATCH_OK: added ProjectReference (Runtime -> Gameplay): " + $RuntimeProj) -ForegroundColor Green
}

Write-Host "NOW_BUILD: dotnet build .\CDE.sln -c Debug" -ForegroundColor Yellow
