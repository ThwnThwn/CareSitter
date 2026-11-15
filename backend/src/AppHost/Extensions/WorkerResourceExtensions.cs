using Aspire.Hosting.ApplicationModel;
using Microsoft.Extensions.Configuration;

namespace CareSitter.AppHost.Extensions;

internal static class WorkerResourceExtensions
{
    public static IResourceBuilder<ProjectResource>? AddNotificationWorker(this IDistributedApplicationBuilder builder,
        AppHostSettings settings, IResourceBuilder<ProjectResource> api)
    {
        var configuration = settings.Configuration;
        if (!configuration.GetValue<bool>("KAFKA_ENABLED") || !configuration.GetValue<bool>("KAFKA_FLOW_NOTIFICATIONS_ENABLED"))
            return null;
        var worker = builder.AddProject<Projects.CareSitter_NotificationWorker>("notification-worker", launchProfileName: null)
            .WithHttpEndpoint(name: "http")
            .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
            .WithEnvironment("KAFKA_SUPPORT_API_URL", api.GetEndpoint("http"))
            .WithHttpHealthCheck("/health/live")
            .WaitFor(api);
        foreach (var key in new[] { "KAFKA_ENABLED", "KAFKA_FLOW_NOTIFICATIONS_ENABLED", "KAFKA_BOOTSTRAP_SERVERS", "KAFKA_CLIENT_ID",
            "KAFKA_TOPIC_NOTIFICATIONS", "KAFKA_TOPIC_PAYMENTS", "KAFKA_TOPIC_NUTRITION", "KAFKA_INTERNAL_SERVICE_KEY",
            "Firebase:ServiceAccountPath", "Firebase:ServiceAccountJson", "Smtp:Host", "Smtp:Port", "Smtp:UserName",
            "Smtp:Password", "Smtp:FromName", "Smtp:TimeoutSeconds" })
        {
            var value = configuration[key];
            if (string.IsNullOrWhiteSpace(value)) continue;
            if (key is "KAFKA_INTERNAL_SERVICE_KEY" or "Firebase:ServiceAccountJson" or "Smtp:Password")
                worker.WithEnvironment(key.Replace(":", "__"), builder.AddSecret(
                    "worker-" + key.ToLowerInvariant().Replace(":", "-").Replace("_", "-"), value));
            else worker.WithEnvironment(key.Replace(":", "__"), value);
        }
        return worker;
    }
}
