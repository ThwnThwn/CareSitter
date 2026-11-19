namespace CareSitter.Modules.Catalog.Application;

internal sealed record ServiceSetupReceipt(Guid ServiceId, string PayloadHash);
internal interface IServiceSetupReceipts
{
    Task<ServiceSetupReceipt?> FindAsync(Guid admin, Guid requestId, CancellationToken ct);
    Task SaveAsync(Guid admin, Guid requestId, Guid serviceId, string hash, CancellationToken ct);
}
