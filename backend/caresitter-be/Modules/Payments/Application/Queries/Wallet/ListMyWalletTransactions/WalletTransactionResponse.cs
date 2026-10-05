using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

public sealed record WalletTransactionResponse(
    Guid Id, Guid? BookingId, string TransactionType, long Amount,
    string Currency, string Status, string Direction, DateTimeOffset CreatedAt);
