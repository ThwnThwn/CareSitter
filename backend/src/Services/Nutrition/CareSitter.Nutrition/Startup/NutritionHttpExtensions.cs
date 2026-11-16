using System.Security.Claims;
using System.Threading.RateLimiting;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Controllers.Grpc;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Options;
using Npgsql;

namespace CareSitter.Nutrition.Startup;

internal static class NutritionHttpExtensions
{
    public static void AddNutritionHttp(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddControllers();
        services.AddExceptionHandler<NutritionExceptionHandler>();
        services.AddProblemDetails();
        var origins = configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
        services.AddCors(options => options.AddDefaultPolicy(policy =>
        {
            if (origins.Length > 0)
                policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod();
        }));
        services.AddRateLimiter(o =>
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
    }

    public static void UseNutritionPipeline(this WebApplication app)
    {
        app.UseExceptionHandler();
        app.UseCors();
        app.UseMiddleware<NutritionGatewayAuthenticationMiddleware>();
        app.UseAuthentication();
        app.UseAuthorization();
        app.UseRateLimiter();
    }

    public static void MapNutritionEndpoints(this WebApplication app, LocalDemoCatalogOptions localDemoCatalog)
    {
        app.MapGet("/health/live", () => Results.Ok(new { status = "up" })).AllowAnonymous();
        app.MapGet("/health/ready", async (NpgsqlDataSource db, INutritionFeatures features,
            IOptions<MealGroundingOptions> groundingOptions, IMealKnowledgeRetriever retriever, CancellationToken ct) =>
        {
            var requirePublishedCatalog = features.RecommendationsEnabled && !localDemoCatalog.Enabled;
            var grounding = await MealGroundingReadiness.CheckAsync(groundingOptions, retriever, ct);
            if (!grounding.Available)
                return Results.Json(new { status = "unavailable", grounding = grounding.Status,
                    groundingReasons = grounding.Reasons }, statusCode: 503);
            var databaseReady = await NutritionDatabaseReadiness.CheckAsync(db, ct, requirePublishedCatalog);
            if (databaseReady && requirePublishedCatalog &&
                await MealGroundingReadiness.CatalogPolicyFailureAsync(db, groundingOptions.Value.AllowNonMedicalReference, ct) is { } policyFailure)
                return Results.Json(new { status = "unavailable", grounding = "grounding unavailable",
                    groundingReasons = new[] { policyFailure } }, statusCode: 503);
            return Results.Json(new { status = databaseReady && grounding.Available ? "ready" : "unavailable",
                grounding = grounding.Status, groundingReasons = grounding.Reasons },
                statusCode: databaseReady && grounding.Available ? 200 : 503);
        }).AllowAnonymous();
        app.MapControllers();
        app.MapGrpcService<NutritionRpcService>();
    }
}
