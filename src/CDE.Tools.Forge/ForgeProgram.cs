using System;
using System.IO;
using System.Threading.Tasks;
using CDE.Tools.Forge.Commands;

namespace CDE.Tools.Forge;

public static class ForgeProgram
{
    public static async Task<int> MainAsync(string[] args)
    {
        var cmd = args.Length > 0 ? args[0].Trim().ToLowerInvariant() : "help";
        var repoRoot = FindRepoRoot(Directory.GetCurrentDirectory());
        if (repoRoot == null)
        {
            Console.Error.WriteLine("FORGE_ERR: could not find repo root (expected CDE.sln)");
            return 2;
        }

        var ctx = new ForgeContext(repoRoot);

        try
        {
            return cmd switch
            {
                "build"  => await new BuildCommand().Run(ctx),
                "run"    => await new RunCommand().Run(ctx),
                "import" => await new ImportCommand().Run(ctx, args),
                "clean"  => await new CleanCommand().Run(ctx),
                "doctor" => await new DoctorCommand().Run(ctx),
                _        => Help()
            };
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("FORGE_FAIL: " + ex.Message);
            return 1;
        }
    }

    private static int Help()
    {
        Console.WriteLine("CDE Forge v0.1");
        Console.WriteLine("Usage:");
        Console.WriteLine("  forge build");
        Console.WriteLine("  forge run");
        Console.WriteLine("  forge import <path>");
        Console.WriteLine("  forge clean");
        Console.WriteLine("  forge doctor");
        return 0;
    }

    private static string? FindRepoRoot(string start)
    {
        var cur = new DirectoryInfo(start);
        while (cur != null)
        {
            var sln = Path.Combine(cur.FullName, "CDE.sln");
            if (File.Exists(sln)) return cur.FullName;
            cur = cur.Parent;
        }
        return null;
    }
}
