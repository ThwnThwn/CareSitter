using CareSitter.Modules.Identity.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Identity.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/users")]
public sealed class AdminUsersController : ControllerBase
{
    private readonly IMediator _mediator;

    public AdminUsersController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpGet]
    public async Task<IActionResult> List(
        string? query = null, string? role = null, string? status = null,
        int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        var result = await _mediator.Send(
            new ListAdminUsersQuery(query, role, status, page, pageSize), ct);
        return result.ToActionResult(this);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetAdminUserQuery(id), ct);
        return result.ToActionResult(this);
    }

    [HttpPatch("{id:guid}/status")]
    public async Task<IActionResult> SetStatus(
        Guid id, [FromBody] AdminUserStatusRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new SetAdminUserStatusCommand(id, request.Status), ct);
        return result.ToActionResult(this);
    }

    [HttpPut("{id:guid}/roles")]
    public async Task<IActionResult> SetRoles(
        Guid id, [FromBody] AdminUserRolesRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new SetAdminUserRolesCommand(id, request.Roles), ct);
        return result.ToActionResult(this);
    }
}
