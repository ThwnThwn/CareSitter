using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public sealed record IdentityPage<T>(IReadOnlyList<T> Items, int Total, int Page, int PageSize);

public sealed record AdminUserResponse(
    Guid Id,
    string Email,
    string? Phone,
    string? DisplayName,
    string? FullName,
    string? AvatarUrl,
    string Status,
    string[] Roles,
    string? AdminDepartment,
    string? AdminRole,
    bool? AdminIsActive,
    DateTimeOffset? LastLoginAt,
    DateTimeOffset CreatedAt,
    DateTimeOffset? UpdatedAt);

public sealed record DeviceResponse(
    Guid Id,
    string Platform,
    string? DeviceName,
    bool HasPushToken,
    bool BiometricEnabled,
    DateTimeOffset? LastSeenAt,
    DateTimeOffset CreatedAt);

public sealed record AvatarResponse(string AvatarUrl);

public sealed class NotificationPrefs
{
    public bool BookingUpdates { get; set; } = true;
    public bool PaymentUpdates { get; set; } = true;
    public bool CaregiverArriving { get; set; } = true;
    public bool ScheduleReminder { get; set; } = true;
    public bool ChatMessage { get; set; } = true;
    public bool Promotion { get; set; }

    public static NotificationPrefs Parse(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return new NotificationPrefs();
        try
        {
            return System.Text.Json.JsonSerializer.Deserialize<NotificationPrefs>(json,
                new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true })
                ?? new NotificationPrefs();
        }
        catch
        {
            return new NotificationPrefs();
        }
    }

    public string ToJson() => System.Text.Json.JsonSerializer.Serialize(this,
        new System.Text.Json.JsonSerializerOptions
        {
            PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase
        });
}

public interface IIdentityStore
{
    Task<User?> FindUserByIdAsync(Guid userId, CancellationToken ct = default);
    Task<User?> FindUserByEmailAsync(string email, CancellationToken ct = default);
    Task<User?> FindUserByIdentifierAsync(string email, string rawIdentifier,
        CancellationToken ct = default);
    Task<User?> FindUserByGoogleIdOrEmailAsync(string googleId, string email,
        CancellationToken ct = default);
    Task<bool> EmailExistsAsync(string email, Guid? exceptUserId = null,
        CancellationToken ct = default);
    Task<bool> PhoneExistsAsync(string phone, CancellationToken ct = default);
    Task<int> CountActiveAdminsAsync(CancellationToken ct = default);
    Task<IdentityPage<AdminUserResponse>> ListUsersAsync(
        string? query, string? role, string? status, int page, int pageSize,
        CancellationToken ct = default);
    Task<AdminUserResponse?> GetUserResponseAsync(Guid userId, CancellationToken ct = default);
    void AddUser(User user);
    Task SaveChangesAsync(CancellationToken ct = default);
}

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

public sealed record IssuedTokenPair(string AccessToken, string RefreshToken);

public interface IRefreshTokenSessionService
{
    Task<IssuedTokenPair> IssueAsync(User user, CancellationToken ct,
        string? deviceId = null, string? deviceInfo = null, string? ipAddress = null);
    Task<Result<IssuedTokenPair>> RotateAsync(string rawRefreshToken, CancellationToken ct);
    Task RevokeAsync(string rawRefreshToken, CancellationToken ct);
    Task RevokeSessionAsync(Guid userId, Guid sessionId, CancellationToken ct);
    Task RevokeAllForUserAsync(Guid userId, CancellationToken ct);
}

public interface IPasswordHasher
{
    string Hash(string password);
    bool Verify(string password, string? passwordHash);
}

public sealed record GoogleIdentity(string Subject, string Email, string Name);

public interface IGoogleIdentityVerifier
{
    Task<Result<GoogleIdentity>> VerifyAsync(string idToken, CancellationToken ct = default);
}

public interface IAuthenticationAttemptLimiter
{
    Task<bool> IsBlockedAsync(string scope, string subject, CancellationToken ct);
    Task<bool> RecordFailureAsync(string scope, string subject, int maxAttempts,
        TimeSpan window, TimeSpan blockDuration, CancellationToken ct);
    Task<bool> TryConsumeAsync(string scope, string subject, int limit,
        TimeSpan window, CancellationToken ct);
    Task ResetAsync(string scope, string subject, CancellationToken ct);
}

public interface IOtpStore
{
    Task<string?> GetAsync(string email, CancellationToken ct = default);
    Task<bool> IsCoolingDownAsync(string email, CancellationToken ct = default);
    Task SaveAsync(string email, string code, TimeSpan ttl, TimeSpan cooldown,
        CancellationToken ct = default);
    Task RemoveAsync(string email, CancellationToken ct = default);
}

public interface IAccessTokenRevocationStore
{
    Task RevokeAsync(string tokenId, TimeSpan ttl, CancellationToken ct = default);
}
