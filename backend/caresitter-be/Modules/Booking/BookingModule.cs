using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Modules;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.Reflection;

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

        // Đăng ký Controllers nằm trong assembly của Booking module
        services.AddControllers()
            .AddApplicationPart(Assembly.GetAssembly(typeof(BookingModule))!);

        // Đăng ký BookingMembershipReader để CareTrackingHub verify quyền join SignalR group.
        // Hub resolve IBookingMembershipChecker (Shared interface) → implementation nằm ở đây.
        // Scoped vì phụ thuộc BookingDbContext (cũng Scoped).
        services.AddScoped<IBookingMembershipChecker, BookingMembershipReader>();
    }

    // Controllers tự được map qua app.MapControllers() ở Program.cs
    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}
