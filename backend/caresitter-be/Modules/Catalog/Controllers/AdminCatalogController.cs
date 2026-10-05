using CareSitter.Modules.Catalog.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Catalog.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/catalog/services")]
public sealed class AdminCatalogController : ControllerBase
{
    private readonly IMediator _mediator;

    public AdminCatalogController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) =>
        Ok(await _mediator.Send(new ListAdminServicesQuery(), ct));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] UpsertServiceRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new CreateServiceCommand(
            request.Code, request.Name, request.Description,
            request.DefaultDurationMinutes, request.IsActive), ct);
        return result.ToActionResult(this,
            value => Created($"/api/v1/admin/catalog/services/{value.Id}", value));
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpsertServiceRequest request,
        CancellationToken ct)
    {
        var result = await _mediator.Send(new UpdateServiceCommand(
            id, request.Code, request.Name, request.Description,
            request.DefaultDurationMinutes, request.IsActive), ct);
        return result.ToActionResult(this);
    }

    [HttpPatch("{id:guid}/active")]
    public async Task<IActionResult> SetActive(Guid id, [FromBody] SetCatalogActiveRequest request,
        CancellationToken ct)
    {
        var result = await _mediator.Send(new SetServiceActiveCommand(id, request.IsActive), ct);
        return result.ToActionResult(this);
    }

    [HttpPost("{serviceId:guid}/pricing-rules")]
    public async Task<IActionResult> CreatePricing(Guid serviceId,
        [FromBody] UpsertPricingRuleRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(ToCreatePricingCommand(serviceId, request), ct);
        return result.ToActionResult(this,
            value => Created(
                $"/api/v1/admin/catalog/services/{serviceId}/pricing-rules/{value.Id}", value));
    }

    [HttpPut("{serviceId:guid}/pricing-rules/{ruleId:guid}")]
    public async Task<IActionResult> UpdatePricing(Guid serviceId, Guid ruleId,
        [FromBody] UpsertPricingRuleRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new UpdatePricingRuleCommand(
            serviceId, ruleId, request.Name, request.BaseHourlyPrice,
            request.NightMultiplier, request.HolidayMultiplier, request.PlatformFeePercent,
            request.DisputeWindowHours, request.EffectiveFrom, request.EffectiveTo,
            request.IsActive), ct);
        return result.ToActionResult(this);
    }

    [HttpPatch("{serviceId:guid}/pricing-rules/{ruleId:guid}/active")]
    public async Task<IActionResult> SetPricingActive(Guid serviceId, Guid ruleId,
        [FromBody] SetCatalogActiveRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(
            new SetPricingRuleActiveCommand(serviceId, ruleId, request.IsActive), ct);
        return result.ToActionResult(this);
    }

    private static CreatePricingRuleCommand ToCreatePricingCommand(
        Guid serviceId, UpsertPricingRuleRequest request) => new(
        serviceId, request.Name, request.BaseHourlyPrice,
        request.NightMultiplier, request.HolidayMultiplier, request.PlatformFeePercent,
        request.DisputeWindowHours, request.EffectiveFrom, request.EffectiveTo,
        request.IsActive);
}
