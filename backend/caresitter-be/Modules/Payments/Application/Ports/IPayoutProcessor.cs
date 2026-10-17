namespace CareSitter.Modules.Payments.Application.Payouts;

internal interface IPayoutProcessor
{
    Task<int> ProcessPendingAsync(CancellationToken ct = default);
}
