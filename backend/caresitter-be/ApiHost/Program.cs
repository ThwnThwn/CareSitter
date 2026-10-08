using CareSitter.ApiHost.OpenApi;
using CareSitter.ApiHost.Persistence;
using CareSitter.ApiHost.Routing;
using CareSitter.ApiHost.Routing.Geoapify;
using CareSitter.ApiHost.Routing.OpenRouteService;
using CareSitter.ApiHost.Security;
using CareSitter.Infrastructure.Auth;
using CareSitter.Infrastructure.Email;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Infrastructure.Modules;
using CareSitter.Infrastructure.Security;
using CareSitter.Infrastructure.Time;
using CareSitter.Infrastructure.Media;
using CareSitter.Modules.Booking;
using CareSitter.Contracts.Services;
using Hangfire;
using Hangfire.InMemory;
using Hangfire.PostgreSql;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;
using Npgsql;
using StackExchange.Redis;
using System.Text.Json;
using CareSitter.Contracts.Services.Routing;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Http.Features;
using CareSitter.Messaging.Kafka;

// Nap file .env (neu co) thanh bien moi truong TRUOC khi build configuration.
// TraversePath() tim .env tu thu muc hien tai len cac thu muc cha (repo root).
// ASP.NET map "ConnectionStrings__CareSitter" -> "ConnectionStrings:CareSitter".
DotNetEnv.Env.TraversePath().Load();

var builder = WebApplication.CreateBuilder(args);
// Network contracts remain independent of the existing in-process MediatR events.
builder.Services.AddKafkaMessaging(builder.Configuration, (events, options) =>
{
    events.Add<CareSitter.Messaging.Contracts.Events.NotificationRequested>(
        "caresitter.notifications.requested", 1, options.NotificationsTopic);
    events.Add<CareSitter.Messaging.Contracts.Events.PaymentSucceeded>(
        "caresitter.payments.succeeded", 1, options.PaymentsTopic);
    events.Add<CareSitter.Messaging.Contracts.Events.MealPlanSelected>(
        "caresitter.nutrition.mealplan-selected", 1, options.NutritionTopic);
});
builder.Services.AddAuthentication().AddScheme<Microsoft.AspNetCore.Authentication.AuthenticationSchemeOptions,
    MessagingServiceAuthenticationHandler>("MessagingService", _ => { });
if (builder.Configuration["KAFKA_FLOW_NOTIFICATIONS_ENABLED"]?.Equals("true", StringComparison.OrdinalIgnoreCase) == true &&
    (builder.Configuration["KAFKA_INTERNAL_SERVICE_KEY"]?.Length is not (>= 32 and <= 256)))
    throw new InvalidOperationException("KAFKA_INTERNAL_SERVICE_KEY must contain 32..256 characters.");
// Hosting request diagnostics include query strings (OAuth codes/state).
// Keep warnings/errors without logging authentication callback URLs.
builder.Logging.AddFilter("Microsoft.AspNetCore.Hosting.Diagnostics", LogLevel.Warning);
builder.WebHost.ConfigureKestrel(options =>
    options.Limits.MaxRequestBodySize = 11 * 1024 * 1024);

DeploymentConfiguration.ValidatePublicEndpoints(
    builder.Configuration,
    builder.Environment.IsDevelopment());

var forwardedHeadersOptions = DeploymentConfiguration.CreateForwardedHeadersOptions(
    builder.Configuration,
    builder.Environment.IsProduction());
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = forwardedHeadersOptions.ForwardedHeaders;
    options.ForwardLimit = forwardedHeadersOptions.ForwardLimit;
    options.KnownProxies.Clear();
    options.KnownNetworks.Clear();
    foreach (var proxy in forwardedHeadersOptions.KnownProxies)
        options.KnownProxies.Add(proxy);
    foreach (var network in forwardedHeadersOptions.KnownNetworks)
        options.KnownNetworks.Add(network);
});

var encryptionKey = builder.Configuration["Encryption:EncryptionKey"];
if (string.IsNullOrWhiteSpace(encryptionKey) || encryptionKey.Length < 32)
    throw new InvalidOperationException(
        "Encryption:EncryptionKey must be configured with at least 32 characters.");

var configuredOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? [];
var allowedOrigins = configuredOrigins
    .Where(x => !string.IsNullOrWhiteSpace(x))
    .Select(x => x.Trim().TrimEnd('/'))
    .ToHashSet(StringComparer.OrdinalIgnoreCase);
if (!builder.Environment.IsDevelopment() && allowedOrigins.Count == 0)
    throw new InvalidOperationException(
        "Cors:AllowedOrigins must contain at least one explicit origin outside Development.");

// HttpClientFactory logs request URLs at Information by default. Some providers
// require API keys in query strings, so suppress those framework logs.
builder.Logging.AddFilter("System.Net.Http.HttpClient", LogLevel.Warning);

builder.Services.Configure<RoutingOptions>(builder.Configuration.GetSection("Routing"));
builder.Services.AddMetrics();
builder.Services.AddSingleton<RoutingMetrics>();
builder.Services.AddHttpClient<GeoapifyRouteMatrixService>((sp, client) =>
{
    var config = sp.GetRequiredService<IOptions<RoutingOptions>>().Value.Geoapify;
    client.BaseAddress = new Uri(string.IsNullOrWhiteSpace(config.BaseUrl)
        ? "https://api.geoapify.com"
        : config.BaseUrl);
});
builder.Services.AddHttpClient<OpenRouteServiceMatrixService>((sp, client) =>
{
    var config = sp.GetRequiredService<IOptions<RoutingOptions>>().Value.OpenRouteService;
    client.BaseAddress = new Uri(string.IsNullOrWhiteSpace(config.BaseUrl)
        ? "https://api.openrouteservice.org"
        : config.BaseUrl);
    var apiKey = sp.GetRequiredService<IConfiguration>()["ORS_API_KEY"]
        ?? sp.GetRequiredService<IConfiguration>()["OpenRouteService:ApiKey"];
    if (!string.IsNullOrWhiteSpace(apiKey))
        client.DefaultRequestHeaders.Add("Authorization", apiKey);
});
builder.Services.AddScoped<ResilientRouteMatrixService>();
builder.Services.AddScoped<IRouteMatrixService>(sp =>
{
    var config = sp.GetRequiredService<IOptions<RoutingOptions>>().Value;
    if (config.EnableBackupProvider || string.Equals(config.Provider, "Resilient", StringComparison.OrdinalIgnoreCase))
        return sp.GetRequiredService<ResilientRouteMatrixService>();
    if (string.Equals(config.Provider, "OpenRouteService", StringComparison.OrdinalIgnoreCase))
        return sp.GetRequiredService<OpenRouteServiceMatrixService>();
    return sp.GetRequiredService<GeoapifyRouteMatrixService>();
});
builder.Services.AddExceptionHandler<RoutingExceptionHandler>();
builder.Services.AddExceptionHandler<PersistenceConcurrencyExceptionHandler>();

// --- Shared infrastructure services ---
builder.Services.AddSingleton<IClock, SystemClock>();
builder.Services.AddSingleton(new EncryptionOptions
{
    EncryptionKey = encryptionKey
});
builder.Services.AddSingleton<IEncryptionService, AesEncryptionService>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, HttpContextCurrentUser>();

builder.Services.AddCloudinaryMediaService(builder.Configuration);

// Đăng ký cấu hình và các dịch vụ xác thực JWT
builder.Services.AddJwtAuthentication(builder.Configuration);
builder.Services.AddGoogleWebAuthentication(builder.Configuration, builder.Environment.IsDevelopment());

// Đăng ký Email sender (Gmail SMTP) để gửi OTP
builder.Services.AddEmailSender(builder.Configuration);

// Đăng ký Redis Distributed Cache để lưu trữ OTP
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration["Redis:ConnectionString"];
    options.InstanceName = "caresitter:"; // Prefix cho tất cả key trong Redis
});

