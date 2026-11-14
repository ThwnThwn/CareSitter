using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Net.Http.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Grpc.V1;
using CareSitter.Nutrition.Infrastructure;
using Google.Protobuf.WellKnownTypes;
using Grpc.Core;
using Grpc.Net.Client;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.IdentityModel.Tokens;

namespace CareSitter.Nutrition.Tests;

public sealed class GrpcTransportTests
{
    [Fact]
    public async Task Online_book_reference_returns_generated_answer_with_exact_passage_and_page()
    {
        await using var fixture = new Fixture(generalKnowledge: true, reference: true);
        var response = await fixture.Client.SearchKnowledgeAsync(new KnowledgeSearchRequest
            { Query = "What is fiber?", GeneralKnowledge = true }, fixture.Headers());
        Assert.True(response.ReferenceKnowledge);
        Assert.False(response.GeneralKnowledge); Assert.False(response.LocalDemo);
        Assert.Equal("answered", response.AnswerStatus);
        Assert.Equal("book-passage", Assert.Single(response.AnswerChunkIds));
        var source = Assert.Single(response.Results);
        Assert.Equal(42, source.PdfPage); Assert.Equal("41", source.PrintedPage);
        Assert.Equal("This is a synthetic book passage.", source.Excerpt);
        Assert.Single(response.AnswerBlocks);
        Assert.Equal(Guid.Empty, fixture.People.LastOwner);
    }

    [Theory]
    [InlineData(true, true)]
    [InlineData(true, false)]
    [InlineData(false, true)]
    public async Task General_knowledge_needs_explicit_enablement_and_consent_without_reading_health_or_books(
        bool enabled, bool approved)
    {
        await using var fixture = new Fixture(enabled, approved);
        var call = fixture.Client.SearchKnowledgeAsync(new KnowledgeSearchRequest
            { Query = "What is fiber?", GeneralKnowledge = true }, fixture.Headers()).ResponseAsync;
        if (!enabled)
        {
            await AssertRpcAsync(StatusCode.Unavailable, () => call);
            Assert.Equal(0, fixture.Ai.Calls);
            return;
        }
        var response = await call;
        Assert.True(response.GeneralKnowledge);
        Assert.False(response.LocalDemo);
        Assert.Empty(response.Results);
        Assert.Empty(response.AnswerChunkIds);
        Assert.Equal(approved ? "ai_suggestion" : "not_configured", response.AnswerStatus);
        Assert.Equal(approved ? 1 : 0, response.AnswerBlocks.Count);
        Assert.Equal(approved ? 1 : 0, fixture.Ai.Calls);
        Assert.Equal(Guid.Empty, fixture.People.LastOwner);
    }

    [Fact]
    public async Task Gateway_key_and_durable_customer_session_are_both_required()
    {
        await using var fixture = new Fixture();
        var client = fixture.Client;
        await AssertRpcAsync(StatusCode.Unauthenticated, () => client.GetCapabilitiesAsync(new Empty()).ResponseAsync);
        await AssertRpcAsync(StatusCode.Unauthenticated, () => client.GetCapabilitiesAsync(new Empty(), fixture.Headers(token: false)).ResponseAsync);
        await AssertRpcAsync(StatusCode.PermissionDenied, () => client.GetCapabilitiesAsync(new Empty(), fixture.Headers(role: "CAREGIVER")).ResponseAsync);
        var response = await client.GetCapabilitiesAsync(new Empty(), fixture.Headers());
        Assert.True(response.Enabled);
        Assert.Equal(NutritionDisclaimer.Reference, response.Disclaimer);
        Assert.Equal(NutritionDisclaimer.ReferenceVersion, response.DisclaimerVersion);
        fixture.Identity.Active = false;
        await AssertRpcAsync(StatusCode.Unauthenticated, () => client.GetCapabilitiesAsync(new Empty(), fixture.Headers()).ResponseAsync);
        fixture.Identity.Unavailable = true;
        await AssertRpcAsync(StatusCode.Unavailable, () => client.GetCapabilitiesAsync(new Empty(), fixture.Headers()).ResponseAsync);
    }

