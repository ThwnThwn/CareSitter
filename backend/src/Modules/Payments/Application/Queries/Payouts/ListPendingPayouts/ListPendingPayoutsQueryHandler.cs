using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application.Payouts.ListPendingPayouts;

internal sealed class ListPendingPayoutsQueryHandler(
    IPayoutStore store,
    ICurrentUser currentUser,
    PayoutMapper mapper)
    : IRequestHandler<ListPendingPayoutsQuery, Result<PayoutPage>>
{
    public async Task<Result<PayoutPage>> Handle(
        ListPendingPayoutsQuery request,
        CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN"))
            return PayoutErrors.Forbidden();

        var page = request.Page;
        var pageSize = request.PageSize;
        return await store.ListForAdminAsync(request.Status, page, pageSize, mapper, ct);
    }
}
