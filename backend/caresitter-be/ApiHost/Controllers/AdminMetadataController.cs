using CareSitter.ApiHost.Application.Admin;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.ApiHost.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/metadata")]
public sealed class AdminMetadataController : ControllerBase
{
    private readonly IMediator _mediator;

    public AdminMetadataController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetAdminMetadataQuery(), ct);
        return result is null ? Unauthorized() : Ok(result);
    }
}
