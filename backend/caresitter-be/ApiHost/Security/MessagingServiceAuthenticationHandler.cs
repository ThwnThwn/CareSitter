using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace CareSitter.ApiHost.Security;

/// <summary>Authenticates private worker requests using an environment-provided service credential.</summary>
public sealed class MessagingServiceAuthenticationHandler(IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger, UrlEncoder encoder, IConfiguration config) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    /// <summary>Compares bounded credentials in constant time and issues a service-only principal.</summary>
    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var expected = config["KAFKA_INTERNAL_SERVICE_KEY"];
        var actual = Request.Headers["X-Messaging-Service-Key"].ToString();
        if (string.IsNullOrWhiteSpace(expected) || expected.Length < 32 || actual.Length > 256 ||
            !CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(expected), Encoding.UTF8.GetBytes(actual)))
            return Task.FromResult(AuthenticateResult.Fail("Invalid messaging service credential."));
        var identity = new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, "notification-worker")], Scheme.Name);
        return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme.Name)));
    }
}
