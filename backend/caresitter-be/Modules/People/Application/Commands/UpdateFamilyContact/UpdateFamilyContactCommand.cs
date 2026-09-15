using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.UpdateFamilyContact;

public sealed record UpdateFamilyContactCommand(
    Guid ContactId, string FullName, string PhoneNumber, string? Note)
    : IRequest<Result<FamilyContactResponse>>;
