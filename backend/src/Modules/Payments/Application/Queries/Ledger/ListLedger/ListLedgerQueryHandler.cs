using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

internal sealed class ListLedgerQueryHandler(IPaymentPortal portal, ICurrentUser currentUser)
    : IRequestHandler<ListLedgerQuery, Result<PaymentPage<LedgerEntryResponse>>>
{
    public async Task<Result<PaymentPage<LedgerEntryResponse>>> Handle(
        ListLedgerQuery request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return PaymentPortalErrors.Forbidden();
        if (currentUser.UserId is null) return PaymentPortalErrors.Unauthenticated();
        return await portal.ListLedgerAsync(request.BookingId, Math.Max(request.Page, 1),
            Math.Clamp(request.PageSize, 1, 50), ct);
    }
}
