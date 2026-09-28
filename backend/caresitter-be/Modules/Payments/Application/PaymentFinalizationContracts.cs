namespace CareSitter.Modules.Payments.Application;

public enum PaymentFinalizationSource
{
    Ipn,
    ReturnFallback,
    RetryPreflight,
    ReconciliationJob,
    AdminManual
}

public sealed record PaymentFinalizationResult(bool Succeeded, string Code, string Message);

public interface IPaymentFinalizationService
{
    Task<PaymentFinalizationResult> FinalizeSuccessfulPaymentAsync(
        Guid intentId, string? transactionId, string? payload,
        PaymentFinalizationSource source, CancellationToken ct = default);
}
