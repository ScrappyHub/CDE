using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;

namespace CDE.Tools.Forge.Commands;

public sealed class RunCommand
{
    public async Task<int> Run(ForgeContext ctx)
    {
        var b = await new BuildCommand().Run(ctx);
        if (b != 0) return b;

        var gameProj = Path.Combine(ctx.RepoRoot, "src", "CDE.Game", "CDE.Game.csproj");
        if (!File.Exists(gameProj))
        {
            Console.Error.WriteLine("FORGE_ERR: missing CDE.Game.csproj at src/CDE.Game/");
            return 2;
        }

        var psi = new ProcessStartInfo
        {
            FileName = "dotnet",
            Arguments = $"run --project \"{gameProj}\"",
            UseShellExecute = false
        };

        Console.WriteLine("FORGE_RUN: dotnet " + psi.Arguments);
        using var p = Process.Start(psi);
        if (p == null) return 3;
        await p.WaitForExitAsync();
        return p.ExitCode;
    }
}
