using CareSitter.Modules.Identity.Application;
using CareSitter.SharedKernel.Results;
using Google.Apis.Auth;
using Microsoft.Extensions.Configuration;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class BcryptPasswordHasher : IPasswordHasher
{
    private static readonly string DummyPasswordHash =
        BCrypt.Net.BCrypt.HashPassword("CareSitter timing equalizer", workFactor: 12);

    public string Hash(string password) => BCrypt.Net.BCrypt.HashPassword(password, workFactor: 12);
    public bool Verify(string password, string? passwordHash) =>
        BCrypt.Net.BCrypt.Verify(password, passwordHash ?? DummyPasswordHash);
}

internal sealed class GoogleIdentityVerifier(IConfiguration configuration) : IGoogleIdentityVerifier
{
    public async Task<Result<GoogleIdentity>> VerifyAsync(
        string idToken, CancellationToken ct = default)
    {
        var clientId = configuration["Google:ClientId"]
            ?? throw new InvalidOperationException(
                "Google:ClientId chưa được cấu hình trong appsettings / .env.");

        try
        {
            var payload = await GoogleJsonWebSignature.ValidateAsync(idToken,
                new GoogleJsonWebSignature.ValidationSettings { Audience = [clientId] });
            var email = payload.Email?.Trim().ToLowerInvariant() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(email))
                return Error.Validation("auth.google_email_missing",
                    "Tài khoản Google không cung cấp địa chỉ email.");

            return new GoogleIdentity(payload.Subject, email, payload.Name ?? email);
        }
        catch (InvalidJwtException)
        {
            return Error.Validation("auth.invalid_google_token",
                "Google ID Token không hợp lệ hoặc đã hết hạn.");
        }
    }
}
