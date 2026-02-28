using System.Collections.Generic;
using System.IO;

namespace CDE.Tools.Forge.Pipeline;

public static class AssetScanner
{
    public static IEnumerable<string> ScanAllFiles(string root)
    {
        if (!Directory.Exists(root)) yield break;

        foreach (var f in Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories))
        {
            var name = Path.GetFileName(f).ToLowerInvariant();
            if (name == "thumbs.db") continue;
            if (name.EndsWith(".tmp")) continue;
            yield return f;
        }
    }
}
