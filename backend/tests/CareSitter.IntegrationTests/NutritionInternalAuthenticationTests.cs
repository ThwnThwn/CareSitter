using System.Net;
using CareSitter.ApiHost.Security;
using CareSitter.Contracts.Nutrition;
using CareSitter.Modules.People.Controllers;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace CareSitter.IntegrationTests;

public sealed class NutritionInternalAuthenticationTests
{
    [Fact]
    public async Task Internal_endpoint_requires_service_credential_and_preserves_owner_scope()
    {
        var key = Guid.NewGuid().ToString("N") + Guid.NewGuid().ToString("N");
        var reader = new Reader();
        using var host = await new HostBuilder().ConfigureWebHost(web => web.UseTestServer()
            .ConfigureAppConfiguration(config => config.AddInMemoryCollection(new Dictionary<string, string?>
                { ["NutritionIntegration:ServiceKey"] = key }))
            .ConfigureServices(services =>
            {
                services.AddLogging();
                services.AddSingleton<IBeneficiaryHealthSnapshotReader>(reader);
                services.AddAuthentication("NutritionService").AddScheme<AuthenticationSchemeOptions,
                    NutritionServiceAuthenticationHandler>("NutritionService", _ => { });
                services.AddAuthorization();
                services.AddControllers().AddApplicationPart(typeof(InternalNutritionProfileController).Assembly);
            }).Configure(app =>
            {
                app.UseRouting(); app.UseAuthentication(); app.UseAuthorization();
                app.UseEndpoints(endpoints => endpoints.MapControllers());
            })).StartAsync();
        using var client = host.GetTestClient();
        var owner = Guid.NewGuid(); var beneficiary = Guid.NewGuid();
        var path = $"/internal/v1/nutrition/owners/{owner}/beneficiaries/{beneficiary}/health-profile";
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(path)).StatusCode);
        client.DefaultRequestHeaders.Add("X-Nutrition-Service-Key", "invalid");
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(path)).StatusCode);
        Assert.Equal(0, reader.Calls);
        client.DefaultRequestHeaders.Remove("X-Nutrition-Service-Key");
        client.DefaultRequestHeaders.Add("X-Nutrition-Service-Key", key);
        var response = await client.GetAsync(path);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal((owner, beneficiary), reader.Request);
        Assert.DoesNotContain("health", await response.Content.ReadAsStringAsync(), StringComparison.OrdinalIgnoreCase);
    }
    private sealed class Reader : IBeneficiaryHealthSnapshotReader
    {
        public int Calls;
        public (Guid, Guid) Request;
        public Task<BeneficiaryHealthSnapshot?> ReadAsync(Guid ownerId, Guid beneficiaryId, CancellationToken ct = default)
        {
            Calls++; Request = (ownerId, beneficiaryId);
            return Task.FromResult<BeneficiaryHealthSnapshot?>(null);
        }
    }
}
