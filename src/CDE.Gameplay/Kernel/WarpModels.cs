namespace CDE.Gameplay.Kernel;

public sealed class WarpEdge
{
    public string Id { get; init; } = "";
    public string FromScene { get; init; } = "";
    public string ToScene { get; init; } = "";
    public float SpawnX { get; init; } = 0f;
    public float SpawnY { get; init; } = 0f;
    public RectF Zone { get; init; } = new RectF(0,0,0,0);
    public string RequireFlag { get; init; } = "";
    public string SetFlag { get; init; } = "";
}

public sealed class WarpGraph
{
    public List<WarpEdge> Warps { get; init; } = new();
}
