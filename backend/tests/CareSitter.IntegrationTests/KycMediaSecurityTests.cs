using System.Net;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Threading.RateLimiting;
using CareSitter.ApiHost.Endpoints;
using CareSitter.ApiHost.OpenApi;
using CareSitter.ApiHost.Security;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Media;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.TestHost;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.IntegrationTests;

public sealed class KycMediaSecurityTests
{
    internal static readonly byte[] Png = [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0];
    internal static readonly Guid Owner = Guid.Parse("20000000-0000-0000-0000-000000000001");
    internal static readonly IOptions<CloudinarySettings> Settings = Options.Create(new CloudinarySettings
    { CloudName = "unit-test-cloud", ApiKey = "unit-test-key", ApiSecret = "unit-test-secret" });

    [Fact]
    public async Task Upload_uses_authenticated_random_object_key_and_returns_only_a_media_id()
    {
        var f = new Fixture();
        var result = await f.Service.UploadAsync(new MemoryStream(Png), "cccd.png", "CCCD_FRONT", default);
        Assert.True(result.IsSuccess);
        var asset = Assert.Single(f.Store.Assets.Values);
        Assert.Equal(result.Value, asset.Id);
        Assert.Equal(Owner, asset.OwnerUserId);
        Assert.Equal("authenticated", asset.DeliveryType);
        Assert.Equal($"CareSitter/Kyc/{Owner:D}/{result.Value:N}", asset.ObjectKey);
        Assert.Equal("CCCD_FRONT", asset.DocumentType);
        Assert.Equal("KYC_MEDIA_UPLOADED", Assert.Single(f.Audit.Actions));
        var parameters = CloudinaryKycGateway.CreateUploadParameters(new MemoryStream(Png), asset.ObjectKey);
        Assert.Equal("authenticated", parameters.Type);
        Assert.False(parameters.Overwrite);
        Assert.False(parameters.UseFilename);
        Assert.Null(parameters.Folder);
    }

    [Theory]
    [InlineData("CUSTOMER", "CCCD_FRONT", "cccd.png", true)]
    [InlineData("ADMIN", "CCCD_FRONT", "cccd.png", true)]
    [InlineData("CAREGIVER", "AVATAR", "cccd.png", true)]
    [InlineData("CAREGIVER", "CCCD_FRONT", "cccd.svg", true)]
    [InlineData("CAREGIVER", "CCCD_FRONT", "cccd.jpg", true)]
    [InlineData("CAREGIVER", "CCCD_FRONT", "cccd.png", false)]
    public async Task Upload_rejects_wrong_role_type_extension_signature_or_empty_stream(
        string role, string type, string file, bool hasBytes)
    {
        var f = new Fixture(); f.Actor.Role = role;
        var result = await f.Service.UploadAsync(new MemoryStream(hasBytes ? Png : []), file, type, default);
        Assert.True(result.IsFailure);
        Assert.Equal(0, f.Gateway.Uploads);
        Assert.Empty(f.Store.Assets);
    }

    [Theory]
    [InlineData("upload", "image", "png")]
    [InlineData("private", "image", "png")]
    [InlineData("authenticated", "raw", "png")]
    [InlineData("authenticated", "image", "jpg")]
    public async Task Upload_never_persists_an_unverified_provider_contract(string delivery, string resource, string format)
    {
        var f = new Fixture();
        f.Gateway.ResponseDelivery = delivery; f.Gateway.ResponseResource = resource; f.Gateway.ResponseFormat = format;
        var result = await f.Service.UploadAsync(new MemoryStream(Png), "cccd.png", "CCCD_FRONT", default);
        Assert.True(result.IsFailure); Assert.Empty(f.Store.Assets);
    }

