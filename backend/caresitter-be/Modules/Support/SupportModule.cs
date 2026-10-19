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
using CareSitter.Modules.Support.Application.Consultations;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Builder;
using System.Threading.RateLimiting;
using System.Security.Claims;
using CareSitter.Messaging.Persistence;
using CareSitter.Modules.Support.Application.Ports;
using CareSitter.Modules.Support.Application.Chat;

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
        services.AddScoped<IConsultationRequestStore, ConsultationRequestStore>();
        services.AddRateLimiter(options => options.AddPolicy("consultation-request", context =>
            RateLimitPartition.GetFixedWindowLimiter(
                context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 20, Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0, AutoReplenishment = true
                })));
        var chatLimit = Math.Clamp(configuration.GetValue("SupportChat:RateLimitPerMinute", 30), 1, 300);
        services.AddRateLimiter(options => options.AddPolicy("support-chat-write", context =>
            RateLimitPartition.GetFixedWindowLimiter(
                context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                    ?? context.User.FindFirst("sub")?.Value
                    ?? context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = chatLimit, Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0, AutoReplenishment = true
                })));
        services.AddScoped<ISupportReadStore, SupportReadStore>();
        services.AddScoped<IUserNotificationService, UserNotificationService>();
        services.AddScoped<IBookingChatSupportTicketService, BookingChatSupportTicketService>();
        services.AddScoped<ISupportChatService, SupportChatService>();
        services.AddSingleton<SupportChatMetrics>();
        services.AddScoped<IChatTicketGuard, ChatTicketGuard>();
        services.AddScoped<ISupportChatMembership, SupportChatMembership>();
        services.AddScoped<INotificationDeliveryStore, NotificationDeliveryStore>();
        services.AddModuleOutbox<SupportDbContext>(configuration, SupportDbContext.SchemaName,
            string.Equals(configuration["KAFKA_ENABLED"], "true", StringComparison.OrdinalIgnoreCase));
        services.AddScoped<IDisputeLookupService, DisputeLookupService>();
        services.AddScoped<IAdminSupportReader, AdminSupportReader>();

        // Đăng ký Controllers nằm trong assembly của Support module
        services.AddControllers()
            .AddApplicationPart(Assembly.GetAssembly(typeof(SupportModule))!);
    }

    // Controllers tự được map qua app.MapControllers() ở Program.cs
    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}
