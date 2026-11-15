using CareSitter.Modules.Support.Application.Diagnostics;
using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareSitter.Modules.Support.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/crash-reports")]
[EnableRateLimiting("crash-reports-read")]
public sealed class AdminCrashReportsController(CrashReportService service, IClock clock) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct, DateTimeOffset? until = null,
        int days = 7, int page = 1, int pageSize = 20, string? errorType = null)
    {
        Response.Headers.CacheControl = "no-store, private";
        var result = await service.ListAsync(new CrashReportFilter(until ?? clock.UtcNow, days,
            page, pageSize, string.IsNullOrEmpty(errorType) ? null : errorType), ct);
        return result.IsSuccess ? Ok(result.Value) : StatusCode(result.Error.Type switch {
            ErrorType.Validation => 400, ErrorType.Forbidden => 403, _ => 503
        }, new ProblemDetails { Title = result.Error.Code, Detail = result.Error.Message });
    }
}
