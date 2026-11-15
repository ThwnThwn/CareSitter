using CareSitter.Modules.People.Application.Commands.HealthProfile;
using CareSitter.Modules.People.Application.Queries.HealthProfile;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.People.Controllers;

[ApiController, Authorize(Roles = "CUSTOMER")]
[Route("api/v1/beneficiaries/{beneficiaryId:guid}/health-profile")]
public sealed class HealthProfileController(IMediator mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(Guid beneficiaryId, CancellationToken ct) =>
        (await mediator.Send(new GetHealthProfileQuery(beneficiaryId), ct)).ToActionResult(this);

    [HttpPatch, RequestSizeLimit(32 * 1024)]
    public async Task<IActionResult> Patch(Guid beneficiaryId, HealthProfileUpdateRequest request, CancellationToken ct) =>
        (await mediator.Send(new UpdateHealthProfileCommand(beneficiaryId, request.ExpectedHealthRevision, request.Changes), ct)).ToActionResult(this);
}
