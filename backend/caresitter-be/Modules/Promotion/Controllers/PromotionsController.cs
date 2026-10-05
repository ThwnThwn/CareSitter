using CareSitter.Modules.Promotion.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Promotion.Controllers;

[ApiController]
[Route("api/v1/promotions")]
public sealed class PromotionsController : ControllerBase
{
    private readonly IMediator _mediator;

    public PromotionsController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> List(CancellationToken ct) =>
        Ok(await _mediator.Send(new ListActivePromotionsQuery(), ct));

    [HttpGet("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetActivePromotionQuery(id), ct);
        return result is null ? NotFound() : Ok(result);
    }

    [Authorize(Roles = "CUSTOMER,ADMIN")]
    [HttpPost("preview")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Preview(
        [FromBody] PromotionPreviewRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new PreviewPromotionCommand(request.Code,
            request.ServiceTypeId, request.ScheduledStart, request.ScheduledEnd), ct);
        return result.ToActionResult(this);
    }
}
