namespace CareSitter.Modules.Payments.Application.Payouts;

internal enum PayoutProviderOutcome
{
    Processing,
    Succeeded,
    Failed,
    Unknown
}

internal sealed record PayoutProviderRequest(
    string ReferenceId,
    string IdempotencyKey,
    long Amount,
    string Description,
    string BankBin,
    string AccountNumber);

internal sealed record PayoutProviderResult(
    PayoutProviderOutcome Outcome,
    string ProviderState,
    string? ProviderPayoutId = null,
    string? ProviderTransactionId = null,
    string? ErrorCode = null);
