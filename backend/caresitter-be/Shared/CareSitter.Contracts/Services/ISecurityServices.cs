namespace CareSitter.Contracts.Services;

/// <summary>
/// Validates that an authenticated user and the durable session bound to an
/// access token are still active. Implemented by the Identity module so the
/// shared JWT infrastructure does not depend on a feature module.
/// </summary>
public interface IAccessSessionValidator
{
    Task<bool> IsActiveAsync(Guid userId, Guid sessionId, CancellationToken ct = default);
}
