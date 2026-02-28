using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;

namespace CDE.Runtime.Engine.Graphics;

public static class SpriteDraw
{
    public static Vector2 Snap(Vector2 p)
        => new((float)System.Math.Round(p.X), (float)System.Math.Round(p.Y));

    public static void DrawSnapped(
        SpriteBatch sb,
        Texture2D tex,
        Vector2 pos,
        Rectangle? src,
        Color color)
    {
        sb.Draw(tex, Snap(pos), src, color);
    }
}
