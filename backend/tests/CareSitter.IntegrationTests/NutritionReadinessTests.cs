using System.Net;
using CareSitter.ApiHost.Nutrition;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace CareSitter.IntegrationTests;

public sealed class NutritionReadinessTests
{
    [Theory]
    [InlineData(HttpStatusCode.OK, HttpStatusCode.OK)]
    [InlineData(HttpStatusCode.ServiceUnavailable, HttpStatusCode.ServiceUnavailable)]
    public async Task Ready_endpoint_reflects_nutrition_dependency(
        HttpStatusCode nutritionStatus, HttpStatusCode expectedStatus)
    {
        var probe = new ProbeHandler(nutritionStatus);
        using var client = new HttpClient(probe);
        using var server = new TestServer(new WebHostBuilder()
            .ConfigureServices(services =>
            {
                services.AddRouting();
                services.AddSingleton(client);
                services.AddSingleton<IOptions<NutritionGatewayOptions>>(Options.Create(new NutritionGatewayOptions
                {
                    Enabled = true,
                    GrpcUrl = "https://nutrition:8443/"
                }));
                services.AddHealthChecks().AddCheck<NutritionReadinessHealthCheck>("nutrition");
            })
            .Configure(app =>
            {
                app.UseRouting();
                app.UseEndpoints(endpoints => endpoints.MapHealthChecks("/health/ready", new HealthCheckOptions()));
            }));

        var response = await server.CreateClient().GetAsync("/health/ready");

        Assert.Equal(expectedStatus, response.StatusCode);
        Assert.Equal("https://nutrition:8443/health/ready", probe.RequestUri);
        Assert.Equal(HttpVersion.Version20, probe.RequestVersion);
    }

    private sealed class ProbeHandler(HttpStatusCode statusCode) : HttpMessageHandler
    {
        public string? RequestUri { get; private set; }
        public Version? RequestVersion { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            RequestUri = request.RequestUri?.ToString();
            RequestVersion = request.Version;
            return Task.FromResult(new HttpResponseMessage(statusCode));
        }
    }
}
