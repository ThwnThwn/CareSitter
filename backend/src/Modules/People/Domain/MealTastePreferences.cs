using System.Text.Json;
using System.Text.Json.Nodes;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.People.Domain;

public static class MealTastePreferences
{
    public static Result<string> Apply(string? history, string mealName, bool liked)
    {
        var root = history is null ? new JsonObject() : JsonNode.Parse(history);
        if (root is not JsonObject map || map["nutrition"] is not (null or JsonObject)) return Legacy();
        var nutrition = map["nutrition"] as JsonObject ?? new JsonObject();
        if (nutrition["schemaVersion"] is { } version && version.ToJsonString() != "1") return Legacy();
        if (nutrition["preferredFoods"] is { } preferred && preferred.GetValueKind() != JsonValueKind.String ||
            nutrition["dislikedFoods"] is { } disliked && disliked.GetValueKind() != JsonValueKind.String) return Legacy();
        List<string> Read(string key) => (nutrition[key]?.GetValue<string>() ?? "")
            .Split([';', ',', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        var yes = Read("preferredFoods");
        var no = Read("dislikedFoods");
        var label = string.Join(' ', mealName.Split([';', ',', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
        yes.RemoveAll(value => value.Equals(label, StringComparison.OrdinalIgnoreCase));
        no.RemoveAll(value => value.Equals(label, StringComparison.OrdinalIgnoreCase));
        (liked ? yes : no).Add(label);
        if (yes.Count > 20 || no.Count > 20 || string.Join("; ", yes).Length > 800 || string.Join("; ", no).Length > 800)
            return Error.Conflict("nutrition.preferences_full", "Danh sách sở thích đã đầy. Hãy chỉnh lại sở thích trước khi duyệt món mới.");
        nutrition["preferredFoods"] = string.Join("; ", yes);
        nutrition["dislikedFoods"] = string.Join("; ", no);
        nutrition["schemaVersion"] = 1;
        map["nutrition"] = nutrition;
        return map.ToJsonString();
    }

    private static Error Legacy() => Error.Conflict("nutrition.legacy_health", "Hồ sơ cần được kiểm tra trước khi cập nhật sở thích.");
}
