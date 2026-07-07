using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.SharedKernel.Modules;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.Reflection;

namespace CareSitter.Modules.Identity;

public sealed class IdentityModule : IModule
{
    public string Name => "Identity";

    public void RegisterServices(IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<IdentityDbContext>(options =>
            options.UseNpgsql(
                configuration.GetConnectionString("CareSitter"),
                npgsql => npgsql.UseNetTopologySuite()
                    .MigrationsHistoryTable("__ef_migrations", IdentityDbContext.SchemaName)));

        services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<IdentityModule>());

        // Đăng ký Controllers nằm trong assembly của Identity module
        // (AuthController được khai báo trong project này, không phải ApiHost)
        services.AddControllers()
            .AddApplicationPart(Assembly.GetAssembly(typeof(IdentityModule))!);
    }

    // Controllers tự được map qua app.MapControllers() ở Program.cs
    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}
