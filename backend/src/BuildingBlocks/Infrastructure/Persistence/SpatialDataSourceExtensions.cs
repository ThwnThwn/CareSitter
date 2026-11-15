using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;

namespace CareSitter.Infrastructure.Persistence;

public static class SpatialDataSourceExtensions
{
    /// <summary>Configure ADO.NET and EF separately; never depend on global mapper initialization order.</summary>
    public static IServiceCollection AddSpatialDataSource(this IServiceCollection services, IConfiguration configuration)
    {
        services.TryAddSingleton<NpgsqlDataSource>(_ =>
        {
            var builder = new NpgsqlDataSourceBuilder(configuration.GetConnectionString("CareSitter")
                ?? throw new InvalidOperationException("CareSitter connection is required."));
            builder.UseNetTopologySuite();
            return builder.Build();
        });
        return services;
    }
}
