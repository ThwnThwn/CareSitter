using System.Text.Json;

namespace CareSitter.Modules.People.Controllers;

public sealed record SelfBeneficiaryRequest(string FullName, DateOnly? DateOfBirth,
    string? Gender, string? Phone, string? AvatarUrl, Guid? DefaultAddressId,
    string? CareLevel, string? GeneralNote, string? CareInstructions, JsonElement? EmergencyContacts);
