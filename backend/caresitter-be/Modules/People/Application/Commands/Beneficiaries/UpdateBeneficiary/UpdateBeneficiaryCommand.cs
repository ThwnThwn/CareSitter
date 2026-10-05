using System.Text.Json;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.UpdateBeneficiary;

public sealed record UpdateBeneficiaryCommand(Guid BeneficiaryId, string FullName,
    DateOnly? DateOfBirth, string? Gender, string? RelationshipToCustomer, string? Phone,
    Guid? DefaultAddressId, string? MobilityNote, string? GeneralNote,
    JsonElement? HealthHistory, JsonElement? Allergies, JsonElement? ChronicConditions,
    string? CareInstructions, string? CareLevel, string? AvatarUrl,
    JsonElement? EmergencyContacts, JsonElement? Medications)
    : IRequest<Result<BeneficiaryResponse>>;
