using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public interface IIdentityDeviceStore
{
    Task<UserDevice?> FindByPushTokenAsync(string pushToken, CancellationToken ct = default);
    Task<UserDevice?> FindByUserAndPlatformAsync(Guid userId, string platform,
        CancellationToken ct = default);
    Task<UserDevice?> FindOwnedAsync(Guid deviceId, Guid userId, CancellationToken ct = default);
    Task<IReadOnlyList<DeviceResponse>> ListByUserAsync(Guid userId, CancellationToken ct = default);
    void Add(UserDevice device);
    void Remove(UserDevice device);
    Task SaveChangesAsync(CancellationToken ct = default);
}
