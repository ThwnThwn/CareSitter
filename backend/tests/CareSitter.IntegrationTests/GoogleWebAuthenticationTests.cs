using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.ApiHost.Security;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.TestHost;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Tokens;

namespace CareSitter.IntegrationTests;

public sealed class GoogleWebAuthenticationTests
{
    private const string Origin = "https://app.example.com";
    private const string Redirect = "https://api.example.com" + GoogleWebAuthentication.CallbackPath;
    private static readonly string RequestId = new('a', 64);

    [Theory]
    [InlineData(Origin, false, true)]
    [InlineData("https://app.example.com.evil.test", false, false)]
    [InlineData("https://app.example.com/path", false, false)]
    [InlineData("https://app.example.com/", false, false)]
    [InlineData("https://app.example.com?x=1", false, false)]
    [InlineData("https://app.example.com@evil.test", false, false)]
    [InlineData("http://app.example.com", false, false)]
    [InlineData("http://localhost:7357", false, false)]
    [InlineData("http://localhost:7357", true, true)]
    [InlineData("null", true, false)]
    public void Origin_must_be_exact_and_allowlisted(string origin, bool development, bool expected)
    {
        Assert.Equal(expected, GoogleWebAuthentication.IsAllowedOrigin(origin, Configuration(), development));
    }

    [Fact]
    public async Task Challenge_uses_fixed_redirect_pkce_nonce_and_secure_correlation()
    {
        await using var app = await CreateApp();
        var (response, query) = await Challenge(app);
        Assert.Equal(HttpStatusCode.Redirect, response.StatusCode);
        Assert.Equal(Redirect, query["redirect_uri"]);
        Assert.Equal("code", query["response_type"]);
        Assert.Equal("S256", query["code_challenge_method"]);
        Assert.Equal("select_account", query["prompt"]);
        Assert.False(string.IsNullOrEmpty(query["state"]));
        Assert.False(string.IsNullOrEmpty(query["nonce"]));
        Assert.False(string.IsNullOrEmpty(query["code_challenge"]));
        Assert.All(response.Headers.GetValues("Set-Cookie"), cookie =>
        {
            Assert.Contains("secure", cookie);
            Assert.Contains("httponly", cookie);
            Assert.Contains("samesite=lax", cookie);
        });
    }

    [Fact]
    public async Task Invalid_origin_or_request_is_rejected_before_challenge()
    {
        await using var app = await CreateApp();
        var client = app.GetTestClient();
        foreach (var path in new[] {
            Start("https://evil.test", RequestId), Start(Origin, "bad") })
        {
            var response = await client.GetAsync(path);
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Null(response.Headers.Location);
        }
    }

    [Fact]
    public async Task Missing_configuration_returns_safe_popup_error()
    {
        await using var app = await CreateApp(configured: false);
        var response = await app.GetTestClient().GetAsync(Start(Origin, RequestId));
        var html = await response.Content.ReadAsStringAsync();
        Assert.Contains("\"error\":\"configuration\"", html);
        Assert.Contains(Origin, html);
        Assert.Contains("no-store", response.Headers.CacheControl!.ToString());
        Assert.Null(response.Headers.Location);
    }

    [Fact]
    public async Task Tampered_state_never_returns_token_or_posts_to_an_origin()
    {
        await using var app = await CreateApp();
        var response = await app.GetTestClient().GetAsync(GoogleWebAuthentication.CallbackPath + "?code=fake&state=tampered");
        var html = await response.Content.ReadAsStringAsync();
        Assert.DoesNotContain("postMessage", html);
        Assert.DoesNotContain("idToken", html);
    }

    [Theory]
    [InlineData(true, true)]
    [InlineData(false, true)]
    [InlineData(true, false)]
    public async Task Callback_requires_nonce_and_correlation_before_releasing_token(bool validNonce, bool sendCookies)
    {
        using var rsa = RSA.Create(2048);
        var key = new RsaSecurityKey(rsa) { KeyId = "test-key" };
        var exchange = new TokenExchangeHandler();
        await using var app = await CreateApp(key: key, exchange: exchange);
        var (challenge, query) = await Challenge(app);
        var jwt = new JwtSecurityToken("https://accounts.google.com", "test-client", new[] {
            new Claim("sub", "google-user"),
            new Claim("iat", DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(), ClaimValueTypes.Integer64),
            new Claim("nonce", validNonce ? query["nonce"].ToString() : "wrong-nonce"),
        }, DateTime.UtcNow.AddMinutes(-1), DateTime.UtcNow.AddMinutes(5),
            new SigningCredentials(key, SecurityAlgorithms.RsaSha256));
        var token = new JwtSecurityTokenHandler().WriteToken(jwt);
        exchange.IdToken = token;
        var request = new HttpRequestMessage(HttpMethod.Get, QueryHelpers.AddQueryString(
            GoogleWebAuthentication.CallbackPath, new Dictionary<string, string?> {
                ["code"] = "test-code", ["state"] = query["state"]
            }));
        if (sendCookies)
            request.Headers.Add("Cookie", string.Join("; ", challenge.Headers.GetValues("Set-Cookie").Select(c => c.Split(';')[0])));
        var response = await app.GetTestClient().SendAsync(request);
        var html = await response.Content.ReadAsStringAsync();
        if (validNonce && sendCookies)
        {
            Assert.Contains(token, html);
            Assert.Contains("postMessage", html);
            Assert.Contains(Origin, html);
            Assert.Contains(RequestId, html);
            Assert.Contains("script-src 'nonce-", response.Headers.GetValues("Content-Security-Policy").Single());
            Assert.Contains("no-store", response.Headers.CacheControl!.ToString());
            Assert.Equal(Redirect, exchange.RedirectUri);
            Assert.False(string.IsNullOrEmpty(exchange.CodeVerifier));
            Assert.DoesNotContain(response.Headers.GetValues("Set-Cookie"), c => c.StartsWith(".AspNetCore.GoogleWebTemporary="));
        }
        else
        {
            Assert.DoesNotContain(token, html);
            Assert.Contains("\"error\":\"failed\"", html);
        }
    }