// Liveness chỉ xác nhận process đang chạy; readiness kiểm tra các dependency
// bắt buộc để API có thể phục vụ request thật.
builder.Services.AddHealthChecks()
    .AddAsyncCheck("postgres", async cancellationToken =>
    {
        var connectionString = builder.Configuration.GetConnectionString("CareSitter");
        if (string.IsNullOrWhiteSpace(connectionString))
            return HealthCheckResult.Unhealthy("ConnectionStrings:CareSitter is not configured.");

        try
        {
            await using var connection = new NpgsqlConnection(connectionString);
            await connection.OpenAsync(cancellationToken);
            await using var command = new NpgsqlCommand("SELECT 1", connection);
            await command.ExecuteScalarAsync(cancellationToken);
            return HealthCheckResult.Healthy();
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("PostgreSQL is unavailable.", ex);
        }
    }, timeout: TimeSpan.FromSeconds(5))
    .AddAsyncCheck("redis", async cancellationToken =>
    {
        var connectionString = builder.Configuration["Redis:ConnectionString"];
        if (string.IsNullOrWhiteSpace(connectionString))
            return HealthCheckResult.Unhealthy("Redis:ConnectionString is not configured.");

        try
        {
            var options = ConfigurationOptions.Parse(connectionString);
            options.AbortOnConnectFail = false;
            using var connection = await ConnectionMultiplexer.ConnectAsync(options);
            var pingTask = connection.GetDatabase().PingAsync();
            var completedTask = await Task.WhenAny(
                pingTask,
                Task.Delay(TimeSpan.FromSeconds(3), cancellationToken));

            if (completedTask != pingTask)
                return HealthCheckResult.Unhealthy("Redis ping timed out.");

            var latency = await pingTask;
            return HealthCheckResult.Healthy(data: new Dictionary<string, object>
            {
                ["latencyMs"] = Math.Round(latency.TotalMilliseconds, 2)
            });
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Redis is unavailable.", ex);
        }
    }, timeout: TimeSpan.FromSeconds(5));

// --- Module discovery: quet tat ca IModule trong cac assembly module ---
var moduleAssemblies = new[]
{
    typeof(BookingModule).Assembly,
    typeof(CareSitter.Modules.Identity.IdentityModule).Assembly,
    typeof(CareSitter.Modules.People.PeopleModule).Assembly,
    typeof(CareSitter.Modules.Catalog.CatalogModule).Assembly,
    typeof(CareSitter.Modules.Payments.PaymentsModule).Assembly,
    typeof(CareSitter.Modules.Support.SupportModule).Assembly,
    typeof(CareSitter.Modules.Promotion.PromotionModule).Assembly
};
builder.Services.AddModules(builder.Configuration, moduleAssemblies);
builder.Services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<
    CareSitter.ApiHost.Application.Admin.GetAdminDashboardQuery>());

// --- Cross-cutting ---
builder.Services.AddProblemDetails();
builder.Services.AddControllers(); // Hỗ trợ Controller-based API
builder.Services.Configure<FormOptions>(options =>
    options.MultipartBodyLengthLimit = 11 * 1024 * 1024);
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddCareSitterSwagger();
builder.Services.AddRateLimiter(options =>
{
    options.AddPolicy("auth-recovery", context => RateLimitPartition.GetFixedWindowLimiter(
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown", _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 20, Window = TimeSpan.FromMinutes(10), QueueLimit = 0, AutoReplenishment = true
        }));
    options.AddPolicy("booking-gps", context => RateLimitPartition.GetSlidingWindowLimiter(
        context.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
            ?? context.User.FindFirst("sub")?.Value ?? context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new SlidingWindowRateLimiterOptions
        {
            PermitLimit = 30, Window = TimeSpan.FromMinutes(1), SegmentsPerWindow = 6,
            QueueLimit = 0, AutoReplenishment = true
        }));
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.OnRejected = async (context, ct) =>
    {
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
        context.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
            ?? context.User.FindFirst("sub")?.Value ?? Partition(context),
        _ => new SlidingWindowRateLimiterOptions
        {
            PermitLimit = 120, Window = TimeSpan.FromMinutes(1), SegmentsPerWindow = 6,
            QueueLimit = 0, AutoReplenishment = true
        }));
});
builder.Services.AddCors(options =>
    options.AddPolicy("crm", policy => policy
        .SetIsOriginAllowed(origin =>
        {
            var normalized = origin.TrimEnd('/');
            if (allowedOrigins.Contains(normalized)) return true;
            if (!builder.Environment.IsDevelopment()) return false;
            return Uri.TryCreate(origin, UriKind.Absolute, out var uri)
                && uri.Scheme is "http" or "https"
                && uri.Host is "localhost" or "127.0.0.1" or "10.0.2.2";
        })
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials()));

