using System.Security.Cryptography;
using System.Text.Encodings.Web;
using System.Text.Json;

namespace CareSitter.Nutrition.Infrastructure;

// Python jsonio canonical form. Keep original JSON number spelling from the producer.
internal static class RuntimeReleaseArtifact
{
    public static string ContentHash(JsonElement root, params string[] excluded)
    {
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping }))
            Write(writer, root, excluded);
        return Convert.ToHexString(SHA256.HashData(stream.ToArray())).ToLowerInvariant();
    }

    private static void Write(Utf8JsonWriter writer, JsonElement value, string[]? excluded = null)
    {
        if (value.ValueKind == JsonValueKind.Object)
        {
            writer.WriteStartObject();
            foreach (var property in value.EnumerateObject().OrderBy(p => p.Name, StringComparer.Ordinal))
            {
                if (excluded?.Contains(property.Name) == true) continue;
                writer.WritePropertyName(property.Name);
                Write(writer, property.Value);
            }
            writer.WriteEndObject();
        }
        else if (value.ValueKind == JsonValueKind.Array)
        {
            writer.WriteStartArray();
            foreach (var item in value.EnumerateArray()) Write(writer, item);
            writer.WriteEndArray();
        }
        else if (value.ValueKind == JsonValueKind.String) writer.WriteStringValue(value.GetString());
        else value.WriteTo(writer);
    }

    public static void Verify(JsonElement root, string mode, bool excludeTimestamp = false)
    {
        if (root.GetProperty("schema_version").GetInt32() != 1 || root.GetProperty("mode").GetString() != mode ||
            !Equal(root.GetProperty("content_sha256").GetString(), ContentHash(root,
                excludeTimestamp ? ["content_sha256", "created_at_utc"] : ["content_sha256"])))
            throw new InvalidOperationException("Release artifact integrity is invalid.");
    }

    public static bool Equal(string? left, string? right) =>
        left is not null && right is not null && left.Equals(right, StringComparison.OrdinalIgnoreCase);

    public static bool IsDigest(string? value) => value is { Length: 64 } && value.All(Uri.IsHexDigit);
}
