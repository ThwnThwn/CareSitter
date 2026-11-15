using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

public sealed record LedgerEntryResponse(
    Guid Id, Guid? BookingId, Guid? PaymentIntentId, string TransactionType,
    string DebitAccount, string CreditAccount, long Amount, string Currency,
    string Status, DateTimeOffset CreatedAt);
