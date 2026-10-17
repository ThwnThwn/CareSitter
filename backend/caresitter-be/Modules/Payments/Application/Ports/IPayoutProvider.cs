namespace CareSitter.Modules.Payments.Application.Payouts;

internal interface IPayoutProvider
{
    Task<PayoutProviderResult> CreateAsync(
        PayoutProviderRequest request,
        CancellationToken ct = default);

    Task<PayoutProviderResult> QueryAsync(
        string providerPayoutId,
        PayoutProviderRequest expected,
        CancellationToken ct = default);
}
