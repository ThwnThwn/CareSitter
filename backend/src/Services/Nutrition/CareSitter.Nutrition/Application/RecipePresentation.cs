using System.Text.Json;
using System.Text.Json.Nodes;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

internal static class RecipePresentation
{
    private const string DemoPrefix = "[DEMO]";

    public static JsonObject Map(Recipe recipe)
    {
        var data = JsonSerializer.SerializeToNode(recipe, NutritionJson.Options)!.AsObject();
        NormalizeName(data);
        return data;
    }

    public static void NormalizeName(JsonObject recipe)
    {
        if (recipe["name"] is not JsonValue value || !value.TryGetValue<string>(out var name) ||
            name is null || !name.StartsWith(DemoPrefix, StringComparison.OrdinalIgnoreCase)) return;

        recipe["name"] = name[DemoPrefix.Length..].TrimStart();
        recipe["isLocalDemo"] = true;
    }
}
