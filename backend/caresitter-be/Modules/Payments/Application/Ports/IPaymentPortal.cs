using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

public interface IPaymentPortal
{
    Task<Result<PaymentIntentCreationOutcome>> CreateIntentAsync(
        Guid bookingId, Guid userId, string? customerName, CancellationToken ct = default, string provider = "VNPAY");
    Task<PaymentIntentResponse?> GetIntentAsync(
        Guid intentId, Guid userId, CancellationToken ct = default);
    Task<WalletResponse> GetWalletAsync(
        Guid userId, string accountType, CancellationToken ct = default);
    Task<PaymentPage<WalletTransactionResponse>> ListWalletTransactionsAsync(
        Guid userId, string accountType, int page, int pageSize, CancellationToken ct = default);
    Task<PaymentPage<LedgerEntryResponse>> ListLedgerAsync(
        Guid? bookingId, int page, int pageSize, CancellationToken ct = default);
}