    [Fact]
    public async Task Popup_escapes_script_injection_and_never_uses_wildcard_target()
    {
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();
        var props = new AuthenticationProperties();
        props.Items["web-origin"] = Origin;
        props.Items["web-request-id"] = RequestId;
        await GoogleWebAuthentication.WritePopupAsync(context, props, null, "</script><script>alert(1)</script>");
        context.Response.Body.Position = 0;
        var html = await new StreamReader(context.Response.Body).ReadToEndAsync();
        Assert.DoesNotContain("<script>alert", html);
        Assert.Contains("\\u003C", html);
        Assert.Contains($", \"{Origin}\")", html);
    }

    private static IConfiguration Configuration(bool configured = true) => new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string?> {
            ["Google:ClientId"] = "test-client",
            ["Google:ClientSecret"] = configured ? "test-secret" : null,
            ["Google:Web:RedirectUri"] = Redirect,
            ["Cors:AllowedOrigins:0"] = Origin
        }).Build();

    private static async Task<WebApplication> CreateApp(bool configured = true,
        SecurityKey? key = null, TokenExchangeHandler? exchange = null)
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions { EnvironmentName = "Production" });
        builder.WebHost.UseTestServer();
        builder.Configuration.AddConfiguration(Configuration(configured));
        builder.Services.AddAuthentication();
        builder.Services.AddGoogleWebAuthentication(builder.Configuration, false);
        builder.Services.AddRateLimiter(options => options.AddPolicy("auth-login", _ =>
            System.Threading.RateLimiting.RateLimitPartition.GetNoLimiter("test")));
        if (configured)
            builder.Services.PostConfigure<OpenIdConnectOptions>(GoogleWebAuthentication.Scheme, options => {
                options.Configuration = new OpenIdConnectConfiguration {
                    Issuer = "https://accounts.google.com",
                    AuthorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth",
                    TokenEndpoint = "https://oauth2.googleapis.com/token"
                };
                if (key is not null) options.Configuration.SigningKeys.Add(key);
                options.ConfigurationManager = new StaticConfigurationManager<OpenIdConnectConfiguration>(options.Configuration);
                if (exchange is not null) options.Backchannel = new HttpClient(exchange);
            });
        var app = builder.Build();
        app.UseRouting();
        app.UseRateLimiter();
        app.UseAuthentication();
        app.MapGoogleWebAuthentication();
        await app.StartAsync();
        return app;
    }

    private static string Start(string origin, string requestId) => QueryHelpers.AddQueryString(
        GoogleWebAuthentication.StartPath, new Dictionary<string, string?> { ["origin"] = origin, ["requestId"] = requestId });

    private static async Task<(HttpResponseMessage, Dictionary<string, Microsoft.Extensions.Primitives.StringValues>)> Challenge(WebApplication app)
    {
        var client = app.GetTestClient();
        client.BaseAddress = new Uri("https://untrusted-host.test");
        var response = await client.GetAsync(Start(Origin, RequestId));
        return (response, QueryHelpers.ParseQuery(response.Headers.Location!.Query));
    }

    private sealed class TokenExchangeHandler : HttpMessageHandler
    {
        public string IdToken { get; set; } = "";
        public string? RedirectUri { get; private set; }
        public string? CodeVerifier { get; private set; }
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var form = QueryHelpers.ParseQuery(await request.Content!.ReadAsStringAsync(cancellationToken));
            RedirectUri = form["redirect_uri"];
            CodeVerifier = form["code_verifier"];
            return new HttpResponseMessage(HttpStatusCode.OK) {
                Content = new StringContent(JsonSerializer.Serialize(new {
                    access_token = "test-access-token", token_type = "Bearer", expires_in = 300, id_token = IdToken
                }), Encoding.UTF8, "application/json")
            };
        }
    }
}
