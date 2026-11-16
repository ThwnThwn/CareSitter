using System.Text.Json;
using CareSitter.ApiHost.Nutrition;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Npgsql;
using StackExchange.Redis;

namespace CareSitter.ApiHost.Health;

internal static class HealthCheckExtensions
{
    public static void AddApiHealthChecks(this IServiceCollection services, IConfiguration configuration)
    {
        // Liveness chỉ xác nhận process đang chạy; readiness kiểm tra các dependency
        // bắt buộc để API có thể phục vụ request thật.
        services.AddHealthChecks()
            .AddAsyncCheck("postgres", async cancellationToken =>
            {
                var connectionString = configuration.GetConnectionString("CareSitter");
                if (string.IsNullOrWhiteSpace(connectionString))
                    return HealthCheckResult.Unhealthy("ConnectionStrings:CareSitter is not configured.");

                try
                {
                    await using var connection = new NpgsqlConnection(connectionString);
                    await connection.OpenAsync(cancellationToken);
                    await using var command = new NpgsqlCommand("SELECT 1", connection);
                    await command.ExecuteScalarAsync(cancellationToken);
                    return HealthCheckResult.Healthy();
                }
                catch (Exception ex)
                {
                    return HealthCheckResult.Unhealthy("PostgreSQL is unavailable.", ex);
                }
            }, timeout: TimeSpan.FromSeconds(5))
            .AddAsyncCheck("redis", async cancellationToken =>
            {
                var connectionString = configuration["Redis:ConnectionString"];
                if (string.IsNullOrWhiteSpace(connectionString))
                    return HealthCheckResult.Unhealthy("Redis:ConnectionString is not configured.");

                try
                {
                    var options = ConfigurationOptions.Parse(connectionString);
                    options.AbortOnConnectFail = false;
                    using var connection = await ConnectionMultiplexer.ConnectAsync(options);
                    var pingTask = connection.GetDatabase().PingAsync();
                    var completedTask = await Task.WhenAny(
                        pingTask,
                        Task.Delay(TimeSpan.FromSeconds(3), cancellationToken));

                    if (completedTask != pingTask)
                        return HealthCheckResult.Unhealthy("Redis ping timed out.");

                    var latency = await pingTask;
                    return HealthCheckResult.Healthy(data: new Dictionary<string, object>
                    {
                        ["latencyMs"] = Math.Round(latency.TotalMilliseconds, 2)
                    });
                }
                catch (Exception ex)
                {
                    return HealthCheckResult.Unhealthy("Redis is unavailable.", ex);
                }
            }, timeout: TimeSpan.FromSeconds(5))
            .AddCheck<NutritionReadinessHealthCheck>("nutrition", timeout: TimeSpan.FromSeconds(5));
    }

    public static void MapApiHealthEndpoints(this WebApplication app)
    {
        app.MapGet("/health", () => Results.Ok(new { status = "ok" })).WithTags("System");
        app.MapGet("/health/live", () => Results.Ok(new { status = "ok" })).WithTags("System");
        app.MapHealthChecks("/health/ready", new HealthCheckOptions
        {
            ResponseWriter = async (context, report) =>
            {
                context.Response.ContentType = "application/json";
                var payload = new
                {
                    status = report.Status.ToString(),
                    totalDurationMs = Math.Round(report.TotalDuration.TotalMilliseconds, 2),
                    checks = report.Entries.ToDictionary(
                        entry => entry.Key,
                        entry => new
                        {
                            status = entry.Value.Status.ToString(),
                            description = entry.Value.Description,
                            durationMs = Math.Round(entry.Value.Duration.TotalMilliseconds, 2),
                            data = entry.Value.Data
                        })
                };
                await context.Response.WriteAsync(JsonSerializer.Serialize(payload));
            }
        }).WithTags("System");
    }
}
