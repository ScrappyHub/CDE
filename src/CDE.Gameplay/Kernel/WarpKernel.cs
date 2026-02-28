using System.Text.Json;
using System.Text.Json.Serialization;

namespace CDE.Gameplay.Kernel;

public sealed class WarpKernel
{
    public sealed record WarpRequest(string SceneId, float PlayerX, float PlayerY);
    public sealed record WarpResult(bool Warped, string NewSceneId, float SpawnX, float SpawnY, string MatchedWarpId);

    private readonly WarpGraph _graph;
    private readonly FlagStore _flags;

    public WarpKernel(WarpGraph graph, FlagStore flags)
    {
        _graph = graph ?? new WarpGraph();
        _flags = flags ?? new FlagStore();
    }

    public WarpResult TryWarp(WarpRequest req)
    {
        foreach (var w in _graph.Warps)
        {
            if (!string.Equals(w.FromScene, req.SceneId, StringComparison.Ordinal)) continue;
            if (!w.Zone.Contains(req.PlayerX, req.PlayerY)) continue;

            if (!string.IsNullOrWhiteSpace(w.RequireFlag))
            {
                if (!_flags.GetBool(w.RequireFlag)) continue;
            }

            if (!string.IsNullOrWhiteSpace(w.SetFlag))
            {
                _flags.SetBool(w.SetFlag, true);
            }

            return new WarpResult(true, w.ToScene, w.SpawnX, w.SpawnY, w.Id);
        }
        return new WarpResult(false, req.SceneId, req.PlayerX, req.PlayerY, "");
    }

    public static WarpGraph LoadWarpGraphJson(string json)
    {
        var opt = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            ReadCommentHandling = JsonCommentHandling.Skip,
            AllowTrailingCommas = true
        };
        opt.Converters.Add(new RectFJsonConverter());
        var g = JsonSerializer.Deserialize<WarpGraph>(json, opt);
        return g ?? new WarpGraph();
    }

    private sealed class RectFJsonConverter : JsonConverter<RectF>
    {
        public override RectF Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType != JsonTokenType.StartObject) throw new JsonException();
            float x = 0, y = 0, w = 0, h = 0;
            while (reader.Read())
            {
                if (reader.TokenType == JsonTokenType.EndObject) break;
                if (reader.TokenType != JsonTokenType.PropertyName) throw new JsonException();
                var name = reader.GetString() ?? "";
                reader.Read();
                var v = reader.TokenType == JsonTokenType.Number ? reader.GetSingle() : 0f;
                if (string.Equals(name, "x", StringComparison.OrdinalIgnoreCase)) x = v;
                else if (string.Equals(name, "y", StringComparison.OrdinalIgnoreCase)) y = v;
                else if (string.Equals(name, "w", StringComparison.OrdinalIgnoreCase)) w = v;
                else if (string.Equals(name, "h", StringComparison.OrdinalIgnoreCase)) h = v;
            }
            return new RectF(x, y, w, h);
        }

        public override void Write(Utf8JsonWriter writer, RectF value, JsonSerializerOptions options)
        {
            writer.WriteStartObject();
            writer.WriteNumber("x", value.X);
            writer.WriteNumber("y", value.Y);
            writer.WriteNumber("w", value.W);
            writer.WriteNumber("h", value.H);
            writer.WriteEndObject();
        }
    }
}