// --- SignalR ---
// AllowCredentials đã bật ở CORS → WebSocket hoạt động.
// JWT cho SignalR WebSocket: browser không gửi được header,
// nên phải đọc token từ query string ?access_token=...
builder.Services.AddSignalR();
builder.Services.AddSingleton<RealtimeSessionRegistry>();
builder.Services.AddHostedService<RealtimeSessionWatchdog>();
builder.Services.PostConfigure<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme, options =>
{
    var originalOnMessageReceived = options.Events?.OnMessageReceived;
    options.Events ??= new JwtBearerEvents();
    options.Events.OnMessageReceived = context =>
    {
        var accessToken = context.Request.Query["access_token"];
        var path = context.HttpContext.Request.Path;
        if (!string.IsNullOrEmpty(accessToken) &&
            path.StartsWithSegments("/hubs", System.StringComparison.OrdinalIgnoreCase))
        {
            context.Token = accessToken;
        }
        return originalOnMessageReceived != null
            ? originalOnMessageReceived(context)
            : Task.CompletedTask;
    };
});

// --- Hangfire ---
// Production must use shared PostgreSQL storage so jobs survive restarts and
// multiple API instances coordinate through Hangfire's distributed locks.
var usePostgresHangfire = DeploymentConfiguration.UsePostgresHangfire(
    builder.Configuration,
    builder.Environment.IsProduction());
var hangfireConnectionString = builder.Configuration.GetConnectionString("CareSitter");

builder.Services.AddHangfire(config =>
{
    config.SetDataCompatibilityLevel(CompatibilityLevel.Version_180)
          .UseSimpleAssemblyNameTypeSerializer()
          .UseRecommendedSerializerSettings();

    if (usePostgresHangfire)
    {
        config.UsePostgreSqlStorage(options => options.UseNpgsqlConnection(hangfireConnectionString!));
    }
    else
    {
        // InMemory: jobs mất khi restart — chấp nhận được cho development.
        config.UseInMemoryStorage();
    }
});
builder.Services.AddHangfireServer(options =>
{
    options.ServerName = $"{Environment.MachineName}:{Guid.NewGuid():N}";
    options.WorkerCount = 2;
    options.Queues = new[] { "default", "booking" };
});
var app = builder.Build();

if (usePostgresHangfire)
{
    // Fail before accepting requests if persistent job storage is unreachable.
    try
    {
        await using var connection = new NpgsqlConnection(hangfireConnectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand("SELECT 1", connection);
        await command.ExecuteScalarAsync();
    }
    catch (Exception ex)
    {
        throw new InvalidOperationException(
            "Hangfire PostgreSQL storage is unavailable; refusing to start the API.", ex);
    }
}

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
    app.UseHttpsRedirection();
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

app.MapGet("/health", () => Results.Ok(new { status = "ok" })).WithTags("System");
app.MapGet("/health/live", () => Results.Ok(new { status = "ok" })).WithTags("System");
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    ResponseWriter = async (context, report) =>
    {
        context.Response.ContentType = "application/json";
        var payload = new
        {
            status = report.Status.ToString(),
            totalDurationMs = Math.Round(report.TotalDuration.TotalMilliseconds, 2),
            checks = report.Entries.ToDictionary(
                entry => entry.Key,
                entry => new
                {
                    status = entry.Value.Status.ToString(),
                    description = entry.Value.Description,
                    durationMs = Math.Round(entry.Value.Duration.TotalMilliseconds, 2),
                    data = entry.Value.Data
                })
        };
        await context.Response.WriteAsync(JsonSerializer.Serialize(payload));
    }
}).WithTags("System");

