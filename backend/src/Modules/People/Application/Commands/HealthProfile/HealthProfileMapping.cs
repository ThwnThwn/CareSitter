using System.Text.Json;
using CareSitter.Contracts.Nutrition;
using CareSitter.Modules.People.Domain;

namespace CareSitter.Modules.People.Application.Commands.HealthProfile;

internal static class HealthProfileMapping
{
    public static BeneficiaryHealthSnapshot Snapshot(Beneficiary b) => new(b.Id, b.HealthProfileRevision,
        b.DateOfBirth, b.FoodAllergyStatus, b.FoodAllergyConfirmedAt, b.GeneralNote, b.CareInstructions,
        b.MobilityNote, b.CareLevel, Json(b.HealthHistory), Json(b.Allergies), Json(b.ChronicConditions), Json(b.Medications));
    private static JsonElement? Json(string? text)
    {
        if (text is null) return null;
        using var document = JsonDocument.Parse(text);
        return document.RootElement.Clone();
    }
}
