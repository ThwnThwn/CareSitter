namespace CareSitter.Modules.Payments.Application.Payouts;

public sealed record PayoutResponse(
    Guid Id,
    Guid CaregiverId,
    Guid WalletAccountId,
    long Amount,
    string BankName,
    string AccountHolderName,
    string Status,
    string AccountNumber,
    DateTimeOffset RequestedAt,
    DateTimeOffset? ReviewedAt,
    string? RejectReason);

public sealed record PayoutPage(
    IReadOnlyList<PayoutResponse> Items,
    int Total,
    int Page,
    int PageSize);

public sealed record CreatePayoutResult(PayoutResponse Payout, bool Created);
