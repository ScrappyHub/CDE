param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function ReadAllTextUtf8([string]$p){ return [System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8) }
function WriteUtf8NoBomLf([string]$path,[string]$text){ $u = New-Object System.Text.UTF8Encoding($false); $bytes = $u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$bytes) }
function Backup-IfExists([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force; Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow } }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$GameRoot = Join-Path $RepoRootAbs "src\CDE.Game\GameRoot.cs"
if(-not (Test-Path -LiteralPath $GameRoot -PathType Leaf)){ Die ("MISSING_GAMEROOT: " + $GameRoot) }
Backup-IfExists $GameRoot
$t = ReadAllTextUtf8 $GameRoot
$t = $t.Replace("`r`n","`n")
$orig = $t

if($t -notmatch "CDE_GAME_PICKUPS_V1"){
  $anchor = "(?m)^\s*private\s+SpriteFont\?\s+_font\s*;\s*$"
  $m = [System.Text.RegularExpressions.Regex]::Match($t, $anchor)
  if(-not $m.Success){ Die ("ANCHOR_FONT_FIELD_NOT_FOUND_FOR_PICKUPS: " + $GameRoot) }
  $ins = $m.Value + "`n`n    // CDE_GAME_PICKUPS_V1`n    private enum PickupKind { Coin, Cherry }`n    private struct Pickup { public PickupKind Kind; public Rectangle Rect; public bool Taken; }`n    private readonly System.Collections.Generic.List<Pickup> _pickups = new();`n    private Rectangle _goalRect;`n    private int _coins = 0;`n    private int _cherries = 0;`n    private bool _goalReached = false;"
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t, $anchor, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $ins }, 1)
  if($t2 -eq $t){ Die ("FAILED_INSERT_PICKUP_FIELDS: " + $GameRoot) }
  $t = $t2
}

if($t -notmatch "CDE_GAME_PICKUPS_INIT_V1"){
  $lines = $t -split "`n"
  $out = New-Object System.Collections.Generic.List[string]
  $in = $false; $depth = 0; $done = $false
  for($i=0; $i -lt $lines.Length; $i++){
    $ln = $lines[$i]
    if(-not $in -and $ln -match "^\s*protected\s+override\s+void\s+LoadContent\s*\(\s*\)\s*\{"){ $in=$true; $depth=1; [void]$out.Add($ln); continue }
    if($in -and -not $done){
      # track braces (simple, good enough for this file)
      $open = ([regex]::Matches($ln,"\{")).Count
      $close = ([regex]::Matches($ln,"\}")).Count
      if(($depth + $open - $close) -eq 0){
        # about to close LoadContent -> inject just before this line
        [void]$out.Add("        // CDE_GAME_PICKUPS_INIT_V1")
        [void]$out.Add("        _pickups.Clear();")
        [void]$out.Add("        // world-space pixels (tile size is 16; keep them reachable)")
        [void]$out.Add("        _pickups.Add(new Pickup { Kind = PickupKind.Coin,   Rect = new Rectangle( 9*16,  7*16, 10, 10), Taken = false });")
        [void]$out.Add("        _pickups.Add(new Pickup { Kind = PickupKind.Coin,   Rect = new Rectangle(12*16,  7*16, 10, 10), Taken = false });")
        [void]$out.Add("        _pickups.Add(new Pickup { Kind = PickupKind.Coin,   Rect = new Rectangle(15*16,  7*16, 10, 10), Taken = false });")
        [void]$out.Add("        _pickups.Add(new Pickup { Kind = PickupKind.Cherry, Rect = new Rectangle(24*16,  9*16, 10, 10), Taken = false });")
        [void]$out.Add("        _pickups.Add(new Pickup { Kind = PickupKind.Cherry, Rect = new Rectangle(27*16,  9*16, 10, 10), Taken = false });")
        [void]$out.Add("        _goalRect = new Rectangle(29*16, 7*16, 14, 14);")
        [void]$out.Add("        _coins = 0; _cherries = 0; _goalReached = false;")
        [void]$out.Add("        Window.Title = ""CDE.Game coins=0/3 cherries=0 goal=0  (touch goal after 3 coins)"";")
        $done = $true
      }
      $depth = $depth + $open - $close
      if($depth -le 0){ $in=$false }
    }
    [void]$out.Add($ln)
  }
  if(-not $done){ Die ("FAILED_TO_INJECT_PICKUPS_INIT_IN_LOADCONTENT: " + $GameRoot) }
  $t = (@($out.ToArray()) -join "`n")
}

