namespace CDE.Gameplay.Kernel;

public readonly struct RectF
{
    public readonly float X;
    public readonly float Y;
    public readonly float W;
    public readonly float H;

    public RectF(float x, float y, float w, float h)
    {
        X = x; Y = y; W = w; H = h;
    }

    public bool Contains(float px, float py)
    {
        return px >= X && py >= Y && px < (X + W) && py < (Y + H);
    }
}
