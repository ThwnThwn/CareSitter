using System.Text.Json;
using CareSitter.Modules.People.Domain;

namespace CareSitter.Modules.People.Application;

internal static class PeopleResponseMapper
{
    public static BeneficiaryResponse ToResponse(Beneficiary value) => new(value.Id,
        value.FullName, value.DateOfBirth, value.Gender, value.RelationshipToCustomer,
        value.Phone, value.DefaultAddressId, value.MobilityNote, value.GeneralNote,
        Json(value.HealthHistory), Json(value.Allergies), Json(value.ChronicConditions),
        value.CareInstructions, value.CareLevel, value.AvatarUrl,
        Json(value.EmergencyContacts), Json(value.Medications));

    public static FamilyContactResponse ToResponse(FamilyContact value) =>
        new(value.Id, value.FullName, value.PhoneNumber, value.Note);

    public static CaregiverProfileResponse ToProfileResponse(
        CaregiverProfile profile, string? avatarUrl = null) => new(profile.Id,
        profile.UserId, profile.FullName, profile.Gender,
        profile.DateOfBirth?.ToString("yyyy-MM-dd"), profile.Bio,
        profile.YearsOfExperience, profile.RatingAvg, profile.RatingCount,
        profile.KycStatus, profile.CccdFrontUrl, profile.CccdBackUrl,
        DeserializeUrls(profile.CertificateUrls), profile.AvailabilityStatus,
        profile.Skills, profile.ServiceCity, profile.ServiceDistrict, avatarUrl);

    private static JsonElement? Json(string? value) => string.IsNullOrWhiteSpace(value)
        ? null : JsonDocument.Parse(value).RootElement.Clone();

    private static string[] DeserializeUrls(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return Array.Empty<string>();
        try { return JsonSerializer.Deserialize<string[]>(json) ?? Array.Empty<string>(); }
        catch (JsonException) { return Array.Empty<string>(); }
    }
}
