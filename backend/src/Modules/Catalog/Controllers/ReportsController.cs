using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareSitter.Modules.Catalog.Controllers;

[ApiController]
[Authorize]
[Route("api/v1")]
[EnableRateLimiting("media-read")]
public sealed class ReportsController(ReportService service, FirebaseReportService firebase,
    ICurrentUser currentUser, IActiveUserLookup activeUsers) : ControllerBase
{
    [HttpPost("bookings/{bookingId:guid}/reports/firebase-session")]
    [Authorize(Roles = "CUSTOMER")]
    public async Task<IActionResult> FirebaseSession(Guid bookingId, [FromBody] PrepareFirebaseReport request, CancellationToken ct)
    {
        PrivateHeaders();
        if (currentUser.UserId is not { } owner ||
            !await activeUsers.IsActiveWithAnyRoleAsync(owner, currentUser.Roles, ct)) return Forbid();
        if (!long.TryParse(User.FindFirst("exp")?.Value, out var expires)) return Unauthorized();
        var result = await firebase.PrepareAsync(bookingId, request, expires * 1000, ct);
        return result.IsSuccess ? Ok(result.Value) : Failure(result.Error);
    }
    [HttpPost("reports/{reportId:guid}/firebase-completion")]
    [Authorize(Roles = "CUSTOMER")]
    public async Task<IActionResult> FirebaseCompletion(Guid reportId, CancellationToken ct)
    {
        PrivateHeaders();
        var result = await firebase.CompleteAsync(reportId, ct);
        return result.IsSuccess ? Ok(result.Value) : Failure(result.Error);
    }
    [HttpPost("bookings/{bookingId:guid}/reports")]
    [Authorize(Roles = "CUSTOMER")]
    [RequestSizeLimit(ReportPdfPolicy.MaxBytes + 65536)]
    [RequestFormLimits(MultipartBodyLengthLimit = ReportPdfPolicy.MaxBytes + 65536)]
    public async Task<IActionResult> Upload(Guid bookingId, [FromForm] IFormFile file,
        [FromHeader(Name = "Idempotency-Key")] string key, CancellationToken ct)
    {
        PrivateHeaders();
        if (!Guid.TryParse(key, out var idempotencyKey) || file.Length is <= 0 or > ReportPdfPolicy.MaxBytes ||
            file.ContentType != "application/pdf" || !file.FileName.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase))
            return BadRequest(new ProblemDetails { Title = "report.invalid_pdf", Detail = "Cần tệp PDF tối đa 10 MB và Idempotency-Key hợp lệ." });
        await using var stream = file.OpenReadStream();
        using var buffer = new MemoryStream();
        await stream.CopyToAsync(buffer, ct);
        var result = await service.UploadAsync(bookingId, idempotencyKey, buffer.ToArray(), ct);
        return result.IsSuccess ? Ok(result.Value) : Failure(result.Error);
    }
    [HttpGet("bookings/{bookingId:guid}/reports")]
    public async Task<IActionResult> List(Guid bookingId, CancellationToken ct, int page = 1, int pageSize = 20)
    {
        PrivateHeaders();
        var result = await service.ListAsync(bookingId, page, pageSize, ct);
        return result.IsSuccess ? Ok(result.Value) : Failure(result.Error);
    }
    [HttpGet("reports/{reportId:guid}/content")]
    public async Task<IActionResult> Content(Guid reportId, CancellationToken ct)
    {
        PrivateHeaders();
        var result = await service.ReadAsync(reportId, ct);
        return result.IsSuccess ? File(result.Value, "application/pdf", "caresitter-report.pdf") : Failure(result.Error);
    }
    private void PrivateHeaders()
    {
        Response.Headers.CacheControl = "no-store, private";
        Response.Headers.Pragma = "no-cache";
        Response.Headers["X-Content-Type-Options"] = "nosniff";
        Response.Headers["Content-Security-Policy"] = "default-src 'none'; sandbox";
        Response.Headers["Referrer-Policy"] = "no-referrer";
    }
    private IActionResult Failure(Error error) => StatusCode(error.Type switch {
        ErrorType.Unauthorized => 401, ErrorType.Forbidden => 403, ErrorType.NotFound => 404,
        ErrorType.Validation => 400, ErrorType.Conflict => 409, ErrorType.Unavailable => 503, _ => 500
    }, new ProblemDetails { Title = error.Code, Detail = error.Message });
}
