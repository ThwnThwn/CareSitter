using System.Security.Claims;
using System.Threading.RateLimiting;

namespace CareSitter.ApiHost.Security;

internal static class RateLimitingExtensions
{
    public static void AddApiRateLimiting(this IServiceCollection services)
    {
        services.AddRateLimiter(options =>
        {
            options.AddPolicy("nutrition-knowledge", context => RateLimitPartition.GetFixedWindowLimiter(
                context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                    ?? context.User.FindFirst("sub")?.Value ?? Partition(context),
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 6, Window = TimeSpan.FromMinutes(1), QueueLimit = 0, AutoReplenishment = true
                }));
            options.AddPolicy("auth-session", context => RateLimitPartition.GetFixedWindowLimiter(
                context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                    ?? context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 120, Window = TimeSpan.FromMinutes(1), QueueLimit = 0, AutoReplenishment = true
                }));
            options.AddPolicy("auth-recovery", context => RateLimitPartition.GetFixedWindowLimiter(
                context.Connection.RemoteIpAddress?.ToString() ?? "unknown", _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 20, Window = TimeSpan.FromMinutes(10), QueueLimit = 0, AutoReplenishment = true
                }));
            options.AddPolicy("booking-gps", context => RateLimitPartition.GetSlidingWindowLimiter(
                context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                    ?? context.User.FindFirst("sub")?.Value ?? context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                _ => new SlidingWindowRateLimiterOptions
                {
                    PermitLimit = 30, Window = TimeSpan.FromMinutes(1), SegmentsPerWindow = 6,
                    QueueLimit = 0, AutoReplenishment = true
                }));
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            options.OnRejected = async (context, ct) =>
            {
                if (context.HttpContext.Request.Path.StartsWithSegments("/api/v1/support/conversations"))
                {
                    context.HttpContext.Response.Headers.RetryAfter = "60";
                    context.HttpContext.Response.ContentType = "application/problem+json";
                    await context.HttpContext.Response.WriteAsJsonAsync(new
                    {
                        title = "support.chat.rate_limited",
                        detail = "Bạn thao tác quá nhanh. Vui lòng thử lại sau."
                    }, ct);
                    return;
                }
                if (context.HttpContext.Request.Path.Value?.Contains("/gps", StringComparison.Ordinal) == true)
                {
                    context.HttpContext.Response.Headers.RetryAfter = "60";
                    await context.HttpContext.Response.WriteAsJsonAsync(new
                    {
                        title = "booking.gps.rate_limited",
                        detail = "Vui lòng chờ trước khi gửi lại vị trí."
                    }, ct);
                    return;
                }
                context.HttpContext.Response.ContentType = "application/problem+json";
                await context.HttpContext.Response.WriteAsJsonAsync(new
                {
                    title = "auth.rate_limit",
                    detail = "Bạn thao tác quá nhanh. Vui lòng thử lại sau."
                }, ct);
            };

            static string Partition(HttpContext context) =>
                context.Connection.RemoteIpAddress?.ToString() ?? "unknown";

            options.AddPolicy("auth-send-otp", context => RateLimitPartition.GetFixedWindowLimiter(
                Partition(context), _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 5,
                    Window = TimeSpan.FromMinutes(10),
                    QueueLimit = 0,
                    AutoReplenishment = true
                }));
            options.AddPolicy("auth-login", context => RateLimitPartition.GetFixedWindowLimiter(
                Partition(context), _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 20,
                    Window = TimeSpan.FromMinutes(10),
                    QueueLimit = 0,
                    AutoReplenishment = true
                }));
            options.AddPolicy("auth-register", context => RateLimitPartition.GetFixedWindowLimiter(
                Partition(context), _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 5,
                    Window = TimeSpan.FromHours(1),
                    QueueLimit = 0,
                    AutoReplenishment = true
                }));
            options.AddPolicy("auth-refresh", context => RateLimitPartition.GetFixedWindowLimiter(
                Partition(context), _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 60,
                    Window = TimeSpan.FromMinutes(10),
                    QueueLimit = 0,
                    AutoReplenishment = true
                }));
            options.AddPolicy("media-read", context => RateLimitPartition.GetSlidingWindowLimiter(
                context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                    ?? context.User.FindFirst("sub")?.Value ?? Partition(context),
                _ => new SlidingWindowRateLimiterOptions
                {
                    PermitLimit = 120, Window = TimeSpan.FromMinutes(1), SegmentsPerWindow = 6,
                    QueueLimit = 0, AutoReplenishment = true
                }));
        });
    }
}
