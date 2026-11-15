using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application.Payouts.ListPendingPayouts;

public sealed record ListPendingPayoutsQuery(
    string? Status = "PENDING",
    int Page = 1,
    int PageSize = 20) : IRequest<Result<PayoutPage>>;
