namespace CDE.Runtime.Engine.Platformer.Controller;

public sealed class PlatformerTuning
{
    // Units are pixels and ticks are 60Hz fixed steps.
    public float MoveSpeedPxPerSec { get; set; } = 90f;
    public float JumpSpeedPxPerSec { get; set; } = 230f;
    public float GravityPxPerSec2 { get; set; } = 650f;
    public float MaxFallSpeedPxPerSec { get; set; } = 420f;

    // Feel features
    public int CoyoteTicks { get; set; } = 6;       // ~100ms at 60Hz
    public int JumpBufferTicks { get; set; } = 6;   // ~100ms at 60Hz

    // Variable jump: if player releases jump early, cut upward velocity
    public float JumpCutMultiplier { get; set; } = 0.45f;
}
