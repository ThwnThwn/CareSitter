using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

internal sealed class ListMyWalletTransactionsQueryHandler(
    IPaymentPortal portal, ICurrentUser currentUser)
    : IRequestHandler<ListMyWalletTransactionsQuery, Result<PaymentPage<WalletTransactionResponse>>>
{
    public async Task<Result<PaymentPage<WalletTransactionResponse>>> Handle(
        ListMyWalletTransactionsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PaymentPortalErrors.Unauthenticated();
        var type = currentUser.IsInRole("CAREGIVER") ? "caregiver" : "customer";
        return await portal.ListWalletTransactionsAsync(userId, type,
            Math.Max(request.Page, 1), Math.Clamp(request.PageSize, 1, 50), ct);
    }
}
