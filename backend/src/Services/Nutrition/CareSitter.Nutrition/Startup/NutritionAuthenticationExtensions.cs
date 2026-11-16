using System.Security.Claims;
using System.Text;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;

namespace CareSitter.Nutrition.Startup;

internal static class NutritionAuthenticationExtensions
{
    public static (string Secret, string Issuer, string Audience) ReadNutritionJwtSettings(
        this IConfiguration configuration)
    {
        var jwtSecret = configuration["Jwt:SecretKey"] ?? "";
        var issuer = configuration["Jwt:Issuer"];
        var audience = configuration["Jwt:Audience"];
        if (jwtSecret.Length < 32 || string.IsNullOrWhiteSpace(issuer) || string.IsNullOrWhiteSpace(audience))
            throw new InvalidOperationException("JWT validation must be configured for the Nutrition service.");

        return (jwtSecret, issuer, audience);
    }

    public static void AddNutritionAuthentication(this IServiceCollection services,
        string jwtSecret, string issuer, string audience)
    {
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
        {
            o.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = issuer,
                ValidateAudience = true,
                ValidAudience = audience,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
                ClockSkew = TimeSpan.FromSeconds(30),
                NameClaimType = ClaimTypes.NameIdentifier,
                RoleClaimType = ClaimTypes.Role
            };
            o.Events = new JwtBearerEvents
            {
                OnTokenValidated = async context =>
                {
                    if (!Guid.TryParse(context.Principal?.FindFirstValue(ClaimTypes.NameIdentifier), out _) ||
                        !Guid.TryParse(context.Principal?.FindFirstValue("sid"), out _) ||
                        string.IsNullOrWhiteSpace(context.Principal?.FindFirstValue("jti")))
                    {
                        context.Fail("Token must be bound to a durable Identity session.");
                    return;
                    }
                    var header = context.HttpContext.Request.Headers.Authorization.ToString();
                    try
                    {
                        var identity = context.HttpContext.RequestServices.GetRequiredService<IIdentitySessionClient>();
                        if (!await identity.IsActiveAsync(header["Bearer ".Length..], context.HttpContext.RequestAborted))
                            context.Fail("Identity session is no longer active.");
                    }
                    catch (Exception e) when (e is HttpRequestException or TaskCanceledException)
                    {
                        context.HttpContext.Items["nutrition.identity_unavailable"] = true;
                        context.Fail("Identity session validation unavailable.");
                    }
                },
                OnChallenge = async context =>
                {
                    if (context.HttpContext.Items.ContainsKey("nutrition.identity_unavailable"))
                    {
                        context.HandleResponse();
                        if (context.Request.ContentType?.StartsWith("application/grpc", StringComparison.OrdinalIgnoreCase) == true)
                        {
                            NutritionGatewayAuthenticationMiddleware.GrpcFailure(context.HttpContext, "14", "nutrition.identity_unavailable");
                            return;
                        }
                        context.Response.StatusCode = 503;
                        await context.Response.WriteAsJsonAsync(new ProblemDetails
                        {
                            Title = "nutrition.identity_unavailable",
                            Detail = "Chưa kiểm tra được phiên đăng nhập. Vui lòng thử lại."
                        }, context.HttpContext.RequestAborted);
                    }
                }
            };
        });
        services.AddAuthorization();
        services.AddHttpContextAccessor();
        services.AddScoped<ICurrentUser, HttpCurrentUser>();
    }
}
