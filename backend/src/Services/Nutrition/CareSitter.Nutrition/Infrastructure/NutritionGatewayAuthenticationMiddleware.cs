using System.Security.Cryptography;
using System.Text;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class NutritionGatewayAuthenticationMiddleware(RequestDelegate next, IConfiguration configuration)
{
    public async Task InvokeAsync(HttpContext context)
    {
        if (context.Request.Path.StartsWithSegments("/caresitter.nutrition.v1.NutritionRpc"))
        {
            var expected = configuration["Gateway:ServiceKey"] ?? "";
            var supplied = context.Request.Headers["X-Nutrition-Gateway-Key"].ToString();
            if (expected.Length is not (>= 32 and <= 256) || supplied.Length != expected.Length ||
                !CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(expected), Encoding.UTF8.GetBytes(supplied)))
            {
                GrpcFailure(context, "16", "nutrition.gateway_unauthorized");
                return;
            }
        }
        await next(context);
    }

    internal static void GrpcFailure(HttpContext context, string status, string message)
    {
        context.Response.StatusCode = 200;
        context.Response.ContentType = "application/grpc";
        context.Response.Headers["grpc-status"] = status;
        context.Response.Headers["grpc-message"] = Uri.EscapeDataString(message);
    }
}
