param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir=Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }; $u=New-Object System.Text.UTF8Encoding($false); $b=$u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$b) }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Sln = Join-Path $RepoRootAbs "CDE.sln"
if(-not (Test-Path -LiteralPath $Sln -PathType Leaf)){ Die ("MISSING_SOLUTION: " + $Sln) }

# --- 1) Fix Forge RunCommand.cs Arguments line ---
$runCmd = Join-Path $RepoRootAbs "src\CDE.Tools.Forge\Commands\RunCommand.cs"
if(-not (Test-Path -LiteralPath $runCmd -PathType Leaf)){ Die ("MISSING_FILE: " + $runCmd) }
$lines = [System.IO.File]::ReadAllLines($runCmd)
$out = New-Object System.Collections.Generic.List[string]
$changed = $false
for($i=0; $i -lt $lines.Length; $i++){
  $ln = $lines[$i]
  if($ln -match "^\s*Arguments\s*="){
    # Correct C# interpolated string: braces NOT escaped; quotes escaped
    [void]$out.Add("            Arguments = $`"run --project \`"{gameProj}\`"`",")
    $changed = $true
  } else {
    [void]$out.Add($ln)
  }
}
if(-not $changed){ Die ("PATCH_FAIL: did not find Arguments= line in " + $runCmd) }
$newText = (@($out.ToArray()) -join "`n") + "`n"
Write-Utf8NoBomLf $runCmd $newText
Write-Host ("PATCH_OK: RunCommand.cs Arguments fixed: " + $runCmd) -ForegroundColor Green

# --- 2) Fix CDE.Runtime target framework (net10.0 -> net8.0) ---
$runtimeProj = Join-Path $RepoRootAbs "src\CDE.Runtime\CDE.Runtime.csproj"
if(-not (Test-Path -LiteralPath $runtimeProj -PathType Leaf)){ Die ("MISSING_FILE: " + $runtimeProj) }
$rt = [System.IO.File]::ReadAllText($runtimeProj, [System.Text.Encoding]::UTF8)
$before = "<TargetFramework>net10.0</TargetFramework>"
$after  = "<TargetFramework>net8.0</TargetFramework>"
if($rt -notmatch [regex]::Escape($before)){
  # also handle TargetFrameworks case if it exists
  if($rt -match "<TargetFrameworks>\s*net10\.0\s*</TargetFrameworks>"){
    $rt2 = [regex]::Replace($rt, "<TargetFrameworks>\s*net10\.0\s*</TargetFrameworks>", "<TargetFrameworks>net8.0</TargetFrameworks>")
    Write-Utf8NoBomLf $runtimeProj $rt2
    Write-Host ("PATCH_OK: CDE.Runtime TargetFrameworks net10.0->net8.0: " + $runtimeProj) -ForegroundColor Green
  } else {
    Die ("PATCH_FAIL: could not find net10.0 TargetFramework in " + $runtimeProj)
  }
} else {
  $rt2 = $rt.Replace($before,$after)
  Write-Utf8NoBomLf $runtimeProj $rt2
  Write-Host ("PATCH_OK: CDE.Runtime TargetFramework net10.0->net8.0: " + $runtimeProj) -ForegroundColor Green
}

# --- 3) Restore solution ---
& dotnet restore $Sln | Out-Host
Write-Host "CDE_PATCH_OK: runtime tfm + forge args fixed + restore ok" -ForegroundColor Green
