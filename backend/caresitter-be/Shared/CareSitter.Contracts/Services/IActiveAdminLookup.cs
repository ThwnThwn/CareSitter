namespace CareSitter.Contracts.Services;

public interface IActiveAdminLookup
{
    Task<bool> IsActiveAdminAsync(Guid userId, CancellationToken ct = default);
}
