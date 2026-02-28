namespace CDE.Gameplay.Kernel;

public sealed class FlagStore
{
    private readonly Dictionary<string,int> _ints = new(StringComparer.Ordinal);

    public int GetInt(string key)
    {
        if (string.IsNullOrWhiteSpace(key)) return 0;
        return _ints.TryGetValue(key, out var v) ? v : 0;
    }

    public bool GetBool(string key) => GetInt(key) != 0;

    public void SetInt(string key, int value)
    {
        if (string.IsNullOrWhiteSpace(key)) return;
        _ints[key] = value;
    }

    public void SetBool(string key, bool value) => SetInt(key, value ? 1 : 0);
}
