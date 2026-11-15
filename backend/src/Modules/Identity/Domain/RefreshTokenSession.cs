using CareSitter.SharedKernel.Domain;

namespace CareSitter.Modules.Identity.Domain;

/// <summary>
/// Persistent refresh-token session. Only the SHA-256 token hash is stored;
/// the raw token exists only in the login/refresh response sent to the client.
/// </summary>
public sealed class RefreshTokenSession : Entity
{
    private RefreshTokenSession() { }

    private RefreshTokenSession(
        Guid id,
        Guid userId,
        string tokenHash,
        DateTimeOffset issuedAt,
        DateTimeOffset expiresAt,
        string? deviceId,
        string? deviceInfo,
        string? ipAddress) : base(id)
    {
        UserId = userId;
        TokenHash = tokenHash;
        IssuedAt = issuedAt;
        ExpiresAt = expiresAt;
        DeviceId = deviceId;
        DeviceInfo = deviceInfo;
        IpAddress = ipAddress;
        CreatedAt = issuedAt;
        UpdatedAt = issuedAt;
    }

    public Guid UserId { get; private set; }
    public string TokenHash { get; private set; } = null!;
    public string? DeviceId { get; private set; }
    public string? DeviceInfo { get; private set; }
    public DateTimeOffset IssuedAt { get; private set; }
    public DateTimeOffset ExpiresAt { get; private set; }
    public DateTimeOffset? RevokedAt { get; private set; }
    public Guid? ReplacedById { get; private set; }
    public string? IpAddress { get; private set; }

    public bool IsActiveAt(DateTimeOffset now) => RevokedAt is null && ExpiresAt > now;

    public static RefreshTokenSession Create(
        Guid userId,
        string tokenHash,
        DateTimeOffset issuedAt,
        DateTimeOffset expiresAt,
        string? deviceId = null,
        string? deviceInfo = null,
        string? ipAddress = null,
        Guid? id = null) => new(
            id ?? Guid.NewGuid(),
            userId,
            tokenHash,
            issuedAt,
            expiresAt,
            Normalize(deviceId, 255),
            Normalize(deviceInfo, 500),
            Normalize(ipAddress, 45));

    private static string? Normalize(string? value, int maxLength)
    {
        var normalized = value?.Trim();
        if (string.IsNullOrEmpty(normalized)) return null;
        return normalized.Length <= maxLength ? normalized : normalized[..maxLength];
    }
}
