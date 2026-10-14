using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace CareSitter.IntegrationTests;

internal static class TestEntityFrameworkServices
{
    public static void UseFixtureProvider<TContext>(this IServiceCollection services)
        where TContext : DbContext
    {
        services.AddEntityFrameworkNpgsql().AddEntityFrameworkNpgsqlNetTopologySuite();
        var registration = services.Single(descriptor => descriptor.ServiceType == typeof(DbContextOptions<TContext>));
        var createOptions = registration.ImplementationFactory
            ?? throw new InvalidOperationException("Register the module's DbContext before assigning fixture EF services.");

        // Each fixture owns a different data source. Let its disposable DI container own EF services too,
        // rather than retaining each data source/provider in EF's process-wide service-provider cache.
        services.Replace(ServiceDescriptor.Describe(typeof(DbContextOptions<TContext>), provider =>
            new DbContextOptionsBuilder<TContext>((DbContextOptions<TContext>)createOptions(provider))
                .UseInternalServiceProvider(provider).Options, registration.Lifetime));
    }
}
