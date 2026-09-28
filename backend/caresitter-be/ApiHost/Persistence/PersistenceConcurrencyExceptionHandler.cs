using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace CareSitter.ApiHost.Persistence;

public sealed class PersistenceConcurrencyExceptionHandler(
    ILogger<PersistenceConcurrencyExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var isOptimisticConcurrency = exception is DbUpdateConcurrencyException;
        var isScheduleExclusion = exception is DbUpdateException
        {
            InnerException: PostgresException
            {
                SqlState: PostgresErrorCodes.ExclusionViolation
            }
        };
        if (!isOptimisticConcurrency && !isScheduleExclusion)
            return false;

        logger.LogInformation(exception,
            "A concurrent request changed the resource before this request committed.");

        httpContext.Response.StatusCode = StatusCodes.Status409Conflict;
        await httpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = StatusCodes.Status409Conflict,
            Title = isScheduleExclusion
                ? "booking.schedule_conflict"
                : "concurrency.conflict",
            Detail = isScheduleExclusion
                ? "Lịch chăm sóc vừa bị trùng với một booking khác. Vui lòng chọn thời gian khác."
                : "Dữ liệu vừa được thay đổi bởi một yêu cầu khác. Vui lòng tải lại và thử lại."
        }, cancellationToken);

        return true;
    }
}
