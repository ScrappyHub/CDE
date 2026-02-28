param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function Write-Utf8NoBomLf([string]$path,[string]$text){
  $dir = Split-Path -Parent $path
  if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }
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

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$BridgePath = Join-Path $RepoRootAbs "src\CDE.Game\GameplayBridge.cs"
Backup-IfExists $BridgePath

$bridge = @(
  'using System.IO;'
  'using System.Text;'
  'using CDE.Gameplay.Kernel;'
  ''
  'namespace CDE.Game;'
  ''
  'internal sealed class GameplayBridge'
  '{'
  '    public enum Mode { Yume, Mario }'
  '    public Mode ActiveMode { get; private set; } = Mode.Yume;'
  ''
  '    public string SceneId { get; private set; } = "StartRoom";'
  '    public float X { get; private set; } = 1f;'
  '    public float Y { get; private set; } = 1f;'
  ''
  '    public readonly FlagStore Flags = new();'
  '    private WarpKernel? _warp;'
  '    private KernelWorld? _mario;'
  '    public string Last { get; private set; } = "";'
  ''
  '    public void SetMode(Mode m)'
  '    {'
  '        ActiveMode = m;'
  '        if (m == Mode.Yume) { SceneId = "StartRoom"; X = 1f; Y = 1f; }'
  '        else { SceneId = "MarioRoom"; X = 0f; Y = 0f; }'
  '        Last = "";'
  '    }'
  ''
  '    public void LoadFromRepoRoot(string repoRoot)'
  '    {'
  '        var yumePath = Path.Combine(repoRoot, "assets_src", "gameplay", "warp_graph.v1.json");'
  '        var marioPath = Path.Combine(repoRoot, "assets_src", "gameplay", "mario_graph.v1.json");'
  ''
  '        if (File.Exists(yumePath))'
  '        {'
  '            var json = File.ReadAllText(yumePath, new UTF8Encoding(false));'
  '            var g = WarpKernel.LoadWarpGraphJson(json);'
  '            _warp = new WarpKernel(g, Flags);'
  '        }'
  ''
  '        if (File.Exists(marioPath))'
  '        {'
  '            var json = File.ReadAllText(marioPath, new UTF8Encoding(false));'
  '            _mario = KernelWorld.LoadMarioJson(json);'
  '        }'
  '    }'
  ''
  '    public int GetCoins() => _mario?.Inventory.GetCount("coin") ?? 0;'
  '    public int GetCoinTarget() => _mario?.Objectives.CoinTarget ?? 0;'
  ''
  '    public void Move(float dx, float dy){ X += dx; Y += dy; }'
  ''
  '    public void Tick()'
  '    {'
  '        if (ActiveMode == Mode.Yume)'
  '        {'
  '            if (_warp == null) { Last = ""; return; }'
  '            var r = _warp.TryWarp(new WarpKernel.WarpRequest(SceneId, X, Y));'
  '            if (r.Warped)'
  '            {'
  '                SceneId = r.NewSceneId; X = r.SpawnX; Y = r.SpawnY;'
  '                Last = r.MatchedWarpId;'
  '                return;'
  '            }'
  '            Last = "";'
  '        }'
  '        else'
  '        {'
  '            if (_mario == null) { Last = ""; return; }'
  '            var p = new KernelWorld.PlayerState(SceneId, X, Y);'
  '            var r = _mario.Tick(p);'
  '            SceneId = r.Player.SceneId; X = r.Player.X; Y = r.Player.Y;'
  '            Last = r.MatchedTriggerId ?? "";'
  '        }'
  '    }'
  '}'
)
$bridgeText = (@($bridge) -join "`n") + "`n"
Write-Utf8NoBomLf $BridgePath $bridgeText
Write-Host ("WROTE: " + $BridgePath) -ForegroundColor Green