if($t -notmatch "CDE_GAME_PICKUPS_UPDATE_V1"){
  $pat = "(?m)^\s*_cam\.Follow\s*\(.*\)\s*;\s*$"
  $m = [System.Text.RegularExpressions.Regex]::Match($t, $pat)
  if(-not $m.Success){ Die ("ANCHOR_CAM_FOLLOW_NOT_FOUND_FOR_PICKUPS_UPDATE: " + $GameRoot) }
  $blk = $m.Value + "`n`n        // CDE_GAME_PICKUPS_UPDATE_V1`n        var pr = new Rectangle((int)_ctrl.X, (int)_ctrl.Y, (int)_ctrl.W, (int)_ctrl.H);`n        for (int i = 0; i < _pickups.Count; i++)`n        {`n            var p = _pickups[i];`n            if (p.Taken) continue;`n            if (pr.Intersects(p.Rect))`n            {`n                p.Taken = true;`n                if (p.Kind == PickupKind.Coin) _coins++; else _cherries++;`n                _pickups[i] = p;`n            }`n        }`n        if (!_goalReached && _coins >= 3 && pr.Intersects(_goalRect))`n        {`n            _goalReached = true;`n        }`n        Window.Title = ""CDE.Game coins="" + _coins + ""/3 cherries="" + _cherries + "" goal="" + (_goalReached ? 1 : 0);"`n
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t, $pat, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $blk }, 1)
  if($t2 -eq $t){ Die ("FAILED_INSERT_PICKUPS_UPDATE: " + $GameRoot) }
  $t = $t2
}

if($t -notmatch "CDE_GAME_PICKUPS_DRAW_V1"){
  $endPat = "(?m)^\s*_sb\.End\s*\(\s*\)\s*;\s*$"
  $m = [System.Text.RegularExpressions.Regex]::Match($t, $endPat)
  if(-not $m.Success){ Die ("ANCHOR_SB_END_NOT_FOUND_FOR_PICKUPS_DRAW: " + $GameRoot) }
  $draw = @(
    "        // CDE_GAME_PICKUPS_DRAW_V1",
    "        // coins = yellow-ish, cherries = red-ish, goal = green-ish",
    "        for (int i = 0; i < _pickups.Count; i++)",
    "        {",
    "            var p = _pickups[i];",
    "            if (p.Taken) continue;",
    "            var c = (p.Kind == PickupKind.Coin) ? new Color(240, 220, 40) : new Color(220, 60, 80);",
    "            _sb.Draw(_px, p.Rect, c);",
    "        }",
    "        var goalC = _goalReached ? new Color(80, 200, 120) : new Color(40, 120, 80);",
    "        _sb.Draw(_px, _goalRect, goalC);",
    ""
  ) -join "`n"
  $rep = $draw + "`n" + $m.Value
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t, $endPat, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $rep }, 1)
  if($t2 -eq $t){ Die ("FAILED_INSERT_PICKUPS_DRAW: " + $GameRoot) }
  $t = $t2
}

WriteUtf8NoBomLf $GameRoot ($t + "`n")
Write-Host ("PATCH_OK: added pickups+goal to CDE.Game (coins/cherries/goal) : " + $GameRoot) -ForegroundColor Green
Write-Host "NEXT: dotnet build .\CDE.sln -c Debug" -ForegroundColor Yellow
Write-Host "NEXT: dotnet run --project .\src\CDE.Game\CDE.Game.csproj -c Debug" -ForegroundColor Yellow
