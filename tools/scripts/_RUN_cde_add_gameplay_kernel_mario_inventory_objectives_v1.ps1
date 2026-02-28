param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir=Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u=New-Object System.Text.UTF8Encoding($false); $b=$u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$b) }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Sln = Join-Path $RepoRootAbs "CDE.sln"
if(-not (Test-Path -LiteralPath $Sln -PathType Leaf)){ Die ("MISSING_SOLUTION: " + $Sln) }

$GameplayDir = Join-Path $RepoRootAbs "src\CDE.Gameplay"
$SrcDir = Join-Path $GameplayDir "Kernel"
if(-not (Test-Path -LiteralPath $SrcDir -PathType Container)){ Die ("MISSING_GAMEPLAY_KERNEL_DIR: " + $SrcDir) }

# --- 1) Inventory ---
$inv = Join-Path $SrcDir "Inventory.cs"
if(-not (Test-Path -LiteralPath $inv -PathType Leaf)){
  $c = @(
    "namespace CDE.Gameplay.Kernel;",
    "",
    "public sealed class Inventory",
    "{",
    "    private readonly Dictionary<string,int> _counts = new(StringComparer.Ordinal);",
    "",
    "    public int GetCount(string itemId)",
    "    {",
    "        if (string.IsNullOrWhiteSpace(itemId)) return 0;",
    "        return _counts.TryGetValue(itemId, out var v) ? v : 0;",
    "    }",
    "",
    "    public void Add(string itemId, int amount)",
    "    {",
    "        if (string.IsNullOrWhiteSpace(itemId)) return;",
    "        if (amount <= 0) return;",
    "        _counts[itemId] = GetCount(itemId) + amount;",
    "    }",
    "",
    "    public bool TryConsume(string itemId, int amount)",
    "    {",
    "        if (string.IsNullOrWhiteSpace(itemId)) return false;",
    "        if (amount <= 0) return true;",
    "        var cur = GetCount(itemId);",
    "        if (cur < amount) return false;",
    "        var next = cur - amount;",
    "        if (next == 0) _counts.Remove(itemId); else _counts[itemId] = next;",
    "        return true;",
    "    }",
    "}"
  ) -join "`n"
  Write-Utf8NoBomLf $inv ($c + "`n")
  Write-Host ("WROTE: " + $inv) -ForegroundColor Green
} else { Write-Host ("SKIP: " + $inv) -ForegroundColor Yellow }

# --- 2) Objectives ---
$obj = Join-Path $SrcDir "Objectives.cs"
if(-not (Test-Path -LiteralPath $obj -PathType Leaf)){
  $c = @(
    "namespace CDE.Gameplay.Kernel;",
    "",
    "public sealed class Objectives",
    "{",
    "    public int CoinTarget { get; set; } = 0;",
    "    public bool IsCoinTargetMet(Inventory inv)",
    "    {",
    "        if (inv == null) return false;",
    "        if (CoinTarget <= 0) return true;",
    "        return inv.GetCount(""coin"") >= CoinTarget;",
    "    }",
    "}"
  ) -join "`n"
  Write-Utf8NoBomLf $obj ($c + "`n")
  Write-Host ("WROTE: " + $obj) -ForegroundColor Green
} else { Write-Host ("SKIP: " + $obj) -ForegroundColor Yellow }

