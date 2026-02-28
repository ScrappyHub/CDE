param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function WriteUtf8NoBomLf([string]$path,[string]$text){ $u = New-Object System.Text.UTF8Encoding($false); $bytes = $u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$bytes) }
function ReadAllTextUtf8([string]$p){ return [System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8) }
function Backup-IfExists([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force; Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow } }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Overlay = Join-Path $RepoRootAbs "src\CDE.Runtime\Engine\KernelOverlayComponent.cs"
if(-not (Test-Path -LiteralPath $Overlay -PathType Leaf)){ Die ("MISSING_OVERLAY: " + $Overlay) }
Backup-IfExists $Overlay
$t = ReadAllTextUtf8 $Overlay
$t = $t.Replace("`r`n","`n")
$orig = $t

if($t -notmatch "(?m)^\s*using\s+System\s*;\s*$"){ $t = ("using System;`n" + $t) }
if($t -notmatch "(?m)^\s*using\s+System\.IO\s*;\s*$"){ $t = ("using System.IO;`n" + $t) }

if($t -notmatch "CDE_KERNEL_OVERLAY_AUTOLOAD_GRAPHS_V1"){
  $pat = "(?m)^\s*private\s+bool\s+_menu\s*;\s*$"
  $m = [System.Text.RegularExpressions.Regex]::Match($t, $pat)
  if(-not $m.Success){ Die ("NO_MENU_FIELD_ANCHOR_FOUND: " + $Overlay) }
  $ins = $m.Value + "`n`n    // CDE_KERNEL_OVERLAY_AUTOLOAD_GRAPHS_V1`n    private bool _graphsLoaded = false;"
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t, $pat, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $ins }, 1)
  if($t2 -eq $t){ Die ("FAILED_INSERT_FIELDS: " + $Overlay) }
  $t = $t2
}

if($t -notmatch "TryFindRepoRootForGraphs"){
  $uPat = "(?m)^\s*public\s+override\s+void\s+Update\s*\(\s*GameTime\s+gameTime\s*\)\s*$"
  $m2 = [System.Text.RegularExpressions.Regex]::Match($t, $uPat)
  if(-not $m2.Success){ Die ("UPDATE_SIGNATURE_NOT_FOUND_FOR_INSERT: " + $Overlay) }
  $helper = @(
    "    private static string? TryFindRepoRootForGraphs()",
    "    {",
    "        try",
    "        {",
    "            var dir = new DirectoryInfo(AppContext.BaseDirectory);",
    "            for (int i = 0; i < 8 && dir != null; i++)",
    "            {",
    "                var sln = Path.Combine(dir.FullName, ""CDE.sln"");",
    "                if (File.Exists(sln)) return dir.FullName;",
    "                dir = dir.Parent;",
    "            }",
    "        }",
    "        catch { }",
    "        return null;",
    "    }",
    ""
  ) -join "`n"
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t, $uPat, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) ($helper + "`n" + $mm.Value) }, 1)
  if($t2 -eq $t){ Die ("FAILED_INSERT_HELPER_METHOD: " + $Overlay) }
  $t = $t2
}

if($t -notmatch "CDE_KERNEL_OVERLAY_AUTOLOAD_GRAPHS_UPDATEBLOCK_V1"){
  $kPat = "(?m)^\s*var\s+k\s*=\s*Keyboard\.GetState\s*\(\s*\)\s*;\s*$"
  $m3 = [System.Text.RegularExpressions.Regex]::Match($t, $kPat)
  if(-not $m3.Success){ Die ("KEYBOARD_GETSTATE_LINE_NOT_FOUND: " + $Overlay) }
  $blk = $m3.Value + "`n`n        // CDE_KERNEL_OVERLAY_AUTOLOAD_GRAPHS_UPDATEBLOCK_V1`n        if (!_graphsLoaded)`n        {`n            var rr = TryFindRepoRootForGraphs();`n            if (!string.IsNullOrWhiteSpace(rr))`n            {`n                _bridge.LoadFromRepoRoot(rr);`n                _graphsLoaded = true;`n            }`n        }"
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t, $kPat, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $blk }, 1)
  if($t2 -eq $t){ Die ("FAILED_INSERT_AUTOLOAD_BLOCK: " + $Overlay) }
  $t = $t2
}

if($t -eq $orig){ Write-Host "PATCH_OK: runtime overlay already had autoload graphs blocks" -ForegroundColor Green } else { WriteUtf8NoBomLf $Overlay ($t + "`n"); Write-Host ("PATCH_OK: runtime overlay now autoloads gameplay graphs once: " + $Overlay) -ForegroundColor Green }
Write-Host "NEXT: dotnet build .\CDE.sln -c Debug" -ForegroundColor Yellow
Write-Host "NEXT: dotnet run --project .\src\CDE.Game\CDE.Game.csproj -c Debug" -ForegroundColor Yellow
