namespace CareSitter.Modules.Payments.Application.Refunds;

internal enum RefundProviderOutcome
{
    Confirmed,
    Processing,
    Rejected,
    Unknown
}

internal sealed record RefundProviderResult(
    RefundProviderOutcome Outcome,
    string? ProviderResponseId = null,
    string? ProviderRefundId = null,
    string? ProviderTransactionStatus = null,
    string? ErrorCode = null);