    [Theory]
    [InlineData("CAREGIVER", false, true, true)]
    [InlineData("CAREGIVER", false, false, false)]
    [InlineData("CUSTOMER", true, true, false)]
    [InlineData("ADMIN", true, false, true)]
    [InlineData("ADMIN", false, false, false)]
    public async Task Read_permissions_are_owner_caregiver_or_admin_with_a_submitted_document(
        string role, bool submitted, bool sameOwner, bool allowed)
    {
        var f = new Fixture(); var asset = f.AddAsset();
        f.Actor.Role = role; f.Actor.Id = sameOwner ? Owner : Guid.NewGuid(); f.Access.Submitted = submitted;
        var url = await f.Service.CreateReadUrlAsync(asset.Id, TimeSpan.FromMinutes(2), default);
        Assert.Equal(allowed, url.IsSuccess);
        if (allowed)
        {
            Assert.Equal($"/api/v1/media/{asset.Id}/content", url.Value.Url);
            Assert.DoesNotContain("cloudinary", url.Value.Url);
            Assert.True((await f.Service.ReadAsync(asset.Id, url.Value.Ticket, default)).IsSuccess);
        }
        else Assert.Equal(0, f.Gateway.Downloads);
    }

    [Theory]
    [InlineData(0)] [InlineData(-1)] [InlineData(301)]
    public async Task Url_ttl_is_bounded(int seconds)
    {
        var f = new Fixture(); var asset = f.AddAsset();
        Assert.True((await f.Service.CreateReadUrlAsync(asset.Id, TimeSpan.FromSeconds(seconds), default)).IsFailure);
    }

    [Theory]
    [InlineData("expired")] [InlineData("tampered")] [InlineData("other-user")]
    [InlineData("other-media")] [InlineData("role-revoked")] [InlineData("removed")]
    public async Task Ticket_is_bound_and_authorization_is_rechecked_before_provider_read(string change)
    {
        var f = new Fixture(); var asset = f.AddAsset();
        var url = (await f.Service.CreateReadUrlAsync(asset.Id, TimeSpan.FromMinutes(2), default)).Value;
        var ticket = url.Ticket; var id = asset.Id;
        switch (change)
        {
            case "expired": f.Clock.Now = f.Clock.Now.AddMinutes(2); break;
            case "tampered": ticket = "!" + ticket; break;
            case "other-user": f.Actor.Id = Guid.NewGuid(); break;
            case "other-media": id = Guid.NewGuid(); break;
            case "role-revoked": f.Actor.Role = "CUSTOMER"; break;
            case "removed": f.Store.Assets.Clear(); break;
        }
        var result = await f.Service.ReadAsync(id, ticket, default);
        Assert.True(result.IsFailure); Assert.Equal(0, f.Gateway.Downloads);
    }

    [Fact]
    public async Task Admin_cannot_keep_using_a_ticket_after_document_is_unlinked()
    {
        var f = new Fixture(); var asset = f.AddAsset(); f.Actor.Role = "ADMIN"; f.Access.Submitted = true;
        var url = (await f.Service.CreateReadUrlAsync(asset.Id, TimeSpan.FromMinutes(2), default)).Value;
        f.Access.Submitted = false;
        Assert.True((await f.Service.ReadAsync(asset.Id, url.Ticket, default)).IsFailure);
        Assert.Equal(0, f.Gateway.Downloads);
    }

    [Theory]
    [InlineData("owner")] [InlineData("front-type")] [InlineData("public")]
    [InlineData("missing")] [InlineData("duplicate")] [InlineData("certificate-type")]
    public async Task Submit_rejects_cross_owner_wrong_purpose_public_missing_and_duplicate_media(string problem)
    {
        var f = new Fixture(); var front = f.AddAsset("CCCD_FRONT"); var back = f.AddAsset("CCCD_BACK");
        var cert = f.AddAsset("OTHER");
        switch (problem)
        {
            case "owner": f.Store.Assets[front.Id] = front with { OwnerUserId = Guid.NewGuid() }; break;
            case "front-type": f.Store.Assets[front.Id] = front with { DocumentType = "CCCD_BACK" }; break;
            case "public": f.Store.Assets[front.Id] = front with { DeliveryType = "upload" }; break;
            case "missing": f.Store.Assets.Remove(front.Id); break;
            case "duplicate": back = front; break;
            case "certificate-type": cert = front; break;
        }
        Assert.True((await KycMediaPolicy.ValidateSubmissionAsync(f.Store, Owner, front.Id, back.Id, [cert.Id], default)).IsFailure);
    }

