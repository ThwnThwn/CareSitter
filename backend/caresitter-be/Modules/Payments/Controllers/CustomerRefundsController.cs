using CareSitter.Modules.Payments.Application.Refunds;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Payments.Controllers;

[ApiController]
[Authorize(Roles = "CUSTOMER")]
[Route("api/v1/refunds")]
public sealed class CustomerRefundsController(IMediator mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(
        int page = 1,
        int pageSize = 20,
        CancellationToken ct = default)
    {
        var result = await mediator.Send(new ListMyRefundsQuery(page, pageSize), ct);
        return result.ToActionResult(this);
    }
}
