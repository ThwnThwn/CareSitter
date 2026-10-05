using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.Modules.Catalog.Infrastructure;
using CareSitter.SharedKernel.Modules;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.Reflection;
using FluentValidation;
using CareSitter.Infrastructure.Persistence;
using Npgsql;

namespace CareSitter.Modules.Catalog;

public sealed class CatalogModule : IModule
{
    public string Name => "Catalog";

    public void RegisterServices(IServiceCollection services, IConfiguration configuration)
    {
        services.AddSpatialDataSource(configuration);
        services.AddDbContext<CatalogDbContext>((provider, options) =>
            options.UseNpgsql(
                provider.GetRequiredService<NpgsqlDataSource>(),
                npgsql => npgsql.UseNetTopologySuite()
                    .MigrationsHistoryTable("__ef_migrations", CatalogDbContext.SchemaName)));

        services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<CatalogModule>());
        services.AddValidatorsFromAssemblyContaining<CatalogModule>();
        services.AddScoped<IAddressRepository, AddressRepository>();
        services.AddScoped<ICatalogReadStore, CatalogReadStore>();
        services.AddScoped<ICatalogAdminRepository, CatalogAdminRepository>();
        services.AddScoped<IBookingMediaStore, BookingMediaStore>();
        services.AddScoped<IKycMediaStore, KycMediaStore>();
        services.AddScoped<IServiceChecklistCatalog, ServiceChecklistCatalog>();

        // Catalog cung cap bao gia cho Booking (cross-module qua Contracts).
        services.AddMemoryCache();
        services.AddScoped<IPricingService, PricingService>();
        services.AddScoped<ICatalogLookupService, CatalogLookupService>();
        services.AddScoped<IMatchingAddressReader, MatchingAddressReader>();
        services.AddHttpClient<IPlaceAutocompleteService, GeoapifyPlaceAutocompleteService>((_, client) =>
        {
            client.BaseAddress = new Uri(
                configuration["Geoapify:BaseUrl"] ??
                configuration["Routing:Geoapify:BaseUrl"] ??
                "https://api.geoapify.com");
        });

        // Đăng ký Controllers nằm trong assembly của Catalog module
        services.AddControllers()
            .AddApplicationPart(Assembly.GetAssembly(typeof(CatalogModule))!);
    }

    // Controllers tự được map qua app.MapControllers() ở Program.cs
    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}
