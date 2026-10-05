using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public sealed record ListAdminDisputesQuery(
    string? Status, int Page, int PageSize) : IRequest<Result<SupportPage<DisputeResponse>>>;
