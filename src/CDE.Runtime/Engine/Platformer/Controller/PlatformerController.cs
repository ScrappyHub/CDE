using CDE.Runtime.Engine.Input;
using CDE.Runtime.Engine.Platformer.Tilemap;


namespace CDE.Runtime.Engine.Platformer.Controller;

public sealed class PlatformerController
{
    private readonly PlatformerTuning _t;
    private int _coyote;
    private int _jumpBuf;
    public bool Grounded { get; private set; }

    public float X;
    public float Y;
    public float Vx;
    public float Vy;

    public float W = 10f;
    public float H = 14f;

    public PlatformerController(PlatformerTuning tuning, float startX, float startY)
    {
        _t = tuning;
        X = startX;
        Y = startY;
    }

    public void FixedTick60(InputMap input, CDE.Runtime.Engine.Platformer.Tilemap.Tilemap map)
    {
        // Update timers
        if (Grounded) _coyote = _t.CoyoteTicks; else if (_coyote > 0) _coyote--;
        if (_jumpBuf > 0) _jumpBuf--;

        // Horizontal
        var left = input.Get(InputAction.MoveLeft).Down;
        var right = input.Get(InputAction.MoveRight).Down;
        var move = (left ? -1 : 0) + (right ? 1 : 0);

        var movePerTick = _t.MoveSpeedPxPerSec / 60f;
        Vx = move * movePerTick;

        // Jump buffer
        var jumpPressed = input.Get(InputAction.Jump).Pressed;
        var jumpDown = input.Get(InputAction.Jump).Down;
        var jumpReleased = input.Get(InputAction.Jump).Released;

        if (jumpPressed) _jumpBuf = _t.JumpBufferTicks;

        // Jump if buffered and we are within coyote/grounded
        if (_jumpBuf > 0 && (_coyote > 0 || Grounded))
        {
            Vy = -(_t.JumpSpeedPxPerSec / 60f);
            Grounded = false;
            _coyote = 0;
            _jumpBuf = 0;
        }

        // Variable jump cut
        if (jumpReleased && Vy < 0f)
        {
            Vy *= _t.JumpCutMultiplier;
        }

        // Gravity
        Vy += (_t.GravityPxPerSec2 / 60f) / 60f; // (px/s^2) -> per-tick delta

        var maxFallPerTick = _t.MaxFallSpeedPxPerSec / 60f;
        if (Vy > maxFallPerTick) Vy = maxFallPerTick;

        // Resolve collisions (vx/vy are in pixels per tick)
        var vx = Vx;
        var vy = Vy;
        TileCollision.ResolveSolidTiles(map, ref X, ref Y, W, H, ref vx, ref vy, out var groundedNow);
        Vx = vx;
        Vy = vy;
        Grounded = groundedNow;

        // If grounded, kill tiny downward drift
        if (Grounded && Vy > 0f) Vy = 0f;
    }
}
