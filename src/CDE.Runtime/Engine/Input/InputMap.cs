using System.Collections.Generic;
using Microsoft.Xna.Framework.Input;

namespace CDE.Runtime.Engine.Input;

/// <summary>
/// Action-based input mapping. Keyboard-only v0.1 (gamepad later).
/// </summary>
public sealed class InputMap
{
    private readonly Dictionary<InputAction, Keys[]> _map = new();
    private KeyboardState _prev;
    private KeyboardState _cur;

    public void Set(InputAction action, params Keys[] keys)
        => _map[action] = keys ?? System.Array.Empty<Keys>();

    public void Update()
    {
        _prev = _cur;
        _cur = Keyboard.GetState();
    }

    public InputState Get(InputAction action)
    {
        if (!_map.TryGetValue(action, out var keys) || keys.Length == 0)
            return new InputState(false, false, false);

        bool curDown = false;
        bool prevDown = false;

        for (var i = 0; i < keys.Length; i++)
        {
            var k = keys[i];
            curDown |= _cur.IsKeyDown(k);
            prevDown |= _prev.IsKeyDown(k);
        }

        var pressed = curDown && !prevDown;
        var released = !curDown && prevDown;
        return new InputState(curDown, pressed, released);
    }
}
