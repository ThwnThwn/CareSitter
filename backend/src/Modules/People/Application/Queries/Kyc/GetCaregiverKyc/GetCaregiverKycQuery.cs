using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

public sealed record GetCaregiverKycQuery(Guid CaregiverId) : IRequest<Result<CaregiverKycResponse>>;
