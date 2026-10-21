using System.Text.Json;
using System.Text.Json.Nodes;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.People.Application.Commands.HealthProfile;

internal static class HealthProfilePatch
{
    private static readonly HashSet<string> Fields = ["generalNote", "careInstructions", "healthHistory",
        "allergies", "chronicConditions", "medications", "foodAllergyStatus", "nutritionProfile"];
    private static readonly HashSet<string> NutritionFields = ["conditionsStatus", "medicationsStatus",
        "feedingRoute", "swallowingStatus", "fluidRestriction", "electrolyteRestriction",
        "dietaryPattern", "nutritionGoal", "guidance", "symptoms"];

    public static Result Validate(JsonElement changes)
    {
        if (changes.ValueKind != JsonValueKind.Object || changes.GetRawText().Length > 16000 ||
            !UniqueProperties(changes) || changes.EnumerateObject().Any(p => !Fields.Contains(p.Name)) ||
            (changes.TryGetProperty("nutritionProfile", out _) && changes.TryGetProperty("healthHistory", out _)))
            return Invalid();
        foreach (var p in changes.EnumerateObject())
        {
            var valid = p.Name switch
            {
                "generalNote" or "careInstructions" => OptionalText(p.Value, 4000),
                "foodAllergyStatus" => p.Value.ValueKind == JsonValueKind.String &&
                    p.Value.GetString() is "unknown" or "reported_none" or "reported_present",
                "allergies" => List(p.Value, item => RequiredText(item, 100)),
                "chronicConditions" => List(p.Value, ValidCondition),
                "medications" => List(p.Value, ValidMedication),
                "nutritionProfile" => ValidNutrition(p.Value, patch: true),
                "healthHistory" => p.Value.ValueKind == JsonValueKind.Null ||
                    (p.Value.ValueKind == JsonValueKind.Object && UniqueProperties(p.Value) &&
                     (!p.Value.TryGetProperty("nutrition", out var n) || ValidNutrition(n, patch: false))),
                _ => false
            };
            if (!valid) return Invalid();
        }
        return Result.Success();
    }

    public static Result<string?> MergeNutrition(string? history, JsonElement patch)
    {
        var root = history is null ? new JsonObject() : JsonNode.Parse(history);
        if (root is not JsonObject map || (map["nutrition"] is not null && map["nutrition"] is not JsonObject))
            return Error.Conflict("nutrition.legacy_health", "Hồ sơ có dữ liệu sức khỏe cũ cần được kiểm tra trước khi cập nhật các mục ăn uống.");
        var nutrition = map["nutrition"] as JsonObject ?? new JsonObject();
        if (nutrition["schemaVersion"] is { } version && version.ToJsonString() != "1")
            return Error.Conflict("nutrition.health_schema", "Phiên bản hồ sơ đã thay đổi. Vui lòng tải lại thông tin.");
        // Merge only supplied fields; unrelated history and restrictions retain their values.
        foreach (var p in patch.EnumerateObject()) nutrition[p.Name] = JsonNode.Parse(p.Value.GetRawText());
        nutrition["schemaVersion"] = 1;
        map["nutrition"] = nutrition;
        return map.ToJsonString();
    }

    public static bool ReportsNone(string? history, string field)
    {
        if (history is null) return false;
        using var doc = JsonDocument.Parse(history);
        return doc.RootElement.ValueKind == JsonValueKind.Object &&
            doc.RootElement.TryGetProperty("nutrition", out var n) && n.ValueKind == JsonValueKind.Object &&
            n.TryGetProperty(field, out var value) && value.ValueKind == JsonValueKind.String && value.GetString() == "reported_none";
    }

    public static bool HasCurrentItems(string? json, bool medications = false)
    {
        if (json is null) return false;
        using var doc = JsonDocument.Parse(json);
        if (doc.RootElement.ValueKind == JsonValueKind.Null) return false;
        if (doc.RootElement.ValueKind != JsonValueKind.Array) return true;
        return doc.RootElement.EnumerateArray().Any(item => item.ValueKind != JsonValueKind.Object ||
            (medications ? !(item.TryGetProperty("is_active", out var active) && active.ValueKind == JsonValueKind.False) :
                !(item.TryGetProperty("assertion", out var a) && a.ValueKind == JsonValueKind.String && a.GetString() == "absent") &&
                !(item.TryGetProperty("temporality", out var t) && t.ValueKind == JsonValueKind.String && t.GetString() == "past")));
    }

