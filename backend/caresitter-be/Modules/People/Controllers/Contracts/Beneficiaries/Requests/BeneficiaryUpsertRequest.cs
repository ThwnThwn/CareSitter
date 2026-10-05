using System.Text.Json;
using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Application.Commands.CreateBeneficiary;
using CareSitter.Modules.People.Application.Commands.DeleteBeneficiary;
using CareSitter.Modules.People.Application.Commands.UpdateBeneficiary;

namespace CareSitter.Modules.People.Controllers;

public sealed record BeneficiaryUpsertRequest(string FullName, DateOnly? DateOfBirth,
    string? Gender, string? RelationshipToCustomer, string? Phone, Guid? DefaultAddressId,
    string? MobilityNote, string? GeneralNote, JsonElement? HealthHistory,
    JsonElement? Allergies, JsonElement? ChronicConditions, string? CareInstructions,
    string? CareLevel, string? AvatarUrl, JsonElement? EmergencyContacts,
    JsonElement? Medications);