// --- SignalR Hub ---
app.MapHub<CareTrackingHub>("/hubs/care-tracking", options => options.CloseOnAuthenticationExpiration = true);

// --- Hangfire Dashboard ---
// Dev: localhost-only (không cần JWT).
// Prod: yêu cầu JWT với role ADMIN — ops xem job qua /hangfire sau khi login admin.
app.UseHangfireDashboard("/hangfire", new DashboardOptions
{
    DashboardTitle = "CareSitter — Hangfire Jobs",
    Authorization = new[]
    {
        new HangfireDashboardAuthFilter(app.Environment)
    },
    // Chỉ cho phép xem, không cho trigger/delete job từ Dashboard trong Production
    IsReadOnlyFunc = ctx => !app.Environment.IsDevelopment(),
});

// --- Đăng ký Hangfire Recurring Jobs ---
// Every instance writes the same stable recurring IDs into the shared PostgreSQL
// store; Hangfire's distributed lock prevents duplicate scheduling across servers.
RecurringJob.RemoveIfExists("expire-pending-payments");
RecurringJob.AddOrUpdate<CareSitter.Modules.Booking.Infrastructure.LiveLocationCleanupJob>(
    recurringJobId: "cleanup-live-locations", methodCall: job => job.RunAsync(CancellationToken.None),
    cronExpression: "*/5 * * * *", queue: "booking");
RecurringJob.AddOrUpdate<IBookingJobsService>(
    recurringJobId: "reconcile-pending-payments",
    methodCall: svc => svc.ReconcilePendingPaymentsAsync(),
    cronExpression: "* * * * *",   // Mỗi 1 phút
    queue: "booking");

RecurringJob.AddOrUpdate<IBookingJobsService>(
    recurringJobId: "alert-late-checkins",
    methodCall: svc => svc.AlertLateCheckinsAsync(),
    cronExpression: "*/5 * * * *", // Mỗi 5 phút
    queue: "booking");

RecurringJob.AddOrUpdate<IBookingJobsService>(
    recurringJobId: "auto-request-checkout-expired-shifts",
    methodCall: svc => svc.AutoRequestCheckoutExpiredShiftsAsync(),
    cronExpression: "*/5 * * * *", // Mỗi 5 phút
    queue: "booking");

RecurringJob.AddOrUpdate<IBookingJobsService>(
    recurringJobId: "auto-confirm-pending-checkouts",
    methodCall: svc => svc.AutoConfirmPendingCheckoutsAsync(),
    cronExpression: "*/15 * * * *", // Mỗi 15 phút
    queue: "booking");

RecurringJob.AddOrUpdate<IBookingJobsService>(
    recurringJobId: "expand-expired-booking-offers",
    methodCall: svc => svc.ExpandExpiredBookingOffersAsync(),
    cronExpression: "* * * * *", // Mỗi 1 phút
    queue: "booking");

RecurringJob.AddOrUpdate<IBookingJobsService>(
    recurringJobId: "refund-unmatched-bookings",
    methodCall: svc => svc.RefundUnmatchedBookingsAsync(),
    cronExpression: "* * * * *", // Retry nhanh, refund idempotent
    queue: "booking");

RecurringJob.AddOrUpdate<IBookingJobsService>(
    recurringJobId: "release-mature-settlements",
    methodCall: svc => svc.ReleaseMatureSettlementsAsync(),
    cronExpression: "*/5 * * * *", // Mỗi 5 phút, idempotent theo booking
    queue: "booking");

// --- Map Controllers ---
app.MapControllers();
app.MapGoogleWebAuthentication();

// --- Map endpoint cua tat ca module (Minimal API) ---
app.MapModuleEndpoints();

// Map shared media endpoints
CareSitter.ApiHost.Endpoints.MediaEndpoints.Map(app);

app.Run();

public partial class Program;
