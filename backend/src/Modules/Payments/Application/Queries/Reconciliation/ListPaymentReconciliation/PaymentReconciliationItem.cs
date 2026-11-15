using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

public sealed record PaymentReconciliationItem(
    Guid IntentId,
    Guid BookingId,
    Guid CustomerId,
    long Amount,
    string Currency,
    string? ProviderOrderRef,
    string? ProviderTransactionId,
    int ReconciliationAttempts,
    DateTimeOffset? ReconciliationStartedAt,
    DateTimeOffset? LastReconciliationAt,
    string? LastReconciliationError,
    string? ManualReviewReason,
    string BookingStatus,
    DateTimeOffset? PaymentDeadline,
    string Provider = "VNPAY",
    string IntentStatus = "PENDING",
    bool CanResolve = true);
