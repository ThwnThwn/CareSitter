
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
        services.AddScoped<INotificationRecipientReader, NotificationRecipientReader>();
        services.AddScoped<IRefreshTokenSessionService, RefreshTokenSessionService>();
        services.AddScoped<IAccessSessionValidator, AccessSessionValidator>();
        services.AddScoped<IAuditLogger, IdentityAuditLogger>();
        services.AddScoped<IUserProfileReader, UserProfileReader>();
        services.AddScoped<IActiveAdminLookup, ActiveAdminLookup>();
        services.AddScoped<IActiveUserLookup, ActiveUserLookup>();
        services.AddScoped<IIdentityStore, IdentityStore>();
        services.AddScoped<IIdentityDeviceStore, IdentityDeviceStore>();
        services.AddScoped<IPasswordHasher, BcryptPasswordHasher>();
        services.AddScoped<IGoogleIdentityVerifier, GoogleIdentityVerifier>();
        services.AddScoped<IAuthenticationAttemptLimiter, AuthenticationAttemptLimiter>();
        services.AddScoped<IOtpStore, OtpStore>();
        services.AddScoped<IAccessTokenRevocationStore, AccessTokenRevocationStore>();
        services.AddScoped<IAdminIdentityReader, AdminIdentityReader>();
        services.AddOptions<RecoveryOptions>()
            .Bind(configuration.GetSection("PasswordRecovery"))
            .Validate(x => !x.Enabled || x.SecretKey.Length >= 32, "PasswordRecovery:SecretKey cần ít nhất 32 ký tự.")
            .Validate(x => x.CodeMinutes is >= 1 and <= 30 && x.GrantMinutes is >= 1 and <= 10 &&
                x.ResendSeconds is >= 30 and <= 300 && x.RequestsPerHour is >= 1 and <= 10 &&
                x.MaxAttempts is >= 1 and <= 5 && x.MetadataRetentionDays is >= 1 and <= 30, "PasswordRecovery TTL/limit không hợp lệ.")
            .ValidateOnStart();
        services.AddScoped<RecoverySecrets>();
        services.AddScoped<IPasswordRecoveryService, PasswordRecoveryService>();
        services.AddScoped<RecoveryEmailDispatcher>();
        services.AddHostedService<RecoveryEmailWorker>();

        // Đăng ký Controllers nằm trong assembly của Identity module
        // (AuthController được khai báo trong project này, không phải ApiHost)
        services.AddControllers(options => options.Filters.Add<Controllers.IdentityConcurrencyExceptionFilter>())
            .AddApplicationPart(Assembly.GetAssembly(typeof(IdentityModule))!);
    }

    // Controllers tự được map qua app.MapControllers() ở Program.cs
    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}
