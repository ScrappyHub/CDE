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
$KernelDir = Join-Path $RepoRootAbs "src\CDE.Gameplay\Kernel"
Ensure-Dir $KernelDir
$InvPath = Join-Path $KernelDir "Inventory.cs"
$ObjPath = Join-Path $KernelDir "Objectives.cs"
$TrgPath = Join-Path $KernelDir "Triggers.cs"
$WldPath = Join-Path $KernelDir "KernelWorld.cs"
Backup-IfExists $InvPath
Backup-IfExists $ObjPath
Backup-IfExists $TrgPath
Backup-IfExists $WldPath

$inv = @'
namespace CDE.Gameplay.Kernel;

public sealed class Inventory
{
    private readonly Dictionary<string,int> _counts = new(StringComparer.Ordinal);

    public int GetCount(string itemId)
    {
        if (string.IsNullOrWhiteSpace(itemId)) return 0;
        return _counts.TryGetValue(itemId, out var v) ? v : 0;
    }

    public void Add(string itemId, int amount)
    {
        if (string.IsNullOrWhiteSpace(itemId)) return;
        if (amount <= 0) return;
        var cur = GetCount(itemId);
        _counts[itemId] = checked(cur + amount);
    }
}
'@
Write-Utf8NoBomLf $InvPath ($inv + "`n")
Write-Host ("WROTE: " + $InvPath) -ForegroundColor Green

$obj = @'
namespace CDE.Gameplay.Kernel;

public sealed class Objectives
{
    public int CoinTarget { get; }

    public Objectives(int coinTarget)
    {
        CoinTarget = coinTarget < 0 ? 0 : coinTarget;
    }

    public bool IsCoinTargetMet(Inventory inv)
    {
        if (inv is null) return CoinTarget <= 0;
        return inv.GetCount("coin") >= CoinTarget;
    }
}
'@
Write-Utf8NoBomLf $ObjPath ($obj + "`n")
Write-Host ("WROTE: " + $ObjPath) -ForegroundColor Green

$trg = @'
namespace CDE.Gameplay.Kernel;

public abstract record TriggerBase(
    string Type,
    string Id,
    string SceneId,
    RectF Zone,
    bool OneShot,
    string FiredFlag
);

public sealed record PickupTrigger(
    string Id,
    string SceneId,
    RectF Zone,
    bool OneShot,
    string FiredFlag,
    string ItemId,
    int Amount
) : TriggerBase("pickup", Id, SceneId, Zone, OneShot, FiredFlag);

public sealed record ExitTrigger(
    string Id,
    string SceneId,
    RectF Zone,
    bool OneShot,
    string FiredFlag,
    string ToScene,
    float SpawnX,
    float SpawnY,
    string RequireFlag,
    int RequireCoins
) : TriggerBase("exit", Id, SceneId, Zone, OneShot, FiredFlag);
'@
Write-Utf8NoBomLf $TrgPath ($trg + "`n")
Write-Host ("WROTE: " + $TrgPath) -ForegroundColor Green

$wld = @'
using System.Text.Json;
using System.Text.Json.Serialization;

namespace CDE.Gameplay.Kernel;

public sealed class KernelWorld
{
    public sealed record PlayerState(string SceneId, float X, float Y);
    public sealed record TickResult(PlayerState Player, string MatchedTriggerId);

    public Inventory Inventory { get; } = new();
    public Objectives Objectives { get; }
    public FlagStore Flags { get; } = new();
    private readonly List<TriggerBase> _triggers;

    public KernelWorld(Objectives objectives, List<TriggerBase> triggers)
    {
        Objectives = objectives ?? new Objectives(0);
        _triggers = triggers ?? new List<TriggerBase>();
    }

    public TickResult Tick(PlayerState p)
    {
        var scene = p.SceneId ?? string.Empty;
        foreach (var t in _triggers)
        {
            if (!string.Equals(t.SceneId, scene, StringComparison.Ordinal)) continue;
            if (!t.Zone.Contains(p.X, p.Y)) continue;

            if (t.OneShot && !string.IsNullOrWhiteSpace(t.FiredFlag) && Flags.GetBool(t.FiredFlag))
            {
                continue;
            }

            if (t is PickupTrigger pk)
            {
                if (!string.IsNullOrWhiteSpace(pk.ItemId) && pk.Amount > 0)
                {
                    Inventory.Add(pk.ItemId, pk.Amount);
                }
                if (!string.IsNullOrWhiteSpace(pk.FiredFlag)) Flags.SetBool(pk.FiredFlag, true);
                return new TickResult(p, pk.Id);
            }

            if (t is ExitTrigger ex)
            {
                if (!string.IsNullOrWhiteSpace(ex.RequireFlag) && !Flags.GetBool(ex.RequireFlag))
                {
                    return new TickResult(p, ex.Id);
                }
                if (ex.RequireCoins > 0 && Inventory.GetCount("coin") < ex.RequireCoins)
                {
                    return new TickResult(p, ex.Id);
                }
                if (!string.IsNullOrWhiteSpace(ex.FiredFlag)) Flags.SetBool(ex.FiredFlag, true);
                var np = new PlayerState(ex.ToScene ?? string.Empty, ex.SpawnX, ex.SpawnY);
                return new TickResult(np, ex.Id);
            }
        }
        return new TickResult(p, "");
    }

