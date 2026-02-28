param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir=Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u=New-Object System.Text.UTF8Encoding($false); $b=$u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$b) }
function Backup-IfExists([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force; Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow } }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Sln = Join-Path $RepoRootAbs "CDE.sln"
if(-not (Test-Path -LiteralPath $Sln -PathType Leaf)){ Die ("MISSING_SOLUTION: " + $Sln) }
$GameProj = Join-Path $RepoRootAbs "src\CDE.Game\CDE.Game.csproj"
if(-not (Test-Path -LiteralPath $GameProj -PathType Leaf)){ Die ("MISSING_GAME_PROJECT: " + $GameProj) }

$gameCsprojText = [System.IO.File]::ReadAllText($GameProj,[System.Text.Encoding]::UTF8)
if($gameCsprojText -notmatch "CDE\.Gameplay\.csproj"){
  Backup-IfExists $GameProj
  if($gameCsprojText -match "</Project>\s*$"){
    $ins = @(
      "  <ItemGroup>",
      "    <ProjectReference Include=""..\CDE.Gameplay\CDE.Gameplay.csproj"" />",
      "  </ItemGroup>"
    ) -join "`n"
    $new = [System.Text.RegularExpressions.Regex]::Replace($gameCsprojText,"</Project>\s*$",($ins + "`n</Project>`n"))
    Write-Utf8NoBomLf $GameProj $new
    Write-Host ("PATCH_OK: added ProjectReference to CDE.Gameplay: " + $GameProj) -ForegroundColor Green
  } else { Die "CSPROJ_UNEXPECTED_FORMAT: cannot insert ProjectReference" }
} else { Write-Host ("SKIP: Game already references Gameplay: " + $GameProj) -ForegroundColor Yellow }

$BridgePath = Join-Path $RepoRootAbs "src\CDE.Game\GameplayBridge.cs"
if(-not (Test-Path -LiteralPath $BridgePath -PathType Leaf)){
  $c = @'
using System.Text;
using CDE.Gameplay.Kernel;

namespace CDE.Game;

internal sealed class GameplayBridge
{
    public enum Mode { Yume, Mario }
    public Mode ActiveMode { get; private set; } = Mode.Yume;
    public string SceneId { get; private set; } = "StartRoom";
    public float X { get; private set; } = 1f;
    public float Y { get; private set; } = 1f;
    public readonly FlagStore Flags = new();
    private WarpKernel? _warp;
    private KernelWorld? _mario;
    public string Last { get; private set; } = "";

    public void SetMode(Mode m)
    {
        ActiveMode = m;
        if (m == Mode.Yume) { SceneId = "StartRoom"; X = 1f; Y = 1f; }
        else { SceneId = "MarioRoom"; X = 0f; Y = 0f; }
        Last = "";
    }

    public void LoadFromRepoRoot(string repoRoot)
    {
        var yumePath = Path.Combine(repoRoot, "assets_src", "gameplay", "warp_graph.v1.json");
        var marioPath = Path.Combine(repoRoot, "assets_src", "gameplay", "mario_graph.v1.json");
        if (File.Exists(yumePath))
        {
            var json = File.ReadAllText(yumePath, new UTF8Encoding(false));
            var g = WarpKernel.LoadWarpGraphJson(json);
            _warp = new WarpKernel(g, Flags);
        }
        if (File.Exists(marioPath))
        {
            var json = File.ReadAllText(marioPath, new UTF8Encoding(false));
            _mario = KernelWorld.LoadMarioJson(json);
        }
    }

    public int GetCoins() => _mario?.Inventory.GetCount("coin") ?? 0;
    public int GetCoinTarget() => _mario?.Objectives.CoinTarget ?? 0;

    public void Move(float dx, float dy){ X += dx; Y += dy; }

    public void Tick()
    {
        if (ActiveMode == Mode.Yume)
        {
            if (_warp == null) { Last = ""; return; }
            var r = _warp.TryWarp(new WarpKernel.WarpRequest(SceneId, X, Y));
            if (r.Warped)
            {
                SceneId = r.NewSceneId; X = r.SpawnX; Y = r.SpawnY;
                Last = r.MatchedWarpId;
                return;
            }
            Last = "";
        }
        else
        {
            if (_mario == null) { Last = ""; return; }
            var p = new KernelWorld.PlayerState(SceneId, X, Y);
            var r = _mario.Tick(p);
            SceneId = r.Player.SceneId; X = r.Player.X; Y = r.Player.Y;
            Last = r.MatchedTriggerId ?? "";
        }
    }
}
'@
  Write-Utf8NoBomLf $BridgePath ($c + "`n")
  Write-Host ("WROTE: " + $BridgePath) -ForegroundColor Green
} else { Write-Host ("SKIP: " + $BridgePath) -ForegroundColor Yellow }

