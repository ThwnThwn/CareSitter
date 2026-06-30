using CareSitter.Modules.Booking.Endpoints;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Modules;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Modules.Booking;

public sealed class BookingModule : IModule
{
    public string Name => "Booking";

    public void RegisterServices(IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<BookingDbContext>(options =>
            options.UseNpgsql(
                configuration.GetConnectionString("CareSitter"),
                npgsql => npgsql.UseNetTopologySuite()
                    .MigrationsHistoryTable("__ef_migrations", BookingDbContext.SchemaName)));

        services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<BookingModule>());
    }

    public void MapEndpoints(IEndpointRouteBuilder endpoints) => BookingEndpoints.Map(endpoints);
}
