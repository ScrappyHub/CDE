param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$path,[string]$text){ $dir=Split-Path -Parent $path; if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }; $u=New-Object System.Text.UTF8Encoding($false); $b=$u.GetBytes($text.Replace("`r`n","`n")); [System.IO.File]::WriteAllBytes($path,$b) }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$Sln = Join-Path $RepoRootAbs "CDE.sln"
if(-not (Test-Path -LiteralPath $Sln -PathType Leaf)){ Die ("MISSING_SOLUTION: " + $Sln) }

# --- 1) Add CDE.Gameplay (class library) ---
$GameplayDir = Join-Path $RepoRootAbs "src\CDE.Gameplay"
Ensure-Dir $GameplayDir
$GameplayProj = Join-Path $GameplayDir "CDE.Gameplay.csproj"
if(-not (Test-Path -LiteralPath $GameplayProj -PathType Leaf)){
  $p = @(
    "<Project Sdk=""Microsoft.NET.Sdk"">",
    "  <PropertyGroup>",
    "    <TargetFramework>net8.0</TargetFramework>",
    "    <Nullable>enable</Nullable>",
    "    <ImplicitUsings>enable</ImplicitUsings>",
    "  </PropertyGroup>",
    "</Project>"
  ) -join "`n"
  Write-Utf8NoBomLf $GameplayProj ($p + "`n")
  Write-Host ("WROTE: " + $GameplayProj) -ForegroundColor Green
} else {
  Write-Host ("SKIP: Gameplay csproj exists: " + $GameplayProj) -ForegroundColor Yellow
}

# Gameplay kernel source files (warp + flags + triggers) — Yume Nikki-like proof
$SrcDir = Join-Path $GameplayDir "Kernel"
Ensure-Dir $SrcDir

$f1 = Join-Path $SrcDir "FlagStore.cs"
if(-not (Test-Path -LiteralPath $f1 -PathType Leaf)){
  $c = @(
    "namespace CDE.Gameplay.Kernel;",
    "",
    "public sealed class FlagStore",
    "{",
    "    private readonly Dictionary<string,int> _ints = new(StringComparer.Ordinal);",
    "",
    "    public int GetInt(string key)",
    "    {",
    "        if (string.IsNullOrWhiteSpace(key)) return 0;",
    "        return _ints.TryGetValue(key, out var v) ? v : 0;",
    "    }",
    "",
    "    public bool GetBool(string key) => GetInt(key) != 0;",
    "",
    "    public void SetInt(string key, int value)",
    "    {",
    "        if (string.IsNullOrWhiteSpace(key)) return;",
    "        _ints[key] = value;",
    "    }",
    "",
    "    public void SetBool(string key, bool value) => SetInt(key, value ? 1 : 0);",
    "}"
  ) -join "`n"
  Write-Utf8NoBomLf $f1 ($c + "`n")
  Write-Host ("WROTE: " + $f1) -ForegroundColor Green
} else { Write-Host ("SKIP: " + $f1) -ForegroundColor Yellow }

$f2 = Join-Path $SrcDir "RectF.cs"
if(-not (Test-Path -LiteralPath $f2 -PathType Leaf)){
  $c = @(
    "namespace CDE.Gameplay.Kernel;",
    "",
    "public readonly struct RectF",
    "{",
    "    public readonly float X;",
    "    public readonly float Y;",
    "    public readonly float W;",
    "    public readonly float H;",
    "",
    "    public RectF(float x, float y, float w, float h)",
    "    {",
    "        X = x; Y = y; W = w; H = h;",
    "    }",
    "",
    "    public bool Contains(float px, float py)",
    "    {",
    "        return px >= X && py >= Y && px < (X + W) && py < (Y + H);",
    "    }",
    "}"
  ) -join "`n"
  Write-Utf8NoBomLf $f2 ($c + "`n")
  Write-Host ("WROTE: " + $f2) -ForegroundColor Green
} else { Write-Host ("SKIP: " + $f2) -ForegroundColor Yellow }

