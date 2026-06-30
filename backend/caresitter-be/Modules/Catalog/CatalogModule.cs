using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Infrastructure;
using CareSitter.SharedKernel.Modules;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Modules.Catalog;

public sealed class CatalogModule : IModule
{
    public string Name => "Catalog";

    public void RegisterServices(IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<CatalogDbContext>(options =>
            options.UseNpgsql(
                configuration.GetConnectionString("CareSitter"),
                npgsql => npgsql.UseNetTopologySuite()
                    .MigrationsHistoryTable("__ef_migrations", CatalogDbContext.SchemaName)));

        // Catalog cung cap bao gia cho Booking (cross-module qua Contracts).
        services.AddScoped<IPricingService, PricingService>();
    }

    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}
