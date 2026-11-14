using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using CareSitter.ApiHost.Nutrition;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Auth;
using CareSitter.Nutrition.Grpc.V1;
using Google.Protobuf;
using Google.Protobuf.WellKnownTypes;
using Grpc.Core;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.IdentityModel.Tokens;

namespace CareSitter.IntegrationTests;

public sealed class NutritionGatewayTests : IAsyncLifetime
{
    private readonly string _secret = Guid.NewGuid().ToString("N") + Guid.NewGuid().ToString("N");
    private readonly string _gateway = Guid.NewGuid().ToString("N");
    private IHost _rpcHost = null!, _apiHost = null!;
    private HttpClient _http = null!;
    private readonly RpcStub _stub = new();
    private readonly Guid _beneficiary = Guid.NewGuid();

    public async Task InitializeAsync()
    {
        _rpcHost = await new HostBuilder().ConfigureWebHost(web => web.UseKestrel(options =>
            options.Listen(IPAddress.Loopback, 0, endpoint => endpoint.Protocols = HttpProtocols.Http2))
            .ConfigureServices(services => { services.AddGrpc(); services.AddSingleton(_stub); })
            .Configure(app => { app.UseRouting(); app.UseEndpoints(endpoints => endpoints.MapGrpcService<RpcStub>()); })).StartAsync();
        var address = _rpcHost.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()!.Addresses.Single();
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Jwt:SecretKey"] = _secret, ["Jwt:Issuer"] = "fixture", ["Jwt:Audience"] = "fixture",
            ["NutritionGateway:Enabled"] = "true", ["NutritionGateway:GrpcUrl"] = address,
            ["NutritionGateway:ServiceKey"] = _gateway, ["NutritionGateway:TimeoutSeconds"] = "3"
        }).Build();
        _apiHost = await new HostBuilder().UseEnvironment("Development").ConfigureWebHost(web => web.UseTestServer().ConfigureServices(services =>
        {
            services.AddLogging(); services.AddHttpContextAccessor();
            services.AddRateLimiter(options =>
            {
                options.RejectionStatusCode = 429;
                options.AddPolicy("nutrition-knowledge", context => System.Threading.RateLimiting.RateLimitPartition.GetFixedWindowLimiter(
                    context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "unknown", _ => new()
                    { PermitLimit = 6, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
            });
            services.AddJwtAuthentication(configuration); services.AddSingleton<IAccessSessionValidator>(new Sessions());
            services.Configure<NutritionGatewayOptions>(configuration.GetSection("NutritionGateway"));
            services.Configure<NutritionKnowledgeOptions>(options =>
            {
                options.Enabled = true;
                options.LocalDemoLanAddress = "192.168.55.10";
            });
            services.AddSingleton<INutritionGateway, NutritionGrpcGateway>();
            services.AddControllers().AddApplicationPart(typeof(NutritionGatewayController).Assembly);
        }).Configure(app =>
        {
            app.Use(async (context, next) =>
            {
                context.Connection.LocalIpAddress = IPAddress.Parse("192.168.55.10");
                context.Connection.RemoteIpAddress = IPAddress.Parse("192.168.55.20");
                await next();
            });
            app.UseRouting(); app.UseAuthentication(); app.UseAuthorization(); app.UseRateLimiter(); app.UseEndpoints(endpoints => endpoints.MapControllers());
        })).StartAsync();
        _http = _apiHost.GetTestClient();
    }

    public async Task DisposeAsync() { _http.Dispose(); await _apiHost.StopAsync(); _apiHost.Dispose(); await _rpcHost.StopAsync(); _rpcHost.Dispose(); }

    [Fact]
    public async Task Gateway_connects_to_private_ca_grpc_and_rejects_an_unrelated_ca()
    {
        using var certificates = new InternalCertificateTrustTests.Certificates();
        using var certificate = certificates.Leaf();
        using var host = await new HostBuilder().ConfigureWebHost(web => web.UseKestrel(options =>
            options.Listen(IPAddress.Loopback, 0, endpoint =>
            {
                endpoint.Protocols = HttpProtocols.Http2; endpoint.UseHttps(certificate);
            })).ConfigureServices(services => { services.AddGrpc(); services.AddSingleton(_stub); })
            .Configure(app => { app.UseRouting(); app.UseEndpoints(endpoints => endpoints.MapGrpcService<RpcStub>()); })).StartAsync();
        var address = host.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()!.Addresses.Single();
        var context = new Microsoft.AspNetCore.Http.DefaultHttpContext();
        context.Request.Headers.Authorization = "Bearer fixture-token";
        var options = new NutritionGatewayOptions
        {
            Enabled = true, GrpcUrl = address, ServiceKey = _gateway,
            TrustedRootCertificatePath = certificates.RootPath, TimeoutSeconds = 3
        };
        using (var gateway = new NutritionGrpcGateway(Microsoft.Extensions.Options.Options.Create(options),
                   new Microsoft.AspNetCore.Http.HttpContextAccessor { HttpContext = context },
                   Microsoft.Extensions.Logging.Abstractions.NullLogger<NutritionGrpcGateway>.Instance))
        {
            Assert.Equal(200, (await gateway.CapabilitiesAsync(CancellationToken.None)).StatusCode);
            Assert.Equal("Bearer fixture-token", _stub.Authorization);
            Assert.Equal(_gateway, _stub.GatewayKey);
        }
        using var other = new InternalCertificateTrustTests.Certificates();
        options.TrustedRootCertificatePath = other.RootPath;
        using var rejected = new NutritionGrpcGateway(Microsoft.Extensions.Options.Options.Create(options),
            new Microsoft.AspNetCore.Http.HttpContextAccessor { HttpContext = context },
            Microsoft.Extensions.Logging.Abstractions.NullLogger<NutritionGrpcGateway>.Instance);
        Assert.Equal(503, (await rejected.CapabilitiesAsync(CancellationToken.None)).StatusCode);
        await host.StopAsync();
    }

    [Fact]
    public async Task Public_api_requires_customer_and_forwards_validated_token_gateway_key_and_deadline()
    {
        const string path = "/api/v1/nutrition/capabilities";
        Assert.Equal(HttpStatusCode.Unauthorized, (await _http.GetAsync(path)).StatusCode);
        Authenticate("CAREGIVER"); Assert.Equal(HttpStatusCode.Forbidden, (await _http.GetAsync(path)).StatusCode);
        Authenticate(); var response = await _http.GetAsync(path);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>(); Assert.True(body.GetProperty("enabled").GetBoolean());
        Assert.False(body.GetProperty("freeTextParserReady").GetBoolean());
        Assert.Equal("Chỉ mang tính tham khảo.", body.GetProperty("disclaimer").GetString());
        Assert.Equal("nutrition-reference-2026-11-10-v1", body.GetProperty("disclaimerVersion").GetString());
        Assert.Equal(_http.DefaultRequestHeaders.Authorization!.ToString(), _stub.Authorization);
        Assert.Equal(_gateway, _stub.GatewayKey);
        Assert.InRange(_stub.Deadline - DateTime.UtcNow, TimeSpan.Zero, TimeSpan.FromSeconds(3));
    }

    [Theory]
    [InlineData("192.168.55.10", false, true)]
    [InlineData("192.168.55.10", true, false)]
    [InlineData("tunnel.example", false, false)]
    public async Task Excerpts_require_a_direct_demo_lan_request(string host, bool forwarded, bool expectedDemo)
    {
        Authenticate();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/nutrition/knowledge?q=fiber");
        request.Headers.Host = host;
        if (forwarded) request.Headers.Add("X-Forwarded-For", "203.0.113.10");
        using var response = await _http.SendAsync(request);
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<NutritionKnowledgeSearchResponse>();

        Assert.NotNull(result);
        Assert.Equal(expectedDemo, _stub.KnowledgeRequest?.LocalDemo);
        Assert.Equal(expectedDemo, result.LocalDemo);
        Assert.Equal(expectedDemo ? "demo" : null, result.AnswerChunkId);
        Assert.Equal(expectedDemo ? new[] { "demo" } : [], result.AnswerChunkIds);
        Assert.Equal(expectedDemo ? "answered" : null, result.AnswerStatus);
        Assert.Equal(expectedDemo ? "Gemini" : null, result.AnswerProvider);
        Assert.Equal(expectedDemo ? 1 : 0, result.AnswerBlocks?.Count);
        Assert.Equal(expectedDemo ? "Fixture source passage." : null, Assert.Single(result.Results).Excerpt);
        Assert.True(response.Headers.CacheControl?.NoStore);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Online_general_knowledge_is_explicit_and_never_exposes_corpus(bool forgedCitation)
    {
        _apiHost.Services.GetRequiredService<Microsoft.Extensions.Options.IOptions<NutritionKnowledgeOptions>>()
            .Value.GeneralKnowledgeEnabled = true;
        _stub.ForgeGeneralCitation = forgedCitation;
        Authenticate();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/nutrition/knowledge?q=fiber");
        request.Headers.Host = "customer.example";
        request.Headers.Add("X-Forwarded-For", "203.0.113.10");
        using var response = await _http.SendAsync(request);
        Assert.True(_stub.KnowledgeRequest?.GeneralKnowledge);
        Assert.False(_stub.KnowledgeRequest?.LocalDemo);
        if (forgedCitation)
        {
            Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
            Assert.DoesNotContain("General nutrition answer.", await response.Content.ReadAsStringAsync());
            return;
        }
        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("generalKnowledge").GetBoolean());
        Assert.False(body.GetProperty("localDemo").GetBoolean());
        Assert.Empty(body.GetProperty("results").EnumerateArray());
        Assert.Empty(body.GetProperty("answerChunkIds").EnumerateArray());
        Assert.Equal("ai_suggestion", body.GetProperty("answerStatus").GetString());
        Assert.Equal("General nutrition answer.", body.GetProperty("answerBlocks")[0].GetProperty("text").GetString());
        Assert.True(response.Headers.CacheControl?.NoStore);
    }

    [Fact]
    public async Task Knowledge_has_a_per_customer_budget_and_a_clear_disabled_response()
    {
        Authenticate();
        _apiHost.Services.GetRequiredService<Microsoft.Extensions.Options.IOptions<NutritionKnowledgeOptions>>()
            .Value.Enabled = false;
        for (var index = 0; index < 6; index++)
        {
            var response = await _http.GetAsync("/api/v1/nutrition/knowledge?q=fiber");
            Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
            Assert.Contains("NUTRITION_KNOWLEDGE_UNAVAILABLE", await response.Content.ReadAsStringAsync());
        }
        Assert.Equal(HttpStatusCode.TooManyRequests,
            (await _http.GetAsync("/api/v1/nutrition/knowledge?q=fiber")).StatusCode);
        Assert.Null(_stub.KnowledgeRequest);
    }

    [Theory]
    [InlineData(false, false)]
    [InlineData(true, false)]
    [InlineData(false, true)]
    public async Task Knowledge_suggestions_are_uncited_and_local_only(bool forwarded, bool forgedCitation)
    {
        Authenticate();
        _stub.AnswerStatus = "ai_suggestion";
        _stub.AnswerIds = [];
        _stub.BlockIds = forgedCitation ? ["demo"] : [];
        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/nutrition/knowledge?q=fiber");
        request.Headers.Host = "192.168.55.10";
        if (forwarded) request.Headers.Add("X-Forwarded-For", "203.0.113.10");
        using var response = await _http.SendAsync(request);
        if (forgedCitation)
        {
            Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
            return;
        }
        response.EnsureSuccessStatusCode();
        var body = (await response.Content.ReadFromJsonAsync<NutritionKnowledgeSearchResponse>())!;
        Assert.Empty(body.AnswerChunkIds!);
        Assert.Equal(forwarded ? null : "ai_suggestion", body.AnswerStatus);
        Assert.Equal(forwarded ? 0 : 1, body.AnswerBlocks!.Count);
        if (!forwarded) Assert.Empty(Assert.Single(body.AnswerBlocks).ChunkIds);
    }

    [Fact]
    public async Task Knowledge_preserves_five_sources_and_their_generated_answer_block()
    {
        Authenticate();
        _stub.KnowledgeSources = 5;
        _stub.AnswerIds = _stub.BlockIds = ["demo", "demo2", "demo3", "demo4", "demo5"];
        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/nutrition/knowledge?q=fiber");
        request.Headers.Host = "192.168.55.10";
        using var response = await _http.SendAsync(request);
        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<NutritionKnowledgeSearchResponse>();
        Assert.Equal(5, body!.AnswerChunkIds!.Count);
        Assert.Equal(_stub.BlockIds, Assert.Single(body.AnswerBlocks!).ChunkIds);
        Assert.Equal("Gemini generated fixture answer.", Assert.Single(body.AnswerBlocks!).Text);
    }

    [Theory]
    [InlineData("missing")]
    [InlineData("demo,demo")]
    public async Task Knowledge_rejects_generated_paragraphs_with_invalid_source_binding(string ids)
    {
        Authenticate();
        _stub.BlockIds = ids.Split(',');
        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/nutrition/knowledge?q=fiber");
        request.Headers.Host = "192.168.55.10";
        using var response = await _http.SendAsync(request);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.DoesNotContain("Gemini generated fixture answer.", await response.Content.ReadAsStringAsync());
    }

    [Theory]
    [InlineData("missing")]
    [InlineData("demo,demo")]
    public async Task Knowledge_rejects_invalid_citations_from_internal_service(string ids)
    {
        Authenticate();
        _stub.AnswerIds = ids.Split(',');
        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/nutrition/knowledge?q=fiber");
        request.Headers.Host = "192.168.55.10";
        using var response = await _http.SendAsync(request);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.DoesNotContain("Fixture source passage.", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Assessment_preserves_idempotency_revision_and_public_polling_url()
    {
        Authenticate(); var key = Guid.NewGuid();
        var response = await _http.PostAsJsonAsync($"/api/v1/beneficiaries/{_beneficiary}/nutrition-assessments",
            new { expectedHealthRevision = 7, idempotencyKey = key, plannedDate = "2026-10-12" });
        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        Assert.Equal(CommandOperation.Assess, _stub.Command!.Operation);
        Assert.Equal(key.ToString(), _stub.Command.IdempotencyKey); Assert.Equal(7, _stub.Command.ExpectedHealthRevision);
        Assert.Equal("2026-10-12", _stub.Command.PlannedDate); Assert.False(_stub.Command.HasAssessmentId);
        Assert.Equal($"/api/v1/beneficiaries/{_beneficiary}/nutrition-assessments/{_stub.ResourceId}", response.Headers.Location!.OriginalString);
        var data = await response.Content.ReadFromJsonAsync<JsonElement>(); Assert.Equal("queued", data.GetProperty("status").GetString());
        Assert.Equal(_beneficiary.ToString(), data.GetProperty("beneficiaryId").GetString());
        Assert.Equal(12.34m, data.GetProperty("data").GetProperty("exactNumber").GetDecimal());
    }

    [Fact]
    public async Task Meal_recommendation_trace_fields_pass_through_with_existing_casing()
    {
        Authenticate();
        _stub.DataJson = """
            {"recommendationTrace":{"releaseStatus":"reference","retrievalStrategy":"keyword","graphRole":"explanation",
            "citations":[{"title":"Sách","chapter":"Chương 1","heading":"Mục","pages":"12","graphPath":[{"nodeId":"topic:1","heading":"Mục","pages":[12]}]}],
            "disclaimer":"Chỉ mang tính tham khảo.","disclaimerVersion":"nutrition-reference-2026-11-10-v1"}}
            """;
        try
        {
            var response = await _http.PostAsJsonAsync($"/api/v1/beneficiaries/{_beneficiary}/meal-recommendations",
                new { expectedHealthRevision = 7, idempotencyKey = Guid.NewGuid(), assessmentId = Guid.NewGuid() });
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var trace = (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("data").GetProperty("recommendationTrace");
            Assert.Equal("reference", trace.GetProperty("releaseStatus").GetString());
            Assert.Equal("explanation", trace.GetProperty("graphRole").GetString());
            Assert.Equal("topic:1", trace.GetProperty("citations")[0].GetProperty("graphPath")[0].GetProperty("nodeId").GetString());
            Assert.Equal("nutrition-reference-2026-11-10-v1", trace.GetProperty("disclaimerVersion").GetString());
        }
        finally { _stub.DataJson = "{\"exactNumber\":12.34}"; }
    }

    [Theory]
    [InlineData("nutrition-assessments", 202)]
    [InlineData("nutrition-assessments/{id}/confirm", 200)]
    [InlineData("meal-recommendations", 200)]
    [InlineData("meal-recommendations/{id}/replacements", 200)]
    [InlineData("meal-plans", 200)]
    public async Task Committed_stale_write_preserves_status_identity_and_original_revision(string route, int status)
    {
        Authenticate(); _stub.ResourceStatus = "stale";
        var response = await _http.PostAsJsonAsync($"/api/v1/beneficiaries/{_beneficiary}/{route.Replace("{id}", Guid.NewGuid().ToString())}",
            new { expectedHealthRevision = 7, idempotencyKey = Guid.NewGuid() });
        Assert.Equal(status, (int)response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("stale", body.GetProperty("status").GetString());
        Assert.Equal(_stub.ResourceId.ToString(), body.GetProperty("id").GetString());
        Assert.Equal(7, body.GetProperty("healthRevision").GetInt64());
    }

    [Theory]
    [InlineData(FailureKind.NotFound, 404)]
    [InlineData(FailureKind.Conflict, 409)]
    [InlineData(FailureKind.RateLimited, 429)]
    [InlineData(FailureKind.Unavailable, 503)]
    public async Task Business_failure_retains_semantic_code_without_returning_resource(FailureKind kind, int status)
    {
        Authenticate(); _stub.Failure = new Failure { Kind = kind, Code = "nutrition.test_error", Message = "Cần thử lại." };
        var response = await _http.GetAsync($"/api/v1/beneficiaries/{_beneficiary}/nutrition-assessments/{Guid.NewGuid()}");
        Assert.Equal(status, (int)response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>(); Assert.Equal("nutrition.test_error", body.GetProperty("title").GetString());
        Assert.False(body.TryGetProperty("data", out _));
    }

    [Fact]
    public async Task Invalid_response_or_wrong_beneficiary_is_unavailable_without_leaking_payload()
    {
        Authenticate(); _stub.BeneficiaryOverride = Guid.NewGuid().ToString();
        var path = $"/api/v1/beneficiaries/{_beneficiary}/nutrition-assessments/{Guid.NewGuid()}";
        var response = await _http.GetAsync(path); Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.DoesNotContain("exactNumber", await response.Content.ReadAsStringAsync());
        _stub.BeneficiaryOverride = null; _stub.DataJson = "invalid-json";
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await _http.GetAsync(path)).StatusCode);
    }

    [Theory]
    [InlineData(StatusCode.Unauthenticated, "nutrition.gateway_unauthorized", 503)]
    [InlineData(StatusCode.Unauthenticated, "revoked", 401)]
    [InlineData(StatusCode.Unavailable, "dependency", 503)]
    [InlineData(StatusCode.ResourceExhausted, "quota", 429)]
    public async Task Transport_errors_distinguish_session_revocation_from_gateway_configuration(StatusCode code, string detail, int status)
    {
        Authenticate(); _stub.TransportError = new Status(code, detail);
        var response = await _http.GetAsync("/api/v1/nutrition/capabilities"); Assert.Equal(status, (int)response.StatusCode);
    }

    [Fact]
    public async Task Cancelled_public_request_cancels_the_rpc()
    {
        Authenticate(); _stub.Block = true;
        using var cancellation = new CancellationTokenSource();
        var request = _http.GetAsync("/api/v1/nutrition/capabilities", cancellation.Token);
        await _stub.Started.Task.WaitAsync(TimeSpan.FromSeconds(3)); cancellation.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => request);
        await _stub.Cancelled.Task.WaitAsync(TimeSpan.FromSeconds(3));
    }

    [Theory]
    [InlineData("nutrition-assessments", CommandOperation.Assess)]
    [InlineData("nutrition-assessments/{id}/confirm", CommandOperation.Confirm)]
    [InlineData("meal-recommendations", CommandOperation.Recommend)]
    [InlineData("meal-recommendations/{id}/replacements", CommandOperation.Replace)]
    [InlineData("meal-plans", CommandOperation.Save)]
    public async Task Public_writes_preserve_resource_ids_and_nullable_contract_fields(string route, CommandOperation operation)
    {
        Authenticate(); var id = Guid.NewGuid(); var assessment = Guid.NewGuid(); var recipe = Guid.NewGuid();
        var response = await _http.PostAsJsonAsync($"/api/v1/beneficiaries/{_beneficiary}/{route.Replace("{id}", id.ToString())}",
            new { expectedHealthRevision = 7, idempotencyKey = Guid.NewGuid(), assessmentId = assessment,
                recommendationId = id, recipeVersionId = recipe, mealType = "breakfast" });
        Assert.Equal(operation == CommandOperation.Assess ? 202 : 200, (int)response.StatusCode);
        Assert.Equal(operation, _stub.Command!.Operation); Assert.Equal(assessment.ToString(), _stub.Command.AssessmentId);
        Assert.Equal(recipe.ToString(), _stub.Command.RecipeVersionId); Assert.Equal("breakfast", _stub.Command.MealType);
        Assert.False(_stub.Command.HasPlannedDate);
        if (operation is CommandOperation.Confirm or CommandOperation.Replace or CommandOperation.Save) Assert.Equal(id.ToString(), _stub.Command.ResourceId);
        else Assert.False(_stub.Command.HasResourceId);
    }

    [Theory]
    [InlineData("nutrition-assessments", ResourceKind.Assessment)]
    [InlineData("meal-recommendations", ResourceKind.Recommendation)]
    [InlineData("meal-plans", ResourceKind.Plan)]
    public async Task Public_reads_preserve_resource_kind_and_scope(string route, ResourceKind kind)
    {
        Authenticate(); var id = Guid.NewGuid();
        Assert.Equal(HttpStatusCode.OK, (await _http.GetAsync($"/api/v1/beneficiaries/{_beneficiary}/{route}/{id}")).StatusCode);
        Assert.Equal(kind, _stub.Query!.Kind); Assert.Equal(id.ToString(), _stub.Query.ResourceId);
        Assert.Equal(_beneficiary.ToString(), _stub.Query.BeneficiaryId);
    }

    [Fact]
    public async Task Public_lists_return_arrays_and_keep_the_beneficiary_scope()
    {
        Authenticate();
        var plans = await _http.GetAsync($"/api/v1/beneficiaries/{_beneficiary}/meal-plans");
        Assert.Equal(HttpStatusCode.OK, plans.StatusCode);
        Assert.Equal(JsonValueKind.Array, (await plans.Content.ReadFromJsonAsync<JsonElement>()).ValueKind);
        var replacements = await _http.GetAsync($"/api/v1/beneficiaries/{_beneficiary}/meal-recommendations/{Guid.NewGuid()}/replacement-options?mealType=breakfast");
        Assert.Equal(HttpStatusCode.OK, replacements.StatusCode);
        Assert.Equal("breakfast", _stub.MealType); Assert.Equal(_beneficiary.ToString(), _stub.ListBeneficiary);
        Assert.Equal(JsonValueKind.Array, (await replacements.Content.ReadFromJsonAsync<JsonElement>()).ValueKind);
    }

    [Fact]
    public async Task Deadline_returns_unavailable_and_cancels_the_upstream_request()
    {
        Authenticate(); _stub.Block = true;
        var response = await _http.GetAsync("/api/v1/nutrition/capabilities");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        await _stub.Cancelled.Task.WaitAsync(TimeSpan.FromSeconds(3));
    }

    [Theory]
    [InlineData("http://nutrition:8081/", false, false)]
    [InlineData("http://localhost:5036/", true, true)]
    [InlineData("https://nutrition.example/", false, true)]
    [InlineData("https://nutrition.example/with-path", false, false)]
    [InlineData("https://nutrition.example/?secret=bad", false, false)]
    public void Gateway_configuration_requires_a_safe_root_endpoint(string url, bool development, bool expected)
    {
        var options = new NutritionGatewayOptions { Enabled = true, GrpcUrl = url, ServiceKey = _gateway };
        Assert.Equal(expected, options.IsValid(development));
        options.TimeoutSeconds = 31; Assert.False(options.IsValid(development));
        options.TimeoutSeconds = 15; options.ServiceKey = ""; Assert.False(options.IsValid(development));
    }

    private void Authenticate(string role = "CUSTOMER")
    {
        var token = new JwtSecurityToken("fixture", "fixture",
            [new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()), new Claim(ClaimTypes.Role, role),
             new Claim("sid", Guid.NewGuid().ToString()), new Claim("jti", Guid.NewGuid().ToString())],
            expires: DateTime.UtcNow.AddMinutes(5), signingCredentials:
            new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_secret)), SecurityAlgorithms.HmacSha256));
        _http.DefaultRequestHeaders.Authorization = new("Bearer", new JwtSecurityTokenHandler().WriteToken(token));
    }
    [Fact]
    public async Task Week_start_is_forwarded_to_the_meal_plan_rpc()
    {
        Authenticate("CUSTOMER");
        using var response = await _http.GetAsync($"/api/v1/beneficiaries/{_beneficiary}/meal-plans?weekStart=2027-01-03");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("2027-01-03", _stub.WeekStart);
    }

    private sealed class Sessions : IAccessSessionValidator
    {
        public Task<bool> IsActiveAsync(Guid user, Guid session, CancellationToken ct = default) => Task.FromResult(true);
    }

    [BindServiceMethod(typeof(RpcStub), nameof(BindService))]
    public class RpcStub
    {
        public Guid ResourceId { get; } = Guid.NewGuid();
        public string? Authorization, GatewayKey, BeneficiaryOverride;
        public DateTime Deadline;
        public CommandRequest? Command;
        public ResourceRequest? Query;
        public KnowledgeSearchRequest? KnowledgeRequest;
        public string[] AnswerIds = ["demo"];
        public string[] BlockIds = ["demo"];
        public int KnowledgeSources = 1;
        public string AnswerStatus = "answered";
        public bool ForgeGeneralCitation;
        public string? ListBeneficiary, MealType, WeekStart;
        public Failure? Failure;
        public Status? TransportError;
        public string ResourceStatus = "queued";
        public string DataJson = "{\"exactNumber\":12.34}";
        public bool Block;
        public TaskCompletionSource Started { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource Cancelled { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public static void BindService(ServiceBinderBase binder, RpcStub? service)
        {
            binder.AddMethod(Method("GetCapabilities", Empty.Parser, CapabilitiesResponse.Parser), service is null ? null : service.GetCapabilities);
            binder.AddMethod(Method("Execute", CommandRequest.Parser, ResourceResult.Parser), service is null ? null : service.Execute);
            binder.AddMethod(Method("GetResource", ResourceRequest.Parser, ResourceResult.Parser), service is null ? null : service.GetResource);
            binder.AddMethod(Method("ListMealPlans", BeneficiaryRequest.Parser, ResourceListResult.Parser), service is null ? null : service.ListMealPlans);
            binder.AddMethod(Method("GetReplacementOptions", ReplacementOptionsRequest.Parser, RecipeListResult.Parser), service is null ? null : service.GetReplacementOptions);
            binder.AddMethod(Method("SearchKnowledge", KnowledgeSearchRequest.Parser, KnowledgeSearchResponse.Parser), service is null ? null : service.SearchKnowledge);
        }
        private static Method<TRequest, TResponse> Method<TRequest, TResponse>(string name, MessageParser<TRequest> input, MessageParser<TResponse> output)
            where TRequest : class, IMessage<TRequest> where TResponse : class, IMessage<TResponse> =>
            new(MethodType.Unary, "caresitter.nutrition.v1.NutritionRpc", name,
                Marshallers.Create<TRequest>(value => value.ToByteArray(), value => input.ParseFrom(value)),
                Marshallers.Create<TResponse>(value => value.ToByteArray(), value => output.ParseFrom(value)));

        private async Task ObserveAsync(ServerCallContext context)
        {
            Authorization = context.RequestHeaders.GetValue("authorization"); GatewayKey = context.RequestHeaders.GetValue("x-nutrition-gateway-key");
            Deadline = context.Deadline; Started.TrySetResult();
            if (TransportError.HasValue) throw new RpcException(TransportError.Value);
            if (Block)
            {
                try { await Task.Delay(Timeout.InfiniteTimeSpan, context.CancellationToken); }
                catch (OperationCanceledException) { Cancelled.TrySetResult(); throw; }
            }
        }
        public virtual async Task<CapabilitiesResponse> GetCapabilities(Empty request, ServerCallContext context)
        { await ObserveAsync(context); return new() { Enabled = true, AssessmentsEnabled = true, RecommendationsEnabled = true,
            Disclaimer = "Chỉ mang tính tham khảo.", DisclaimerVersion = "nutrition-reference-2026-11-10-v1" }; }
        public virtual async Task<ResourceResult> Execute(CommandRequest request, ServerCallContext context)
        { await ObserveAsync(context); Command = request; return Result(request.BeneficiaryId); }
        public virtual async Task<ResourceResult> GetResource(ResourceRequest request, ServerCallContext context)
        { await ObserveAsync(context); Query = request; return Result(request.BeneficiaryId); }
        public virtual async Task<ResourceListResult> ListMealPlans(BeneficiaryRequest request, ServerCallContext context)
        {
            await ObserveAsync(context); ListBeneficiary = request.BeneficiaryId;
            WeekStart = request.HasWeekStart ? request.WeekStart : null;
            var list = new ResourceList(); list.Resources.Add(Result(request.BeneficiaryId).Resource);
            return new() { Items = list };
        }
        public virtual async Task<RecipeListResult> GetReplacementOptions(ReplacementOptionsRequest request, ServerCallContext context)
        {
            await ObserveAsync(context); ListBeneficiary = request.BeneficiaryId; MealType = request.MealType;
            var list = new RecipeList(); list.Recipes.Add(new RecipeOption { DataJson = "{\"name\":\"Recipe\"}" });
            return new() { Items = list };
        }
        public virtual async Task<KnowledgeSearchResponse> SearchKnowledge(KnowledgeSearchRequest request, ServerCallContext context)
        {
            await ObserveAsync(context);
            KnowledgeRequest = request;
            if (request.GeneralKnowledge)
            {
                var general = new KnowledgeSearchResponse { Query = request.Query, GeneralKnowledge = true,
                    AnswerStatus = "ai_suggestion", AnswerProvider = "Gemini" };
                var answer = new KnowledgeAnswerBlock { Text = "General nutrition answer." };
                if (ForgeGeneralCitation) answer.ChunkIds.Add("private-book");
                general.AnswerBlocks.Add(answer);
                return general;
            }
            var result = new KnowledgeSearchResponse { Query = request.Query, LocalDemo = true, AnswerChunkId = AnswerStatus == "ai_suggestion" ? "" : "demo",
                AnswerStatus = AnswerStatus, AnswerProvider = "Gemini" };
            result.AnswerChunkIds.AddRange(AnswerIds);
            for (var index = 1; index <= KnowledgeSources; index++)
                result.Results.Add(new KnowledgeHit { ChunkId = index == 1 ? "demo" : $"demo{index}", Heading = "Fixture",
                    SourceTitle = "Test", PdfPage = index + 3, SourceRevisionId = "v1", Excerpt = "Fixture source passage." });
            var block = new KnowledgeAnswerBlock { Text = "Gemini generated fixture answer." };
            block.ChunkIds.AddRange(BlockIds);
            result.AnswerBlocks.Add(block);
            return result;
        }

        private ResourceResult Result(string beneficiary) => Failure is not null ? new() { Failure = Failure } : new()
        {
            Resource = new Resource { Id = ResourceId.ToString(), BeneficiaryId = BeneficiaryOverride ?? beneficiary,
                HealthRevision = 7, Status = ResourceStatus, DataJson = DataJson, CreatedAt = Timestamp.FromDateTime(DateTime.UtcNow) }
        };
    }
}
