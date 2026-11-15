using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

public sealed record ListBeneficiariesQuery : IRequest<Result<IReadOnlyList<BeneficiaryResponse>>>;
