using Microsoft.Xna.Framework;

namespace CDE.Runtime.Engine.Graphics;

/// <summary>
/// Camera that snaps its translation to integer pixels in virtual space.
/// World units are pixels by default (1 unit = 1 pixel).
/// </summary>
public sealed class PixelPerfectCamera2D
{
    public Vector2 Position { get; set; } = Vector2.Zero;
    public Vector2 Origin { get; set; } = Vector2.Zero;

    /// <summary>Optional smoothing (0 = none). Keep small (e.g., 0.10f).</summary>
    public float SmoothFollow { get; set; } = 0f;

    public void Follow(Vector2 target)
    {
        if (SmoothFollow <= 0f)
        {
            Position = target;
            return;
        }
        Position = Vector2.Lerp(Position, target, SmoothFollow);
    }

    public Matrix GetViewMatrix()
    {
        var snapped = new Vector2((float)System.Math.Floor(Position.X), (float)System.Math.Floor(Position.Y));
        return Matrix.CreateTranslation(new Vector3(-snapped + Origin, 0f));
    }
}
