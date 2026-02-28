namespace CDE.Gameplay.Kernel;

public sealed class Objectives
{
    public int CoinTarget { get; }

    public Objectives(int coinTarget)
    {
        CoinTarget = coinTarget < 0 ? 0 : coinTarget;
    }

    public bool IsCoinTargetMet(Inventory inv)
    {
        if (inv is null) return CoinTarget <= 0;
        return inv.GetCount("coin") >= CoinTarget;
    }
}
