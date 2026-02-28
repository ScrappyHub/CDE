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