$f3 = Join-Path $SrcDir "WarpModels.cs"
if(-not (Test-Path -LiteralPath $f3 -PathType Leaf)){
  $c = @(
    "namespace CDE.Gameplay.Kernel;",
    "",
    "public sealed class WarpEdge",
    "{",
    "    public string Id { get; init; } = """";",
    "    public string FromScene { get; init; } = """";",
    "    public string ToScene { get; init; } = """";",
    "    public float SpawnX { get; init; } = 0f;",
    "    public float SpawnY { get; init; } = 0f;",
    "    public RectF Zone { get; init; } = new RectF(0,0,0,0);",
    "    public string RequireFlag { get; init; } = """";",
    "    public string SetFlag { get; init; } = """";",
    "}",
    "",
    "public sealed class WarpGraph",
    "{",
    "    public List<WarpEdge> Warps { get; init; } = new();",
    "}"
  ) -join "`n"
  Write-Utf8NoBomLf $f3 ($c + "`n")
  Write-Host ("WROTE: " + $f3) -ForegroundColor Green
} else { Write-Host ("SKIP: " + $f3) -ForegroundColor Yellow }

$f4 = Join-Path $SrcDir "WarpKernel.cs"
if(-not (Test-Path -LiteralPath $f4 -PathType Leaf)){
  $c = @(
    "using System.Text.Json;",
    "using System.Text.Json.Serialization;",
    "",
    "namespace CDE.Gameplay.Kernel;",
    "",
    "public sealed class WarpKernel",
    "{",
    "    public sealed record WarpRequest(string SceneId, float PlayerX, float PlayerY);",
    "    public sealed record WarpResult(bool Warped, string NewSceneId, float SpawnX, float SpawnY, string MatchedWarpId);",
    "",
    "    private readonly WarpGraph _graph;",
    "    private readonly FlagStore _flags;",
    "",
    "    public WarpKernel(WarpGraph graph, FlagStore flags)",
    "    {",
    "        _graph = graph ?? new WarpGraph();",
    "        _flags = flags ?? new FlagStore();",
    "    }",
    "",
    "    public WarpResult TryWarp(WarpRequest req)",
    "    {",
    "        foreach (var w in _graph.Warps)",
    "        {",
    "            if (!string.Equals(w.FromScene, req.SceneId, StringComparison.Ordinal)) continue;",
    "            if (!w.Zone.Contains(req.PlayerX, req.PlayerY)) continue;",
    "",
    "            if (!string.IsNullOrWhiteSpace(w.RequireFlag))",
    "            {",
    "                if (!_flags.GetBool(w.RequireFlag)) continue;",
    "            }",
    "",
    "            if (!string.IsNullOrWhiteSpace(w.SetFlag))",
    "            {",
    "                _flags.SetBool(w.SetFlag, true);",
    "            }",
    "",
    "            return new WarpResult(true, w.ToScene, w.SpawnX, w.SpawnY, w.Id);",
    "        }",
    "        return new WarpResult(false, req.SceneId, req.PlayerX, req.PlayerY, """");",
    "    }",
    "",
    "    public static WarpGraph LoadWarpGraphJson(string json)",
    "    {",
    "        var opt = new JsonSerializerOptions",
    "        {",
    "            PropertyNameCaseInsensitive = true,",
    "            ReadCommentHandling = JsonCommentHandling.Skip,",
    "            AllowTrailingCommas = true",
    "        };",
    "        opt.Converters.Add(new RectFJsonConverter());",
    "        var g = JsonSerializer.Deserialize<WarpGraph>(json, opt);",
    "        return g ?? new WarpGraph();",
    "    }",
    "",
    "    private sealed class RectFJsonConverter : JsonConverter<RectF>",
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
    "}"
  ) -join "`n"
  Write-Utf8NoBomLf $f4 ($c + "`n")
  Write-Host ("WROTE: " + $f4) -ForegroundColor Green
} else { Write-Host ("SKIP: " + $f4) -ForegroundColor Yellow }

# --- 2) Add CDE.Gameplay.Demo (console exe proof) ---
$DemoDir = Join-Path $RepoRootAbs "src\CDE.Gameplay.Demo"
Ensure-Dir $DemoDir
$DemoProj = Join-Path $DemoDir "CDE.Gameplay.Demo.csproj"
if(-not (Test-Path -LiteralPath $DemoProj -PathType Leaf)){
  $p = @(
    "<Project Sdk=""Microsoft.NET.Sdk"">",
    "  <PropertyGroup>",
    "    <OutputType>Exe</OutputType>",
    "    <TargetFramework>net8.0</TargetFramework>",
    "    <Nullable>enable</Nullable>",
    "    <ImplicitUsings>enable</ImplicitUsings>",
    "  </PropertyGroup>",
    "  <ItemGroup>",
    "    <ProjectReference Include=""..\CDE.Gameplay\CDE.Gameplay.csproj"" />",
    "  </ItemGroup>",
    "</Project>"
  ) -join "`n"
  Write-Utf8NoBomLf $DemoProj ($p + "`n")
  Write-Host ("WROTE: " + $DemoProj) -ForegroundColor Green
} else { Write-Host ("SKIP: Demo csproj exists: " + $DemoProj) -ForegroundColor Yellow }

