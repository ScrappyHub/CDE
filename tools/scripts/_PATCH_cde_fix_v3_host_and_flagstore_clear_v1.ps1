param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir = Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u = New-Object System.Text.UTF8Encoding($false); $bytes = $u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$bytes) }
function Backup-IfExists([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force; Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow } }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Runner = Join-Path $RepoRootAbs "tools\scripts\_RUN_cde_kernel_overlay_menu_damage_v3.ps1"
if(-not (Test-Path -LiteralPath $Runner -PathType Leaf)){ Die ("MISSING_RUNNER_V3: " + $Runner) }

# --- FIX #1: $Host collision in runner v3 (PowerShell variables are case-insensitive) ---
Backup-IfExists $Runner
$rt = [System.IO.File]::ReadAllText($Runner,[System.Text.Encoding]::UTF8)
$changesRunner = 0
if($rt -match "^\s*\$host\s*=\s*ReadAllTextUtf8\s+\$HostPath\s*$"){
  $rt2 = $rt -replace "(?m)^\s*\$host\s*=\s*ReadAllTextUtf8\s+\$HostPath\s*$", "\$hostText = ReadAllTextUtf8 \$HostPath"
  if($rt2 -ne $rt){ $rt = $rt2; $changesRunner++ }
}
$rt2 = $rt -replace "(?m)\bif\s*\(\s*\$host\s+-notmatch\b", "if(`$hostText -notmatch"
if($rt2 -ne $rt){ $rt = $rt2; $changesRunner++ }
if($changesRunner -gt 0){ Write-Utf8NoBomLf $Runner $rt; Write-Host ("PATCH_OK: runner v3 host var fix changes=" + $changesRunner) -ForegroundColor Green } else { Write-Host "SKIP: runner v3 host var already OK" -ForegroundColor Yellow }

# --- FIX #2: FlagStore has no Clear() (remove that line) ---
$Bridge = Join-Path $RepoRootAbs "src\CDE.Runtime\Engine\GameplayBridge.cs"
if(-not (Test-Path -LiteralPath $Bridge -PathType Leaf)){ Die ("MISSING_GAMEPLAYBRIDGE: " + $Bridge) }
Backup-IfExists $Bridge
$lines = [System.IO.File]::ReadAllLines($Bridge,[System.Text.Encoding]::UTF8)
$out = New-Object System.Collections.Generic.List[string]
$removed = 0
for($i=0; $i -lt $lines.Length; $i++){
  $ln = $lines[$i]
  if($ln -match "^\s*Flags\.Clear\(\)\s*;\s*$"){ $removed++; continue }
  [void]$out.Add($ln)
}
if($removed -gt 0){
  $newText = (@($out.ToArray()) -join "`n") + "`n"
  Write-Utf8NoBomLf $Bridge $newText
  Write-Host ("PATCH_OK: removed Flags.Clear() calls removed=" + $removed) -ForegroundColor Green
} else {
  Write-Host "SKIP: no Flags.Clear() found" -ForegroundColor Yellow
}

Write-Host "NEXT: dotnet build .\CDE.sln -c Debug" -ForegroundColor Yellow
