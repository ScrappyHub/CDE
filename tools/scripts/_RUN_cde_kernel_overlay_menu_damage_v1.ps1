param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir = Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u = New-Object System.Text.UTF8Encoding($false); $bytes = $u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$bytes) }
function ReadAllTextUtf8([string]$p){ return [System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8) }
function Backup-IfExists([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ"); $bak=($p + ".bak_" + $ts); Copy-Item -LiteralPath $p -Destination $bak -Force; Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow } }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Sln = Join-Path $RepoRootAbs "CDE.sln"
if(-not (Test-Path -LiteralPath $Sln -PathType Leaf)){ Die ("MISSING_SOLUTION: " + $Sln) }

$EngineDir = Join-Path $RepoRootAbs "src\CDE.Runtime\Engine"
Ensure-Dir $EngineDir
$BridgePath  = Join-Path $EngineDir "GameplayBridge.cs"
$OverlayPath = Join-Path $EngineDir "KernelOverlayComponent.cs"
$HostPath    = Join-Path $EngineDir "CdeGame.cs"
if(-not (Test-Path -LiteralPath $HostPath -PathType Leaf)){ Die ("MISSING_HOST: " + $HostPath) }

# --- overwrite GameplayBridge.cs (adds Reset + HP + Damage test hooks) ---
Backup-IfExists $BridgePath
$bridge = New-Object System.Collections.Generic.List[string]
$bridgeText = (@($bridge.ToArray()) -join "`n") + "`n"
Write-Utf8NoBomLf $BridgePath $bridgeText
Write-Host ("WROTE: " + $BridgePath) -ForegroundColor Green

# --- overwrite KernelOverlayComponent.cs (menu/reset/damage test + obvious title) ---
Backup-IfExists $OverlayPath
$overlay = New-Object System.Collections.Generic.List[string]
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('using Microsoft.Xna.Framework;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('using Microsoft.Xna.Framework.Graphics;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('using Microsoft.Xna.Framework.Input;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('using XnaGame = Microsoft.Xna.Framework.Game;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('namespace CDE.Runtime.Engine;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('internal sealed class KernelOverlayComponent : DrawableGameComponent')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('{')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    private readonly GameplayBridge _bridge;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    private SpriteBatch? _sb;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    private Texture2D? _px;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    private KeyboardState _prev;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    private bool _menu;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game)')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    {')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        _bridge = bridge;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        Enabled = true;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        Visible = true;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        UpdateOrder = int.MaxValue;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        DrawOrder = int.MaxValue;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    }')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    protected override void LoadContent()')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    {')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        _sb = new SpriteBatch(GraphicsDevice);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        _px = new Texture2D(GraphicsDevice, 1, 1);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        _px.SetData(new[] { Color.White });')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        base.LoadContent();')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    }')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    private static bool Pressed(Keys k, KeyboardState now, KeyboardState prev) => now.IsKeyDown(k) && !prev.IsKeyDown(k);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    public override void Update(GameTime gameTime)')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    {')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        var k = Keyboard.GetState();')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        float s = 0.10f;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        if (k.IsKeyDown(Keys.Left)  || k.IsKeyDown(Keys.A)) _bridge.Move(-s, 0);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        if (k.IsKeyDown(Keys.Right) || k.IsKeyDown(Keys.D)) _bridge.Move( s, 0);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        if (k.IsKeyDown(Keys.Up)    || k.IsKeyDown(Keys.W)) _bridge.Move(0, -s);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        if (k.IsKeyDown(Keys.Down)  || k.IsKeyDown(Keys.S)) _bridge.Move(0,  s);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        if (Pressed(Keys.F1, k, _prev)) _bridge.SetMode(GameplayBridge.Mode.Yume);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        if (Pressed(Keys.F2, k, _prev)) _bridge.SetMode(GameplayBridge.Mode.Mario);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        // obvious controls')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        if (Pressed(Keys.Escape, k, _prev)) _menu = !_menu;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        if (Pressed(Keys.F5, k, _prev)) _bridge.ResetToDefaults();')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        // deterministic damage test keys')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        if (Pressed(Keys.K, k, _prev)) _bridge.ApplyDamage(1);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        if (Pressed(Keys.L, k, _prev)) _bridge.Heal(1);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        _bridge.Tick();')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        _prev = k;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        var coins = _bridge.GetCoins();')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        var tgt = _bridge.GetCoinTarget();')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        var key = _bridge.Flags.GetBool("has_dream_key") ? "1" : "0";')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        var last = string.IsNullOrWhiteSpace(_bridge.Last) ? "-" : _bridge.Last;')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        var menu = _menu ? "ON" : "off";')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        Game.Window.Title =')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('            "CDE KERNEL GUI v3c | MENU=" + menu +')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('            " | mode=" + _bridge.ActiveMode +')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('            " scene=" + _bridge.SceneId +')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('            " HP=" + _bridge.Hp + "/" + _bridge.MaxHp +')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('            " coins=" + coins + "/" + tgt +')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('            " key=" + key +')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('            " last=" + last +')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('            " | (ESC menu, F5 reset, K dmg, L heal)";')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        base.Update(gameTime);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    }')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    public override void Draw(GameTime gameTime)')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    {')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        if (_sb == null || _px == null){ base.Draw(gameTime); return; }')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        _sb.Begin(samplerState: SamplerState.PointClamp);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        // player marker')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        int sx = 20 + (int)(_bridge.X * 12f);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        int sy = 60 + (int)(_bridge.Y * 12f);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        _sb.Draw(_px, new Rectangle(sx, sy, 18, 18), Color.LimeGreen);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        // menu panel (no font required; just obvious UI blocks)')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        if (_menu)')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        {')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('            _sb.Draw(_px, new Rectangle(10, 10, 220, 120), new Color(0, 0, 0, 180));')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('            _sb.Draw(_px, new Rectangle(20, 25, 200, 25), new Color(40, 40, 40, 220)); // reset row')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('            _sb.Draw(_px, new Rectangle(20, 60, 200, 25), new Color(40, 40, 40, 220)); // mode row')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('            _sb.Draw(_px, new Rectangle(20, 95, 200, 25), new Color(40, 40, 40, 220)); // damage row')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        }')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        _sb.End();')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('        base.Draw(gameTime);')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('    }')
  [void]using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using XnaGame = Microsoft.Xna.Framework.Game;

namespace CDE.Game;

internal sealed class KernelOverlayComponent : DrawableGameComponent
{
    private readonly GameplayBridge _bridge;
    private SpriteBatch? _sb;
    private Texture2D? _px;
    private KeyboardState _prev;

    public KernelOverlayComponent(XnaGame game, GameplayBridge bridge) : base(game){ _bridge = bridge; }

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

        Game.Window.Title =
            "CDE KERNEL GUI v3b | mode=" + _bridge.ActiveMode +
            " scene=" + _bridge.SceneId +
            " pos=(" + _bridge.X.ToString("0.00") + "," + _bridge.Y.ToString("0.00") + ")" +
            " coins=" + coins + "/" + tgt +
            " key=" + key +
            " last=" + last;

        base.Update(gameTime);
    }

    public override void Draw(GameTime gameTime)
    {
        if (_sb == null || _px == null){ base.Draw(gameTime); return; }

        _sb.Begin(samplerState: SamplerState.PointClamp);

        int sx = 20 + (int)(_bridge.X * 12f);
        int sy = 60 + (int)(_bridge.Y * 12f);
        var r = new Rectangle(sx, sy, 18, 18);
        _sb.Draw(_px, r, Color.LimeGreen);

        _sb.End();
        base.Draw(gameTime);
    }
}.Add('}')
$overlayText = (@($overlay.ToArray()) -join "`n") + "`n"
Write-Utf8NoBomLf $OverlayPath $overlayText
Write-Host ("WROTE: " + $OverlayPath) -ForegroundColor Green

# --- Patch host to ensure overlay is created and is topmost ---
$HostText = ReadAllTextUtf8 $HostPath
$t = $HostText.Replace("`r`n","`n")
if($t -notmatch "CDE_KERNEL_OVERLAY_V3B"){ Die ("HOST_MISSING_MARKER_EXPECTED_FROM_PRIOR_PATCH: " + $HostPath) }
Backup-IfExists $HostPath

# Ensure we flip mouse visible (helps prove we are in this host)
if($t -notmatch "IsMouseVisible\s*=\s*true"){
  $t = [System.Text.RegularExpressions.Regex]::Replace($t,"(\bCdeGame\s*\([^\)]*\)\s*\{)","`$1`n        IsMouseVisible = true;")
}

Write-Utf8NoBomLf $HostPath ($t + "`n")
Write-Host ("PATCH_OK: host refreshed (mouse visible) : " + $HostPath) -ForegroundColor Green

Write-Host "NEXT: dotnet build .\CDE.sln -c Debug" -ForegroundColor Yellow
Write-Host "NEXT: dotnet run --project .\src\CDE.Game\CDE.Game.csproj -c Debug" -ForegroundColor Yellow
