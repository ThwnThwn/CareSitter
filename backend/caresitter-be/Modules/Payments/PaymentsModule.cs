using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Infrastructure;
using CareSitter.SharedKernel.Modules;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.Reflection;

namespace CareSitter.Modules.Payments;

public sealed class PaymentsModule : IModule
{
    public string Name => "Payments";

    public void RegisterServices(IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<PaymentsDbContext>(options =>
            options.UseNpgsql(
                configuration.GetConnectionString("CareSitter"),
                npgsql => npgsql.UseNetTopologySuite()
                    .MigrationsHistoryTable("__ef_migrations", PaymentsDbContext.SchemaName)));

        services.AddScoped<IWalletService, WalletService>();

        // Đăng ký Controllers nằm trong assembly của Payments module
        services.AddControllers()
            .AddApplicationPart(Assembly.GetAssembly(typeof(PaymentsModule))!);
    }

    // Controllers tự được map qua app.MapControllers() ở Program.cs
    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}
