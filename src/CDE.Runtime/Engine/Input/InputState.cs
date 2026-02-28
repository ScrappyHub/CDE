namespace CDE.Runtime.Engine.Input;

public readonly struct InputState
{
    public readonly bool Down;
    public readonly bool Pressed;
    public readonly bool Released;

    public InputState(bool down, bool pressed, bool released)
    {
        Down = down;
        Pressed = pressed;
        Released = released;
    }
}
