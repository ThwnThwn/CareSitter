using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Catalog.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Controllers;

/// <summary>Quản trị checklist mẫu áp dụng cho các booking mới của từng gói dịch vụ.</summary>
[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/services/{serviceTypeId:guid}/checklist-templates")]
public sealed class AdminChecklistTemplatesController(
    BookingDbContext bookingDb,
    CatalogDbContext catalogDb) : ControllerBase
{
    [HttpPatch("/api/v1/admin/services/{serviceTypeId:guid}/checklist-policy")]
    public async Task<IActionResult> SetPolicy(Guid serviceTypeId, [FromBody] ChecklistPolicyRequest request,
        CancellationToken ct)
    {
        var service = await catalogDb.ServiceTypes.SingleOrDefaultAsync(x => x.Id == serviceTypeId, ct);
        if (service is null) return NotFound();
        service.SetAllowAdHocTasks(request.AllowAdHocTasks);
        await catalogDb.SaveChangesAsync(ct);
        return Ok(new { service.Id, service.AllowAdHocTasks });
    }

    [HttpGet]
    public async Task<IActionResult> List(Guid serviceTypeId, CancellationToken ct)
    {
        if (!await catalogDb.ServiceTypes.AnyAsync(x => x.Id == serviceTypeId, ct))
            return NotFound();

        var templates = await bookingDb.PackageTaskTemplates.AsNoTracking()
            .Where(x => x.ServiceTypeId == serviceTypeId)
            .OrderBy(x => x.SortOrder).ThenBy(x => x.Name)
            .ToListAsync(ct);
        return Ok(templates.Select(ToResponse));
    }

    [HttpPost]
    public async Task<IActionResult> Create(Guid serviceTypeId, [FromBody] UpsertChecklistTemplateRequest request,
        CancellationToken ct)
    {
        var validation = Validate(request);
        if (validation is not null) return BadRequest(new { error = validation });
        if (!await catalogDb.ServiceTypes.AnyAsync(x => x.Id == serviceTypeId, ct))
            return NotFound();
        if (await bookingDb.PackageTaskTemplates.AnyAsync(x => x.ServiceTypeId == serviceTypeId && x.Name == request.Name.Trim(), ct))
            return Conflict(new { error = "Checklist của gói đã có công việc cùng tên." });

        var template = PackageTaskTemplate.Create(serviceTypeId, request.Name, request.Description,
            request.IsRequired, request.RequiresPhoto, request.SortOrder);
        bookingDb.PackageTaskTemplates.Add(template);
        await bookingDb.SaveChangesAsync(ct);
        return Created($"/api/v1/admin/services/{serviceTypeId}/checklist-templates/{template.Id}", ToResponse(template));
    }

    [HttpPut("{templateId:guid}")]
    public async Task<IActionResult> Update(Guid serviceTypeId, Guid templateId,
        [FromBody] UpsertChecklistTemplateRequest request, CancellationToken ct)
    {
        var validation = Validate(request);
        if (validation is not null) return BadRequest(new { error = validation });
        var template = await bookingDb.PackageTaskTemplates.SingleOrDefaultAsync(
            x => x.Id == templateId && x.ServiceTypeId == serviceTypeId, ct);
        if (template is null) return NotFound();
        if (await bookingDb.PackageTaskTemplates.AnyAsync(
                x => x.ServiceTypeId == serviceTypeId && x.Id != templateId && x.Name == request.Name.Trim(), ct))
            return Conflict(new { error = "Checklist của gói đã có công việc cùng tên." });

        template.Update(request.Name, request.Description, request.IsRequired, request.RequiresPhoto, request.SortOrder);
        await bookingDb.SaveChangesAsync(ct);
        return Ok(ToResponse(template));
    }

    [HttpPatch("{templateId:guid}/active")]
    public async Task<IActionResult> SetActive(Guid serviceTypeId, Guid templateId,
        [FromBody] SetChecklistTemplateActiveRequest request, CancellationToken ct)
    {
        var template = await bookingDb.PackageTaskTemplates.SingleOrDefaultAsync(
            x => x.Id == templateId && x.ServiceTypeId == serviceTypeId, ct);
        if (template is null) return NotFound();
        template.SetActive(request.IsActive);
        await bookingDb.SaveChangesAsync(ct);
        return Ok(ToResponse(template));
    }

    [HttpDelete("{templateId:guid}")]
    public async Task<IActionResult> Delete(Guid serviceTypeId, Guid templateId, CancellationToken ct)
    {
        var template = await bookingDb.PackageTaskTemplates.SingleOrDefaultAsync(
            x => x.Id == templateId && x.ServiceTypeId == serviceTypeId, ct);
        if (template is null) return NotFound();
        bookingDb.PackageTaskTemplates.Remove(template);
        await bookingDb.SaveChangesAsync(ct);
        return NoContent();
    }

    private static string? Validate(UpsertChecklistTemplateRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name) || request.Name.Trim().Length is < 3 or > 255)
            return "Tên công việc phải có từ 3 đến 255 ký tự.";
        if (request.Description?.Trim().Length > 1000)
            return "Mô tả công việc tối đa 1000 ký tự.";
        if (request.SortOrder is < 0 or > 1000)
            return "Thứ tự phải nằm trong khoảng từ 0 đến 1000.";
        return null;
    }

    private static ChecklistTemplateResponse ToResponse(PackageTaskTemplate template) => new(
        template.Id, template.ServiceTypeId, template.Name, template.Description,
        template.IsRequired, template.RequiresPhoto, template.SortOrder, template.IsActive);
}

public sealed record UpsertChecklistTemplateRequest(string Name, string? Description,
    bool IsRequired, bool RequiresPhoto, int SortOrder);
public sealed record SetChecklistTemplateActiveRequest(bool IsActive);
public sealed record ChecklistPolicyRequest(bool AllowAdHocTasks);
public sealed record ChecklistTemplateResponse(Guid Id, Guid ServiceTypeId, string Name,
    string? Description, bool IsRequired, bool RequiresPhoto, int SortOrder, bool IsActive);
