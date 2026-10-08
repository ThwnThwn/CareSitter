using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Controllers.Contracts.Recovery.Requests;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareSitter.Modules.Identity.Controllers;

[ApiController]
[AllowAnonymous]
[Route("api/v1/auth/password-recovery")]
public sealed class PasswordRecoveryController(IMediator mediator) : ControllerBase
{
    [HttpPost("request")]
    [EnableRateLimiting("auth-recovery")]
    public async Task<IActionResult> RequestCode([FromBody] RequestPasswordRecoveryRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new RequestPasswordRecoveryCommand(request.Email), ct);
        if (result.IsFailure && result.Error.Code == "recovery.rate_limit")
        {
            Response.Headers.RetryAfter = "60";
            return StatusCode(429, new ProblemDetails { Title = result.Error.Code, Detail = result.Error.Message });
        }
        return result.ToActionResult(this, value => Accepted(value));
    }

    [HttpPost("verify")]
    [EnableRateLimiting("auth-recovery")]
    public async Task<IActionResult> Verify([FromBody] VerifyPasswordRecoveryRequest request, CancellationToken ct)
        => (await mediator.Send(new VerifyPasswordRecoveryCommand(request.ChallengeId, request.Code), ct)).ToActionResult(this);

    [HttpPost("reset")]
    [EnableRateLimiting("auth-recovery")]
    public async Task<IActionResult> Reset([FromBody] ResetPasswordRecoveryRequest request, CancellationToken ct)
        => (await mediator.Send(new ResetPasswordRecoveryCommand(request.ResetToken, request.NewPassword, request.ConfirmPassword), ct)).ToActionResult(this);
}
