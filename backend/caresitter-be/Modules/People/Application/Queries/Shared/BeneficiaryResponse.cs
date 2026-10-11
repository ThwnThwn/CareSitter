using System.Text.Json;

namespace CareSitter.Modules.People.Application;

public sealed record BeneficiaryResponse(Guid Id, string FullName, DateOnly? DateOfBirth,
    string? Gender, string? RelationshipToCustomer, string? Phone, Guid? DefaultAddressId,
    string? MobilityNote, string? GeneralNote, JsonElement? HealthHistory,
    JsonElement? Allergies, JsonElement? ChronicConditions, string? CareInstructions,
    string? CareLevel, string? AvatarUrl, JsonElement? EmergencyContacts,
    JsonElement? Medications, bool IsSelf = false);
