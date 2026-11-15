using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

public sealed record ListFamilyContactsQuery : IRequest<Result<IReadOnlyList<FamilyContactResponse>>>;
