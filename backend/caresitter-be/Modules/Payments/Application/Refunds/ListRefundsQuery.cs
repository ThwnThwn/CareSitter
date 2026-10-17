using MediatR;

namespace CareSitter.Modules.Payments.Application.Refunds;

public sealed record ListRefundsQuery(string? Status, int Page, int PageSize)
    : IRequest<RefundPage>;

internal sealed class ListRefundsQueryHandler(IRefundStore store)
    : IRequestHandler<ListRefundsQuery, RefundPage>
{
    public Task<RefundPage> Handle(ListRefundsQuery request, CancellationToken ct) =>
        store.ListForAdminAsync(request.Status, request.Page, request.PageSize, ct);
}
