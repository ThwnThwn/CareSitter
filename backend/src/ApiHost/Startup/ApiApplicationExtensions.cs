using CareSitter.ApiHost.Endpoints;
using CareSitter.ApiHost.OpenApi;
using CareSitter.ApiHost.Security;
using CareSitter.Infrastructure.Modules;

namespace CareSitter.ApiHost.Startup;

internal static class ApiApplicationExtensions
{
    public static void UseApiPipeline(this WebApplication app)
    {
        app.UseExceptionHandler();
        app.UseStatusCodePages();

        // Must run before HTTPS redirection and rate limiting so requests behind a
        // configured reverse proxy retain the original scheme and client IP.
        app.UseForwardedHeaders();

        if (app.Environment.IsDevelopment())
        {
            app.UseCareSitterSwagger();
        }
        else
        {
            app.UseHsts();
            // Render probes the HTTP port and treats redirects as healthy.
            app.UseWhen(context => context.Request.Path != "/health/live" && context.Request.Path != "/health/ready",
                branch => branch.UseHttpsRedirection());
        }

        app.Use(async (context, next) =>
        {
            context.Response.OnStarting(() =>
            {
                var headers = context.Response.Headers;
                headers["X-Content-Type-Options"] = "nosniff";
                headers["X-Frame-Options"] = "DENY";
                headers["Referrer-Policy"] = "no-referrer";
                headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
                if (!headers.ContainsKey("Content-Security-Policy") &&
                    (context.Request.Path.StartsWithSegments("/api") ||
                     context.Request.Path.StartsWithSegments("/health")))
                    headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'";
                return Task.CompletedTask;
            });
            await next();
        });

        app.UseCors("crm");

        // Serve static files từ wwwroot (chỉ dùng khi Development — vd: google-token-tester.html)
        if (app.Environment.IsDevelopment())
            app.UseStaticFiles();

        // Sử dụng Middleware xác thực (Authentication) và ủy quyền (Authorization)
        app.UseAuthentication();
        // Actor-scoped media limits need the validated JWT principal; auth policies
        // still use the forwarded client IP and apply before authorization rejects.
        app.UseRateLimiter();
        app.UseAuthorization();
    }

    public static void MapApiEndpoints(this WebApplication app)
    {
        app.MapControllers();
        app.MapGoogleWebAuthentication();
        app.MapModuleEndpoints();
        MediaEndpoints.Map(app);
    }
}
