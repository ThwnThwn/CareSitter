using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.DeleteFamilyContact;

public sealed record DeleteFamilyContactCommand(Guid ContactId) : IRequest<Result<Unit>>;
