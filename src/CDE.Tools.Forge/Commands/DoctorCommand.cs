using System;
using System.IO;
using System.Threading.Tasks;

namespace CDE.Tools.Forge.Commands;

public sealed class DoctorCommand
{
    public Task<int> Run(ForgeContext ctx)
    {
        Console.WriteLine("FORGE_DOCTOR:");
        Console.WriteLine("  repo_root=" + ctx.RepoRoot);
        Console.WriteLine("  assets_src_exists=" + Directory.Exists(ctx.AssetsSrc));
        Console.WriteLine("  assets_build_exists=" + Directory.Exists(ctx.AssetsBuild));
        Console.WriteLine("FORGE_DOCTOR_OK");
        return Task.FromResult(0);
    }
}
