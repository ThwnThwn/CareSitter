using CareSitter.Modules.Support.Application.Queries.Diagnostics;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareSitter.Modules.Support.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/crash-reports")]
[EnableRateLimiting("crash-reports-read")]
public sealed class AdminCrashReportsController(ISender sender) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct, DateTimeOffset? until = null,
        int days = 7, int page = 1, int pageSize = 20, string? errorType = null)
    {
        Response.Headers.CacheControl = "no-store, private";
        var result = await sender.Send(new ListCrashReportsQuery(until, days, page, pageSize, errorType), ct);
        return result.IsSuccess ? Ok(result.Value) : StatusCode(result.Error.Type switch {
            ErrorType.Validation => 400, ErrorType.Forbidden => 403, _ => 503
        }, new ProblemDetails { Title = result.Error.Code, Detail = result.Error.Message });
    }
}