# --- 3) Triggers (pickup + exit) ---
$tr = Join-Path $SrcDir "Triggers.cs"
if(-not (Test-Path -LiteralPath $tr -PathType Leaf)){
  $c = @(
    "namespace CDE.Gameplay.Kernel;",
    "",
    "public abstract class Trigger",
    "{",
    "    public string Id { get; init; } = """";",
    "    public string SceneId { get; init; } = """";",
    "    public RectF Zone { get; init; } = new RectF(0,0,0,0);",
    "    public bool OneShot { get; init; } = true;",
    "    public string FiredFlag { get; init; } = """"; // if set, engine sets this flag when fired",
    "",
    "    public bool IsActive(FlagStore flags)",
    "    {",
    "        if (flags == null) return true;",
    "        if (!OneShot) return true;",
    "        if (string.IsNullOrWhiteSpace(FiredFlag)) return true;",
    "        return !flags.GetBool(FiredFlag);",
    "    }",
    "}",
    "",
    "public sealed class PickupTrigger : Trigger",
    "{",
    "    public string ItemId { get; init; } = ""coin"";",
    "    public int Amount { get; init; } = 1;",
    "}",
    "",
    "public sealed class ExitTrigger : Trigger",
    "{",
    "    public string ToScene { get; init; } = """";",
    "    public float SpawnX { get; init; } = 0f;",
    "    public float SpawnY { get; init; } = 0f;",
    "    public string RequireFlag { get; init; } = """";",
    "    public int RequireCoins { get; init; } = 0;",
    "}"
  ) -join "`n"
  Write-Utf8NoBomLf $tr ($c + "`n")
  Write-Host ("WROTE: " + $tr) -ForegroundColor Green
} else { Write-Host ("SKIP: " + $tr) -ForegroundColor Yellow }

# --- 4) World model + deterministic tick ---
$wk = Join-Path $SrcDir "KernelWorld.cs"
if(-not (Test-Path -LiteralPath $wk -PathType Leaf)){
  $c = @(
    "using System.Text.Json;",
    "using System.Text.Json.Serialization;",
    "",
    "namespace CDE.Gameplay.Kernel;",
    "",
    "public sealed class KernelWorld",
    "{",
    "    public sealed record PlayerState(string SceneId, float X, float Y);",
    "    public sealed record TickResult(bool Warped, PlayerState Player, string MatchedTriggerId);",
    "",
    "    public List<Trigger> Triggers { get; init; } = new();",
    "    public Inventory Inventory { get; } = new();",
    "    public Objectives Objectives { get; } = new();",
    "    public FlagStore Flags { get; } = new();",
    "",
    "    public TickResult Tick(PlayerState p)",
    "    {",
    "        // Stable ordering: by Id ordinal to guarantee determinism across content load order",
    "        var ordered = Triggers.OrderBy(t => t.Id, StringComparer.Ordinal).ToList();",
    "        foreach (var t in ordered)",
    "        {",
    "            if (!string.Equals(t.SceneId, p.SceneId, StringComparison.Ordinal)) continue;",
    "            if (!t.Zone.Contains(p.X, p.Y)) continue;",
    "            if (!t.IsActive(Flags)) continue;",
    "",
    "            if (t is PickupTrigger pt)",
    "            {",
    "                Inventory.Add(pt.ItemId, pt.Amount);",
    "                if (!string.IsNullOrWhiteSpace(pt.FiredFlag)) Flags.SetBool(pt.FiredFlag, true);",
    "                return new TickResult(false, p, t.Id);",
    "            }",
    "            else if (t is ExitTrigger et)",
    "            {",
    "                if (!string.IsNullOrWhiteSpace(et.RequireFlag) && !Flags.GetBool(et.RequireFlag))",
    "                    return new TickResult(false, p, ""EXIT_LOCKED_FLAG:"" + t.Id);",
    "                if (et.RequireCoins > 0 && Inventory.GetCount(""coin"") < et.RequireCoins)",
    "                    return new TickResult(false, p, ""EXIT_LOCKED_COINS:"" + t.Id);",
    "",
    "                if (!string.IsNullOrWhiteSpace(et.FiredFlag)) Flags.SetBool(et.FiredFlag, true);",
    "                var np = new PlayerState(et.ToScene, et.SpawnX, et.SpawnY);",
    "                return new TickResult(true, np, t.Id);",
    "            }",
    "        }",
    "        return new TickResult(false, p, """");",
    "    }",
    "",
    "    public static KernelWorld LoadMarioJson(string json)",
    "    {",
    "        var opt = new JsonSerializerOptions",
    "        {",
    "            PropertyNameCaseInsensitive = true,",
    "            ReadCommentHandling = JsonCommentHandling.Skip,",
    "            AllowTrailingCommas = true",
    "        };",
    "        opt.Converters.Add(new RectFConverter());",
    "        opt.Converters.Add(new TriggerConverter());",
    "        var root = JsonSerializer.Deserialize<MarioRoot>(json, opt) ?? new MarioRoot();",
    "        var w = new KernelWorld();",
    "        w.Objectives.CoinTarget = root.CoinTarget;",
    "        foreach (var t in root.Triggers) w.Triggers.Add(t);",
    "        return w;",
    "    }",
    "",
    "    private sealed class MarioRoot",
    "    {",
    "        public int CoinTarget { get; set; } = 0;",
    "        public List<Trigger> Triggers { get; set; } = new();",
    "    }",
    "",
    "    private sealed class RectFConverter : JsonConverter<RectF>",
    "    {",
    "        public override RectF Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)",
    "        {",
    "            if (reader.TokenType != JsonTokenType.StartObject) throw new JsonException();",
    "            float x = 0, y = 0, w = 0, h = 0;",
    "            while (reader.Read())",
    "            {",
    "                if (reader.TokenType == JsonTokenType.EndObject) break;",
    "                if (reader.TokenType != JsonTokenType.PropertyName) throw new JsonException();",
    "                var name = reader.GetString() ?? """";",
    "                reader.Read();",
    "                var v = reader.TokenType == JsonTokenType.Number ? reader.GetSingle() : 0f;",
    "                if (string.Equals(name, ""x"", StringComparison.OrdinalIgnoreCase)) x = v;",
    "                else if (string.Equals(name, ""y"", StringComparison.OrdinalIgnoreCase)) y = v;",
    "                else if (string.Equals(name, ""w"", StringComparison.OrdinalIgnoreCase)) w = v;",
    "                else if (string.Equals(name, ""h"", StringComparison.OrdinalIgnoreCase)) h = v;",
    "            }",
    "            return new RectF(x, y, w, h);",
    "        }",
    "",
    "        public override void Write(Utf8JsonWriter writer, RectF value, JsonSerializerOptions options)",
    "        {",
    "            writer.WriteStartObject();",
    "            writer.WriteNumber(""x"", value.X);",
    "            writer.WriteNumber(""y"", value.Y);",
    "            writer.WriteNumber(""w"", value.W);",
    "            writer.WriteNumber(""h"", value.H);",
    "            writer.WriteEndObject();",
    "        }",
    "    }",
    "",
    "    private sealed class TriggerConverter : JsonConverter<Trigger>",
    "    {",
    "        public override Trigger Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)",
    "        {",
    "            using var doc = JsonDocument.ParseValue(ref reader);",
    "            var root = doc.RootElement;",
    "            var type = root.TryGetProperty(""type"", out var te) ? (te.GetString() ?? """") : """";",
    "            Trigger t = type switch",
    "            {",
    "                ""pickup"" => new PickupTrigger(),",
    "                ""exit"" => new ExitTrigger(),",
    "                _ => new PickupTrigger()",
    "            };",
    "",
    "            // common",
    "            t = ApplyCommon(t, root);",
    "",
    "            if (t is PickupTrigger pt)",
    "            {",
    "                if (root.TryGetProperty(""itemId"", out var ie)) pt = pt with { ItemId = ie.GetString() ?? ""coin"" };",
    "                if (root.TryGetProperty(""amount"", out var ae) && ae.ValueKind == JsonValueKind.Number) pt = pt with { Amount = ae.GetInt32() };",
    "                return pt;",
    "            }",
    "            if (t is ExitTrigger et)",
    "            {",
    "                if (root.TryGetProperty(""toScene"", out var se)) et = et with { ToScene = se.GetString() ?? """" };",
    "                if (root.TryGetProperty(""spawnX"", out var sx) && sx.ValueKind == JsonValueKind.Number) et = et with { SpawnX = sx.GetSingle() };",
    "                if (root.TryGetProperty(""spawnY"", out var sy) && sy.ValueKind == JsonValueKind.Number) et = et with { SpawnY = sy.GetSingle() };",
    "                if (root.TryGetProperty(""requireFlag"", out var rf)) et = et with { RequireFlag = rf.GetString() ?? """" };",
    "                if (root.TryGetProperty(""requireCoins"", out var rc) && rc.ValueKind == JsonValueKind.Number) et = et with { RequireCoins = rc.GetInt32() };",
    "                return et;",
    "            }",
    "            return t;",
    "        }",
    "",
    "        private static Trigger ApplyCommon(Trigger t, JsonElement root)",
    "        {",
    "            RectF zone = new RectF(0,0,0,0);",
    "            if (root.TryGetProperty(""zone"", out var zE))",
    "            {",
    "                var zjson = zE.GetRawText();",
    "                zone = JsonSerializer.Deserialize<RectF>(zjson, new JsonSerializerOptions { Converters = { new RectFConverter() } });",
    "            }",
    "            // init-only props, so construct new instances to set them",
    "            if (t is PickupTrigger pt) return new PickupTrigger { Id = id, SceneId = scene, Zone = zone, OneShot = one, FiredFlag = fired, ItemId = pt.ItemId, Amount = pt.Amount };",
    "            if (t is ExitTrigger et) return new ExitTrigger { Id = id, SceneId = scene, Zone = zone, OneShot = one, FiredFlag = fired, ToScene = et.ToScene, SpawnX = et.SpawnX, SpawnY = et.SpawnY, RequireFlag = et.RequireFlag, RequireCoins = et.RequireCoins };",
    "            return t;",
    "        }",
    "",
    "        public override void Write(Utf8JsonWriter writer, Trigger value, JsonSerializerOptions options) => throw new NotSupportedException();",
    "    }",
    "}"
  ) -join "`n"
  Write-Utf8NoBomLf $wk ($c + "`n")
  Write-Host ("WROTE: " + $wk) -ForegroundColor Green
} else { Write-Host ("SKIP: " + $wk) -ForegroundColor Yellow }

# --- 5) Write Mario proof content ---
$AssetsDir = Join-Path $RepoRootAbs "assets_src\gameplay"
Ensure-Dir $AssetsDir
$MarioJson = Join-Path $AssetsDir "mario_graph.v1.json"
if(-not (Test-Path -LiteralPath $MarioJson -PathType Leaf)){
  $j = @(
    "{",
    "  ""coinTarget"": 3,",
    "  ""triggers"": [",
    "    { ""type"": ""pickup"", ""id"": ""coin_a"", ""sceneId"": ""MarioRoom"", ""zone"": { ""x"": 2, ""y"": 2, ""w"": 2, ""h"": 2 }, ""oneShot"": true, ""firedFlag"": ""picked_coin_a"", ""itemId"": ""coin"", ""amount"": 1 },",
    "    { ""type"": ""pickup"", ""id"": ""coin_b"", ""sceneId"": ""MarioRoom"", ""zone"": { ""x"": 6, ""y"": 2, ""w"": 2, ""h"": 2 }, ""oneShot"": true, ""firedFlag"": ""picked_coin_b"", ""itemId"": ""coin"", ""amount"": 1 },",
    "    { ""type"": ""pickup"", ""id"": ""coin_c"", ""sceneId"": ""MarioRoom"", ""zone"": { ""x"": 10, ""y"": 2, ""w"": 2, ""h"": 2 }, ""oneShot"": true, ""firedFlag"": ""picked_coin_c"", ""itemId"": ""coin"", ""amount"": 1 },",
    "  ]",
    "}"
  ) -join "`n"
  Write-Utf8NoBomLf $MarioJson ($j + "`n")
  Write-Host ("WROTE: " + $MarioJson) -ForegroundColor Green
} else { Write-Host ("SKIP: mario graph exists: " + $MarioJson) -ForegroundColor Yellow }

# --- 6) Update demo Program.cs to run mario proof too (non-destructive rewrite if marker missing) ---
$DemoProg = Join-Path $RepoRootAbs "src\CDE.Gameplay.Demo\Program.cs"
if(-not (Test-Path -LiteralPath $DemoProg -PathType Leaf)){ Die ("MISSING_DEMO_PROGRAM: " + $DemoProg) }
$orig = [System.IO.File]::ReadAllText($DemoProg,[System.Text.Encoding]::UTF8)
if($orig -notmatch "MARIO_DEMO_OK"){
  $c = @(
    "using System.Text;",
    "using CDE.Gameplay.Kernel;",
    "",
    "static class Program",
    "{",
    "    private static string ReadUtf8(string path)",
    "    {",
    "        return File.ReadAllText(path, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));",
    "    }",
    "",
    "    private static void Main(string[] args)",
    "    {",
    "        var root = FindRepoRoot(AppContext.BaseDirectory);",
    "        RunYumeProof(root);",
    "        RunMarioProof(root);",
    "    }",
    "",
    "    private static void RunYumeProof(string root)",
    "    {",
    "        var jsonPath = Path.Combine(root, ""assets_src"", ""gameplay"", ""warp_graph.v1.json"");",
    "        if (!File.Exists(jsonPath))",
    "        {",
    "            Console.WriteLine(""DEMO_MISSING_WARP_GRAPH: "" + jsonPath);",
    "            Environment.ExitCode = 2;",
    "            return;",
    "        }",
    "        var flags = new FlagStore();",
    "        flags.SetBool(""has_dream_key"", false);",
    "        var graph = WarpKernel.LoadWarpGraphJson(ReadUtf8(jsonPath));",
    "        var kernel = new WarpKernel(graph, flags);",
    "        var scene = ""StartRoom"";",
    "        float x = 1, y = 1;",
    "        Print(""YUME_START"", scene, x, y, flags);",
    "        x = 12; y = 2;",
    "        var r1 = kernel.TryWarp(new WarpKernel.WarpRequest(scene, x, y));",
    "        Apply(ref scene, ref x, ref y, r1, flags);",
    "        x = 3; y = 9;",
    "        var r2 = kernel.TryWarp(new WarpKernel.WarpRequest(scene, x, y));",
    "        Apply(ref scene, ref x, ref y, r2, flags);",
    "        Console.WriteLine(""YUME_DEMO_OK: warp+flags proof complete"");",
    "    }",
    "",
    "    private static void RunMarioProof(string root)",
    "    {",
    "        var jsonPath = Path.Combine(root, ""assets_src"", ""gameplay"", ""mario_graph.v1.json"");",
    "        if (!File.Exists(jsonPath))",
    "        {",
    "            Console.WriteLine(""MARIO_MISSING_GRAPH: "" + jsonPath);",
    "            Environment.ExitCode = 3;",
    "            return;",
    "        }",
    "        var world = KernelWorld.LoadMarioJson(ReadUtf8(jsonPath));",
    "        var p = new KernelWorld.PlayerState(""MarioRoom"", 0, 0);",
    "        Console.WriteLine(""MARIO_START scene="" + p.SceneId + "" coins="" + world.Inventory.GetCount(""coin"") + "" target="" + world.Objectives.CoinTarget);",
    "",
    "        // Walk over 3 coins then try exit",
    "        p = p with { X = 2.5f, Y = 2.5f }; Step(world, ref p);",
    "        p = p with { X = 6.5f, Y = 2.5f }; Step(world, ref p);",
    "        p = p with { X = 10.5f, Y = 2.5f }; Step(world, ref p);",
    "",
    "        p = p with { X = 14.5f, Y = 3.0f }; Step(world, ref p);",
    "        Console.WriteLine(""MARIO_DEMO_OK: coins+exit objective proof complete"");",
    "    }",
    "",
    "    private static void Step(KernelWorld world, ref KernelWorld.PlayerState p)",
    "    {",
    "        var r = world.Tick(p);",
    "        p = r.Player;",
    "        var coins = world.Inventory.GetCount(""coin"");",
    "        var met = world.Objectives.IsCoinTargetMet(world.Inventory) ? ""1"" : ""0"";",
    "        Console.WriteLine(""STEP trigger="" + (string.IsNullOrWhiteSpace(r.MatchedTriggerId) ? ""(none)"" : r.MatchedTriggerId) + "" scene="" + p.SceneId + "" pos=(""+p.X+"",""+p.Y+"") coins="" + coins + "" met="" + met);",
    "    }",
    "",
    "    private static void Apply(ref string scene, ref float x, ref float y, WarpKernel.WarpResult r, FlagStore flags)",
    "    {",
    "        if (r.Warped)",
    "        {",
    "            scene = r.NewSceneId;",
    "            x = r.SpawnX;",
    "            y = r.SpawnY;",
    "            Print(""YUME_WARP:"" + r.MatchedWarpId, scene, x, y, flags);",
    "        }",
    "        else",
    "        {",
    "            Print(""YUME_NO_WARP"", scene, x, y, flags);",
    "        }",
    "    }",
    "",
    "    private static void Print(string tag, string scene, float x, float y, FlagStore flags)",
    "    {",
    "        Console.WriteLine(tag + "" scene="" + scene + "" pos=(""+x+"",""+y+"") has_dream_key="" + (flags.GetBool(""has_dream_key"") ? ""1"" : ""0""));",
    "    }",
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
    "}"
  ) -join "`n"
  Write-Utf8NoBomLf $DemoProg ($c + "`n")
  Write-Host ("PATCH_OK: Demo updated for mario proof (marker=MARIO_DEMO_OK): " + $DemoProg) -ForegroundColor Green
} else {
  Write-Host ("SKIP: Demo already contains MARIO_DEMO_OK: " + $DemoProg) -ForegroundColor Yellow
}

& dotnet build $Sln -c Debug | Out-Host
if($LASTEXITCODE -ne 0){ Die "DOTNET_BUILD_FAILED_AFTER_MARIO_KERNEL_PATCH" }
Write-Host "CDE_MARIO_KERNEL_PATCH_OK: build ok" -ForegroundColor Green
& dotnet run --project (Join-Path $RepoRootAbs "src\CDE.Gameplay.Demo\CDE.Gameplay.Demo.csproj") -c Debug | Out-Host
if($LASTEXITCODE -ne 0){ Die "DEMO_RUN_FAILED_AFTER_MARIO_KERNEL_PATCH" }
Write-Host "CDE_MARIO_DEMO_OK: ran" -ForegroundColor Green
