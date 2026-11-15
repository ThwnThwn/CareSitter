using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using CareSitter.Contracts.Nutrition;

namespace CareSitter.Modules.Booking.Application;

internal static class MealHealthFingerprint
{
    public static string For(BeneficiaryHealthSnapshot snapshot)
    {
        var history = snapshot.HealthHistory is { ValueKind: JsonValueKind.Object } element
            ? JsonNode.Parse(element.GetRawText())!.AsObject() : new JsonObject();
        // Only these two soft preferences may change without invalidating an ongoing shared menu.
        // Keep every other field, including notes, restrictions, allergy confirmation and medications.
        if (history["nutrition"] is JsonObject nutrition)
        {
            nutrition.Remove("preferredFoods");
            nutrition.Remove("dislikedFoods");
            if (nutrition.Count == 0 || nutrition.Count == 1 && nutrition.ContainsKey("schemaVersion"))
                history.Remove("nutrition");
        }
        var sanitized = snapshot.HealthHistory is { ValueKind: not (JsonValueKind.Object or JsonValueKind.Null) } legacy
            ? legacy : JsonSerializer.SerializeToElement(history);
        var value = JsonSerializer.SerializeToElement(snapshot with
        { Revision = 0, HealthHistory = sanitized });
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(Canonical(value))));
    }

    public static bool Current(Domain.BookingMealPlan plan, BeneficiaryHealthSnapshot? snapshot) =>
        snapshot is not null && (plan.HealthFingerprint is { } fingerprint
            ? fingerprint == For(snapshot) : plan.HealthRevision > 0 && plan.HealthRevision == snapshot.Revision);

    private static string Canonical(JsonElement element) => element.ValueKind switch
    {
        JsonValueKind.Object => "{" + string.Join(',', element.EnumerateObject().OrderBy(p => p.Name, StringComparer.Ordinal)
            .Select(p => JsonSerializer.Serialize(p.Name) + ":" + Canonical(p.Value))) + "}",
        JsonValueKind.Array => "[" + string.Join(',', element.EnumerateArray().Select(Canonical)) + "]",
        _ => element.GetRawText()
    };
}
