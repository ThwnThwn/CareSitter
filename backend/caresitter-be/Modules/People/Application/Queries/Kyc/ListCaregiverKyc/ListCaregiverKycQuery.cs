using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

public sealed record ListCaregiverKycQuery(
    string? Status, int Page, int PageSize) : IRequest<Result<PeoplePage<CaregiverKycResponse>>>;
