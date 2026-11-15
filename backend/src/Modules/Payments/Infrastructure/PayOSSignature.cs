using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;

namespace CareSitter.Modules.Payments.Infrastructure;

/// <summary>Chữ ký payment-requests của payOS; không dùng quy tắc chữ ký payouts.</summary>
internal static class PayOSSignature
{
    internal static string Sign(string value, string key) =>
        Convert.ToHexString(HMACSHA256.HashData(Encoding.UTF8.GetBytes(key), Encoding.UTF8.GetBytes(value)))
            .ToLowerInvariant();

    internal static string Canonicalize(JsonElement data)
    {
        if (data.ValueKind != JsonValueKind.Object) throw new JsonException("Expected object.");
        RejectDuplicateKeys(data);
        return string.Join('&', data.EnumerateObject().OrderBy(x => x.Name, StringComparer.Ordinal)
            .Select(x => $"{x.Name}={Value(x.Value)}"));
    }

    internal static bool Verify(JsonElement data, string? signature, string key)
    {
        if (string.IsNullOrWhiteSpace(key) || signature?.Length != 64) return false;
        try
        {
            var actual = Convert.FromHexString(signature);
            var expected = Convert.FromHexString(Sign(Canonicalize(data), key));
            return CryptographicOperations.FixedTimeEquals(expected, actual);
        }
        catch (Exception e) when (e is FormatException or JsonException or InvalidOperationException)
        { return false; }
    }

    private static string Value(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Null or JsonValueKind.Undefined => "",
        JsonValueKind.String => value.GetString() is null or "null" or "undefined" ? "" : value.GetString()!,
        JsonValueKind.True => "true",
        JsonValueKind.False => "false",
        JsonValueKind.Number => value.GetRawText(),
        _ => SortedJson(value)
    };

    private static string SortedJson(JsonElement value)
    {
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream, new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping }))
            WriteSorted(writer, value);
        return Encoding.UTF8.GetString(stream.ToArray());
    }

    private static void WriteSorted(Utf8JsonWriter writer, JsonElement value)
    {
        if (value.ValueKind == JsonValueKind.Object)
        {
            writer.WriteStartObject();
            foreach (var field in value.EnumerateObject().OrderBy(x => x.Name, StringComparer.Ordinal))
            { writer.WritePropertyName(field.Name); WriteSorted(writer, field.Value); }
            writer.WriteEndObject();
        }
        else if (value.ValueKind == JsonValueKind.Array)
        {
            writer.WriteStartArray();
            foreach (var item in value.EnumerateArray()) WriteSorted(writer, item);
            writer.WriteEndArray();
        }
        else value.WriteTo(writer);
    }

    internal static void RejectDuplicateKeys(JsonElement data)
    {
        if (data.ValueKind == JsonValueKind.Object)
        {
            var keys = new HashSet<string>(StringComparer.Ordinal);
            foreach (var field in data.EnumerateObject())
            {
                if (!keys.Add(field.Name)) throw new JsonException("Duplicate JSON key.");
                RejectDuplicateKeys(field.Value);
            }
        }
        else if (data.ValueKind == JsonValueKind.Array)
            foreach (var item in data.EnumerateArray()) RejectDuplicateKeys(item);
    }
}
