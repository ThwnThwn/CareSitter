using System.Security.Claims;
using System.Text;
using System.Threading.RateLimiting;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Infrastructure;
using CareSitter.Nutrition.Controllers.Grpc;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);
var localDemoCatalog = LocalDemoCatalogOptions.From(builder.Configuration, builder.Environment);
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
var gatewayKey = builder.Configuration["Gateway:ServiceKey"] ?? "";
if (gatewayKey.Length > 0 && gatewayKey.Length is not (>= 32 and <= 256))
    throw new InvalidOperationException("Gateway:ServiceKey must contain 32..256 characters.");
builder.Services.AddGrpc(o =>
{
    o.MaxReceiveMessageSize = 32768;
    o.MaxSendMessageSize = 1024 * 1024;
    o.Interceptors.Add<NutritionRpcInterceptor>();
});
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
builder.Services.AddAuthorization(); builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, HttpCurrentUser>();
builder.Services.AddSingleton<INutritionFeatures, NutritionFeatures>();
builder.Services.AddSingleton(localDemoCatalog);
builder.Services.AddSingleton(_ => NpgsqlDataSource.Create(builder.Configuration.GetConnectionString("Nutrition")
    ?? throw new InvalidOperationException("ConnectionStrings:Nutrition is required.")));
builder.Services.AddScoped<INutritionStore, NutritionStore>();
builder.Services.AddSingleton<IValidateOptions<HealthParserOptions>, HealthParserOptionsValidator>();
builder.Services.AddOptions<HealthParserOptions>()
    .Bind(builder.Configuration.GetSection(HealthParserOptions.SectionName))
    .ValidateOnStart();
builder.Services.AddSingleton<HealthParserRuntimeGuard>();
builder.Services.AddScoped<UnconfiguredHealthParser>();
builder.Services.AddHttpClient<OpenAiHealthDescriptionParser>((services, client) =>
{
    var options = services.GetRequiredService<IOptions<HealthParserOptions>>().Value;
    client.BaseAddress = new Uri(options.EffectiveBaseUrl.TrimEnd('/') + '/');
    client.Timeout = Timeout.InfiniteTimeSpan;
});
builder.Services.AddHttpClient<GeminiHealthDescriptionParser>((services, client) =>
{
    var options = services.GetRequiredService<IOptions<HealthParserOptions>>().Value;
    client.BaseAddress = new Uri(options.EffectiveBaseUrl.TrimEnd('/') + '/');
    client.Timeout = Timeout.InfiniteTimeSpan;
});
builder.Services.AddScoped<IHealthDescriptionParser>(services =>
{
    var options = services.GetRequiredService<IOptions<HealthParserOptions>>().Value;
    if (!options.Enabled) return services.GetRequiredService<UnconfiguredHealthParser>();
    return HealthParserProviders.IsGemini(options.Provider)
        ? services.GetRequiredService<GeminiHealthDescriptionParser>()
        : services.GetRequiredService<OpenAiHealthDescriptionParser>();
});
builder.Services.AddScoped<AssessmentProcessor>();
builder.Services.AddScoped<NutritionWriteScope>();
builder.Services.AddScoped<MealPreparationService>();
builder.Services.AddHttpClient<IPeopleHealthClient, PeopleHealthClient>(client =>
{
    client.BaseAddress = new Uri(peopleUrl.TrimEnd('/') + '/');
    client.DefaultRequestHeaders.Add("X-Nutrition-Service-Key", serviceKey);
    client.Timeout = TimeSpan.FromSeconds(5);
}).ConfigurePrimaryHttpMessageHandler(() =>
    InternalCertificateTrust.CreateHandler(builder.Configuration["People:TrustedRootCertificatePath"]));
builder.Services.AddHttpClient<IIdentitySessionClient, IdentitySessionClient>(client =>
{
    client.BaseAddress = new Uri(peopleUrl.TrimEnd('/') + '/');
    client.Timeout = TimeSpan.FromSeconds(5);
}).ConfigurePrimaryHttpMessageHandler(() =>
    InternalCertificateTrust.CreateHandler(builder.Configuration["People:TrustedRootCertificatePath"]));
builder.Services.AddHostedService<NutritionWorker>();
builder.Services.AddMediatR(c => c.RegisterServicesFromAssemblyContaining<AssessmentProcessor>());
builder.Services.AddControllers(); builder.Services.AddExceptionHandler<NutritionExceptionHandler>();
builder.Services.AddProblemDetails();
var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
builder.Services.AddCors(o => o.AddDefaultPolicy(p => { if (origins.Length > 0) p.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod(); }));
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = 429;
    o.OnRejected = (context, _) =>
    {
        if (context.HttpContext.Request.ContentType?.StartsWith("application/grpc", StringComparison.OrdinalIgnoreCase) == true)
            NutritionGatewayAuthenticationMiddleware.GrpcFailure(context.HttpContext, "8", "nutrition.rate_limited");
        return ValueTask.CompletedTask;
    };
    o.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? ctx.Connection.RemoteIpAddress?.ToString() ?? "anonymous",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 120, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
});
var app = builder.Build(); app.UseExceptionHandler(); app.UseCors();
app.UseMiddleware<NutritionGatewayAuthenticationMiddleware>();
app.UseAuthentication(); app.UseAuthorization(); app.UseRateLimiter();
app.MapGet("/health/live", () => Results.Ok(new { status = "up" })).AllowAnonymous();
app.MapGet("/health/ready", async (NpgsqlDataSource db, CancellationToken ct) =>
{
    return await NutritionDatabaseReadiness.CheckAsync(db, ct)
        ? Results.Ok(new { status = "ready" }) : Results.StatusCode(503);
}).AllowAnonymous();
app.MapControllers(); app.MapGrpcService<NutritionRpcService>(); app.Run();
public partial class Program;
