using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Application.GoogleLogin;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using Newtonsoft.Json.Linq;

namespace CareSitter.IntegrationTests;

public sealed class FirebaseGoogleIdentityTests
{
    private static Dictionary<string, object> Claims() => new()
    {
        ["sub"] = "firebase-uid-must-not-be-linked-as-google-subject",
        ["email"] = "Demo@Example.com", ["email_verified"] = true, ["name"] = "Demo",
        ["firebase"] = new Dictionary<string, object> {
            ["sign_in_provider"] = "google.com",
            ["identities"] = new Dictionary<string, object> { ["google.com"] = new[] { "google-subject" } }
        }
    };

    [Fact]
    public void Verified_claims_use_google_subject_and_normalize_email()
    {
        var result = FirebaseGoogleIdentityVerifier.ReadGoogleIdentity(Claims());
        Assert.True(result.IsSuccess);
        Assert.Equal("google-subject", result.Value.Subject);
        Assert.Equal("demo@example.com", result.Value.Email);
    }

    [Fact]
    public void Verified_newtonsoft_claims_from_firebase_admin_are_accepted()
    {
        var claims = Claims();
        claims["firebase"] = JObject.Parse("""
            {"sign_in_provider":"google.com","identities":{"google.com":["google-subject"]}}
            """);
        claims["email_verified"] = new JValue(true);
        claims["email"] = new JValue("Demo@Example.com");
        claims["name"] = new JValue("Demo");

        var result = FirebaseGoogleIdentityVerifier.ReadGoogleIdentity(claims);

        Assert.True(result.IsSuccess);
        Assert.Equal("google-subject", result.Value.Subject);
        Assert.Equal("demo@example.com", result.Value.Email);
    }

    [Fact]
    public void Unverified_newtonsoft_email_is_rejected()
    {
        var claims = Claims();
        claims["firebase"] = JObject.Parse("""
            {"sign_in_provider":"google.com","identities":{"google.com":["google-subject"]}}
            """);
        claims["email_verified"] = new JValue(false);
        claims["email"] = new JValue("Demo@Example.com");

        Assert.True(FirebaseGoogleIdentityVerifier.ReadGoogleIdentity(claims).IsFailure);
    }

    [Theory]
    [InlineData("email_verified", false)]
    [InlineData("email_verified", "true")]
    [InlineData("email", "")]
    [InlineData("firebase", "malformed")]
    public void Missing_or_unverified_claims_are_rejected(string key, object value)
    {
        var claims = Claims(); claims[key] = value;
        Assert.True(FirebaseGoogleIdentityVerifier.ReadGoogleIdentity(claims).IsFailure);
    }

    [Theory]
    [InlineData("password")]
    [InlineData("custom")]
    [InlineData("anonymous")]
    public void Other_firebase_providers_cannot_issue_a_google_caresitter_session(string provider)
    {
        var claims = Claims();
        ((Dictionary<string, object>)claims["firebase"])["sign_in_provider"] = provider;
        Assert.True(FirebaseGoogleIdentityVerifier.ReadGoogleIdentity(claims).IsFailure);
    }

    [Fact]
    public async Task Invalid_token_never_reads_accounts_or_issues_a_session()
    {
        var handler = new FirebaseGoogleLoginHandler(new InvalidVerifier(), new GoogleAccountSignIn(null!, null!));
        var result = await handler.Handle(new FirebaseGoogleLoginCommand("wrong-project-or-signature"), default);
        Assert.True(result.IsFailure); Assert.Equal("auth.invalid_firebase_token", result.Error.Code);
    }

    private sealed class InvalidVerifier : IFirebaseGoogleIdentityVerifier
    {
        public Task<Result<GoogleIdentity>> VerifyAsync(string token, CancellationToken ct = default) =>
            Task.FromResult<Result<GoogleIdentity>>(Error.Validation("auth.invalid_firebase_token", "invalid"));
    }
}
