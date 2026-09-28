
using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.Contracts.Services;
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
        services.AddScoped<IPushNotificationService, FirebasePushNotificationService>();
        services.AddScoped<IRefreshTokenSessionService, RefreshTokenSessionService>();
        services.AddScoped<IAccessSessionValidator, AccessSessionValidator>();
        services.AddScoped<IAuditLogger, IdentityAuditLogger>();
        services.AddScoped<IUserProfileReader, UserProfileReader>();
        services.AddScoped<IIdentityStore, IdentityStore>();
        services.AddScoped<IIdentityDeviceStore, IdentityDeviceStore>();
        services.AddScoped<IPasswordHasher, BcryptPasswordHasher>();
        services.AddScoped<IGoogleIdentityVerifier, GoogleIdentityVerifier>();
        services.AddScoped<IAuthenticationAttemptLimiter, AuthenticationAttemptLimiter>();
        services.AddScoped<IOtpStore, OtpStore>();
        services.AddScoped<IAccessTokenRevocationStore, AccessTokenRevocationStore>();

        // Đăng ký Controllers nằm trong assembly của Identity module
        // (AuthController được khai báo trong project này, không phải ApiHost)
        services.AddControllers()
            .AddApplicationPart(Assembly.GetAssembly(typeof(IdentityModule))!);
    }

    // Controllers tự được map qua app.MapControllers() ở Program.cs
    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}
