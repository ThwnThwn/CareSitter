using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application.Refunds;

public sealed record ListMyRefundsQuery(int Page, int PageSize)
    : IRequest<Result<CustomerRefundPage>>;

internal sealed class ListMyRefundsQueryHandler(
    IRefundStore store,
    ICurrentUser currentUser)
    : IRequestHandler<ListMyRefundsQuery, Result<CustomerRefundPage>>
{
    public async Task<Result<CustomerRefundPage>> Handle(
        ListMyRefundsQuery request,
        CancellationToken ct)
    {
        if (currentUser.UserId is not { } customerId)
            return Error.Unauthorized("refund.unauthenticated", string.Empty);
        if (!currentUser.IsInRole("CUSTOMER"))
            return Error.Forbidden("refund.forbidden", string.Empty);

        return await store.ListForCustomerAsync(
            customerId, request.Page, request.PageSize, ct);
    }
}
