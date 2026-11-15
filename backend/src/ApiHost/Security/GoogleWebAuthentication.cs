using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;

namespace CareSitter.ApiHost.Security;

// Browser transport only. The existing Google/customer endpoint still owns
// account creation, role assignment and issuance of CareSitter sessions.
internal static class GoogleWebAuthentication
{
    internal const string Scheme = "GoogleWeb";
    internal const string StartPath = "/api/v1/auth/google/customer/web/start";
    internal const string CallbackPath = "/api/v1/auth/google/customer/web/callback";
    private const string TemporaryCookieScheme = "GoogleWebTemporary";
    private const string OriginKey = "web-origin";
    private const string RequestKey = "web-request-id";

    public static IServiceCollection AddGoogleWebAuthentication(
        this IServiceCollection services, IConfiguration configuration, bool isDevelopment)
    {
        var clientId = configuration["Google:ClientId"];
        var secret = configuration["Google:ClientSecret"];
        var redirectUrl = configuration["Google:Web:RedirectUri"];
        if (new[] { clientId, secret, redirectUrl }.Any(value =>
            string.IsNullOrWhiteSpace(value) || value.Contains("REPLACE_WITH", StringComparison.OrdinalIgnoreCase)))
            return services; // Native login remains available; the popup reports missing setup.

        if (!Uri.TryCreate(redirectUrl, UriKind.Absolute, out var redirect) ||
            redirect.AbsolutePath != CallbackPath || redirect.Query.Length != 0 ||
            redirect.Fragment.Length != 0 || redirect.UserInfo.Length != 0 ||
            !(redirect.Scheme == "https" || isDevelopment && redirect.IsLoopback && redirect.Scheme == "http"))
            throw new InvalidOperationException("Google:Web:RedirectUri must be the HTTPS Google web callback URL (HTTP loopback is allowed in Development).");

        services.AddAuthentication()
            .AddCookie(TemporaryCookieScheme)
            .AddOpenIdConnect(Scheme, options =>
            {
                options.SignInScheme = TemporaryCookieScheme;
                options.Authority = "https://accounts.google.com";
                options.ClientId = clientId;
                options.ClientSecret = secret;
                options.CallbackPath = CallbackPath;
                options.ResponseType = OpenIdConnectResponseType.Code;
                options.ResponseMode = OpenIdConnectResponseMode.Query;
                options.UsePkce = true;
                options.SaveTokens = true;
                options.GetClaimsFromUserInfoEndpoint = false;
                options.MapInboundClaims = false;
                options.Scope.Clear();
                options.Scope.Add("openid");
                options.Scope.Add("email");
                options.Scope.Add("profile");
                options.RemoteAuthenticationTimeout = TimeSpan.FromMinutes(5);
                // Query-mode callbacks are top-level GET navigations, so Lax works
                // on HTTP localhost without relying on third-party cookies.
                options.CorrelationCookie.SameSite = SameSiteMode.Lax;
                options.NonceCookie.SameSite = SameSiteMode.Lax;
                options.CorrelationCookie.SecurePolicy = isDevelopment
                    ? CookieSecurePolicy.SameAsRequest : CookieSecurePolicy.Always;
                options.NonceCookie.SecurePolicy = options.CorrelationCookie.SecurePolicy;
                options.Events = new OpenIdConnectEvents
                {
                    OnRedirectToIdentityProvider = context =>
                    {
                        // Never derive the OAuth redirect from an untrusted Host header.
                        context.ProtocolMessage.RedirectUri = redirectUrl;
                        context.ProtocolMessage.Prompt = "select_account";
                        return Task.CompletedTask;
                    },
                    OnAuthorizationCodeReceived = context =>
                    {
                        context.TokenEndpointRequest!.RedirectUri = redirectUrl;
                        return Task.CompletedTask;
                    },
                    OnTicketReceived = async context =>
                    {
                        // The middleware has validated state/correlation, nonce,
                        // issuer, audience, signature and lifetime before this event.
                        var idToken = context.Properties?.GetTokenValue("id_token");
                        context.HandleResponse(); // No external authentication cookie/session.
                        await WritePopupAsync(context.HttpContext, context.Properties,
                            string.IsNullOrEmpty(idToken) ? "missing_token" : null, idToken);
                    },
                    OnAccessDenied = async context =>
                    {
                        context.HandleResponse();
                        await WritePopupAsync(context.HttpContext, context.Properties, "cancelled");
                    },
                    OnRemoteFailure = async context =>
                    {
                        context.HandleResponse();
                        await WritePopupAsync(context.HttpContext, context.Properties, "failed");
                    }
                };
            });
        return services;
    }

