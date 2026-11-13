using System.Net;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Diagnostics;
using CareSitter.Modules.Support.Controllers;
using CareSitter.Modules.Support.Infrastructure.Diagnostics;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using System.Threading.RateLimiting;

namespace CareSitter.IntegrationTests;

public sealed class CrashReportsTests
{
    private static CrashReportOptions Config() => new() { Enabled = true, ProjectId = "demo-project", Location = "US" };
    private static CrashReportFilter Filter() => new(DateTimeOffset.UtcNow, 7, 1, 20, null);
    [Theory]
    [InlineData("vn_caresitter_customer_ANDROID", true)]
    [InlineData("vn_caresitter_customer_ANDROID_REALTIME", true)]
    [InlineData("vn_caresitter_customer_IOS", true)]
    [InlineData("vn_caresitter_customer_IOS_REALTIME", true)]
    [InlineData("vn_caresitter_customer_iOS", false)]
    [InlineData("other_table", false)]
    [InlineData("vn_caresitter_customer_ANDROID` UNION SELECT secret", false)]
    public void Only_server_allowlisted_export_tables_can_be_queried(string table, bool valid)
    {
        var settings = Config(); settings.Table = table;
        Assert.Equal(valid, settings.IsValid);
        if (!valid) Assert.Throws<ArgumentException>(() => BigQueryCrashReportSource.Query(settings, Filter()));
    }
    [Fact]
    public void Query_is_parameterized_and_has_explicit_cost_window_and_result_limits()
    {
        var json = JsonSerializer.Serialize(BigQueryCrashReportSource.Query(Config(), Filter()));
        Assert.Contains("@since", json); Assert.Contains("@until", json);
        Assert.Contains("@offset", json); Assert.Contains("maximumBytesBilled", json);
        Assert.DoesNotContain("exception_message", json); Assert.DoesNotContain("installation_uuid", json);
        Assert.DoesNotContain("logs.message", json); Assert.DoesNotContain("user", json);
    }
    [Theory]
    [InlineData("""{"jobComplete":false}""")]
    [InlineData("""{"jobComplete":true,"errors":[{"message":"secret"}]}""")]
    [InlineData("""{"jobComplete":true,"pageToken":"next"}""")]
    public async Task Incomplete_or_provider_error_is_not_reported_as_empty_success(string response)
    {
        using var http = new HttpClient(new Transport(response));
        var source = new BigQueryCrashReportSource(http, Options.Create(Config()), new Token(), new Clock(),
            NullLogger<BigQueryCrashReportSource>.Instance);
        var result = await source.ReadAsync(Filter(), default);
        Assert.True(result.IsFailure); Assert.DoesNotContain("secret", result.Error.Message);
    }
    [Fact]
    public async Task Disabled_source_is_explicit_not_configured_and_never_requests_provider()
    {
        using var http = new HttpClient(new Transport("invalid"));
        var source = new BigQueryCrashReportSource(http, Options.Create(new CrashReportOptions()), new Token(), new Clock(),
            NullLogger<BigQueryCrashReportSource>.Instance);
        var result = await source.ReadAsync(Filter(), default);
        Assert.True(result.IsSuccess); Assert.Equal("not_configured", result.Value.SourceStatus);
    }
    [Fact]
    public async Task Export_schema_maps_report_without_arbitrary_context_or_sensitive_messages()
    {
        var item = new { eventId = "event-1", issueId = "issue-1", occurredAt = DateTimeOffset.UtcNow,
            errorType = "FATAL", appVersion = "1.0.0", buildVersion = "1", platform = "ANDROID",
            screen = "email@example.com", demoRunId = "private-note" };
        var body = JsonSerializer.Serialize(new { jobComplete = true, rows = new[] { new { f = new[] { new { v = JsonSerializer.Serialize(item) } } } } });
        using var http = new HttpClient(new Transport(body));
        var source = new BigQueryCrashReportSource(http, Options.Create(Config()), new Token(), new Clock(),
            NullLogger<BigQueryCrashReportSource>.Instance);
        var result = await source.ReadAsync(Filter(), default);
        Assert.True(result.IsSuccess); var report = Assert.Single(result.Value.Items);
        Assert.Equal("unknown", report.Screen); Assert.Equal("", report.DemoRunId);
    }
    [Fact]
    public async Task Application_rejects_wrong_role_or_invalid_pagination_without_reading_source()
    {
        var actor = new Actor { Role = "CUSTOMER" };
        var source = new Source(); var service = new CrashReportService(source, actor, new Clock());
        Assert.True((await service.ListAsync(Filter(), default)).IsFailure);
        actor.Role = "ADMIN";
        Assert.True((await service.ListAsync(Filter() with { Days = 8 }, default)).IsFailure);
        Assert.True((await service.ListAsync(Filter() with { Page = 101 }, default)).IsFailure);
        Assert.True((await service.ListAsync(Filter() with { ErrorType = "FATAL' OR 1=1" }, default)).IsFailure);
        Assert.Equal(0, source.Reads);
    }
    [Theory]
    [InlineData(null, 401)]
    [InlineData("CUSTOMER", 403)]
    [InlineData("ADMIN", 200)]
    public async Task Http_endpoint_enforces_admin_before_reading(string? role, int status)
    {
        var builder = WebApplication.CreateBuilder(); builder.WebHost.UseTestServer();
        builder.Services.AddAuthentication("test").AddScheme<AuthenticationSchemeOptions, Auth>("test", _ => {});
        builder.Services.AddAuthorization(); builder.Services.AddLogging();
        builder.Services.AddControllers().AddApplicationPart(typeof(AdminCrashReportsController).Assembly);
        builder.Services.AddRateLimiter(options => options.AddPolicy("crash-reports-read", _ => RateLimitPartition.GetNoLimiter("test")));
        var source = new Source(); builder.Services.AddSingleton<ICrashReportSource>(source);
        builder.Services.AddSingleton<ICurrentUser>(new Actor()); builder.Services.AddSingleton<IClock>(new Clock());
        builder.Services.AddScoped<CrashReportService>();
        await using var app = builder.Build(); app.UseRouting(); app.UseAuthentication(); app.UseAuthorization(); app.UseRateLimiter(); app.MapControllers();
        await app.StartAsync(); var client = app.GetTestClient();
        if (role != null) client.DefaultRequestHeaders.Add("X-Role", role);
        var response = await client.GetAsync("/api/v1/admin/crash-reports");
        Assert.Equal(status, (int)response.StatusCode); Assert.Equal(role == "ADMIN" ? 1 : 0, source.Reads);
        if (role == "ADMIN") Assert.Contains("no-store", response.Headers.CacheControl!.ToString());
    }
    private sealed class Auth(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory log, UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, log, encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var role = Request.Headers["X-Role"].ToString();
            return Task.FromResult(string.IsNullOrEmpty(role) ? AuthenticateResult.NoResult() :
                AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(new ClaimsIdentity(
                    [new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()), new Claim(ClaimTypes.Role, role)], Scheme.Name)), Scheme.Name)));
        }
    }
    private sealed class Actor : ICurrentUser { public string Role = "ADMIN"; public Guid? UserId => Guid.NewGuid();
        public IReadOnlyCollection<string> Roles => [Role]; public bool IsInRole(string role) => role == Role; }
    private sealed class Source : ICrashReportSource { public int Reads;
        public Task<Result<CrashReportPage>> ReadAsync(CrashReportFilter f, CancellationToken ct) {
            Reads++; return Task.FromResult<Result<CrashReportPage>>(new CrashReportPage("ready", "batch", DateTimeOffset.UtcNow, f.Until, f.Days, f.Page, f.PageSize, false, [])); } }
    private sealed class Token : ICrashQueryTokenProvider { public Task<string> GetAsync(CancellationToken ct) => Task.FromResult("test-token"); }
    private sealed class Clock : IClock { public DateTimeOffset UtcNow => DateTimeOffset.UtcNow; }
    private sealed class Transport(string response) : HttpMessageHandler {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) =>
            Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(response) }); }
}
