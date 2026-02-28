using System.Collections.Generic;

namespace CDE.Runtime.Engine.Scene;

public sealed class SceneStack
{
    private readonly Stack<Scene> _stack = new();

    public Scene? Current => _stack.Count > 0 ? _stack.Peek() : null;

    public void Push(Scene scene)
    {
        _stack.Push(scene);
        scene.OnEnter();
    }

    public void Pop()
    {
        if (_stack.Count <= 0) return;
        var s = _stack.Pop();
        s.OnExit();
    }

    public void Clear()
    {
        while (_stack.Count > 0) Pop();
    }
}