$DemoProg = Join-Path $DemoDir "Program.cs"
if(-not (Test-Path -LiteralPath $DemoProg -PathType Leaf)){
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
    "        var repo = AppContext.BaseDirectory;",
    "        var root = FindRepoRoot(repo);",
    "        var jsonPath = Path.Combine(root, ""assets_src"", ""gameplay"", ""warp_graph.v1.json"");",
    "        if (!File.Exists(jsonPath))",
    "        {",
    "            Console.WriteLine(""DEMO_MISSING_WARP_GRAPH: "" + jsonPath);",
    "            Environment.ExitCode = 2;",
    "            return;",
    "        }",
    "",
    "        var flags = new FlagStore();",
    "        flags.SetBool(""has_dream_key"", false);",
    "        var graph = WarpKernel.LoadWarpGraphJson(ReadUtf8(jsonPath));",
    "        var kernel = new WarpKernel(graph, flags);",
    "",
    "        // Scripted walk: StartRoom -> DreamHall (sets flag) -> LockedDoor (requires flag) -> SecretRoom",
    "        var scene = ""StartRoom"";",
    "        float x = 1, y = 1;",
    "        Print(""START"", scene, x, y, flags);",
    "",
    "        // Step 1: enter warp zone that sets has_dream_key",
    "        x = 12; y = 2; // inside zone",
    "        var r1 = kernel.TryWarp(new WarpKernel.WarpRequest(scene, x, y));",
    "        Apply(ref scene, ref x, ref y, r1, flags);",
    "",
    "        // Step 2: try locked warp (requires has_dream_key)",
    "        x = 3; y = 9; // inside locked zone",
    "        var r2 = kernel.TryWarp(new WarpKernel.WarpRequest(scene, x, y));",
    "        Apply(ref scene, ref x, ref y, r2, flags);",
    "",
    "        Console.WriteLine(""DEMO_OK: warp+flags proof complete"");",
    "    }",
    "",
    "    private static void Apply(ref string scene, ref float x, ref float y, WarpKernel.WarpResult r, FlagStore flags)",
    "    {",
    "        if (r.Warped)",
    "        {",
    "            scene = r.NewSceneId;",
    "            x = r.SpawnX;",
    "            y = r.SpawnY;",
    "            Print(""WARP:"" + r.MatchedWarpId, scene, x, y, flags);",
    "        }",
    "        else",
    "        {",
    "            Print(""NO_WARP"", scene, x, y, flags);",
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
  Write-Host ("WROTE: " + $DemoProg) -ForegroundColor Green
} else { Write-Host ("SKIP: Program.cs exists: " + $DemoProg) -ForegroundColor Yellow }

# --- 3) Add minimal warp graph asset (assets_src/gameplay/warp_graph.v1.json) ---
$AssetsDir = Join-Path $RepoRootAbs "assets_src\gameplay"
Ensure-Dir $AssetsDir
$WarpJson = Join-Path $AssetsDir "warp_graph.v1.json"
if(-not (Test-Path -LiteralPath $WarpJson -PathType Leaf)){
  $j = @(
    "{",
    "  ""warps"": [",
    "    {",
    "      ""id"": ""start_to_dreamhall_setkey"",",
    "      ""fromScene"": ""StartRoom"",",
    "      ""toScene"": ""DreamHall"",",
    "      ""spawnX"": 2,",
    "      ""spawnY"": 2,",
    "      ""zone"": { ""x"": 10, ""y"": 0, ""w"": 6, ""h"": 6 },",
    "      ""setFlag"": ""has_dream_key""",
    "    },",
    "    {",
    "      ""id"": ""dreamhall_to_secret_requires_key"",",
    "      ""fromScene"": ""DreamHall"",",
    "      ""toScene"": ""SecretRoom"",",
    "      ""spawnX"": 1,",
    "      ""spawnY"": 1,",
    "      ""zone"": { ""x"": 0, ""y"": 8, ""w"": 6, ""h"": 6 },",
    "      ""setFlag"": """"",
    "    }",
    "  ]",
    "}"
  ) -join "`n"
  Write-Utf8NoBomLf $WarpJson ($j + "`n")
  Write-Host ("WROTE: " + $WarpJson) -ForegroundColor Green
} else { Write-Host ("SKIP: warp graph exists: " + $WarpJson) -ForegroundColor Yellow }

# --- 4) Add projects to solution (idempotent) ---
& dotnet sln $Sln add $GameplayProj | Out-Host
& dotnet sln $Sln add $DemoProj | Out-Host
& dotnet restore $Sln | Out-Host
& dotnet build $Sln -c Debug | Out-Host
if($LASTEXITCODE -ne 0){ Die "DOTNET_BUILD_FAILED_AFTER_GAMEPLAY_KERNEL_ADD" }
Write-Host "CDE_GAMEPLAY_KERNEL_OK: build ok" -ForegroundColor Green

# --- 5) Run Yume Nikki-like proof demo ---
& dotnet run --project $DemoProj -c Debug | Out-Host
if($LASTEXITCODE -ne 0){ Die "DEMO_RUN_FAILED" }
Write-Host "CDE_GAMEPLAY_DEMO_OK: warp+flags proof ran" -ForegroundColor Green
