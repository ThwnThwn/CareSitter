using CareSitter.Contracts.Nutrition;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.People.Controllers;

[ApiController,Authorize(AuthenticationSchemes="NutritionService")]
[Route("internal/v1/nutrition/owners/{ownerId:guid}/beneficiaries/{beneficiaryId:guid}/health-profile")]
public sealed class InternalNutritionProfileController(IBeneficiaryHealthSnapshotReader reader) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(Guid ownerId,Guid beneficiaryId,CancellationToken ct)
    {
        var result=await reader.ReadAsync(ownerId,beneficiaryId,ct);
        return result is null?NotFound():Ok(result);
    }
}
