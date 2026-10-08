using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Controllers.Contracts.Recovery.Requests;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareSitter.Modules.Identity.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/profile/recovery-email")]
public sealed class RecoveryEmailController(IMediator mediator) : ControllerBase
{
    [HttpPost("request")]
    [EnableRateLimiting("auth-recovery")]
    public async Task<IActionResult> RequestCode([FromBody] RequestRecoveryEmailRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new RequestRecoveryEmailCommand(request.NewEmail, request.CurrentPassword), ct);
        if (result.IsFailure && result.Error.Code == "recovery.rate_limit")
        {
            Response.Headers.RetryAfter = "60";
            return StatusCode(429, new ProblemDetails { Title = result.Error.Code, Detail = result.Error.Message });
        }
        return result.ToActionResult(this, value => Accepted(value));
    }
    [HttpPost("confirm")]
    [EnableRateLimiting("auth-recovery")]
    public async Task<IActionResult> Confirm([FromBody] ConfirmRecoveryEmailRequest request, CancellationToken ct)
        => (await mediator.Send(new ConfirmRecoveryEmailCommand(request.ChallengeId, request.Code), ct)).ToActionResult(this);
}
