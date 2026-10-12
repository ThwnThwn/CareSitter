using CareSitter.Nutrition.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Nutrition.Controllers;

[ApiController, Authorize(Roles = "CUSTOMER"), Route("api/v1/nutrition/capabilities")]
public sealed class NutritionCapabilitiesController(IMediator mediator) : ControllerBase
{
    [HttpGet]
    public Task<NutritionCapabilitiesResponse> Get(CancellationToken ct) => mediator.Send(new NutritionCapabilitiesQuery(), ct);
}
