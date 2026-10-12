using CareSitter.Contracts.Nutrition;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Queries.HealthProfile;

public sealed record GetHealthProfileQuery(Guid BeneficiaryId) : IRequest<Result<BeneficiaryHealthSnapshot>>;