$OverlayPath = Join-Path $RepoRootAbs "src\CDE.Game\KernelOverlayComponent.cs"
if(-not (Test-Path -LiteralPath $OverlayPath -PathType Leaf)){
  $c = @'
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(Game game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

    protected override void LoadContent()
    {
        _sb = new SpriteBatch(GraphicsDevice);
        _px = new Texture2D(GraphicsDevice, 1, 1);
        _px.SetData(new[] { Color.White });
        base.LoadContent();
    }

    public override void Update(GameTime gameTime)
    {
        var k = Keyboard.GetState();
        float s = 0.10f;
        if (k.IsKeyDown(Keys.Left)  || k.IsKeyDown(Keys.A)) _bridge.Move(-s, 0);
        if (k.IsKeyDown(Keys.Right) || k.IsKeyDown(Keys.D)) _bridge.Move( s, 0);
        if (k.IsKeyDown(Keys.Up)    || k.IsKeyDown(Keys.W)) _bridge.Move(0, -s);
        if (k.IsKeyDown(Keys.Down)  || k.IsKeyDown(Keys.S)) _bridge.Move(0,  s);

        if (k.IsKeyDown(Keys.F1) && !_prev.IsKeyDown(Keys.F1)) _bridge.SetMode(GameplayBridge.Mode.Yume);
        if (k.IsKeyDown(Keys.F2) && !_prev.IsKeyDown(Keys.F2)) _bridge.SetMode(GameplayBridge.Mode.Mario);

        _bridge.Tick();
        _prev = k;

        var coins = _bridge.GetCoins();
        var tgt = _bridge.GetCoinTarget();
        var key = _bridge.Flags.GetBool("has_dream_key") ? "1" : "0";
        var last = string.IsNullOrWhiteSpace(_bridge.Last) ? "-" : _bridge.Last;
        Game.Window.Title = "CDE KERNEL GUI v2 | mode=" + _bridge.ActiveMode + " scene=" + _bridge.SceneId + " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ") coins=" + coins + "/" + tgt + " key=" + key + " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }
        _sb.Begin(samplerState: SamplerState.PointClamp);

        // Draw a visible player rectangle (proof overlay is running)
        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}
'@
  Write-Utf8NoBomLf $OverlayPath ($c + "`n")
  Write-Host ("WROTE: " + $OverlayPath) -ForegroundColor Green
} else { Write-Host ("SKIP: " + $OverlayPath) -ForegroundColor Yellow }

$GameSrcDir = Join-Path $RepoRootAbs "src\CDE.Game"
$cs = Get-ChildItem -LiteralPath $GameSrcDir -Recurse -Filter *.cs -File | ForEach-Object { $_.FullName }
if(-not $cs -or $cs.Count -lt 1){ Die ("NO_CS_FILES_IN: " + $GameSrcDir) }
$host = $null
foreach($f in $cs){
  $txt = [System.IO.File]::ReadAllText($f,[System.Text.Encoding]::UTF8)
  if($txt -match ":\s*Game\b" -or $txt -match "Microsoft\.Xna\.Framework\.Game"){ $host = $f; break }
}
if([string]::IsNullOrWhiteSpace($host)){ Die "CANNOT_FIND_MONOGAME_HOST: no class derives from Game found in src\CDE.Game" }
$hostText = [System.IO.File]::ReadAllText($host,[System.Text.Encoding]::UTF8)
if($hostText -match "CDE_KERNEL_OVERLAY_V2"){ Write-Host ("SKIP: host already patched: " + $host) -ForegroundColor Yellow } else {
  Backup-IfExists $host
  $new = $hostText

  # Insert fields after class opening brace
  $new = [System.Text.RegularExpressions.Regex]::Replace($new, "(class\s+\w+.*?\{)", { param($m) ($m.Groups[1].Value + "`n    // CDE_KERNEL_OVERLAY_V2`n    private GameplayBridge? _kernel;`n    private KernelOverlayComponent? _kernelOverlay;") }, 1, [System.Text.RegularExpressions.RegexOptions]::Singleline)

  # Add helper method near end of class (before last })
  $helper = @(
    "",
    "    private static string FindRepoRoot(string start)",
    "    {",
    "        var d = new DirectoryInfo(start);",
    "        for (int i = 0; i < 12 && d != null; i++)",
    "        {",
    "            var sln = Path.Combine(d.FullName, ""CDE.sln"");",
    "            if (File.Exists(sln)) return d.FullName;",
    "            d = d.Parent;",
    "        }",
    "        return Directory.GetCurrentDirectory();",
    "    }",
    ",
    "    private void EnsureKernelOverlay()",
    "    {",
    "        if (_kernelOverlay != null) return;",
    "        var root = FindRepoRoot(AppContext.BaseDirectory);",
    "        _kernel = new GameplayBridge();",
    "        _kernel.LoadFromRepoRoot(root);",
    "        _kernelOverlay = new KernelOverlayComponent(this, _kernel);",
    "        Components.Add(_kernelOverlay);",
    "    }"
  ) -join "`n"
  $new = [System.Text.RegularExpressions.Regex]::Replace($new, "\}\s*$", ($helper + "`n}`n"))

  # Insert call inside Initialize before base.Initialize();
  if($new -match "override\s+void\s+Initialize\s*\("){
    $new = [System.Text.RegularExpressions.Regex]::Replace($new, "(override\s+void\s+Initialize\s*\(\s*\)\s*\{)", { param($m) ($m.Groups[1].Value + "`n        EnsureKernelOverlay();") }, 1)
  } elseif($new -match "override\s+void\s+LoadContent\s*\("){
    $new = [System.Text.RegularExpressions.Regex]::Replace($new, "(override\s+void\s+LoadContent\s*\(\s*\)\s*\{)", { param($m) ($m.Groups[1].Value + "`n        EnsureKernelOverlay();") }, 1)
  } else { Die ("HOST_HAS_NO_INITIALIZE_OR_LOADCONTENT_TO_PATCH: " + $host) }

  Write-Utf8NoBomLf $host ($new.Replace("`r`n","`n") + "`n")
  Write-Host ("PATCH_OK: wired kernel overlay into host: " + $host) -ForegroundColor Green
}

& dotnet build $Sln -c Debug | Out-Host
if($LASTEXITCODE -ne 0){ Die "DOTNET_BUILD_FAILED_AFTER_GUI_KERNEL_OVERLAY_V2" }
Write-Host "CDE_GUI_KERNEL_OVERLAY_V2_BUILD_OK" -ForegroundColor Green
Write-Host "RUN: dotnet run --project .\src\CDE.Game\CDE.Game.csproj -c Debug" -ForegroundColor Yellow
