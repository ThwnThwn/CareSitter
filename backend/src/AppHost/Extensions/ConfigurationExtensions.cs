using Aspire.Hosting.ApplicationModel;
using Microsoft.Extensions.Configuration;

namespace CareSitter.AppHost.Extensions;

internal static class ConfigurationExtensions
{
    public static string Required(this IConfiguration configuration, string key) =>
        !string.IsNullOrWhiteSpace(configuration[key])
            ? configuration[key]!
            : throw new InvalidOperationException($"Configure {key} in the API environment or AppHost configuration.");

    public static IResourceBuilder<ParameterResource> AddSecret(this IDistributedApplicationBuilder builder,
        string name, string value)
    {
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
        {
            [$"Parameters:{name}"] = builder.Configuration[$"Parameters:{name}"] ?? value
        });
        return builder.AddParameter(name, secret: true);
    }
}
