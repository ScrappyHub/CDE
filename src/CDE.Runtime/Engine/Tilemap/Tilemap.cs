namespace CDE.Runtime.Engine.Tilemap;

public sealed class Tilemap
{
    public int Width { get; } = 0;
    public int Height { get; } = 0;
    public int TileSize { get; } = 16;

    public bool IsSolidAtCell(int x, int y) => false;
}
