using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using CDE.Tools.Forge.Pipeline;

namespace CDE.Tools.Forge.Commands;

public sealed class BuildCommand
{
    public Task<int> Run(ForgeContext ctx)
    {
        Directory.CreateDirectory(ctx.AssetsSrc);
        Directory.CreateDirectory(ctx.AssetsBuild);

        var files = AssetScanner.ScanAllFiles(ctx.AssetsSrc)
            .OrderBy(p => p.Replace('\\','/') , StringComparer.Ordinal)
            .ToArray();

        foreach (var src in files)
        {
            var rel = Path.GetRelativePath(ctx.AssetsSrc, src);
            var dst = Path.Combine(ctx.AssetsBuild, rel);
            Directory.CreateDirectory(Path.GetDirectoryName(dst)!);
            File.Copy(src, dst, overwrite: true);
        }

        var manifest = new
        {
            schema = "cde.assets.manifest.v1",
            generated_utc = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"),
            files = files.Select(f => Path.GetRelativePath(ctx.AssetsSrc, f).Replace('\\','/')).ToArray()
        };

        var json = JsonSerializer.Serialize(manifest, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(Path.Combine(ctx.AssetsBuild, "manifest.json"), json);

        Console.WriteLine($"FORGE_BUILD_OK: files={files.Length}");
        return Task.FromResult(0);
    }
}
