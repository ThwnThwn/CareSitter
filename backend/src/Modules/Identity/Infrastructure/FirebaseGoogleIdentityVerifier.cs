using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class FirebaseGoogleIdentityVerifier(IConfiguration configuration,
    ILogger<FirebaseGoogleIdentityVerifier> logger) : IFirebaseGoogleIdentityVerifier, IDisposable
{
    private readonly object _gate = new();
    private FirebaseApp? _app;

    public async Task<Result<GoogleIdentity>> VerifyAsync(string idToken, CancellationToken ct = default)
    {
        var project = configuration["Firebase:ProjectId"];
        if (string.IsNullOrWhiteSpace(project))
            return Error.Unavailable("auth.firebase_unavailable", "Đăng nhập Firebase chưa được cấu hình.");
        try
        {
            FirebaseApp app;
            lock (_gate)
            {
                if (_app is null)
                {
                    var json = configuration["Firebase:ServiceAccountJson"];
                    var path = configuration["Firebase:ServiceAccountPath"]
                        ?? configuration["GOOGLE_APPLICATION_CREDENTIALS"];
                    var credential = !string.IsNullOrWhiteSpace(json) ? GoogleCredential.FromJson(json)
                        : !string.IsNullOrWhiteSpace(path) ? GoogleCredential.FromFile(path)
                        : GoogleCredential.GetApplicationDefault();
                    _app = FirebaseApp.Create(new AppOptions { Credential = credential, ProjectId = project },
                        "CareSitterGoogleLogin-" + Guid.NewGuid().ToString("N"));
                }
                app = _app;
            }
            // SDK validates signature, issuer, audience, expiry and revoked/disabled users.
            var token = await FirebaseAuth.GetAuth(app).VerifyIdTokenAsync(idToken, true, ct);
            return ReadGoogleIdentity(token.Claims);
        }
        catch (FirebaseAuthException)
        {
            return Error.Validation("auth.invalid_firebase_token", "Firebase ID token không hợp lệ hoặc đã hết hạn.");
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogWarning("Firebase login verifier unavailable ({ErrorType}).", ex.GetType().Name);
            return Error.Unavailable("auth.firebase_unavailable", "Chưa kết nối được dịch vụ xác thực Firebase.");
        }
    }

    internal static Result<GoogleIdentity> ReadGoogleIdentity(IReadOnlyDictionary<string, object> claims)
    {
        // Only inspect claims AFTER SDK verification. A Firebase UID is not a Google subject.
        if (!claims.TryGetValue("firebase", out var provider)) return Invalid();
        var firebase = ToToken(provider);
        var verified = claims.TryGetValue("email_verified", out var rawVerified) ? ToToken(rawVerified) : null;
        var emailClaim = claims.TryGetValue("email", out var rawEmail) ? ToToken(rawEmail) : null;
        var nameClaim = claims.TryGetValue("name", out var rawName) ? ToToken(rawName) : null;
        if (firebase is not JObject firebaseObject ||
            firebaseObject["sign_in_provider"]?.Type != JTokenType.String ||
            firebaseObject["sign_in_provider"]?.Value<string>() != "google.com" ||
            firebaseObject["identities"] is not JObject identities ||
            identities["google.com"] is not JArray { Count: 1 } subjects ||
            subjects[0].Type != JTokenType.String ||
            string.IsNullOrWhiteSpace(subjects[0].Value<string>()) ||
            verified?.Type != JTokenType.Boolean || !verified.Value<bool>() ||
            emailClaim?.Type != JTokenType.String ||
            string.IsNullOrWhiteSpace(emailClaim.Value<string>())) return Invalid();
        var email = emailClaim.Value<string>()!;
        var name = nameClaim?.Type == JTokenType.String ? nameClaim.Value<string>() : null;
        return new GoogleIdentity(subjects[0].Value<string>()!, email.Trim().ToLowerInvariant(), name ?? email);
    }

    private static JToken? ToToken(object? value) => value is null ? null : JToken.FromObject(value);

    private static Result<GoogleIdentity> Invalid() => Error.Validation(
        "auth.firebase_google_required", "Cần tài khoản Google có email đã xác minh.");

    public void Dispose() { lock (_gate) { _app?.Delete(); _app = null; } }
}
