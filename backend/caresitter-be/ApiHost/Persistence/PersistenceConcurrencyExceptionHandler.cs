using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.ApiHost.Persistence;

public sealed class PersistenceConcurrencyExceptionHandler(
    ILogger<PersistenceConcurrencyExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not DbUpdateConcurrencyException)
            return false;

        logger.LogInformation(exception,
            "A concurrent request changed the resource before this request committed.");

        httpContext.Response.StatusCode = StatusCodes.Status409Conflict;
        await httpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = StatusCodes.Status409Conflict,
            Title = "concurrency.conflict",
            Detail = "Dữ liệu vừa được thay đổi bởi một yêu cầu khác. Vui lòng tải lại và thử lại."
        }, cancellationToken);

        return true;
    }
}
