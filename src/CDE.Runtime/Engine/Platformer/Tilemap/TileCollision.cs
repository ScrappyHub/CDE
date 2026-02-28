using CDE.Runtime.Engine.Platformer.Physics;

namespace CDE.Runtime.Engine.Platformer.Tilemap;

public static class TileCollision
{
    // Resolve X then Y (platformer-friendly).
    public static void ResolveSolidTiles(Tilemap map, ref float x, ref float y, float w, float h, ref float vx, ref float vy, out bool grounded)
    {
        grounded = false;

        // --- X move ---
        if (vx != 0f)
        {
            var newX = x + vx;
            var box = new Aabb(newX, y, w, h);
            if (Collides(map, box))
            {
                // step back to nearest non-colliding pixel
                var step = vx > 0f ? 1f : -1f;
                while (!Collides(map, new Aabb(x + step, y, w, h)))
                {
                    x += step;
                }
                vx = 0f;
            }
            else
            {
                x = newX;
            }
        }

        // --- Y move ---
        if (vy != 0f)
        {
            var newY = y + vy;
            var box = new Aabb(x, newY, w, h);
            if (Collides(map, box))
            {
                var step = vy > 0f ? 1f : -1f;
                while (!Collides(map, new Aabb(x, y + step, w, h)))
                {
                    y += step;
                }

                // if we were moving down and hit something, we are grounded
                if (vy > 0f) grounded = true;
                vy = 0f;
            }
            else
            {
                y = newY;
            }
        }
    }

    private static bool Collides(Tilemap map, Aabb box)
    {
        var ts = map.TileSize;
        int left = (int)System.Math.Floor(box.Left / ts);
        int right = (int)System.Math.Floor((box.Right - 0.001f) / ts);
        int top = (int)System.Math.Floor(box.Top / ts);
        int bottom = (int)System.Math.Floor((box.Bottom - 0.001f) / ts);

        for (int ty = top; ty <= bottom; ty++)
        for (int tx = left; tx <= right; tx++)
        {
            if (map.IsSolid(tx, ty)) return true;
        }
        return false;
    }
}
