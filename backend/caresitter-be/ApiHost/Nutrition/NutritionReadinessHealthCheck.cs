using System.Net;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;

namespace CareSitter.ApiHost.Nutrition;

public sealed class NutritionReadinessHealthCheck(
    HttpClient client, IOptions<NutritionGatewayOptions> options) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var gateway = options.Value;
        if (!gateway.Enabled) return HealthCheckResult.Healthy("Nutrition gateway is disabled.");

        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get,
                new Uri(new Uri(gateway.GrpcUrl), "health/ready"))
            {
                Version = HttpVersion.Version20,
                VersionPolicy = HttpVersionPolicy.RequestVersionExact
            };
            using var response = await client.SendAsync(request,
                HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            return response.StatusCode == HttpStatusCode.OK
                ? HealthCheckResult.Healthy()
                : HealthCheckResult.Unhealthy("Nutrition readiness did not return HTTP 200.");
        }
        catch (Exception exception) when (exception is HttpRequestException or TaskCanceledException)
        {
            return HealthCheckResult.Unhealthy("Nutrition readiness is unreachable.", exception);
        }
    }
}