    [Fact]
    public async Task Submit_accepts_owned_authenticated_documents_and_rejects_more_than_ten_certificates()
    {
        var f = new Fixture(); var front = f.AddAsset(); var back = f.AddAsset("CCCD_BACK"); var cert = f.AddAsset("OTHER");
        Assert.True((await KycMediaPolicy.ValidateSubmissionAsync(f.Store, Owner, front.Id, back.Id, [cert.Id], default)).IsSuccess);
        Assert.True((await KycMediaPolicy.ValidateSubmissionAsync(f.Store, Owner, front.Id, back.Id,
            Enumerable.Range(0, 11).Select(_ => Guid.NewGuid()).ToArray(), default)).IsFailure);
    }

    [Fact]
    public void Provider_download_url_uses_authenticated_type_explicit_expiry_and_no_transformations()
    {
        var f = new Fixture(); var asset = f.AddAsset();
        var gateway = new CloudinaryKycGateway(new HttpClient(), Settings, f.Clock);
        var uri = new Uri(gateway.CreateProviderDownloadUrl(asset));
        var query = QueryHelpers.ParseQuery(uri.Query);
        Assert.Equal("https", uri.Scheme); Assert.Equal("api.cloudinary.com", uri.Host);
        Assert.Equal("authenticated", query["type"]);
        Assert.Equal(f.Clock.Now.AddSeconds(30).ToUnixTimeSeconds().ToString(), query["expires_at"]);
        Assert.Equal(asset.ObjectKey, query["public_id"]);
        Assert.False(query.ContainsKey("transformation"));
        Assert.DoesNotContain(Settings.Value.ApiSecret, uri.AbsoluteUri);
    }

    [Theory]
    [InlineData(302, "image/png", true)] [InlineData(404, "image/png", true)]
    [InlineData(200, "text/html", true)] [InlineData(200, "image/png", false)]
    public async Task Provider_download_does_not_forward_errors_redirects_html_or_invalid_images(int status, string mime, bool image)
    {
        var f = new Fixture(); var asset = f.AddAsset();
        var response = new HttpResponseMessage((HttpStatusCode)status) { Content = new ByteArrayContent(image ? Png : [1, 2, 3]) };
        response.Content.Headers.ContentType = new MediaTypeHeaderValue(mime);
        var gateway = new CloudinaryKycGateway(new HttpClient(new ReplyHandler(response)), Settings, f.Clock);
        Assert.True((await gateway.DownloadAsync(asset, default)).IsFailure);
    }

