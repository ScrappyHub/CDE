using System;
using System.IO;
using System.Threading.Tasks;

namespace CDE.Tools.Forge.Commands;

public sealed class ImportCommand
{
    public Task<int> Run(ForgeContext ctx, string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("FORGE_IMPORT_ERR: missing <path>");
            return Task.FromResult(2);
        }

        var srcPath = Path.GetFullPath(args[1]);
        if (!Directory.Exists(srcPath))
        {
            Console.Error.WriteLine("FORGE_IMPORT_ERR: directory not found: " + srcPath);
            return Task.FromResult(2);
        }

        Directory.CreateDirectory(ctx.AssetsSrc);

        var name = new DirectoryInfo(srcPath).Name;
        var dstRoot = Path.Combine(ctx.AssetsSrc, "imported", name);
        Directory.CreateDirectory(dstRoot);

        foreach (var f in Directory.GetFiles(srcPath, "*", SearchOption.AllDirectories))
        {
            var rel = Path.GetRelativePath(srcPath, f);
            var dst = Path.Combine(dstRoot, rel);
            Directory.CreateDirectory(Path.GetDirectoryName(dst)!);
            File.Copy(f, dst, overwrite: true);
        }

        Console.WriteLine("FORGE_IMPORT_OK: " + dstRoot);
        return Task.FromResult(0);
    }
}
