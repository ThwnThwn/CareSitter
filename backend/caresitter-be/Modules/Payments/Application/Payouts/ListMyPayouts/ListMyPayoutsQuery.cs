using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application.Payouts.ListMyPayouts;

public sealed record ListMyPayoutsQuery(int Page = 1, int PageSize = 20)
    : IRequest<Result<PayoutPage>>;
