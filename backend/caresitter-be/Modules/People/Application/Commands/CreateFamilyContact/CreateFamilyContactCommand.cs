using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.CreateFamilyContact;

public sealed record CreateFamilyContactCommand(
    string FullName, string PhoneNumber, string? Note)
    : IRequest<Result<FamilyContactResponse>>;
