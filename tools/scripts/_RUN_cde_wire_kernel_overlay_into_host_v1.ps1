param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Write-Utf8NoBomLf([string]$path,[string]$text){
  $u = New-Object System.Text.UTF8Encoding($false)
  $bytes = $u.GetBytes($text.Replace("`r`n","`n"))
  [System.IO.File]::WriteAllBytes($path,$bytes)
}
function Backup-IfExists([string]$p){
  if(Test-Path -LiteralPath $p -PathType Leaf){
    $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ")
    $bak=($p + ".bak_" + $ts)
    Copy-Item -LiteralPath $p -Destination $bak -Force
    Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow
  }
}
function ReadAllTextUtf8([string]$p){ return [System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8) }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$GameSrcDir = Join-Path $RepoRootAbs "src\CDE.Game"
if(-not (Test-Path -LiteralPath $GameSrcDir -PathType Container)){ Die ("MISSING_GAME_SRC_DIR: " + $GameSrcDir) }
$csFiles = Get-ChildItem -LiteralPath $GameSrcDir -Recurse -Filter *.cs -File | ForEach-Object { $_.FullName }
if(-not $csFiles -or $csFiles.Count -lt 1){ Die ("NO_CS_FILES_IN: " + $GameSrcDir) }

# Pick host candidate
$HostPath = $null
foreach($f in $csFiles){
  $t = ReadAllTextUtf8 $f
  if($t -match "GraphicsDeviceManager" -and $t -match "class\s+\w+"){ $HostPath = $f; break }
}
if([string]::IsNullOrWhiteSpace($HostPath)){
  foreach($f in $csFiles){
    $t = ReadAllTextUtf8 $f
    if($t -match "Microsoft\.Xna\.Framework\.Game" -or $t -match "GameWindow"){ $HostPath = $f; break }
  }
}
if([string]::IsNullOrWhiteSpace($HostPath)){ Die "CANNOT_FIND_HOST_CANDIDATE: no file mentions GraphicsDeviceManager/GameWindow/Microsoft.Xna.Framework.Game" }

$HostText = ReadAllTextUtf8 $HostPath
if($HostText -match "CDE_KERNEL_OVERLAY_V3B"){ Write-Host ("SKIP: already wired: " + $HostPath) -ForegroundColor Yellow; return }
Backup-IfExists $HostPath
$t = $HostText.Replace("`r`n","`n")

# Ensure using for System.IO and CDE.Game types are in same namespace already
if($t -notmatch "using\s+System\.IO\s*;"){
  if($t -match "using\s+System\s*;"){
    $t = [System.Text.RegularExpressions.Regex]::Replace($t,"using\s+System\s*;","using System;`nusing System.IO;")
  } else {
    $t = ("using System.IO;`n" + $t)
  }
}

# Insert fields after first class open brace
$t = [System.Text.RegularExpressions.Regex]::Replace(
  $t,
  "(class\s+\w+.*?\{)",
  ('$1' + "`n    // CDE_KERNEL_OVERLAY_V3B`n    private GameplayBridge? _kernel;`n    private KernelOverlayComponent? _kernelOverlay;"),
  1,
  [System.Text.RegularExpressions.RegexOptions]::Singleline
)

# Add helper methods at end before final }
$helper = @(
'    private static string FindRepoRoot(string start)'
'    {'
'        var d = new DirectoryInfo(start);'
'        for (int i = 0; i < 12 && d != null; i++)'
'        {'
'            var sln = Path.Combine(d.FullName, "CDE.sln");'
'            if (File.Exists(sln)) return d.FullName;'
'            d = d.Parent;'
'        }'
'        return Directory.GetCurrentDirectory();'
'    }'
''
'    private void EnsureKernelOverlay()'
'    {'
'        if (_kernelOverlay != null) return;'
'        var root = FindRepoRoot(AppContext.BaseDirectory);'
'        _kernel = new GameplayBridge();'
'        _kernel.LoadFromRepoRoot(root);'
'        _kernelOverlay = new KernelOverlayComponent(this, _kernel);'
'        Components.Add(_kernelOverlay);'
'    }'
)
$helperText = (@($helper) -join "`n")
$t = [System.Text.RegularExpressions.Regex]::Replace($t,"\}\s*$",("`n" + $helperText + "`n}`n"))

# Call EnsureKernelOverlay in Initialize or LoadContent (first match)
if($t -match "override\s+void\s+Initialize\s*\("){
  $t = [System.Text.RegularExpressions.Regex]::Replace($t,"(override\s+void\s+Initialize\s*\(\s*\)\s*\{)",('$1' + "`n        EnsureKernelOverlay();"),1)
} elseif($t -match "override\s+void\s+LoadContent\s*\("){
  $t = [System.Text.RegularExpressions.Regex]::Replace($t,"(override\s+void\s+LoadContent\s*\(\s*\)\s*\{)",('$1' + "`n        EnsureKernelOverlay();"),1)
} else {
  Die ("HOST_HAS_NO_INITIALIZE_OR_LOADCONTENT: " + $HostPath)
}

Write-Utf8NoBomLf $HostPath ($t + "`n")
Write-Host ("PATCH_OK: wired overlay into host: " + $HostPath) -ForegroundColor Green