    public static void MapGoogleWebAuthentication(this WebApplication app) =>
        app.MapGet(StartPath, StartAsync).AllowAnonymous().RequireRateLimiting("auth-login");

    private static async Task<IResult> StartAsync(HttpContext context,
        IConfiguration configuration, IWebHostEnvironment environment,
        IAuthenticationSchemeProvider schemes)
    {
        var origin = context.Request.Query["origin"].ToString();
        var requestId = context.Request.Query["requestId"].ToString();
        if (!IsAllowedOrigin(origin, configuration, environment.IsDevelopment()) ||
            requestId.Length != 64 || !requestId.All(Uri.IsHexDigit))
            return Results.BadRequest(new { error = "Invalid Google login origin or request." });

        var properties = new AuthenticationProperties();
        // Authentication middleware protects these values in the OAuth state.
        properties.Items[OriginKey] = origin;
        properties.Items[RequestKey] = requestId;
        if (await schemes.GetSchemeAsync(Scheme) is null)
        {
            await WritePopupAsync(context, properties, "configuration");
            return Results.Empty;
        }
        return Results.Challenge(properties, [Scheme]);
    }

    internal static bool IsAllowedOrigin(string origin, IConfiguration configuration, bool isDevelopment)
    {
        if (!Uri.TryCreate(origin, UriKind.Absolute, out var uri) ||
            uri.Scheme is not ("http" or "https") || uri.UserInfo.Length != 0 ||
            !string.Equals(origin, uri.GetLeftPart(UriPartial.Authority), StringComparison.OrdinalIgnoreCase))
            return false;
        if (isDevelopment && uri.IsLoopback) return true;
        return uri.Scheme == "https" && configuration.GetSection("Cors:AllowedOrigins")
            .GetChildren().Any(value => string.Equals(value.Value?.TrimEnd('/'), origin, StringComparison.OrdinalIgnoreCase));
    }

    internal static async Task WritePopupAsync(HttpContext context,
        AuthenticationProperties? properties, string? error, string? idToken = null)
    {
        string? origin = null;
        string? requestId = null;
        properties?.Items.TryGetValue(OriginKey, out origin);
        properties?.Items.TryGetValue(RequestKey, out requestId);
        var nonce = Convert.ToBase64String(RandomNumberGenerator.GetBytes(24));
        context.Response.ContentType = "text/html; charset=utf-8";
        context.Response.Headers.CacheControl = "no-store";
        context.Response.Headers.Pragma = "no-cache";
        context.Response.Headers["Referrer-Policy"] = "no-referrer";
        context.Response.Headers.ContentSecurityPolicy = $"default-src 'none'; script-src 'nonce-{nonce}'; frame-ancestors 'none'; base-uri 'none'";
        var script = "";
        if (!string.IsNullOrEmpty(origin) && !string.IsNullOrEmpty(requestId))
        {
            // Default JSON escaping also escapes '<', preventing script-tag injection.
            var payload = JsonSerializer.Serialize(new
            {
                type = "caresitter:google-auth", requestId,
                idToken = error is null ? idToken : null, error
            });
            script = $"<script nonce=\"{nonce}\">if (window.opener) {{ window.opener.postMessage({payload}, {JsonSerializer.Serialize(origin)}); window.close(); }}</script>";
        }
        await context.Response.WriteAsync("<!doctype html><html lang=\"vi\"><meta charset=\"utf-8\"><title>CareSitter — Google</title><body><p>Quay lại CareSitter để tiếp tục. Bạn có thể đóng cửa sổ này.</p>" + script + "</body></html>");
    }
}
