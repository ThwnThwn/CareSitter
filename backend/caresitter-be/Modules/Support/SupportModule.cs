using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Domain;
using CareSitter.Modules.Support.Infrastructure;
using CareSitter.SharedKernel.Modules;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.Reflection;
using FluentValidation;

namespace CareSitter.Modules.Support;

public sealed class SupportModule : IModule
{
    public string Name => "Support";

    public void RegisterServices(IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<SupportDbContext>(options =>
            options.UseNpgsql(
                configuration.GetConnectionString("CareSitter"),
                npgsql => npgsql.UseNetTopologySuite()
                    .MigrationsHistoryTable("__ef_migrations", SupportDbContext.SchemaName)));
        services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<SupportModule>());
        services.AddValidatorsFromAssemblyContaining<SupportModule>();
        services.AddScoped<ISupportRepository, SupportRepository>();
        services.AddScoped<ISupportReadStore, SupportReadStore>();
        services.AddScoped<IUserNotificationService, UserNotificationService>();
        services.AddScoped<IDisputeLookupService, DisputeLookupService>();

        // Đăng ký Controllers nằm trong assembly của Support module
        services.AddControllers()
            .AddApplicationPart(Assembly.GetAssembly(typeof(SupportModule))!);
    }

    // Controllers tự được map qua app.MapControllers() ở Program.cs
    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}