    private static bool ValidNutrition(JsonElement value, bool patch)
    {
        if (value.ValueKind != JsonValueKind.Object || !UniqueProperties(value)) return false;
        if (!patch && (!value.TryGetProperty("schemaVersion", out var version) || version.GetRawText() != "1")) return false;
        return value.EnumerateObject().All(p =>
        {
            if (!patch && p.Name == "schemaVersion") return true;
            if (!NutritionFields.Contains(p.Name) || p.Value.ValueKind != JsonValueKind.String) return false;
            var text = p.Value.GetString();
            return p.Name switch
            {
                "conditionsStatus" or "medicationsStatus" => text is "unknown" or "reported_none" or "reported_present",
                "feedingRoute" => text is "unknown" or "oral" or "tube",
                "swallowingStatus" => text is "unknown" or "normal" or "difficulty",
                "fluidRestriction" or "electrolyteRestriction" => text is "unknown" or "none" or "present",
                "dietaryPattern" => text is "regular" or "vegetarian",
                "nutritionGoal" => text is "maintain" or "gain" or "lose",
                _ => text!.Length <= 4000
            };
        });
    }

    private static bool ValidCondition(JsonElement item)
    {
        if (item.ValueKind == JsonValueKind.String) return RequiredText(item, 200);
        if (item.ValueKind != JsonValueKind.Object || !UniqueProperties(item)) return false;
        if (!(item.TryGetProperty("label", out var label) && RequiredText(label, 200)) &&
            !(item.TryGetProperty("code", out var code) && RequiredText(code, 100))) return false;
        return item.EnumerateObject().All(p => p.Name switch
        {
            "label" => RequiredText(p.Value, 200),
            "code" => RequiredText(p.Value, 100),
            "assertion" => p.Value.ValueKind == JsonValueKind.String && p.Value.GetString() is "present" or "absent" or "uncertain",
            "temporality" => p.Value.ValueKind == JsonValueKind.String && p.Value.GetString() is "current" or "past" or "unknown",
            _ => false
        });
    }

    private static bool ValidMedication(JsonElement item)
    {
        if (item.ValueKind != JsonValueKind.Object || !UniqueProperties(item) ||
            !item.TryGetProperty("name", out var name) || !RequiredText(name, 200)) return false;
        if (!item.EnumerateObject().All(p => p.Name switch
        {
            "name" => RequiredText(p.Value, 200),
            "dosage" or "schedule" or "instruction" => OptionalText(p.Value, 1000),
            "is_active" => p.Value.ValueKind is JsonValueKind.True or JsonValueKind.False,
            "start_date" or "end_date" => p.Value.ValueKind == JsonValueKind.Null ||
                (p.Value.ValueKind == JsonValueKind.String && DateOnly.TryParseExact(p.Value.GetString(), "yyyy-MM-dd", out _)),
            _ => false
        })) return false;
        return !(item.TryGetProperty("start_date", out var start) && start.ValueKind == JsonValueKind.String &&
            item.TryGetProperty("end_date", out var end) && end.ValueKind == JsonValueKind.String) ||
            string.CompareOrdinal(start.GetString(), end.GetString()) <= 0;
    }

    private static bool List(JsonElement value, Func<JsonElement, bool> valid) => value.ValueKind == JsonValueKind.Null ||
        (value.ValueKind == JsonValueKind.Array && value.GetArrayLength() <= 40 && value.EnumerateArray().All(valid));
    private static bool RequiredText(JsonElement value, int limit) => value.ValueKind == JsonValueKind.String &&
        !string.IsNullOrWhiteSpace(value.GetString()) && value.GetString()!.Length <= limit;
    private static bool OptionalText(JsonElement value, int limit) => value.ValueKind == JsonValueKind.Null ||
        (value.ValueKind == JsonValueKind.String && value.GetString()!.Length <= limit);
    private static bool UniqueProperties(JsonElement value) => value.EnumerateObject().Select(p => p.Name).Distinct().Count() == value.EnumerateObject().Count();
    private static Error Invalid() => Error.Validation("nutrition.health_payload", "Thông tin sức khỏe không đúng định dạng hoặc vượt giới hạn. Vui lòng kiểm tra mục vừa cập nhật.");
}
