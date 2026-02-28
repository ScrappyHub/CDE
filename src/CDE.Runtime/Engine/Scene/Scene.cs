using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;

namespace CDE.Runtime.Engine.Scene;

public abstract class Scene
{
    public virtual void OnEnter() { }
    public virtual void OnExit() { }

    // FixedUpdate runs at a fixed timestep (e.g. 60Hz) for physics & controllers.
    public virtual void FixedUpdate(GameTime gameTime) { }

    // Update runs every frame (input sampling, timers).
    public virtual void Update(GameTime gameTime) { }

    public virtual void Draw(GameTime gameTime, SpriteBatch spriteBatch) { }
}
