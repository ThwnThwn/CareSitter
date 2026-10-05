using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

public sealed record GetBeneficiaryQuery(Guid BeneficiaryId) : IRequest<Result<BeneficiaryResponse>>;
