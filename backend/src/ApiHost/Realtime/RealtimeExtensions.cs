using CareSitter.Infrastructure.Hubs;
using Microsoft.AspNetCore.Authentication.JwtBearer;

namespace CareSitter.ApiHost.Realtime;

internal static class RealtimeExtensions
{
    public static void AddApiRealtime(this IServiceCollection services)
    {
        // AllowCredentials đã bật ở CORS → WebSocket hoạt động.
        // JWT cho SignalR WebSocket: browser không gửi được header,
        // nên phải đọc token từ query string ?access_token=...
        services.AddSignalR();
        services.AddSingleton<RealtimeSessionRegistry>();
        services.AddHostedService<RealtimeSessionWatchdog>();
        services.PostConfigure<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme, options =>
        {
            var originalOnMessageReceived = options.Events?.OnMessageReceived;
            options.Events ??= new JwtBearerEvents();
            options.Events.OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) &&
                    path.StartsWithSegments("/hubs", StringComparison.OrdinalIgnoreCase))
                {
                    context.Token = accessToken;
                }
                return originalOnMessageReceived != null
                    ? originalOnMessageReceived(context)
                    : Task.CompletedTask;
            };
        });
    }

    public static void MapApiHubs(this WebApplication app)
    {
        app.MapHub<CareTrackingHub>("/hubs/care-tracking", options => options.CloseOnAuthenticationExpiration = true);
        app.MapHub<SupportChatHub>("/hubs/support-chat", options => options.CloseOnAuthenticationExpiration = true);
    }
}
