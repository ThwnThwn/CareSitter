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
        Json(value.EmergencyContacts), Json(value.Medications), value.IsSelf);

    public static FamilyContactResponse ToResponse(FamilyContact value) =>
        new(value.Id, value.FullName, value.PhoneNumber, value.Note);

    public static CaregiverProfileResponse ToProfileResponse(
        CaregiverProfile profile, string? avatarUrl = null) => new(profile.Id,
        profile.UserId, profile.FullName, profile.Gender,
        profile.DateOfBirth?.ToString("yyyy-MM-dd"), profile.Bio,
        profile.YearsOfExperience, profile.RatingAvg, profile.RatingCount,
        profile.KycStatus, null, null, [], profile.AvailabilityStatus,
        profile.Skills, profile.ServiceCity, profile.ServiceDistrict, avatarUrl,
        profile.CccdFrontMediaId, profile.CccdBackMediaId, CertificateIds(profile), RequiresResubmission(profile));

    public static CaregiverResponse ToCaregiverResponse(
        CaregiverProfile profile, int? distanceMeters = null) => new(
        profile.Id, profile.UserId, profile.FullName, profile.Bio,
        profile.YearsOfExperience, profile.RatingAvg, profile.RatingCount,
        profile.AvailabilityStatus, Json(profile.Skills), profile.ServiceCity,
        profile.ServiceDistrict,
        profile.ServiceCenterLocation?.Y,
        profile.ServiceCenterLocation?.X,
        profile.ServiceRadiusMeters,
        distanceMeters);

    public static CaregiverKycResponse ToKycResponse(CaregiverProfile profile) => new(
        profile.Id, profile.UserId, profile.FullName, profile.DateOfBirth,
        profile.Gender, profile.KycStatus, null, null, [], profile.CreatedAt, profile.UpdatedAt,
        profile.CccdFrontMediaId, profile.CccdBackMediaId, CertificateIds(profile), RequiresResubmission(profile));

    public static Guid[] CertificateIds(CaregiverProfile profile)
    {
        try { return JsonSerializer.Deserialize<Guid[]>(profile.CertificateMediaIds) ?? []; }
        catch (JsonException) { return [Guid.Empty]; } // fail validation rather than silently approve corrupt data
    }

    private static bool RequiresResubmission(CaregiverProfile profile) =>
        !string.IsNullOrWhiteSpace(profile.CccdFrontUrl) || !string.IsNullOrWhiteSpace(profile.CccdBackUrl) ||
        DeserializeUrls(profile.CertificateUrls).Length > 0 ||
        (profile.KycStatus != "DRAFT" && (profile.CccdFrontMediaId is null || profile.CccdBackMediaId is null));

    private static JsonElement? Json(string? value) => string.IsNullOrWhiteSpace(value)
        ? null : JsonDocument.Parse(value).RootElement.Clone();

    private static string[] DeserializeUrls(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return Array.Empty<string>();
        try { return JsonSerializer.Deserialize<string[]>(json) ?? Array.Empty<string>(); }
        catch (JsonException) { return Array.Empty<string>(); }
    }
}
