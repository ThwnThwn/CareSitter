using CareSitter.ApiHost.Security;
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
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
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
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("crm");

app.MapGet("/health", () => Results.Ok(new { status = "ok" })).WithTags("System");

// --- Map endpoint cua tat ca module ---
app.MapModuleEndpoints();

app.Run();

public partial class Program;