    public static KernelWorld LoadMarioJson(string json)
    {
        var opt = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            ReadCommentHandling = JsonCommentHandling.Skip,
            AllowTrailingCommas = true
        };
        opt.Converters.Add(new RectFJsonConverter());
        var root = JsonSerializer.Deserialize<MarioRoot>(json, opt) ?? new MarioRoot();
        var objectives = new Objectives(root.CoinTarget);
        var list = new List<TriggerBase>();
        if (root.Triggers != null)
        {
            foreach (var t in root.Triggers)
            {
                var type = (t.Type ?? "").Trim();
                var id = t.Id ?? "";
                var scene = t.SceneId ?? "";
                var fired = t.FiredFlag ?? "";
                var zone = t.Zone ?? new RectF(0, 0, 0, 0);
                var one = t.OneShot;

                if (string.Equals(type, "pickup", StringComparison.OrdinalIgnoreCase))
                {
                    var item = t.ItemId ?? "";
                    var amt = t.Amount < 0 ? 0 : t.Amount;
                    list.Add(new PickupTrigger(id, scene, zone, one, fired, item, amt));
                }
                else if (string.Equals(type, "exit", StringComparison.OrdinalIgnoreCase))
                {
                    var toScene = t.ToScene ?? "";
                    var reqFlag = t.RequireFlag ?? "";
                    var reqCoins = t.RequireCoins < 0 ? 0 : t.RequireCoins;
                    list.Add(new ExitTrigger(id, scene, zone, one, fired, toScene, t.SpawnX, t.SpawnY, reqFlag, reqCoins));
                }
            }
        }
        return new KernelWorld(objectives, list);
    }

    private sealed class MarioRoot
    {
        public int CoinTarget { get; set; } = 0;
        public List<MarioTrigger>? Triggers { get; set; }
    }

    private sealed class MarioTrigger
    {
        public string? Type { get; set; }
        public string? Id { get; set; }
        public string? SceneId { get; set; }
        public RectF? Zone { get; set; }
        public bool OneShot { get; set; } = false;
        public string? FiredFlag { get; set; }
        public string? ItemId { get; set; }
        public int Amount { get; set; } = 0;
        public string? ToScene { get; set; }
        public float SpawnX { get; set; } = 0f;
        public float SpawnY { get; set; } = 0f;
        public string? RequireFlag { get; set; }
        public int RequireCoins { get; set; } = 0;
    }

    private sealed class RectFJsonConverter : JsonConverter<RectF>
    {
        public override RectF Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType != JsonTokenType.StartObject) throw new JsonException();
            float x = 0, y = 0, w = 0, h = 0;
            while (reader.Read())
            {
                if (reader.TokenType == JsonTokenType.EndObject) break;
                if (reader.TokenType != JsonTokenType.PropertyName) throw new JsonException();
                var name = reader.GetString() ?? "";
                reader.Read();
                var v = reader.TokenType == JsonTokenType.Number ? reader.GetSingle() : 0f;
                if (string.Equals(name, "x", StringComparison.OrdinalIgnoreCase)) x = v;
                else if (string.Equals(name, "y", StringComparison.OrdinalIgnoreCase)) y = v;
                else if (string.Equals(name, "w", StringComparison.OrdinalIgnoreCase)) w = v;
                else if (string.Equals(name, "h", StringComparison.OrdinalIgnoreCase)) h = v;
            }
            return new RectF(x, y, w, h);
        }

        public override void Write(Utf8JsonWriter writer, RectF value, JsonSerializerOptions options)
        {
            writer.WriteStartObject();
            writer.WriteNumber("x", value.X);
            writer.WriteNumber("y", value.Y);
            writer.WriteNumber("w", value.W);
            writer.WriteNumber("h", value.H);
            writer.WriteEndObject();
        }
    }
}
'@
Write-Utf8NoBomLf $WldPath ($wld + "`n")
Write-Host ("WROTE: " + $WldPath) -ForegroundColor Green

& dotnet build $Sln -c Debug | Out-Host
if($LASTEXITCODE -ne 0){ Die "DOTNET_BUILD_FAILED_AFTER_MARIO_KERNEL_FIX_V3" }
Write-Host "CDE_MARIO_KERNEL_FIX_V3_BUILD_OK" -ForegroundColor Green
& dotnet run --project (Join-Path $RepoRootAbs "src\CDE.Gameplay.Demo\CDE.Gameplay.Demo.csproj") -c Debug | Out-Host
if($LASTEXITCODE -ne 0){ Die "DEMO_RUN_FAILED_AFTER_MARIO_KERNEL_FIX_V3" }
Write-Host "CDE_MARIO_KERNEL_FIX_V3_DEMO_OK" -ForegroundColor Green
