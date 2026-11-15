namespace CareSitter.Modules.Payments.Application.Refunds;

internal interface IRefundProcessor
{
    Task<int> ProcessPendingAsync(CancellationToken ct = default);
}
