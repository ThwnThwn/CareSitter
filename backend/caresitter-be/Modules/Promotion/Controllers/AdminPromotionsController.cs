using CareSitter.Modules.Promotion.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Promotion.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/promotions")]
public sealed class AdminPromotionsController(IMediator mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] string? status,
        CancellationToken ct, [FromQuery] int page = 1, [FromQuery] int pageSize = 20) =>
        (await mediator.Send(new ListAdminPromotionsQuery(search, status, page, pageSize), ct)).ToActionResult(this);

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new GetAdminPromotionQuery(id), ct);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] UpsertAdminPromotionRequest request, CancellationToken ct) =>
        (await mediator.Send(new CreateAdminPromotionCommand(request.ToConfiguration()), ct))
        .ToActionResult(this, value => Created($"/api/v1/admin/promotions/{value.Id}", value));

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpsertAdminPromotionRequest request, CancellationToken ct) =>
        (await mediator.Send(new UpdateAdminPromotionCommand(id, request.ToConfiguration(),
            request.ExpectedUpdatedAt ?? default), ct)).ToActionResult(this);

    [HttpPatch("{id:guid}/active")]
    public async Task<IActionResult> SetActive(Guid id, [FromBody] SetAdminPromotionActiveRequest request, CancellationToken ct) =>
        (await mediator.Send(new SetAdminPromotionActiveCommand(id, request.IsActive,
            request.ExpectedUpdatedAt), ct)).ToActionResult(this);

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, [FromBody] DeleteAdminPromotionRequest request, CancellationToken ct) =>
        (await mediator.Send(new DeleteAdminPromotionCommand(id, request.ExpectedUpdatedAt), ct))
        .ToActionResult(this, _ => NoContent());
}
