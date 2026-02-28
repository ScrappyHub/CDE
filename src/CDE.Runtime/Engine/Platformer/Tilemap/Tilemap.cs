namespace CDE.Runtime.Engine.Platformer.Tilemap;

public sealed class Tilemap
{
    public int TileSize { get; }
    public int Width { get; }
    public int Height { get; }
    private readonly bool[] _solid;

    public Tilemap(int tileSize, int width, int height)
    {
        if (tileSize <= 0) throw new System.ArgumentOutOfRangeException(nameof(tileSize));
        if (width <= 0 || height <= 0) throw new System.ArgumentOutOfRangeException(nameof(width));
        TileSize = tileSize;
        Width = width;
        Height = height;
        _solid = new bool[width * height];
    }

    public bool InBounds(int tx, int ty) => tx >= 0 && ty >= 0 && tx < Width && ty < Height;
    public bool IsSolid(int tx, int ty) => InBounds(tx, ty) && _solid[(ty * Width) + tx];

    public void SetSolid(int tx, int ty, bool solid)
    {
        if (!InBounds(tx, ty)) return;
        _solid[(ty * Width) + tx] = solid;
    }
}
