using System.Security.Claims;

namespace CareSitter.Contracts.Services;

/// <summary>Identity and roles of the authenticated request actor.</summary>
public interface ICurrentUser
{
    Guid? UserId { get; }
    IReadOnlyCollection<string> Roles { get; }
    bool IsInRole(string role);
}

/// <summary>Clock abstraction for deterministic application behavior.</summary>
public interface IClock
{
    DateTimeOffset UtcNow { get; }
}

/// <summary>Protects sensitive values without exposing a concrete cipher to application code.</summary>
public interface IEncryptionService
{
    string Encrypt(string plaintext);
    string Decrypt(string ciphertext);
    string Hmac(string value);
}

/// <summary>Creates and validates application authentication tokens.</summary>
public interface IJwtTokenService
{
    string GenerateAccessToken(
        Guid userId,
        IEnumerable<string> roles,
        string? displayName = null,
        Guid? sessionId = null);

    string GenerateRefreshToken();
    ClaimsPrincipal? GetPrincipalFromExpiredToken(string token);
    string HashRefreshToken(string rawToken);
}

/// <summary>Sends application email without coupling use cases to an SMTP adapter.</summary>
public interface IEmailSender
{
    Task SendAsync(string to, string subject, string htmlBody, CancellationToken ct = default);
}

/// <summary>Read-only public identity data exposed to other modules.</summary>
public interface IUserProfileReader
{
    Task<string?> GetAvatarUrlAsync(Guid userId, CancellationToken ct = default);
}

/// <summary>Creates the People-side profile required for a newly registered caregiver.</summary>
public interface ICaregiverRegistrationService
{
    Task EnsureProfileAsync(Guid userId, string? fullName, CancellationToken ct = default);
}
