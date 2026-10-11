using System.Security.Claims;
using System.Text;
using System.Threading.RateLimiting;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);
var jwtSecret = builder.Configuration["Jwt:SecretKey"] ?? "";
var issuer = builder.Configuration["Jwt:Issuer"];
var audience = builder.Configuration["Jwt:Audience"];
var peopleUrl = builder.Configuration["People:BaseUrl"] ?? "";
var serviceKey = builder.Configuration["People:ServiceKey"] ?? "";
if (jwtSecret.Length < 32 || string.IsNullOrWhiteSpace(issuer) || string.IsNullOrWhiteSpace(audience))
    throw new InvalidOperationException("JWT validation must be configured for the Nutrition service.");
if (!Uri.TryCreate(peopleUrl, UriKind.Absolute, out var peopleUri) || serviceKey.Length is not (>= 32 and <= 256) ||
    (peopleUri.Scheme != "https" && !builder.Environment.IsDevelopment()))
    throw new InvalidOperationException("People HTTPS endpoint and internal service key must be configured.");
builder.Logging.AddFilter("System.Net.Http.HttpClient", LogLevel.Warning);
builder.Logging.AddFilter("Microsoft.AspNetCore.Hosting.Diagnostics", LogLevel.Warning);
builder.WebHost.ConfigureKestrel(o => o.Limits.MaxRequestBodySize = 32768);
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
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
                context.Fail("Token must be bound to a durable Identity session."); return;
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
                context.HandleResponse(); context.Response.StatusCode = 503;
                await context.Response.WriteAsJsonAsync(new ProblemDetails
                {
                    Title = "nutrition.identity_unavailable",
                    Detail = "Chưa kiểm tra được phiên đăng nhập. Vui lòng thử lại."
                }, context.HttpContext.RequestAborted);
            }
        }
    };
});
builder.Services.AddAuthorization(); builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, HttpCurrentUser>();
builder.Services.AddSingleton<INutritionFeatures, NutritionFeatures>();
builder.Services.AddSingleton(_ => NpgsqlDataSource.Create(builder.Configuration.GetConnectionString("Nutrition")
    ?? throw new InvalidOperationException("ConnectionStrings:Nutrition is required.")));
builder.Services.AddScoped<INutritionStore, NutritionStore>();
builder.Services.AddScoped<IHealthDescriptionParser, UnconfiguredHealthParser>();
builder.Services.AddScoped<AssessmentProcessor>();
builder.Services.AddHttpClient<IPeopleHealthClient, PeopleHealthClient>(client =>
{
    client.BaseAddress = new Uri(peopleUrl.TrimEnd('/') + '/');
    client.DefaultRequestHeaders.Add("X-Nutrition-Service-Key", serviceKey);
    client.Timeout = TimeSpan.FromSeconds(5);
});
builder.Services.AddHttpClient<IIdentitySessionClient, IdentitySessionClient>(client =>
{
    client.BaseAddress = new Uri(peopleUrl.TrimEnd('/') + '/');
    client.Timeout = TimeSpan.FromSeconds(5);
});
builder.Services.AddHostedService<NutritionWorker>();
builder.Services.AddMediatR(c => c.RegisterServicesFromAssemblyContaining<AssessmentProcessor>());
builder.Services.AddControllers(); builder.Services.AddExceptionHandler<NutritionExceptionHandler>();
builder.Services.AddProblemDetails();
var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
builder.Services.AddCors(o => o.AddDefaultPolicy(p => { if (origins.Length > 0) p.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod(); }));
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = 429;
    o.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? ctx.Connection.RemoteIpAddress?.ToString() ?? "anonymous",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 120, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
});
var app = builder.Build(); app.UseExceptionHandler(); app.UseCors(); app.UseAuthentication(); app.UseAuthorization(); app.UseRateLimiter();
app.MapGet("/health/live", () => Results.Ok(new { status = "up" })).AllowAnonymous();
app.MapGet("/health/ready", async (NpgsqlDataSource db, CancellationToken ct) =>
{
    await using var connection = await db.OpenConnectionAsync(ct);
    await using var command = new NpgsqlCommand("SELECT to_regclass('nutrition.assessments') IS NOT NULL", connection);
    return (bool)(await command.ExecuteScalarAsync(ct))! ? Results.Ok(new { status = "ready" }) : Results.StatusCode(503);
}).AllowAnonymous();
app.MapControllers(); app.Run();
public partial class Program;
