using Hangfire.Dashboard;

namespace CareSitter.ApiHost.Security;

/// <summary>
/// Hangfire Dashboard authorization filter.
///
/// Rules:
///   - Development: cho phép localhost request (không cần login) ĐỂ DỄ DEBUG.
///     Trong thực tế có thể thêm JWT check ở đây nếu cần bảo mật hơn.
///   - Production: bắt buộc phải có JWT hợp lệ với role "ADMIN".
///     Truyền token qua cookie "hangfire_token" (set sau khi login admin).
/// </summary>
public sealed class HangfireDashboardAuthFilter : IDashboardAuthorizationFilter
{
    private readonly IWebHostEnvironment _env;

    public HangfireDashboardAuthFilter(IWebHostEnvironment env)
    {
        _env = env;
    }

    public bool Authorize(DashboardContext context)
    {
        var httpContext = context.GetHttpContext();

        // ── Development: cho phép localhost ──────────────────────────────
        if (_env.IsDevelopment())
        {
            var ip = httpContext.Connection.RemoteIpAddress;
            if (ip != null && (
                System.Net.IPAddress.IsLoopback(ip) ||
                ip.Equals(System.Net.IPAddress.Parse("::1"))))
            {
                return true;
            }
        }

        // ── Production: JWT với role ADMIN ───────────────────────────────
        // Kiểm tra user đã xác thực
        if (httpContext.User?.Identity?.IsAuthenticated != true)
            return false;

        // Kiểm tra role ADMIN
        return httpContext.User.IsInRole("ADMIN")
            || httpContext.User.HasClaim("role", "ADMIN")
            || httpContext.User.HasClaim(
                System.Security.Claims.ClaimTypes.Role, "ADMIN");
    }
}
