using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public interface IRefreshTokenSessionService
{
    Task<IssuedTokenPair> IssueAsync(User user, CancellationToken ct,
        string? deviceId = null, string? deviceInfo = null, string? ipAddress = null);
    Task<Result<IssuedTokenPair>> RotateAsync(string rawRefreshToken, CancellationToken ct);
    Task RevokeAsync(string rawRefreshToken, CancellationToken ct);
    Task RevokeSessionAsync(Guid userId, Guid sessionId, CancellationToken ct);
    Task RevokeAllForUserAsync(Guid userId, CancellationToken ct);
}
