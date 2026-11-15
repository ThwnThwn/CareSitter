using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Consultations;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareSitter.Modules.Support.Controllers;

[ApiController]
[Route("api/v1/consultation-requests")]
public sealed class ConsultationRequestsController(IMediator mediator) : ControllerBase
{
    [HttpPost]
    [AllowAnonymous]
    [EnableRateLimiting("consultation-request")]
    [RequestSizeLimit(8192)]
    public async Task<IActionResult> Create([FromBody] ConsultationRequestBody body,
        [FromHeader(Name = "Idempotency-Key")] string? key, CancellationToken ct)
    {
        _ = Guid.TryParse(key, out var id);
        var result = await mediator.Send(new CreateConsultationRequest(id, body.ContactName,
            body.Phone, body.ServiceCategory, body.PreferredDate, body.Hours,
            body.CaregiverPreference, body.Note, body.Consent), ct);
        // Only a saved receipt is public; personal data is never echoed.
        return result.ToActionResult(this, receipt => Ok(receipt));
    }

    [HttpGet]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> List(int page = 1, int pageSize = 20,
        CancellationToken ct = default) =>
        (await mediator.Send(new ListConsultationRequests(page, pageSize), ct)).ToActionResult(this);
}

public sealed record ConsultationRequestBody(string? ContactName, string? Phone,
    string? ServiceCategory, DateOnly PreferredDate, int Hours,
    string? CaregiverPreference, string? Note, bool Consent);
