param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function ReadAllTextUtf8([string]$p){ return [System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8) }
function WriteUtf8NoBomLf([string]$path,[string]$text){ $u = New-Object System.Text.UTF8Encoding($false); $bytes = $u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$bytes) }
function Backup-IfExists([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force; Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow } }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$ToolsDir = Join-Path $RepoRootAbs "tools\scripts"
$Bad = Join-Path $ToolsDir "_PATCH_cde_game_add_pickups_goal_v1.ps1"
if(-not (Test-Path -LiteralPath $Bad -PathType Leaf)){ Die ("MISSING_BAD_PATCHER: " + $Bad) }
Backup-IfExists $Bad
$t = ReadAllTextUtf8 $Bad
$t = $t.Replace("`r`n","`n")

# Replace the entire $blk assignment with a safe one (single-quoted; no stray `n tokens)
$pat = "(?m)^\s*\$blk\s*=\s*\$m\.Value\s*\+\s*.*$"
$m = [System.Text.RegularExpressions.Regex]::Match($t, $pat)
if(-not $m.Success){ Die ("CANNOT_FIND_BLK_ASSIGNMENT_TO_REPLACE: " + $Bad) }

$safe = '  $blk = $m.Value + "`n`n' +
'        // CDE_GAME_PICKUPS_UPDATE_V1`n' +
'        var pr = new Rectangle((int)_ctrl.X, (int)_ctrl.Y, (int)_ctrl.W, (int)_ctrl.H);`n' +
'        for (int i = 0; i < _pickups.Count; i++)`n' +
'        {`n' +
'            var p = _pickups[i];`n' +
'            if (p.Taken) continue;`n' +
'            if (pr.Intersects(p.Rect))`n' +
'            {`n' +
'                p.Taken = true;`n' +
'                if (p.Kind == PickupKind.Coin) _coins++; else _cherries++;`n' +
'                _pickups[i] = p;`n' +
'            }`n' +
'        }`n' +
'        if (!_goalReached && _coins >= 3 && pr.Intersects(_goalRect))`n' +
'        {`n' +
'            _goalReached = true;`n' +
'        }`n' +
'        Window.Title = "CDE.Game coins=" + _coins + "/3 cherries=" + _cherries + " goal=" + (_goalReached ? 1 : 0);'

$t2 = [System.Text.RegularExpressions.Regex]::Replace($t, $pat, $safe, 1)
if($t2 -eq $t){ Die ("REPLACE_NOOP: " + $Bad) }
WriteUtf8NoBomLf $Bad ($t2 + "`n")
Write-Host ("PATCH_OK: fixed $blk line in bad pickups patcher: " + $Bad) -ForegroundColor Green
