$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
param([Parameter(Mandatory=$true)][string]$RepoRoot)

function Die([string]$m){ throw $m }
function ReadUtf8([string]$p){ [System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8) }
function WriteUtf8NoBomLf([string]$path,[string]$text){
  $u = New-Object System.Text.UTF8Encoding($false)
  $bytes = $u.GetBytes($text.Replace("
","
"))
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

$GameRoot = Join-Path $RepoRoot "src\CDE.Game\GameRoot.cs"
if(-not (Test-Path -LiteralPath $GameRoot -PathType Leaf)){ Die ("MISSING: " + $GameRoot) }
Backup-IfExists $GameRoot

$t = (ReadUtf8 $GameRoot).Replace("
","
")

# --- Blocks as arrays (quote-safe) ---
$FieldsLines = @(
'    // CDE_GAME_PICKUPS_V4',
'    private enum PickupKind { Coin, Cherry }',
'    private struct Pickup',
'    {',
'        public PickupKind Kind;',
'        public Rectangle Rect;',
'        public bool Taken;',
'    }',
'    private readonly System.Collections.Generic.List<Pickup> _pickups = new();',
'    private Rectangle _goalRect;',
'    private int _coins = 0;',
'    private int _cherries = 0;',
'    private bool _goalReached = false;'
)
$Fields = ((@($FieldsLines) -join "
") + "
")

$InitLines = @(
'        // CDE_GAME_PICKUPS_INIT_V4',
'        _pickups.Clear();',
'        _coins = 0; _cherries = 0; _goalReached = false;',
'        _pickups.Add(new Pickup { Kind = PickupKind.Coin,   Rect = new Rectangle( 80, 120, 10, 10), Taken = false });',
'        _pickups.Add(new Pickup { Kind = PickupKind.Coin,   Rect = new Rectangle(160, 120, 10, 10), Taken = false });',
'        _pickups.Add(new Pickup { Kind = PickupKind.Coin,   Rect = new Rectangle(240, 120, 10, 10), Taken = false });',
'        _pickups.Add(new Pickup { Kind = PickupKind.Cherry, Rect = new Rectangle(200,  80, 10, 10), Taken = false });',
'        _goalRect = new Rectangle(300, 112, 12, 24);'
)
$Init = ((@($InitLines) -join "
") + "
")

$UpdLines = @(
'        // CDE_GAME_PICKUPS_UPDATE_V4',
'        var pr = new Rectangle((int)_ctrl.X, (int)_ctrl.Y, (int)_ctrl.W, (int)_ctrl.H);',
'        for (int i = 0; i < _pickups.Count; i++)',
'        {',
'            var p = _pickups[i];',
'            if (p.Taken) continue;',
'            if (pr.Intersects(p.Rect))',
'            {',
'                p.Taken = true;',
'                if (p.Kind == PickupKind.Coin) _coins++; else _cherries++;',
'                _pickups[i] = p;',
'            }',
'        }',
'        if (!_goalReached && _coins >= 3 && pr.Intersects(_goalRect))',
'        {',
'            _goalReached = true;',
'        }',
'        Window.Title = "CDE.Game coins=" + _coins + "/3 cherries=" + _cherries + " goal=" + (_goalReached ? 1 : 0);'
)
$Upd = ((@($UpdLines) -join "
") + "
")

$DrawLines = @(
'        // CDE_GAME_PICKUPS_DRAW_V4',
'        for (int i = 0; i < _pickups.Count; i++)',
'        {',
'            var p = _pickups[i];',
'            if (p.Taken) continue;',
'            var c = (p.Kind == PickupKind.Coin) ? new Color(240, 220, 40) : new Color(220, 60, 80);',
'            _sb.Draw(_px, p.Rect, c);',
'        }',
'        var goalC = _goalReached ? new Color(80, 200, 120) : new Color(40, 120, 80);',
'        _sb.Draw(_px, _goalRect, goalC);',
'        if (_font != null)',
'        {',
'            _sb.DrawString(_font, "coins " + _coins + "/3  cherries " + _cherries + "  goal " + (_goalReached ? "OK" : "LOCK"), new Vector2(8, 8), Color.White);',
'        }'
)
$Draw = ((@($DrawLines) -join "
") + "
")

# 1) Insert fields after class open
if($t -notmatch "CDE_GAME_PICKUPS_V4"){
  $m = [System.Text.RegularExpressions.Regex]::Match($t, "(?s)class\\s+GameRoot.*?\\{")
  if(-not $m.Success){ Die "ANCHOR_CLASS_OPEN_NOT_FOUND" }
  $ins = $m.Value + "
" + $Fields + "
"
  $t2 = $ins + $t.Substring($m.Length)
  if($t2 -eq $t){ Die "FAILED_INSERT_FIELDS" }
  $t = $t2
}

# 2) Inject init right after LoadContent {
if($t -notmatch "CDE_GAME_PICKUPS_INIT_V4"){
  $m = [System.Text.RegularExpressions.Regex]::Match($t, "(?s)void\\s+LoadContent\\s*\\(\\s*\\)\\s*\\{")
  if(-not $m.Success){ Die "ANCHOR_LOADCONTENT_NOT_FOUND" }
  $idx = $m.Index + $m.Length
  $t2 = $t.Substring(0,$idx) + "

" + $Init + "
" + $t.Substring($idx)
  if($t2 -eq $t){ Die "FAILED_INSERT_INIT" }
  $t = $t2
}

# 3) Inject update after _cam.Follow(...)
if($t -notmatch "CDE_GAME_PICKUPS_UPDATE_V4"){
  $pat = "(?m)^\\s*_cam\\.Follow\\s*\\(.*\\)\\s*;\\s*$"
  $m = [System.Text.RegularExpressions.Regex]::Match($t, $pat)
  if(-not $m.Success){ Die "ANCHOR_CAM_FOLLOW_NOT_FOUND" }
  $rep = $m.Value + "

" + $Upd
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t, $pat, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $rep }, 1)
  if($t2 -eq $t){ Die "FAILED_INSERT_UPDATE" }
  $t = $t2
}

# 4) Inject draw before _sb.End()
if($t -notmatch "CDE_GAME_PICKUPS_DRAW_V4"){
  $endPat = "(?m)^\\s*_sb\\.End\\s*\\(\\s*\\)\\s*;\\s*$"
  $m = [System.Text.RegularExpressions.Regex]::Match($t, $endPat)
  if(-not $m.Success){ Die "ANCHOR_SB_END_NOT_FOUND" }
  $rep = $Draw + "
" + $m.Value
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t, $endPat, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $rep }, 1)
  if($t2 -eq $t){ Die "FAILED_INSERT_DRAW" }
  $t = $t2
}

WriteUtf8NoBomLf $GameRoot ($t + "
")
Write-Host ("PATCH_OK: pickups+goal v4 applied: " + $GameRoot) -ForegroundColor Green
