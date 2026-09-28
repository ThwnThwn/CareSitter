using System.IdentityModel.Tokens.Jwt;
using System.Text;
using CareSitter.Contracts.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;

namespace CareSitter.Infrastructure.Auth;

/// <summary>
/// Registers JWT authentication and rejects access tokens that have been revoked through logout.
/// </summary>
public static class AuthServiceRegistration
{
    public static IServiceCollection AddJwtAuthentication(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddOptions<JwtSettings>()
            .Bind(configuration.GetSection(JwtSettings.SectionName))
            .Validate(x => !string.IsNullOrWhiteSpace(x.Issuer), "Jwt:Issuer is required.")
            .Validate(x => !string.IsNullOrWhiteSpace(x.Audience), "Jwt:Audience is required.")
            .Validate(x => x.SecretKey?.Length >= 32, "Jwt:SecretKey must contain at least 32 characters.")
            .Validate(x => x.ExpiryMinutes is >= 5 and <= 60,
                "Jwt:ExpiryMinutes must be between 5 and 60.")
            .Validate(x => x.RefreshTokenExpiryDays is >= 1 and <= 30,
                "Jwt:RefreshTokenExpiryDays must be between 1 and 30.")
            .ValidateOnStart();

        var jwtSettings = configuration.GetSection(JwtSettings.SectionName).Get<JwtSettings>()
            ?? new JwtSettings();

        services.AddScoped<IJwtTokenService, JwtTokenService>();

        services.AddAuthentication(options =>
        {
            options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
            options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
        })
        .AddJwtBearer(options =>
        {
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer = jwtSettings.Issuer,
                ValidAudience = jwtSettings.Audience,
                IssuerSigningKey = new SymmetricSecurityKey(
                    Encoding.UTF8.GetBytes(jwtSettings.SecretKey)),
                ClockSkew = TimeSpan.Zero
            };

            options.Events = new JwtBearerEvents
            {
                OnTokenValidated = async context =>
                {
                    var jti = context.Principal?.FindFirst(JwtRegisteredClaimNames.Jti)?.Value;
                    if (string.IsNullOrWhiteSpace(jti))
                    {
                        context.Fail("Token is missing jti.");
                        return;
                    }

                    var userIdValue = context.Principal?.FindFirst(JwtRegisteredClaimNames.Sub)?.Value
                        ?? context.Principal?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
                    var sessionIdValue = context.Principal?.FindFirst("sid")?.Value;
                    if (!Guid.TryParse(userIdValue, out var userId) ||
                        !Guid.TryParse(sessionIdValue, out var sessionId))
                    {
                        context.Fail("Token is not bound to a durable session.");
                        return;
                    }

                    var sessionValidator = context.HttpContext.RequestServices
                        .GetRequiredService<IAccessSessionValidator>();
                    if (!await sessionValidator.IsActiveAsync(
                            userId, sessionId, context.HttpContext.RequestAborted))
                    {
                        context.Fail("The account or session is no longer active.");
                        return;
                    }

                    var cache = context.HttpContext.RequestServices.GetService<IDistributedCache>();
                    if (cache is null)
                    {
                        return;
                    }

                    try
                    {
                        var revokedToken = await cache.GetStringAsync(
                            JwtRevocationCacheKeys.RevokedAccessToken(jti),
                            context.HttpContext.RequestAborted);

                        if (revokedToken is not null)
                        {
                            context.Fail("The access token has been revoked.");
                        }
                    }
                    catch (OperationCanceledException) when (context.HttpContext.RequestAborted.IsCancellationRequested)
                    {
                        throw;
                    }
                    catch (Exception ex)
                    {
                        // Access tokens are short-lived. If Redis is unavailable,
                        // continue normal JWT validation instead of taking the API
                        // offline; durable refresh-session revocation lives in DB.
                        var logger = context.HttpContext.RequestServices
                            .GetService<ILoggerFactory>()?
                            .CreateLogger("CareSitter.Auth.TokenRevocation");
                        logger?.LogWarning(ex,
                            "Access-token blacklist check unavailable; accepting valid short-lived JWT.");
                    }
                }
            };
        });

        services.AddAuthorization();

        return services;
    }
}
