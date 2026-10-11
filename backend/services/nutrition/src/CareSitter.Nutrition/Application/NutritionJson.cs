using System.Text.Json;
using System.Text.Json.Serialization;

namespace CareSitter.Nutrition.Application;

public static class NutritionJson
{
    public static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web) { UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow };
    public static string Write<T>(T value) => JsonSerializer.Serialize(value, Options);
    public static T Read<T>(string text) => JsonSerializer.Deserialize<T>(text, Options)
        ?? throw new JsonException("Invalid nutrition payload.");
}
