using System;
using System.IO;
using System.Threading.Tasks;

namespace CDE.Tools.Forge.Commands;

public sealed class CleanCommand
{
    public Task<int> Run(ForgeContext ctx)
    {
        if (Directory.Exists(ctx.AssetsBuild))
        {
            Directory.Delete(ctx.AssetsBuild, recursive: true);
            Console.WriteLine("FORGE_CLEAN_OK: assets_build deleted");
        }
        else
        {
            Console.WriteLine("FORGE_CLEAN_OK: nothing to clean");
        }
        return Task.FromResult(0);
    }
}
