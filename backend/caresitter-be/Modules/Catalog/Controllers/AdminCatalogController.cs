using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.Modules.Catalog.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/catalog/services")]
public sealed class AdminCatalogController(CatalogDbContext db, ICurrentUser currentUser) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var services = await db.ServiceTypes.AsNoTracking().OrderBy(x => x.Name).ToListAsync(ct);
        var serviceIds = services.Select(x => x.Id).ToArray();
        var prices = await db.PricingRules.AsNoTracking()
            .Where(x => serviceIds.Contains(x.ServiceTypeId))
            .OrderByDescending(x => x.EffectiveFrom)
            .ToListAsync(ct);

        return Ok(services.Select(service => new
        {
            service.Id,
            service.Code,
            service.Name,
            service.Description,
            service.DefaultDurationMinutes,
            service.IsActive,
            service.AllowAdHocTasks,
            PricingRules = prices.Where(x => x.ServiceTypeId == service.Id).Select(ToPricingResponse)
        }));
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] UpsertServiceRequest request, CancellationToken ct)
    {
        var code = request.Code?.Trim().ToUpperInvariant() ?? string.Empty;
        if (await db.ServiceTypes.AnyAsync(x => x.Code == code, ct))
            return Conflict(new { error = "Mã dịch vụ đã tồn tại." });

        var result = ServiceType.Create(code, request.Name, request.Description,
            request.DefaultDurationMinutes, request.IsActive);
        if (result.IsFailure) return BadRequest(new { error = result.Error.Message });
        db.ServiceTypes.Add(result.Value);
        await db.SaveChangesAsync(ct);
        return Created($"/api/v1/admin/catalog/services/{result.Value.Id}", ToServiceResponse(result.Value));
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpsertServiceRequest request, CancellationToken ct)
    {
        var service = await db.ServiceTypes.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (service is null) return NotFound();
        var code = request.Code?.Trim().ToUpperInvariant() ?? string.Empty;
        if (await db.ServiceTypes.AnyAsync(x => x.Id != id && x.Code == code, ct))
            return Conflict(new { error = "Mã dịch vụ đã tồn tại." });

        var result = service.Update(code, request.Name, request.Description, request.DefaultDurationMinutes);
        if (result.IsFailure) return BadRequest(new { error = result.Error.Message });
        service.SetActive(request.IsActive);
        await db.SaveChangesAsync(ct);
        return Ok(ToServiceResponse(service));
    }

    [HttpPatch("{id:guid}/active")]
    public async Task<IActionResult> SetActive(Guid id, [FromBody] SetCatalogActiveRequest request,
        CancellationToken ct)
    {
        var service = await db.ServiceTypes.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (service is null) return NotFound();
        service.SetActive(request.IsActive);
        await db.SaveChangesAsync(ct);
        return Ok(ToServiceResponse(service));
    }

    [HttpPost("{serviceId:guid}/pricing-rules")]
    public async Task<IActionResult> CreatePricing(Guid serviceId,
        [FromBody] UpsertPricingRuleRequest request, CancellationToken ct)
    {
        if (!await db.ServiceTypes.AnyAsync(x => x.Id == serviceId, ct)) return NotFound();
        var created = PricingRule.Create(request.Name, serviceId, request.BaseHourlyPrice,
            request.NightMultiplier, request.HolidayMultiplier, request.PlatformFeePercent,
            request.DisputeWindowHours, effectiveFrom: request.EffectiveFrom,
            effectiveTo: request.EffectiveTo, isActive: request.IsActive,
            createdByAdminId: currentUser.UserId);
        if (created.IsFailure) return BadRequest(new { error = created.Error.Message });
        var validation = created.Value.Update(request.Name, request.BaseHourlyPrice,
            request.NightMultiplier, request.HolidayMultiplier, request.PlatformFeePercent,
            request.DisputeWindowHours, request.EffectiveFrom, request.EffectiveTo);
        if (validation.IsFailure) return BadRequest(new { error = validation.Error.Message });

        db.PricingRules.Add(created.Value);
        await db.SaveChangesAsync(ct);
        return Created($"/api/v1/admin/catalog/services/{serviceId}/pricing-rules/{created.Value.Id}",
            ToPricingResponse(created.Value));
    }

    [HttpPut("{serviceId:guid}/pricing-rules/{ruleId:guid}")]
    public async Task<IActionResult> UpdatePricing(Guid serviceId, Guid ruleId,
        [FromBody] UpsertPricingRuleRequest request, CancellationToken ct)
    {
        var rule = await db.PricingRules.SingleOrDefaultAsync(
            x => x.Id == ruleId && x.ServiceTypeId == serviceId, ct);
        if (rule is null) return NotFound();
        var result = rule.Update(request.Name, request.BaseHourlyPrice,
            request.NightMultiplier, request.HolidayMultiplier, request.PlatformFeePercent,
            request.DisputeWindowHours, request.EffectiveFrom, request.EffectiveTo);
        if (result.IsFailure) return BadRequest(new { error = result.Error.Message });
        rule.SetActive(request.IsActive);
        await db.SaveChangesAsync(ct);
        return Ok(ToPricingResponse(rule));
    }

    [HttpPatch("{serviceId:guid}/pricing-rules/{ruleId:guid}/active")]
    public async Task<IActionResult> SetPricingActive(Guid serviceId, Guid ruleId,
        [FromBody] SetCatalogActiveRequest request, CancellationToken ct)
    {
        var rule = await db.PricingRules.SingleOrDefaultAsync(
            x => x.Id == ruleId && x.ServiceTypeId == serviceId, ct);
        if (rule is null) return NotFound();
        rule.SetActive(request.IsActive);
        await db.SaveChangesAsync(ct);
        return Ok(ToPricingResponse(rule));
    }

    private static object ToServiceResponse(ServiceType x) => new
    {
        x.Id, x.Code, x.Name, x.Description, x.DefaultDurationMinutes,
        x.IsActive, x.AllowAdHocTasks
    };

    private static object ToPricingResponse(PricingRule x) => new
    {
        x.Id, x.ServiceTypeId, x.Name, x.BaseHourlyPrice, x.NightMultiplier,
        x.HolidayMultiplier, x.PlatformFeePercent, x.DisputeWindowHours,
        x.EffectiveFrom, x.EffectiveTo, x.IsActive
    };
}

public sealed record UpsertServiceRequest(
    string Code,
    string Name,
    string? Description,
    int DefaultDurationMinutes = 60,
    bool IsActive = true);

public sealed record SetCatalogActiveRequest(bool IsActive);

public sealed record UpsertPricingRuleRequest(
    string Name,
    long BaseHourlyPrice,
    decimal NightMultiplier,
    decimal HolidayMultiplier,
    decimal PlatformFeePercent,
    int DisputeWindowHours,
    DateTimeOffset EffectiveFrom,
    DateTimeOffset? EffectiveTo,
    bool IsActive = true);
