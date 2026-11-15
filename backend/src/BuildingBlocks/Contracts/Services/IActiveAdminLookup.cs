namespace CareSitter.Contracts.Services;

public interface IActiveAdminLookup
{
    Task<bool> IsActiveAdminAsync(Guid userId, CancellationToken ct = default);
}

public interface IActiveUserLookup
{
    Task<bool> IsActiveWithAnyRoleAsync(
        Guid userId,
        IReadOnlyCollection<string> roles,
        CancellationToken ct = default);
}
