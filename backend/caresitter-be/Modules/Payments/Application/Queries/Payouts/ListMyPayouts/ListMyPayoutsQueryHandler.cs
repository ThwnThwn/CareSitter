using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application.Payouts.ListMyPayouts;

internal sealed class ListMyPayoutsQueryHandler(
    IPayoutStore store,
    ICurrentUser currentUser,
    PayoutMapper mapper)
    : IRequestHandler<ListMyPayoutsQuery, Result<PayoutPage>>
{
    public async Task<Result<PayoutPage>> Handle(
        ListMyPayoutsQuery request,
        CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return PayoutErrors.Unauthenticated();

        var page = request.Page;
        var pageSize = request.PageSize;
        return await store.ListForCaregiverAsync(userId, page, pageSize, mapper, ct);
    }
}