    [Fact]
    public async Task Grpc_validates_contract_and_checks_profile_owner_before_returning_any_content()
    {
        await using var fixture = new Fixture();
        var request = new CommandRequest
        {
            Operation = CommandOperation.Assess, BeneficiaryId = Guid.NewGuid().ToString(),
            IdempotencyKey = Guid.NewGuid().ToString(), ExpectedHealthRevision = 7
        };
        var result = await fixture.Client.ExecuteAsync(request, fixture.Headers());
        Assert.Equal(FailureKind.NotFound, result.Failure.Kind);
        Assert.Equal(fixture.Owner, fixture.People.LastOwner);
        Assert.Equal(Guid.Parse(request.BeneficiaryId), fixture.People.LastBeneficiary);
        Assert.Null(result.Resource);
        request.Operation = (CommandOperation)100;
        await AssertRpcAsync(StatusCode.InvalidArgument, () => fixture.Client.ExecuteAsync(request, fixture.Headers()).ResponseAsync);
        request.Operation = CommandOperation.Assess;
        request.PlannedDate = "2026-02-31";
        await AssertRpcAsync(StatusCode.InvalidArgument, () => fixture.Client.ExecuteAsync(request, fixture.Headers()).ResponseAsync);
        request.ClearPlannedDate(); request.BeneficiaryId = "not-a-guid";
        await AssertRpcAsync(StatusCode.InvalidArgument, () => fixture.Client.ExecuteAsync(request, fixture.Headers()).ResponseAsync);
    }

    [Fact]
    public async Task Profile_dependency_failure_is_unavailable_and_never_becomes_a_healthy_profile()
    {
        await using var fixture = new Fixture();
        fixture.People.Unavailable = true;
        await AssertRpcAsync(StatusCode.Unavailable, () => fixture.Client.GetResourceAsync(new ResourceRequest
        {
            Kind = ResourceKind.Assessment, BeneficiaryId = Guid.NewGuid().ToString(), ResourceId = Guid.NewGuid().ToString()
        }, fixture.Headers()).ResponseAsync);
    }

    private static async Task AssertRpcAsync(StatusCode code, Func<Task> call) =>
        Assert.Equal(code, (await Assert.ThrowsAsync<RpcException>(call)).StatusCode);

