using CareSitter.ApiHost.OpenApi;
using CareSitter.ApiHost.Security;
using CareSitter.Infrastructure.Auth;
using CareSitter.Infrastructure.Email;
using CareSitter.Infrastructure.Modules;
using CareSitter.Infrastructure.Security;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Booking;

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
        .WithOrigins("http://localhost:3000")
        .AllowAnyHeader()
        .AllowAnyMethod()));

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

// --- Map Controllers ---
app.MapControllers();

// --- Map endpoint cua tat ca module (Minimal API) ---
app.MapModuleEndpoints();

app.Run();

public partial class Program;
