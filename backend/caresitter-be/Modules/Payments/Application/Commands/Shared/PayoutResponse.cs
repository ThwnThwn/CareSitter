namespace CareSitter.Modules.Payments.Application.Payouts;

public sealed record PayoutResponse(
    Guid Id,
    Guid CaregiverId,
    Guid WalletAccountId,
    long Amount,
    string BankName,
    string BankBin,
    string AccountHolderName,
    string Status,
    string AccountNumber,
    DateTimeOffset RequestedAt,
    DateTimeOffset? ReviewedAt,
    string? RejectReason,
    string Provider,
    string ProviderReferenceId,
    string? ProviderPayoutId,
    string? ProviderState,
    string? ProviderTransactionId,
    string? ProviderErrorCode,
    int ProviderAttemptCount,
    DateTimeOffset? CompletedAt);
