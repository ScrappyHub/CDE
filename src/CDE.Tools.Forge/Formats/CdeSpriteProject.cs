namespace CDE.Tools.Forge.Formats;

// v0.1 placeholder for .cdesprite.json
public sealed class CdeSpriteProject
{
    public string schema { get; set; } = "cde.sprite.project.v1";
    public int width { get; set; }
    public int height { get; set; }
    public object? palette { get; set; }
    public object[] layers { get; set; } = System.Array.Empty<object>();
    public object[] frames { get; set; } = System.Array.Empty<object>();
    public object[] tags { get; set; } = System.Array.Empty<object>();
}
