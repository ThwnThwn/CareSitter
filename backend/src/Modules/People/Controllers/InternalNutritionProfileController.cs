using CareSitter.Modules.People.Application.Queries.HealthProfile;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.People.Controllers;

[ApiController]
[Authorize(AuthenticationSchemes = "NutritionService")]
[Route("internal/v1/nutrition/owners/{ownerId:guid}/beneficiaries/{beneficiaryId:guid}/health-profile")]
public sealed class InternalNutritionProfileController(ISender sender) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(Guid ownerId, Guid beneficiaryId, CancellationToken ct)
    {
        var result = await sender.Send(new GetNutritionHealthSnapshotQuery(ownerId, beneficiaryId), ct);
        return result is null ? NotFound() : Ok(result);
    }
}
