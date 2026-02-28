namespace CDE.Gameplay.Kernel;

public abstract record TriggerBase(
    string Type,
    string Id,
    string SceneId,
    RectF Zone,
    bool OneShot,
    string FiredFlag
);

public sealed record PickupTrigger(
    string Id,
    string SceneId,
    RectF Zone,
    bool OneShot,
    string FiredFlag,
    string ItemId,
    int Amount
) : TriggerBase("pickup", Id, SceneId, Zone, OneShot, FiredFlag);

public sealed record ExitTrigger(
    string Id,
    string SceneId,
    RectF Zone,
    bool OneShot,
    string FiredFlag,
    string ToScene,
    float SpawnX,
    float SpawnY,
    string RequireFlag,
    int RequireCoins
) : TriggerBase("exit", Id, SceneId, Zone, OneShot, FiredFlag);
