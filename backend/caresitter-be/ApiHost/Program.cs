using CareSitter.ApiHost.Jobs;
using CareSitter.ApiHost.OpenApi;
using CareSitter.ApiHost.Security;
using CareSitter.Infrastructure.Auth;
using CareSitter.Infrastructure.Email;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Infrastructure.Modules;
using CareSitter.Infrastructure.Security;
using CareSitter.Infrastructure.Time;
using CareSitter.Infrastructure.Media;
using CareSitter.Modules.Booking;
using Hangfire;
using Hangfire.InMemory;
using Hangfire.PostgreSql;
using Microsoft.AspNetCore.Authentication.JwtBearer;

// Nap file .env (neu co) thanh bien moi truong TRUOC khi build configuration.
// TraversePath() tim .env tu thu muc hien tai len cac thu muc cha (repo root).
// ASP.NET map "ConnectionStrings__CareSitter" -> "ConnectionStrings:CareSitter".
DotNetEnv.Env.TraversePath().Load();

var builder = WebApplication.CreateBuilder(args);

// --- Shared infrastructure services ---
builder.Services.AddSingleton<IClock, SystemClock>();
builder.Services.AddSingleton(new EncryptionOptions
{
    EncryptionKey = builder.Configuration["Encryption:EncryptionKey"] ?? "dev-only-change-me-please-32bytes!"
});
builder.Services.AddSingleton<IEncryptionService, AesEncryptionService>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, HttpContextCurrentUser>();

builder.Services.AddCloudinaryMediaService(builder.Configuration);

// Đăng ký cấu hình và các dịch vụ xác thực JWT
builder.Services.AddJwtAuthentication(builder.Configuration);

// Đăng ký Email sender (Gmail SMTP) để gửi OTP
builder.Services.AddEmailSender(builder.Configuration);

// Đăng ký Redis Distributed Cache để lưu trữ OTP
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration["Redis:ConnectionString"];
    options.InstanceName = "caresitter:"; // Prefix cho tất cả key trong Redis
});

// --- Module discovery: quet tat ca IModule trong cac assembly module ---
var moduleAssemblies = new[]
{
    typeof(BookingModule).Assembly,
    typeof(CareSitter.Modules.Identity.IdentityModule).Assembly,
    typeof(CareSitter.Modules.People.PeopleModule).Assembly,
    typeof(CareSitter.Modules.Catalog.CatalogModule).Assembly,
    typeof(CareSitter.Modules.Payments.PaymentsModule).Assembly,
    typeof(CareSitter.Modules.Support.SupportModule).Assembly
};
builder.Services.AddModules(builder.Configuration, moduleAssemblies);

// --- Cross-cutting ---
builder.Services.AddProblemDetails();
builder.Services.AddControllers(); // Hỗ trợ Controller-based API
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddCareSitterSwagger();
builder.Services.AddCors(options =>
    options.AddPolicy("crm", policy => policy
        // Cho phép tất cả localhost (Flutter Web chạy port ngẫu nhiên)
        // và 10.0.2.2 (Android emulator trỏ về host machine)
        .SetIsOriginAllowed(origin =>
        {
            var uri = new Uri(origin);
            return uri.Host is "localhost" or "127.0.0.1" or "10.0.2.2";
        })
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials()));

// --- SignalR ---
// AllowCredentials đã bật ở CORS → WebSocket hoạt động.
// JWT cho SignalR WebSocket: browser không gửi được header,
// nên phải đọc token từ query string ?access_token=...
builder.Services.AddSignalR();
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
// Development: dùng InMemory (không cần PostgreSQL kết nối lúc startup).
// Production: đặt HANGFIRE_USE_POSTGRES=true để dùng PostgreSQL storage (durable).
var usePostgresHangfire = builder.Configuration["HANGFIRE_USE_POSTGRES"] == "true"
    && !string.IsNullOrEmpty(builder.Configuration.GetConnectionString("CareSitter"));

builder.Services.AddHangfire(config =>
{
    config.SetDataCompatibilityLevel(CompatibilityLevel.Version_180)
          .UseSimpleAssemblyNameTypeSerializer()
          .UseRecommendedSerializerSettings();

    if (usePostgresHangfire)
    {
        var hangfireConnStr = builder.Configuration.GetConnectionString("CareSitter");
        config.UsePostgreSqlStorage(options => options.UseNpgsqlConnection(hangfireConnStr));
    }
    else
    {
        // InMemory: jobs mất khi restart — chấp nhận được cho development.
        config.UseInMemoryStorage();
    }
});
builder.Services.AddHangfireServer(options =>
{
    options.WorkerCount = 2;
    options.Queues = new[] { "default", "booking" };
});
builder.Services.AddScoped<BookingJobsService>();


var app = builder.Build();

app.UseExceptionHandler();
app.UseStatusCodePages();

if (app.Environment.IsDevelopment())
{
    app.UseCareSitterSwagger();
}

app.UseCors("crm");

// Serve static files từ wwwroot (chỉ dùng khi Development — vd: google-token-tester.html)
if (app.Environment.IsDevelopment())
    app.UseStaticFiles();

// Sử dụng Middleware xác thực (Authentication) và ủy quyền (Authorization)
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(new { status = "ok" })).WithTags("System");

// --- SignalR Hub ---
app.MapHub<CareTrackingHub>("/hubs/care-tracking");

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
RecurringJob.AddOrUpdate<BookingJobsService>(
    recurringJobId: "expire-pending-payments",
    methodCall: svc => svc.ExpirePendingPaymentsAsync(),
    cronExpression: "* * * * *",   // Mỗi 1 phút
    queue: "booking");

RecurringJob.AddOrUpdate<BookingJobsService>(
    recurringJobId: "alert-late-checkins",
    methodCall: svc => svc.AlertLateCheckinsAsync(),
    cronExpression: "*/5 * * * *", // Mỗi 5 phút
    queue: "booking");

RecurringJob.AddOrUpdate<BookingJobsService>(
    recurringJobId: "auto-complete-shifts",
    methodCall: svc => svc.AutoCompleteExpiredShiftsAsync(),
    cronExpression: "*/5 * * * *", // Mỗi 5 phút
    queue: "booking");

// --- Map Controllers ---
app.MapControllers();

// --- Map endpoint cua tat ca module (Minimal API) ---
app.MapModuleEndpoints();

// Map shared media endpoints
CareSitter.ApiHost.Endpoints.MediaEndpoints.Map(app);

app.Run();

public partial class Program;
