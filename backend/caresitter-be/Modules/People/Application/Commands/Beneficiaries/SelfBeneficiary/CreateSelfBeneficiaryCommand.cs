using System.Text.Json;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.SelfBeneficiary;

public sealed record CreateSelfBeneficiaryCommand(string FullName, DateOnly? DateOfBirth,
    string? Gender, string? Phone, string? AvatarUrl, Guid? DefaultAddressId,
    string? CareLevel, string? GeneralNote, string? CareInstructions, JsonElement? EmergencyContacts)
    : IRequest<Result<SelfBeneficiaryCreationResponse>>;
