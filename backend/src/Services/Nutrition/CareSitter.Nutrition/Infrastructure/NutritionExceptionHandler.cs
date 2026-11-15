using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class NutritionExceptionHandler(ILogger<NutritionExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken ct)
    {
        if (exception is OperationCanceledException && context.RequestAborted.IsCancellationRequested) return false;
        logger.LogWarning("Nutrition request failed ({ErrorType}), trace {TraceId}.", exception.GetType().Name, context.TraceIdentifier);
        context.Response.StatusCode = 503;
        await context.Response.WriteAsJsonAsync(new ProblemDetails { Status = 503, Title = "nutrition.service_unavailable", Detail = "Dịch vụ tạm thời không khả dụng. Thông tin đã lưu vẫn được giữ." }, ct);
        return true;
    }
}
