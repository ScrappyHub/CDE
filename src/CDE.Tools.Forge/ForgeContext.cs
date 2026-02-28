using System.IO;

namespace CDE.Tools.Forge;

public sealed class ForgeContext
{
    public string RepoRoot { get; }
    public string AssetsSrc { get; }
    public string AssetsBuild { get; }

    public ForgeContext(string repoRoot)
    {
        RepoRoot = repoRoot;
        AssetsSrc = Path.Combine(repoRoot, "assets_src");
        AssetsBuild = Path.Combine(repoRoot, "assets_build");
    }
}
