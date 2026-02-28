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

$MarioJson = Join-Path $RepoRootAbs "assets_src\gameplay\mario_graph.v1.json"
Backup-IfExists $MarioJson
$j = @'
{
  "coinTarget": 3,
  "triggers": [
    { "type": "pickup", "id": "coin_a", "sceneId": "MarioRoom", "zone": { "x": 2,  "y": 2, "w": 2, "h": 2 }, "oneShot": true,  "firedFlag": "picked_coin_a", "itemId": "coin", "amount": 1 },
    { "type": "pickup", "id": "coin_b", "sceneId": "MarioRoom", "zone": { "x": 6,  "y": 2, "w": 2, "h": 2 }, "oneShot": true,  "firedFlag": "picked_coin_b", "itemId": "coin", "amount": 1 },
    { "type": "pickup", "id": "coin_c", "sceneId": "MarioRoom", "zone": { "x": 10, "y": 2, "w": 2, "h": 2 }, "oneShot": true,  "firedFlag": "picked_coin_c", "itemId": "coin", "amount": 1 },
    { "type": "exit",   "id": "exit_locked", "sceneId": "MarioRoom", "zone": { "x": 14, "y": 2, "w": 3, "h": 4 }, "oneShot": false, "firedFlag": "", "toScene": "MarioGoal", "spawnX": 1, "spawnY": 1, "requireFlag": "", "requireCoins": 3 }
  ]
}
'@
Write-Utf8NoBomLf $MarioJson ($j + "`n")
Write-Host ("WROTE: " + $MarioJson) -ForegroundColor Green

$DemoProg = Join-Path $RepoRootAbs "src\CDE.Gameplay.Demo\Program.cs"
if(-not (Test-Path -LiteralPath $DemoProg -PathType Leaf)){ Die ("MISSING_DEMO_PROGRAM: " + $DemoProg) }
Backup-IfExists $DemoProg
$demo = @'
using System.Text;
using CDE.Gameplay.Kernel;

static class Program
{
    private static string ReadUtf8(string path) => File.ReadAllText(path, new UTF8Encoding(false));

    private static void Main(string[] args)
    {
        var root = FindRepoRoot(AppContext.BaseDirectory);
        RunYumeProof(root);
        RunMarioProof(root);
    }

    private static void RunYumeProof(string root)
    {
        var jsonPath = Path.Combine(root, "assets_src", "gameplay", "warp_graph.v1.json");
        if (!File.Exists(jsonPath)) { Console.WriteLine("DEMO_MISSING_WARP_GRAPH: " + jsonPath); Environment.ExitCode = 2; return; }
        var flags = new FlagStore();
        flags.SetBool("has_dream_key", false);
        var graph = WarpKernel.LoadWarpGraphJson(ReadUtf8(jsonPath));
        var kernel = new WarpKernel(graph, flags);
        var scene = "StartRoom";
        float x = 1, y = 1;
        Print("YUME_START", scene, x, y, flags);
        x = 12; y = 2;
        Apply(ref scene, ref x, ref y, kernel.TryWarp(new WarpKernel.WarpRequest(scene, x, y)), flags);
        x = 3; y = 9;
        Apply(ref scene, ref x, ref y, kernel.TryWarp(new WarpKernel.WarpRequest(scene, x, y)), flags);
        Console.WriteLine("YUME_DEMO_OK: warp+flags proof complete");
    }

    private static void RunMarioProof(string root)
    {
        var jsonPath = Path.Combine(root, "assets_src", "gameplay", "mario_graph.v1.json");
        if (!File.Exists(jsonPath)) { Console.WriteLine("MARIO_MISSING_GRAPH: " + jsonPath); Environment.ExitCode = 3; return; }
        var world = KernelWorld.LoadMarioJson(ReadUtf8(jsonPath));
        var p = new KernelWorld.PlayerState("MarioRoom", 0, 0);
        Console.WriteLine("MARIO_START scene=" + p.SceneId + " coins=" + world.Inventory.GetCount("coin") + " target=" + world.Objectives.CoinTarget);

        p = p with { X = 2.5f,  Y = 2.5f  }; Step(world, ref p);
        p = p with { X = 6.5f,  Y = 2.5f  }; Step(world, ref p);
        p = p with { X = 10.5f, Y = 2.5f  }; Step(world, ref p);

        p = p with { X = 14.5f, Y = 3.0f  }; Step(world, ref p);
        if (!string.Equals(p.SceneId, "MarioGoal", StringComparison.Ordinal))
        {
            Console.WriteLine("MARIO_EXIT_WARP_MISSING: expected=MarioGoal got=" + p.SceneId);
            Environment.ExitCode = 5;
            return;
        }
        Console.WriteLine("MARIO_DEMO_OK: coins+exit objective proof complete");
    }

    private static void Step(KernelWorld world, ref KernelWorld.PlayerState p)
    {
        var r = world.Tick(p);
        p = r.Player;
        var coins = world.Inventory.GetCount("coin");
        var met = world.Objectives.IsCoinTargetMet(world.Inventory) ? "1" : "0";
        Console.WriteLine("STEP trigger=" + (string.IsNullOrWhiteSpace(r.MatchedTriggerId) ? "(none)" : r.MatchedTriggerId) + " scene=" + p.SceneId + " pos=(" + p.X + "," + p.Y + ") coins=" + coins + " met=" + met);
    }

    private static void Apply(ref string scene, ref float x, ref float y, WarpKernel.WarpResult r, FlagStore flags)
    {
        if (r.Warped)
        {
            scene = r.NewSceneId; x = r.SpawnX; y = r.SpawnY;
            Print("YUME_WARP:" + r.MatchedWarpId, scene, x, y, flags);
        }
        else
        {
            Print("YUME_NO_WARP", scene, x, y, flags);
        }
    }

    private static void Print(string tag, string scene, float x, float y, FlagStore flags)
        => Console.WriteLine(tag + " scene=" + scene + " pos=(" + x + "," + y + ") has_dream_key=" + (flags.GetBool("has_dream_key") ? "1" : "0"));

    private static string FindRepoRoot(string start)
    {
        var d = new DirectoryInfo(start);
        for (int i = 0; i < 12 && d != null; i++)
        {
            var sln = Path.Combine(d.FullName, "CDE.sln");
            if (File.Exists(sln)) return d.FullName;
            d = d.Parent;
        }
        return Directory.GetCurrentDirectory();
    }
}
'@
Write-Utf8NoBomLf $DemoProg ($demo + "`n")
Write-Host ("PATCH_OK: Demo asserts Mario exit warp: " + $DemoProg) -ForegroundColor Green

& dotnet build $Sln -c Debug | Out-Host
if($LASTEXITCODE -ne 0){ Die "DOTNET_BUILD_FAILED_AFTER_MARIO_PROOF_V4" }
& dotnet run --project (Join-Path $RepoRootAbs "src\CDE.Gameplay.Demo\CDE.Gameplay.Demo.csproj") -c Debug | Out-Host
if($LASTEXITCODE -ne 0){ Die "DEMO_RUN_FAILED_AFTER_MARIO_PROOF_V4" }
Write-Host "CDE_MARIO_PROOF_V4_OK" -ForegroundColor Green
