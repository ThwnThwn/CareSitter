namespace CareSitter.Modules.Payments.Application;

public interface IPaymentFinalizationService
{
    Task<PaymentFinalizationResult> FinalizeSuccessfulPaymentAsync(
        Guid intentId, string? transactionId, string? payload,
        PaymentFinalizationSource source, CancellationToken ct = default);
}