    private sealed class Fixture : IAsyncDisposable
    {
        public Guid Owner { get; } = Guid.NewGuid();
        private readonly string _secret = Guid.NewGuid().ToString("N") + Guid.NewGuid().ToString("N");
        private readonly string _gateway = Guid.NewGuid().ToString("N");
        private readonly WebApplicationFactory<Program> _factory;
        private readonly GrpcChannel _channel;
        public Identity Identity { get; } = new();
        public People People { get; } = new();
        public NutritionRpc.NutritionRpcClient Client { get; }
        public AiHandler Ai { get; } = new();
        public Fixture(bool generalKnowledge = false, bool approved = true, bool reference = false)
        {
            _factory = new WebApplicationFactory<Program>().WithWebHostBuilder(web =>
            {
                web.UseSetting("Jwt:SecretKey", _secret); web.UseSetting("Jwt:Issuer", "fixture"); web.UseSetting("Jwt:Audience", "fixture");
                web.UseSetting("Gateway:ServiceKey", _gateway);
                web.UseSetting("People:BaseUrl", "https://people.example.test/"); web.UseSetting("People:ServiceKey", Guid.NewGuid().ToString("N"));
                web.UseSetting("ConnectionStrings:Nutrition", "Host=127.0.0.1;Port=1;Database=unused;Username=unused");
                web.UseSetting("Nutrition:Enabled", "true"); web.UseSetting("Nutrition:AssessmentsEnabled", "true");
                web.UseSetting("MealGrounding:Enabled", "false");
                web.UseSetting("NutritionKnowledgeAi:Enabled", approved.ToString());
                web.UseSetting("NutritionKnowledgeAi:GeneralKnowledgeEnabled", generalKnowledge.ToString());
                web.UseSetting("NutritionKnowledgeAi:DataProcessingApproved", approved.ToString());
                web.UseSetting("NutritionKnowledgeAi:ApiKey", "fixture-key");
                web.ConfigureServices(services =>
                {
                    services.RemoveAll<IIdentitySessionClient>(); services.AddSingleton<IIdentitySessionClient>(Identity);
                    services.RemoveAll<IPeopleHealthClient>(); services.AddSingleton<IPeopleHealthClient>(People);
                    services.AddHttpClient<GeminiKnowledgeAnswer>().ConfigurePrimaryHttpMessageHandler(() => Ai);
                    if (reference)
                    {
                        services.RemoveAll<INutritionReferenceLibrary>();
                        services.AddSingleton<INutritionReferenceLibrary>(new ReferenceFixture());
                    }
                });
            });
            _channel = GrpcChannel.ForAddress("http://localhost", new GrpcChannelOptions { HttpHandler = _factory.Server.CreateHandler() });
            Client = new NutritionRpc.NutritionRpcClient(_channel);
        }
        public Metadata Headers(string role = "CUSTOMER", bool token = true)
        {
            var headers = new Metadata { { "x-nutrition-gateway-key", _gateway } };
            if (token)
            {
                var jwt = new JwtSecurityToken("fixture", "fixture",
                    [new Claim(ClaimTypes.NameIdentifier, Owner.ToString()), new Claim(ClaimTypes.Role, role),
                     new Claim("sid", Guid.NewGuid().ToString()), new Claim("jti", Guid.NewGuid().ToString())],
                    expires: DateTime.UtcNow.AddMinutes(5), signingCredentials:
                    new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_secret)), SecurityAlgorithms.HmacSha256));
                headers.Add("authorization", "Bearer " + new JwtSecurityTokenHandler().WriteToken(jwt));
            }
            return headers;
        }
        public async ValueTask DisposeAsync() { _channel.Dispose(); await _factory.DisposeAsync(); }
    }
    private sealed class AiHandler : HttpMessageHandler
    {
        public int Calls;
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Calls++;
            using var body = System.Text.Json.JsonDocument.Parse(await request.Content!.ReadAsStringAsync(ct));
            using var input = System.Text.Json.JsonDocument.Parse(body.RootElement.GetProperty("contents")[0]
                .GetProperty("parts")[0].GetProperty("text").GetString()!);
            var output = input.RootElement.GetProperty("sources").GetArrayLength() > 0
                ? """{"status":"answered","blocks":[{"text":"Synthetic answer from the supplied book passage.","evidence":[{"index":1,"quote":"This is a synthetic book passage."}]}]}"""
                : """{"status":"ai_suggestion","blocks":[{"text":"General nutrition fixture answer.","evidence":[]}]}""";
            return new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = JsonContent.Create(new { candidates = new[] { new { finishReason = "STOP",
                    content = new { parts = new[] { new { text = output } } } } } })
            };
        }
    }
    private sealed class ReferenceFixture : INutritionReferenceLibrary
    {
        public Task<IReadOnlyList<KnowledgeSearchHit>?> FindAsync(string query, CancellationToken ct) =>
            Task.FromResult<IReadOnlyList<KnowledgeSearchHit>?>([new("book-passage", "Fixture section", 42, "41",
                "Synthetic book", "synthetic-r1", "This is a synthetic book passage.")]);
    }
    private sealed class Identity : IIdentitySessionClient
    {
        public bool Active = true, Unavailable;
        public Task<bool> IsActiveAsync(string token, CancellationToken ct) => Unavailable ? throw new HttpRequestException() : Task.FromResult(Active);
    }
    private sealed class People : IPeopleHealthClient
    {
        public bool Unavailable;
        public Guid LastOwner, LastBeneficiary;
        public Task<BeneficiaryHealthSnapshot?> ReadAsync(Guid owner, Guid beneficiary, CancellationToken ct)
        {
            LastOwner = owner; LastBeneficiary = beneficiary;
            return Unavailable ? throw new HttpRequestException() : Task.FromResult<BeneficiaryHealthSnapshot?>(null);
        }
    }
}
