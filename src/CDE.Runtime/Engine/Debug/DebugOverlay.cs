using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;

namespace CDE.Runtime.Engine.Debug;

public sealed class DebugOverlay
{
    private double _accum;
    private int _frames;
    private int _fps;

    public bool Enabled { get; set; } = true;

    public void Update(GameTime gt)
    {
        _accum += gt.ElapsedGameTime.TotalSeconds;
        _frames++;

        if (_accum >= 1.0)
        {
            _fps = _frames;
            _frames = 0;
            _accum = 0;
        }
    }

    public void Draw(SpriteBatch sb, SpriteFont font)
    {
        if (!Enabled) return;
        sb.DrawString(font, $"FPS: {_fps}", new Vector2(4, 4), Color.White);
    }
}
