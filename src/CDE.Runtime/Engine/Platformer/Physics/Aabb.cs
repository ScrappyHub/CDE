using Microsoft.Xna.Framework;

namespace CDE.Runtime.Engine.Platformer.Physics;

public readonly struct Aabb
{
    public readonly float X;
    public readonly float Y;
    public readonly float W;
    public readonly float H;

    public Aabb(float x, float y, float w, float h)
    {
        X = x; Y = y; W = w; H = h;
    }

    public float Left => X;
    public float Right => X + W;
    public float Top => Y;
    public float Bottom => Y + H;

    public Aabb WithXY(float x, float y) => new Aabb(x, y, W, H);
    public Rectangle ToRect() => new Rectangle((int)System.Math.Floor(X), (int)System.Math.Floor(Y), (int)System.Math.Ceiling(W), (int)System.Math.Ceiling(H));
}
