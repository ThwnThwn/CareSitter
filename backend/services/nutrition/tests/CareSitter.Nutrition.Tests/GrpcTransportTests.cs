using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Grpc.V1;
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
    public async Task Gateway_key_and_durable_customer_session_are_both_required()
    {
        await using var fixture = new Fixture();
        var client = fixture.Client;
        await AssertRpcAsync(StatusCode.Unauthenticated, () => client.GetCapabilitiesAsync(new Empty()).ResponseAsync);
        await AssertRpcAsync(StatusCode.Unauthenticated, () => client.GetCapabilitiesAsync(new Empty(), fixture.Headers(token: false)).ResponseAsync);
        await AssertRpcAsync(StatusCode.PermissionDenied, () => client.GetCapabilitiesAsync(new Empty(), fixture.Headers(role: "CAREGIVER")).ResponseAsync);
        var response = await client.GetCapabilitiesAsync(new Empty(), fixture.Headers());
        Assert.True(response.Enabled);
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
        public Fixture()
        {
            _factory = new WebApplicationFactory<Program>().WithWebHostBuilder(web =>
            {
                web.UseSetting("Jwt:SecretKey", _secret); web.UseSetting("Jwt:Issuer", "fixture"); web.UseSetting("Jwt:Audience", "fixture");
                web.UseSetting("Gateway:ServiceKey", _gateway);
                web.UseSetting("People:BaseUrl", "https://people.example.test/"); web.UseSetting("People:ServiceKey", Guid.NewGuid().ToString("N"));
                web.UseSetting("ConnectionStrings:Nutrition", "Host=127.0.0.1;Port=1;Database=unused;Username=unused");
                web.UseSetting("Nutrition:Enabled", "true"); web.UseSetting("Nutrition:AssessmentsEnabled", "true");
                web.ConfigureServices(services =>
                {
                    services.RemoveAll<IIdentitySessionClient>(); services.AddSingleton<IIdentitySessionClient>(Identity);
                    services.RemoveAll<IPeopleHealthClient>(); services.AddSingleton<IPeopleHealthClient>(People);
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
