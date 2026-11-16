using CareSitter.ApiHost.Application.Admin;
using CareSitter.ApiHost.ChatFirestore;
using CareSitter.ApiHost.Health;
using CareSitter.ApiHost.Nutrition;
using CareSitter.ApiHost.OpenApi;
using CareSitter.ApiHost.Persistence;
using CareSitter.ApiHost.Realtime;
using CareSitter.ApiHost.Routing;
using CareSitter.ApiHost.Security;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Auth;
using CareSitter.Infrastructure.Email;
using CareSitter.Infrastructure.Media;
using CareSitter.Infrastructure.Modules;
using CareSitter.Infrastructure.Security;
using CareSitter.Infrastructure.Time;
using CareSitter.Messaging.Contracts.Events;
using CareSitter.Messaging.Kafka;
using CareSitter.Modules.Booking;
using CareSitter.Modules.Catalog;
using CareSitter.Modules.Identity;
using CareSitter.Modules.Payments;
using CareSitter.Modules.People;
using CareSitter.Modules.Promotion;
using CareSitter.Modules.Support;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.HttpOverrides;
using AuthenticationSchemeOptions = Microsoft.AspNetCore.Authentication.AuthenticationSchemeOptions;

namespace CareSitter.ApiHost.Startup;

internal static class ApiServiceExtensions
{
    private const int RequestBodyLimit = 11 * 1024 * 1024;

    public static WebApplicationBuilder CreateBuilder(string[] args)
    {
        // Load .env before the host reads environment variables into configuration.
        var envFile = Environment.GetEnvironmentVariable("CARESITTER_ENV_FILE");
        if (string.IsNullOrWhiteSpace(envFile))
            DotNetEnv.Env.NoClobber().TraversePath().Load();
        else if (File.Exists(envFile))
            DotNetEnv.Env.NoClobber().Load(envFile);
        else
            throw new InvalidOperationException("Configured CARESITTER_ENV_FILE does not exist.");

        return WebApplication.CreateBuilder(args);
    }

    public static void AddCareSitterApi(this WebApplicationBuilder builder)
    {
        if (builder.Configuration.GetValue<bool>("SupportChat:PushEnabled") &&
            (!builder.Configuration.GetValue<bool>("KAFKA_ENABLED") ||
             !builder.Configuration.GetValue<bool>("KAFKA_FLOW_NOTIFICATIONS_ENABLED")))
            throw new InvalidOperationException(
                "SupportChat push requires Kafka and notification flow to be enabled.");

        builder.AddNutritionGateway();
        builder.Services.AddChatFirestore(builder.Configuration);
        AddMessaging(builder.Services, builder.Configuration);
        AddInternalAuthentication(builder.Services, builder.Configuration);

        // Hosting request diagnostics include query strings (OAuth codes/state).
        // Keep warnings/errors without logging authentication callback URLs.
        builder.Logging.AddFilter("Microsoft.AspNetCore.Hosting.Diagnostics", LogLevel.Warning);
        builder.WebHost.ConfigureKestrel(options =>
            options.Limits.MaxRequestBodySize = RequestBodyLimit);

        DeploymentConfiguration.ValidatePublicEndpoints(
            builder.Configuration,
            builder.Environment.IsDevelopment());
        ConfigureForwardedHeaders(builder);

        var encryptionKey = builder.Configuration["Encryption:EncryptionKey"];
        if (string.IsNullOrWhiteSpace(encryptionKey) || encryptionKey.Length < 32)
            throw new InvalidOperationException(
                "Encryption:EncryptionKey must be configured with at least 32 characters.");

        var allowedOrigins = GetAllowedOrigins(builder);

        // HttpClientFactory logs request URLs at Information by default. Some providers
        // require API keys in query strings, so suppress those framework logs.
        builder.Logging.AddFilter("System.Net.Http.HttpClient", LogLevel.Warning);

        builder.Services.AddApiRouting(builder.Configuration);
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
        builder.Services.AddApiHealthChecks(builder.Configuration);

        AddModules(builder.Services, builder.Configuration);

        builder.Services.AddProblemDetails();
        builder.Services.AddControllers(); // Hỗ trợ Controller-based API
        builder.Services.Configure<FormOptions>(options =>
            options.MultipartBodyLengthLimit = RequestBodyLimit);
        builder.Services.AddEndpointsApiExplorer();
        builder.Services.AddCareSitterSwagger();
        builder.Services.AddApiRateLimiting();
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
        builder.Services.AddApiRealtime();
    }

    private static void AddMessaging(IServiceCollection services, IConfiguration configuration)
    {
        // Network contracts remain independent of the existing in-process MediatR events.
        services.AddKafkaMessaging(configuration, (events, options) =>
        {
            events.Add<NotificationRequested>(
                "caresitter.notifications.requested", 1, options.NotificationsTopic);
            events.Add<PaymentSucceeded>(
                "caresitter.payments.succeeded", 1, options.PaymentsTopic);
            events.Add<MealPlanSelected>(
                "caresitter.nutrition.mealplan-selected", 1, options.NutritionTopic);
            events.Add<BeneficiaryDeleted>(
                "caresitter.people.beneficiary-deleted", 1, options.NutritionTopic);
        });
    }

    private static void AddInternalAuthentication(IServiceCollection services, IConfiguration configuration)
    {
        services.AddAuthentication().AddScheme<AuthenticationSchemeOptions,
            MessagingServiceAuthenticationHandler>("MessagingService", _ => { });
        services.AddAuthentication().AddScheme<AuthenticationSchemeOptions,
            NutritionServiceAuthenticationHandler>("NutritionService", _ => { });

        if (configuration["NutritionIntegration:ServiceKey"] is { Length: > 0 } nutritionServiceKey &&
            nutritionServiceKey.Length is not (>= 32 and <= 256))
            throw new InvalidOperationException("NutritionIntegration:ServiceKey must contain 32..256 characters.");

        if (configuration["KAFKA_FLOW_NOTIFICATIONS_ENABLED"]?.Equals("true", StringComparison.OrdinalIgnoreCase) == true &&
            (configuration["KAFKA_INTERNAL_SERVICE_KEY"]?.Length is not (>= 32 and <= 256)))
            throw new InvalidOperationException("KAFKA_INTERNAL_SERVICE_KEY must contain 32..256 characters.");
    }

    private static void ConfigureForwardedHeaders(WebApplicationBuilder builder)
    {
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
    }

    private static HashSet<string> GetAllowedOrigins(WebApplicationBuilder builder)
    {
        var configuredOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins")
            .Get<string[]>() ?? [];
        var allowedOrigins = configuredOrigins
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim().TrimEnd('/'))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        if (!builder.Environment.IsDevelopment() && allowedOrigins.Count == 0)
            throw new InvalidOperationException(
                "Cors:AllowedOrigins must contain at least one explicit origin outside Development.");

        return allowedOrigins;
    }

    private static void AddModules(IServiceCollection services, IConfiguration configuration)
    {
        var moduleAssemblies = new[]
        {
            typeof(BookingModule).Assembly,
            typeof(IdentityModule).Assembly,
            typeof(PeopleModule).Assembly,
            typeof(CatalogModule).Assembly,
            typeof(PaymentsModule).Assembly,
            typeof(SupportModule).Assembly,
            typeof(PromotionModule).Assembly
        };
        services.AddModules(configuration, moduleAssemblies);
        services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<GetAdminDashboardQuery>());
    }
}