    [Fact]
    public async Task Content_endpoint_requires_authentication_and_never_redirects_or_caches()
    {
        var f = new Fixture(); var asset = f.AddAsset();
        var builder = WebApplication.CreateBuilder(); builder.WebHost.UseTestServer();
        builder.Services.AddEndpointsApiExplorer(); builder.Services.AddCareSitterSwagger();
        builder.Services.AddAuthentication("test").AddScheme<AuthenticationSchemeOptions, TestAuth>("test", _ => { });
        builder.Services.AddAuthorization(); builder.Services.AddHttpContextAccessor();
        builder.Services.AddRateLimiter(options => options.AddPolicy("media-read", _ =>
            RateLimitPartition.GetNoLimiter("test")));
        builder.Services.AddScoped<ICurrentUser, HttpContextCurrentUser>();
        builder.Services.AddSingleton<IKycImageGateway>(f.Gateway); builder.Services.AddSingleton<IKycMediaStore>(f.Store);
        builder.Services.AddSingleton<IKycDocumentAccess>(f.Access); builder.Services.AddSingleton<IClock>(f.Clock);
        builder.Services.AddSingleton<IAuditLogger>(f.Audit); builder.Services.AddSingleton(Settings);
        builder.Services.AddSingleton<IDataProtectionProvider>(new EphemeralDataProtectionProvider());
        builder.Services.AddScoped<IKycMediaService, KycMediaService>();
        builder.Services.AddSingleton<IMediaService, UnusedPublicMedia>();
        await using var app = builder.Build(); app.UseSwagger(); app.UseAuthentication(); app.UseAuthorization(); app.UseRateLimiter(); MediaEndpoints.Map(app);
        await app.StartAsync(); var client = app.GetTestClient();
        var swagger = await client.GetAsync("/swagger/v1/swagger.json");
        Assert.Equal(HttpStatusCode.OK, swagger.StatusCode);
        using var specification = JsonDocument.Parse(await swagger.Content.ReadAsStringAsync());
        var uploadSchema = specification.RootElement.GetProperty("paths").GetProperty("/api/v1/media/upload")
            .GetProperty("post").GetProperty("requestBody").GetProperty("content")
            .GetProperty("multipart/form-data").GetProperty("schema").GetProperty("properties");
        Assert.Contains(uploadSchema.EnumerateObject(), p => p.Name.Equals("folder", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(uploadSchema.EnumerateObject(), p => p.Name.Equals("documentType", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(uploadSchema.EnumerateObject(), p => p.Name.Equals("file", StringComparison.OrdinalIgnoreCase) &&
            p.Value.GetProperty("format").GetString() == "binary");
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsync($"/api/v1/media/{asset.Id}/access", null)).StatusCode);
        client.DefaultRequestHeaders.Add("X-Test-Actor", "owner");
        using (var multipart = new MultipartFormDataContent())
        {
            var image = new ByteArrayContent(Png);
            image.Headers.ContentType = new MediaTypeHeaderValue("image/png");
            multipart.Add(image, "file", "front.png");
            multipart.Add(new StringContent("kyc"), "folder");
            multipart.Add(new StringContent("CCCD_FRONT"), "documentType");
            var upload = await client.PostAsync("/api/v1/media/upload", multipart);
            Assert.Equal(HttpStatusCode.OK, upload.StatusCode);
            var uploaded = JsonDocument.Parse(await upload.Content.ReadAsStringAsync());
            Assert.True(uploaded.RootElement.TryGetProperty("mediaId", out var mediaId));
            Assert.False(uploaded.RootElement.TryGetProperty("url", out _));
            Assert.Equal("authenticated", f.Store.Assets[mediaId.GetGuid()].DeliveryType);
            Assert.Equal(1, f.Gateway.Uploads);
        }
        var access = await client.PostAsync($"/api/v1/media/{asset.Id}/access", null);
        var json = JsonDocument.Parse(await access.Content.ReadAsStringAsync());
        var url = json.RootElement.GetProperty("url").GetString()!;
        client.DefaultRequestHeaders.Add("X-Kyc-Read-Ticket", json.RootElement.GetProperty("ticket").GetString());
        var content = await client.GetAsync(url);
        Assert.Equal(HttpStatusCode.OK, content.StatusCode);
        Assert.Equal(Png, await content.Content.ReadAsByteArrayAsync());
        Assert.Contains("no-store", content.Headers.CacheControl!.ToString());
        Assert.Equal("no-referrer", content.Headers.GetValues("Referrer-Policy").Single());
        Assert.Null(content.Headers.Location);
        client.DefaultRequestHeaders.Remove("X-Test-Actor");
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(url)).StatusCode);
        client.DefaultRequestHeaders.Add("X-Test-Actor", "customer");
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync(url)).StatusCode);
        Assert.Equal(1, f.Gateway.Downloads);
    }

    internal sealed class Fixture
    {
        public Actor Actor { get; } = new(); public Clock Clock { get; } = new();
        public Store Store { get; } = new(); public Access Access { get; } = new();
        public Gateway Gateway { get; } = new(); public Audit Audit { get; } = new();
        public KycMediaService Service { get; }
        public Fixture() => Service = new KycMediaService(Gateway, Store, Access, Actor, Clock,
            new EphemeralDataProtectionProvider(), Settings, Audit);
        public KycMediaAsset AddAsset(string type = "CCCD_FRONT")
        {
            var id = Guid.NewGuid(); var asset = new KycMediaAsset(id, Owner, Settings.Value.CloudName,
                $"CareSitter/Kyc/{Owner:D}/{id:N}", "png", type, Png.Length);
            Store.Assets[id] = asset; return asset;
        }
    }
    internal sealed class Actor : ICurrentUser
    {
        public Guid Id { get; set; } = Owner; public string Role { get; set; } = "CAREGIVER";
        public Guid? UserId => Id; public IReadOnlyCollection<string> Roles => [Role];
        public bool IsInRole(string role) => role == Role;
    }
    internal sealed class Clock : IClock
    { public DateTimeOffset Now { get; set; } = DateTimeOffset.Parse("2026-10-04T00:00:00Z"); public DateTimeOffset UtcNow => Now; }
    internal sealed class Store : IKycMediaStore
    {
        public Dictionary<Guid, KycMediaAsset> Assets { get; } = new();
        public Task AddAsync(KycMediaAsset asset, CancellationToken ct) { Assets.Add(asset.Id, asset); return Task.CompletedTask; }
        public Task<KycMediaAsset?> FindAsync(Guid id, CancellationToken ct) => Task.FromResult(Assets.GetValueOrDefault(id));
    }
    internal sealed class Access : IKycDocumentAccess
    { public bool Submitted { get; set; } public Task<bool> IsSubmittedAsync(Guid id, Guid owner, CancellationToken ct) => Task.FromResult(Submitted); }
    internal sealed class Gateway : IKycImageGateway
    {
        public int Uploads, Downloads; public string ResponseDelivery = "authenticated", ResponseResource = "image", ResponseFormat = "png";
        public Task<Result<KycProviderUpload>> UploadAsync(Stream stream, string key, CancellationToken ct)
        { Uploads++; return Task.FromResult(Result.Success(new KycProviderUpload(key, ResponseFormat, ResponseDelivery, ResponseResource, Png.Length))); }
        public Task<Result<KycImageContent>> DownloadAsync(KycMediaAsset asset, CancellationToken ct)
        { Downloads++; return Task.FromResult(Result.Success(new KycImageContent(Png, "image/png"))); }
    }
    internal sealed class Audit : IAuditLogger
    {
        public List<string> Actions { get; } = [];
        public Task WriteAsync(string action, string entity, Guid id, object? before, object? after, CancellationToken ct = default)
        { Actions.Add(action); return Task.CompletedTask; }
    }
    private sealed class ReplyHandler(HttpResponseMessage reply) : HttpMessageHandler
    { protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => Task.FromResult(reply); }
    private sealed class UnusedPublicMedia : IMediaService
    {
        public Task<Result<string>> CreateSignedUrlAsync(Guid id, TimeSpan ttl, CancellationToken ct) => throw new NotSupportedException();
        public Task<Result<string>> UploadImageAsync(Stream stream, string name, string folder, CancellationToken ct) => throw new NotSupportedException();
    }
    private sealed class TestAuth(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var actor = Request.Headers["X-Test-Actor"].ToString();
            if (actor is not ("owner" or "customer")) return Task.FromResult(AuthenticateResult.NoResult());
            var identity = new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, Owner.ToString()),
                new Claim(ClaimTypes.Role, actor == "owner" ? "CAREGIVER" : "CUSTOMER")], "test");
            return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity), "test")));
        }
    }
}
