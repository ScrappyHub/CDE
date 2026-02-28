namespace CDE.Gameplay.Kernel;

public sealed class Inventory
{
    private readonly Dictionary<string,int> _counts = new(StringComparer.Ordinal);

    public int GetCount(string itemId)
    {
        if (string.IsNullOrWhiteSpace(itemId)) return 0;
        return _counts.TryGetValue(itemId, out var v) ? v : 0;
    }

    public void Add(string itemId, int amount)
    {
        if (string.IsNullOrWhiteSpace(itemId)) return;
        if (amount <= 0) return;
        var cur = GetCount(itemId);
        _counts[itemId] = checked(cur + amount);
    }
}
